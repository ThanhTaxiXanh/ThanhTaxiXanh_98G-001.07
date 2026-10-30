import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/device_location_service.dart';
import '../data/osm_map_repository.dart';
import '../domain/map_models.dart';

final mapRepositoryProvider = Provider<MapRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return OsmMapRepository(client);
});
final locationServiceProvider = Provider<LocationService>(
  (ref) => DeviceLocationService(),
);

class MapSessionState {
  const MapSessionState({
    this.fix,
    this.destination,
    this.route,
    this.traffic,
    this.gpsActive = false,
    this.requestingGps = false,
    this.loadingRoute = false,
    this.loadingTraffic = false,
    this.follow = false,
    this.is3D = true,
    this.message,
    this.trafficMessage,
    this.carNavigationActive = false,
  });
  final GpsFix? fix;
  final MapPlace? destination;
  final RoutePlan? route;
  final TrafficSnapshot? traffic;
  final bool gpsActive,
      requestingGps,
      loadingRoute,
      loadingTraffic,
      follow,
      is3D;
  final String? message, trafficMessage;
  final bool carNavigationActive;
  MapSessionState copy({
    GpsFix? fix,
    MapPlace? destination,
    RoutePlan? route,
    TrafficSnapshot? traffic,
    bool? gpsActive,
    bool? requestingGps,
    bool? loadingRoute,
    bool? loadingTraffic,
    bool? follow,
    bool? is3D,
    String? message,
    String? trafficMessage,
    bool clearFix = false,
    bool clearRoute = false,
    bool clearDestination = false,
    bool clearMessage = false,
    bool clearTrafficMessage = false,
    bool? carNavigationActive,
  }) => MapSessionState(
    fix: clearFix ? null : fix ?? this.fix,
    destination: clearDestination ? null : destination ?? this.destination,
    route: clearRoute ? null : route ?? this.route,
    traffic: traffic ?? this.traffic,
    gpsActive: gpsActive ?? this.gpsActive,
    requestingGps: requestingGps ?? this.requestingGps,
    loadingRoute: loadingRoute ?? this.loadingRoute,
    loadingTraffic: loadingTraffic ?? this.loadingTraffic,
    follow: follow ?? this.follow,
    is3D: is3D ?? this.is3D,
    message: clearMessage ? null : message ?? this.message,
    trafficMessage: clearTrafficMessage
        ? null
        : trafficMessage ?? this.trafficMessage,
    carNavigationActive: carNavigationActive ?? this.carNavigationActive,
  );
}

final mapSessionProvider =
    NotifierProvider.autoDispose<MapSession, MapSessionState>(MapSession.new);

class MapSession extends Notifier<MapSessionState> {
  StreamSubscription<GpsFix>? _subscription;
  int _gpsGeneration = 0, _routeGeneration = 0;
  DateTime? _lastTrafficAttempt;
  GeoPoint? _lastTrafficPoint;

  @override
  MapSessionState build() {
    ref.onDispose(() {
      _gpsGeneration++;
      _routeGeneration++;
      unawaited(_subscription?.cancel());
    });
    return const MapSessionState();
  }

  String _friendly(Object error, String fallback) =>
      error is MapServiceException ? error.message : fallback;

