import 'package:geolocator/geolocator.dart';

import '../error/exceptions.dart';
import '../utils/geo_point.dart';

/// Abstracts "where is the user right now" so the feature layer never talks
/// to `geolocator` directly.
abstract class LocationService {
  Future<GeoPoint> currentLocation();
}

/// Real implementation backed by the device GPS.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<GeoPoint> currentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationException('Điện thoại đang tắt định vị (GPS).');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationException('Ứng dụng chưa được cấp quyền vị trí.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Quyền vị trí bị từ chối vĩnh viễn — bật lại trong Cài đặt.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return GeoPoint(lat: position.latitude, lon: position.longitude);
  }
}

/// Fake used for local dev, demos and tests: always returns the same point
/// so the app is runnable with zero platform permission setup.
class FixedLocationService implements LocationService {
  const FixedLocationService(this.point);

  final GeoPoint point;

  @override
  Future<GeoPoint> currentLocation() async => point;
}
