import {getApps, initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore, Timestamp} from "firebase-admin/firestore";
import {getMessaging, Message} from "firebase-admin/messaging";
import {logger} from "firebase-functions";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import {createHash} from "node:crypto";

import {
  isWakeUpCooldownActive,
  shouldNotifyFriendAccepted,
  shouldNotifyFriendRequest,
  WAKE_UP_COOLDOWN_MS,
} from "./notification_logic";

if (getApps().length === 0) initializeApp();

const db = getFirestore();
const messaging = getMessaging();
const region = "asia-northeast3";
const channelId = "sharefit_social_notifications";

type NotificationKind = "wake_up" | "friend_request" | "friend_request_accepted";

function eventDocumentId(kind: string, eventId: string): string {
  return `${kind}_${createHash("sha256").update(eventId).digest("hex")}`;
}

async function profileName(uid: string): Promise<string> {
  const snapshot = await db.collection("publicProfiles").doc(uid).get();
  const name = snapshot.data()?.name;
  return typeof name === "string" && name.trim().length > 0 ? name.trim() : "친구";
}

function isPermanentTokenError(code: string | undefined): boolean {
  return code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token";
}

async function sendToUser(
  uid: string,
  kind: NotificationKind,
  senderUid: string,
  body: string,
): Promise<number> {
  const tokensSnapshot = await db
    .collection("users")
    .doc(uid)
    .collection("fcmTokens")
    .limit(20)
    .get();
  const entries = tokensSnapshot.docs
    .map((document) => ({document, token: document.data().token}))
    .filter((entry): entry is {document: FirebaseFirestore.QueryDocumentSnapshot; token: string} =>
      typeof entry.token === "string" && entry.token.length > 0,
    );
  if (entries.length === 0) return 0;

  const baseMessage: Omit<Message, "token"> = {
    notification: {title: "ShareFit", body},
    data: {type: kind, senderUid},
    android: {
      priority: "high",
      notification: {channelId, sound: "default"},
    },
    apns: {
      payload: {aps: {sound: "default"}},
    },
  };
  const response = await messaging.sendEach(
    entries.map((entry) => ({...baseMessage, token: entry.token})),
  );
  const cleanup = db.batch();
  let hasCleanup = false;
  response.responses.forEach((result, index) => {
    if (!result.success && isPermanentTokenError(result.error?.code)) {
      cleanup.delete(entries[index].document.ref);
      hasCleanup = true;
    }
  });
  if (hasCleanup) await cleanup.commit();
  return response.successCount;
}

async function claimEvent(eventId: string): Promise<boolean> {
  const ref = db.collection("notificationEvents").doc(eventId);
  return db.runTransaction(async (transaction) => {
    if ((await transaction.get(ref)).exists) return false;
    transaction.create(ref, {createdAt: FieldValue.serverTimestamp()});
    return true;
  });
}

async function releaseEvent(eventId: string): Promise<void> {
  await db.collection("notificationEvents").doc(eventId).delete();
}

export const notifyFriendRequest = onDocumentCreated(
  {document: "friendRequests/{requestId}", region},
  async (event) => {
    const data = event.data?.data();
    if (!data || !shouldNotifyFriendRequest(data)) return;
    const eventId = eventDocumentId("request", event.id);
    if (!(await claimEvent(eventId))) return;
    try {
      const senderUid = data.fromUid as string;
      const targetUid = data.toUid as string;
      const senderName = await profileName(senderUid);
      await sendToUser(
        targetUid,
        "friend_request",
        senderUid,
        `${senderName}님이 친구 요청을 보냈어요.`,
      );
    } catch (error) {
      await releaseEvent(eventId);
      logger.error("친구 요청 알림 전송 실패", error);
      throw error;
    }
  },
);

export const notifyFriendAccepted = onDocumentUpdated(
  {document: "friendRequests/{requestId}", region},
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || !shouldNotifyFriendAccepted(before, after)) return;
    const eventId = eventDocumentId("accepted", event.id);
    if (!(await claimEvent(eventId))) return;
    try {
      const senderUid = after.toUid as string;
      const targetUid = after.fromUid as string;
      const senderName = await profileName(senderUid);
      await sendToUser(
        targetUid,
        "friend_request_accepted",
        senderUid,
        `${senderName}님이 친구 요청을 수락했어요.`,
      );
    } catch (error) {
      await releaseEvent(eventId);
      logger.error("친구 수락 알림 전송 실패", error);
      throw error;
    }
  },
);

export const sendWakeUp = onCall({region}, async (request) => {
  const senderUid = request.auth?.uid;
  if (senderUid == null) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  const targetUid = request.data?.targetUid;
  if (typeof targetUid !== "string" || targetUid.length === 0 || targetUid === senderUid) {
    throw new HttpsError("invalid-argument", "올바른 친구를 선택해주세요.");
  }

  const friendship = await db
    .collection("users")
    .doc(senderUid)
    .collection("friends")
    .doc(targetUid)
    .get();
  if (!friendship.exists) {
    throw new HttpsError("permission-denied", "친구에게만 깨우기를 보낼 수 있습니다.");
  }
  const [senderProfile, targetProfile] = await Promise.all([
    db.collection("publicProfiles").doc(senderUid).get(),
    db.collection("publicProfiles").doc(targetUid).get(),
  ]);
  if (senderProfile.data()?.active !== true || targetProfile.data()?.active !== true) {
    throw new HttpsError("not-found", "사용 가능한 친구를 찾을 수 없습니다.");
  }

  const cooldownRef = db
    .collection("notificationCooldowns")
    .doc(senderUid)
    .collection("targets")
    .doc(targetUid);
  const requestId = db.collection("notificationEvents").doc().id;
  const now = Timestamp.now();
  await db.runTransaction(async (transaction) => {
    const cooldown = await transaction.get(cooldownRef);
    const lastSentAt = cooldown.data()?.lastSentAt;
    const lastSentMillis = lastSentAt instanceof Timestamp ? lastSentAt.toMillis() : null;
    if (isWakeUpCooldownActive(lastSentMillis, now.toMillis())) {
      const remainingSeconds = Math.ceil(
        (WAKE_UP_COOLDOWN_MS - (now.toMillis() - (lastSentMillis ?? 0))) / 1000,
      );
      throw new HttpsError(
        "resource-exhausted",
        "같은 친구에게는 10분에 한 번만 보낼 수 있습니다.",
        {remainingSeconds},
      );
    }
    transaction.set(cooldownRef, {senderUid, targetUid, lastSentAt: now, requestId});
  });

  try {
    const senderName = await profileName(senderUid);
    const sentCount = await sendToUser(
      targetUid,
      "wake_up",
      senderUid,
      `${senderName}님이 운동을 하자고 해요.`,
    );
    if (sentCount === 0) throw new HttpsError("not-found", "알림을 받을 기기가 없습니다.");
    return {sent: true};
  } catch (error) {
    await db.runTransaction(async (transaction) => {
      const cooldown = await transaction.get(cooldownRef);
      if (cooldown.data()?.requestId === requestId) transaction.delete(cooldownRef);
    });
    if (error instanceof HttpsError) throw error;
    logger.error("깨우기 알림 전송 실패", error);
    throw new HttpsError("internal", "깨우기를 보내지 못했습니다.");
  }
});
