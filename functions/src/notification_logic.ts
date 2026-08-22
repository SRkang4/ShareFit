export const WAKE_UP_COOLDOWN_MS = 10 * 60 * 1000;

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
