import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/models/photo_expiration.dart';

void main() {
  final now = DateTime.utc(2026, 8, 16, 12);

  group('PhotoExpiration', () {
    test('future expiry keeps a non-empty URL valid', () {
      expect(
        PhotoExpiration.validUrl(
          photoUrl: ' https://example.com/photo.jpg ',
          expiresAt: now.add(const Duration(seconds: 1)),
          now: now,
        ),
        'https://example.com/photo.jpg',
      );
    });

    test('expired or exactly expiring photos are invalid', () {
      expect(
        PhotoExpiration.isValid(
          photoUrl: 'https://example.com/photo.jpg',
          expiresAt: now,
          now: now,
        ),
        isFalse,
      );
      expect(
        PhotoExpiration.isValid(
          photoUrl: 'https://example.com/photo.jpg',
          expiresAt: now.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('legacy photos without expiry metadata are invalid', () {
      expect(
        PhotoExpiration.isValid(
          photoUrl: 'https://example.com/photo.jpg',
          expiresAt: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('null, empty, and whitespace URLs are invalid', () {
      for (final url in <String?>[null, '', '   ']) {
        expect(
          PhotoExpiration.isValid(
            photoUrl: url,
            expiresAt: now.add(const Duration(days: 1)),
            now: now,
          ),
          isFalse,
        );
      }
    });
  });
}
