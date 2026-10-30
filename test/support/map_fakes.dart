import 'dart:async';

import 'package:taxi_auto/features/map/domain/map_models.dart';

class FakeMapRepository implements MapRepository {
  int searches = 0, routes = 0, trafficRequests = 0;
  Completer<RoutePlan>? delayedRoute;
  bool failTraffic = false;
  RoutePlan get sampleRoute => const RoutePlan(
    points: [GeoPoint(21, 105), GeoPoint(21.01, 105.01)],
    distanceMeters: 1000,
    durationSeconds: 300,
    steps: [
      RouteStep(
        name: 'Đường thử nghiệm',
        type: 'turn',
        modifier: 'right',
        distance: 100,
      ),
    ],
  );
  @override
  Future<List<MapPlace>> search(String query) async {
    searches++;
    return const [MapPlace('Điểm đến thử nghiệm', GeoPoint(21.01, 105.01))];
  }

  @override
  Future<RoutePlan> route(GeoPoint from, GeoPoint to) async {
    routes++;
    return delayedRoute == null ? sampleRoute : await delayedRoute!.future;
  }

  @override
  Future<TrafficSnapshot> traffic(GeoPoint point) async {
    trafficRequests++;
    if (failTraffic) throw const MapServiceException('Offline');
    return TrafficSnapshot(point, const [], DateTime.now().toUtc());
  }
}

class FakeLocationService implements LocationService {
  final positions = StreamController<GpsFix>.broadcast(sync: true);
  bool denied = false;
  int permissions = 0;
  bool? backgroundRequested;
  @override
  Future<void> ensureReady({bool allowPermissionRequest = true}) async {
    permissions++;
    if (denied) throw const MapServiceException('Vị trí bị từ chối.');
  }

  @override
  Stream<GpsFix> watch({bool backgroundNavigation = false}) {
    backgroundRequested = backgroundNavigation;
    return positions.stream;
  }

  void sendFix() => positions.add(
    GpsFix(
      point: const GeoPoint(21, 105),
      accuracyMeters: 5,
      recordedAt: DateTime.now().toUtc(),
      speedMetersPerSecond: 10,
    ),
  );
}
