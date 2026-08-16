class PhotoExpiration {
  const PhotoExpiration._();

  static const retention = Duration(days: 30);

  static bool isValid({
    required String? photoUrl,
    required DateTime? expiresAt,
    DateTime? now,
  }) {
    final normalizedUrl = photoUrl?.trim();
    if (normalizedUrl == null || normalizedUrl.isEmpty || expiresAt == null) {
      return false;
    }
    return expiresAt.isAfter(now ?? DateTime.now());
  }

  static String? validUrl({
    required String? photoUrl,
    required DateTime? expiresAt,
    DateTime? now,
  }) {
    if (!isValid(photoUrl: photoUrl, expiresAt: expiresAt, now: now)) {
      return null;
    }
    return photoUrl!.trim();
  }
}
