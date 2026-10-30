import 'package:geolocator/geolocator.dart';

import '../domain/map_models.dart';

class DeviceLocationService implements LocationService {
  @override
  Future<void> ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const MapServiceException(
        'Hãy bật dịch vụ vị trí trên điện thoại rồi thử lại.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const MapServiceException(
        'Chưa có quyền vị trí. Bạn có thể cấp quyền trong cài đặt ứng dụng.',
      );
    }
  }

  @override
  Stream<GpsFix> watch() =>
      Geolocator.getPositionStream(
            locationSettings: AndroidSettings(
              accuracy: LocationAccuracy.high,
              forceLocationManager: true,
              timeLimit: const Duration(seconds: 30),
              distanceFilter: 0,
              intervalDuration: const Duration(seconds: 2),
            ),
          )
          .where((p) => GeoPoint(p.latitude, p.longitude).isValid)
          .map(
            (p) => GpsFix(
              point: GeoPoint(p.latitude, p.longitude),
              accuracyMeters: p.accuracy,
              recordedAt: p.timestamp.toUtc(),
              speedMetersPerSecond: p.speed,
              heading: p.heading.isFinite && p.heading >= 0 ? p.heading : null,
            ),
          );
}