  Future<void> enableGps({bool backgroundNavigation = false}) async {
    if (state.requestingGps) return;
    if (state.gpsActive &&
        (!backgroundNavigation || state.carNavigationActive)) {
      state = state.copy(follow: true);
      return;
    }
    if (state.gpsActive) pauseGps();
    final generation = ++_gpsGeneration;
    final service = ref.read(locationServiceProvider);
    state = state.copy(requestingGps: true, clearFix: true, clearMessage: true);
    try {
      await service.ensureReady(allowPermissionRequest: !backgroundNavigation);
      if (!ref.mounted || generation != _gpsGeneration) return;
      state = state.copy(
        requestingGps: false,
        gpsActive: true,
        follow: true,
        carNavigationActive: backgroundNavigation,
      );
      _subscription = service
          .watch(backgroundNavigation: backgroundNavigation)
          .listen(
            (fix) {
              if (!ref.mounted || generation != _gpsGeneration) return;
              state = state.copy(fix: fix, gpsActive: true);
              unawaited(refreshTraffic());
            },
            onError: (Object error) {
              if (!ref.mounted || generation != _gpsGeneration) return;
              unawaited(_subscription?.cancel());
              state = state.copy(
                gpsActive: false,
                requestingGps: false,
                carNavigationActive: false,
                message: _friendly(
                  error,
                  'Chưa nhận được vị trí GPS. Vui lòng thử lại.',
                ),
              );
            },
          );
    } catch (error) {
      if (ref.mounted && generation == _gpsGeneration) {
        state = state.copy(
          requestingGps: false,
          gpsActive: false,
          message: _friendly(
            error,
            'Không thể bật vị trí GPS. Vui lòng thử lại.',
          ),
        );
      }
    }
  }

  void pauseGps() {
    _gpsGeneration++;
    unawaited(_subscription?.cancel());
    _subscription = null;
    state = state.copy(
      gpsActive: false,
      requestingGps: false,
      follow: false,
      clearFix: true,
      carNavigationActive: false,
    );
  }

  void stopFollowing() {
    if (state.follow) state = state.copy(follow: false);
  }

  void toggle3D() => state = state.copy(is3D: !state.is3D);

  void selectDestination(MapPlace place) {
    if (!place.point.isValid) return;
    _routeGeneration++;
    state = state.copy(
      destination: place,
      clearRoute: true,
      clearMessage: true,
      loadingRoute: false,
      follow: false,
    );
  }

  void clearDestination() {
    _routeGeneration++;
    state = state.copy(
      clearDestination: true,
      clearRoute: true,
      loadingRoute: false,
      clearMessage: true,
    );
  }

  Future<void> fetchRoute() async {
    final fix = state.fix;
    final destination = state.destination;
    if (!state.gpsActive || fix == null || destination == null) {
      state = state.copy(
        message: 'Bật GPS và chọn điểm đến trước khi xem tuyến đường.',
      );
      return;
    }
    final generation = ++_routeGeneration;
    final repo = ref.read(mapRepositoryProvider);
    state = state.copy(
      loadingRoute: true,
      clearMessage: true,
      clearRoute: true,
    );
    try {
      final route = await repo.route(fix.point, destination.point);
      if (ref.mounted && generation == _routeGeneration) {
        state = state.copy(route: route, loadingRoute: false, follow: false);
      }
    } catch (error) {
      if (ref.mounted && generation == _routeGeneration) {
        state = state.copy(
          loadingRoute: false,
          message: _friendly(
            error,
            'Không tải được tuyến đường. Kiểm tra mạng rồi thử lại.',
          ),
        );
      }
    }
  }

  Future<void> refreshTraffic({bool manual = false}) async {
    final fix = state.fix;
    if (fix == null || !state.gpsActive || state.loadingTraffic) return;
    final last = _lastTrafficAttempt;
    final now = DateTime.now();
    if (last != null) {
      final age = now.difference(last);
      if (age < const Duration(seconds: 30) ||
          (!manual &&
              (age < const Duration(minutes: 2) ||
                  (_lastTrafficPoint!.distanceTo(fix.point) < 250 &&
                      age < const Duration(minutes: 5))))) {
        return;
      }
    }
    _lastTrafficAttempt = now;
    _lastTrafficPoint = fix.point;
    final repo = ref.read(mapRepositoryProvider);
    state = state.copy(loadingTraffic: true, clearTrafficMessage: true);
    try {
      final traffic = await repo.traffic(fix.point);
      if (ref.mounted) {
        state = state.copy(traffic: traffic, loadingTraffic: false);
      }
    } catch (_) {
      if (ref.mounted) {
        state = state.copy(
          loadingTraffic: false,
          trafficMessage:
              'Không tải được dữ liệu OSM mới. Kiểm tra mạng rồi thử lại sau.',
        );
      }
    }
  }
}
