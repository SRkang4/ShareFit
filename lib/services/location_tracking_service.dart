import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationTrackingFailureType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  positionUnavailable,
}

class LocationTrackingException implements Exception {
  const LocationTrackingException(this.type);

  final LocationTrackingFailureType type;
}

class LocationTrackingService {
  StreamSubscription<Position>? _positionSubscription;

  Future<void> start({
    required void Function(Position position) onPosition,
    required void Function(Object error) onError,
  }) async {
    await stop();
    await _ensureLocationAccess();

    final locationSettings = _createLocationSettings();

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          onPosition,
          onError: (Object error) {
            onError(
              const LocationTrackingException(
                LocationTrackingFailureType.positionUnavailable,
              ),
            );
          },
        );
  }

  Future<void> stop() async {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();
  }

  Future<void> dispose() => stop();

  LocationSettings _createLocationSettings() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          intervalDuration: const Duration(seconds: 3),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'ShareFit 러닝 추적 중',
            notificationText: '백그라운드에서도 러닝 거리와 시간을 측정하고 있어요.',
            enableWakeLock: true,
            setOngoing: true,
          ),
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: LocationAccuracy.best,
          activityType: ActivityType.fitness,
          distanceFilter: 5,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        );
    }
  }

  Future<void> _ensureLocationAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationTrackingException(
        LocationTrackingFailureType.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationTrackingException(
        LocationTrackingFailureType.permissionDeniedForever,
      );
    }

    if (permission == LocationPermission.denied) {
      throw const LocationTrackingException(
        LocationTrackingFailureType.permissionDenied,
      );
    }
  }
}
