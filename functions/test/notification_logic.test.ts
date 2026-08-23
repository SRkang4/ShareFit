import assert from "node:assert/strict";
import test from "node:test";

import {
  isNotificationEnabled,
  isWakeUpCooldownActive,
  shouldNotifyFriendAccepted,
  shouldNotifyFriendRequest,
  WAKE_UP_COOLDOWN_MS,
} from "../src/notification_logic";

test("notification preferences default to enabled and only explicit false disables", () => {
  assert.equal(isNotificationEnabled("wake_up", undefined), true);
  assert.equal(isNotificationEnabled("friend_request", {}), true);
  assert.equal(isNotificationEnabled("wake_up", {wakeUp: false}), false);
  assert.equal(isNotificationEnabled("friend_request", {friendRequest: false}), false);
  assert.equal(
    isNotificationEnabled("friend_request_accepted", {friendAccepted: false}),
    false,
  );
});

test("pending friend request only", () => {
  assert.equal(shouldNotifyFriendRequest({status: "pending", fromUid: "a", toUid: "b"}), true);
  assert.equal(shouldNotifyFriendRequest({status: "accepted", fromUid: "a", toUid: "b"}), false);
  assert.equal(shouldNotifyFriendRequest({status: "pending", fromUid: "a", toUid: "a"}), false);
});

test("accepted transition only", () => {
  assert.equal(
    shouldNotifyFriendAccepted(
      {status: "pending", fromUid: "a", toUid: "b"},
      {status: "accepted", fromUid: "a", toUid: "b"},
    ),
    true,
  );
  assert.equal(
    shouldNotifyFriendAccepted(
      {status: "accepted", fromUid: "a", toUid: "b"},
      {status: "accepted", fromUid: "a", toUid: "b"},
    ),
    false,
  );
});

test("wake-up cooldown is ten minutes", () => {
  const now = 1_000_000;
  assert.equal(isWakeUpCooldownActive(null, now), false);
  assert.equal(isWakeUpCooldownActive(now - WAKE_UP_COOLDOWN_MS + 1, now), true);
  assert.equal(isWakeUpCooldownActive(now - WAKE_UP_COOLDOWN_MS, now), false);
});
