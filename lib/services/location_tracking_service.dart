import 'dart:async';

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

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

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
