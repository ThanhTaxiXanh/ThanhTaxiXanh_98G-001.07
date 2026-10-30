import 'dart:math' as math;

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
  List<double> get coordinates => [longitude, latitude];

  double distanceTo(GeoPoint other) {
    const rad = math.pi / 180;
    final dLat = (other.latitude - latitude) * rad;
    final dLon = (other.longitude - longitude) * rad;
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(latitude * rad) *
            math.cos(other.latitude * rad) *
            math.pow(math.sin(dLon / 2), 2);
    return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }
}

class GpsFix {
  const GpsFix({
    required this.point,
    required this.accuracyMeters,
    required this.recordedAt,
    this.speedMetersPerSecond,
    this.heading,
  });
  final GeoPoint point;
  final double accuracyMeters;
  final DateTime recordedAt;
  final double? speedMetersPerSecond;
  final double? heading;
  double? get speedKmh {
    final value = speedMetersPerSecond;
    return value != null && value.isFinite && value >= 0 ? value * 3.6 : null;
  }
}

class MapPlace {
  const MapPlace(this.name, this.point);
  final String name;
  final GeoPoint point;
}

class RouteStep {
  const RouteStep({
    required this.name,
    required this.type,
    required this.distance,
    this.modifier = '',
  });
  final String name;
  final String type;
  final String modifier;
  final double distance;
  String get instruction {
    if (type == 'depart') {
      return 'Bắt đầu ${name.isEmpty ? '' : 'trên $name'}'.trim();
    }
    if (type == 'arrive') return 'Đến điểm đích';
    if (type == 'roundabout' || type == 'rotary') return 'Đi qua vòng xuyến';
    final direction = switch (modifier) {
      'left' || 'slight left' || 'sharp left' => 'Rẽ trái',
      'right' || 'slight right' || 'sharp right' => 'Rẽ phải',
      'uturn' => 'Quay đầu',
      _ => 'Đi tiếp',
    };
    return '$direction${name.isEmpty ? '' : ' vào $name'}';
  }
}

class RoutePlan {
  const RoutePlan({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
  });
  final List<GeoPoint> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;
}

class TrafficFeature {
  const TrafficFeature({
    required this.id,
    required this.point,
    required this.label,
    required this.isSpeedTag,
  });
  final String id;
  final GeoPoint point;
  final String label;

  /// A road-center maxspeed tag is not a matched speed limit for the current road.
  final bool isSpeedTag;
}

class TrafficSnapshot {
  const TrafficSnapshot(this.center, this.features, this.fetchedAt);
  final GeoPoint center;
  final List<TrafficFeature> features;
  final DateTime fetchedAt;
  List<TrafficFeature> nearby(GeoPoint point) =>
      features.where((f) => f.point.distanceTo(point) <= 1000).toList()..sort(
        (a, b) =>
            a.point.distanceTo(point).compareTo(b.point.distanceTo(point)),
      );
}

class MapServiceException implements Exception {
  const MapServiceException(this.message);
  final String message;
}

abstract interface class MapRepository {
  Future<List<MapPlace>> search(String query);
  Future<RoutePlan> route(GeoPoint from, GeoPoint to);
  Future<TrafficSnapshot> traffic(GeoPoint point);
}

abstract interface class LocationService {
  Future<void> ensureReady();
  Stream<GpsFix> watch();
}

String formatDistance(double meters) => meters >= 1000
    ? '${(meters / 1000).toStringAsFixed(1)} km'
    : '${meters.round()} m';
