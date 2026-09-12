/// Temporary classroom-project mode. Set to true to restore subscriptions.
/// This does not grant or write a Firebase entitlement.
const bool proSubscriptionEnabled = false;

/// Only for client-side gates (photos, statistics and rankings).
/// Firestore still enforces friend limits and profile customization permissions;
/// those gates must continue to use the user's actual isPro value.
bool hasClientProAccess(bool isPro) => !proSubscriptionEnabled || isPro;
