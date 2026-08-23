export const WAKE_UP_COOLDOWN_MS = 10 * 60 * 1000;

export type NotificationKind =
  | "wake_up"
  | "friend_request"
  | "friend_request_accepted";

export function isNotificationEnabled(
  kind: NotificationKind,
  preferences: Record<string, unknown> | undefined,
): boolean {
  const preferenceKey = {
    wake_up: "wakeUp",
    friend_request: "friendRequest",
    friend_request_accepted: "friendAccepted",
  }[kind];
  return preferences?.[preferenceKey] !== false;
}

export function shouldNotifyFriendRequest(data: Record<string, unknown>): boolean {
  return data.status === "pending" &&
    typeof data.fromUid === "string" &&
    typeof data.toUid === "string" &&
    data.fromUid !== data.toUid;
}

export function shouldNotifyFriendAccepted(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
): boolean {
  return before.status === "pending" &&
    after.status === "accepted" &&
    before.fromUid === after.fromUid &&
    before.toUid === after.toUid;
}

export function isWakeUpCooldownActive(
  lastSentMillis: number | null,
  nowMillis: number,
): boolean {
  return lastSentMillis !== null &&
    nowMillis - lastSentMillis < WAKE_UP_COOLDOWN_MS;
}
