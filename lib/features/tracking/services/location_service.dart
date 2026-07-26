import 'package:geolocator/geolocator.dart';

enum LocationServiceFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class LocationServiceException implements Exception {
  const LocationServiceException(this.failure);

  final LocationServiceFailure failure;
}

class LocationService {
  static const updateInterval = Duration(seconds: 5);

  Future<void> ensureReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException(
        LocationServiceFailure.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return;
      case LocationPermission.deniedForever:
        throw const LocationServiceException(
          LocationServiceFailure.permissionDeniedForever,
        );
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        throw const LocationServiceException(
          LocationServiceFailure.permissionDenied,
        );
    }
  }

  Stream<Position> getPositionStream() {
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      intervalDuration: updateInterval,
    );

    return Geolocator.getPositionStream(locationSettings: settings);
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
