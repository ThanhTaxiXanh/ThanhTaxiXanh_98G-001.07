import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_auto/features/map/domain/map_models.dart';
import 'package:taxi_auto/features/map/presentation/map_providers.dart';

import 'support/map_fakes.dart';

void main() {
  late FakeMapRepository repo;
  late FakeLocationService location;
  late ProviderContainer container;
  setUp(() {
    repo = FakeMapRepository();
    location = FakeLocationService();
    container = ProviderContainer(
      overrides: [
        mapRepositoryProvider.overrideWithValue(repo),
        locationServiceProvider.overrideWithValue(location),
      ],
    );
    container.listen(mapSessionProvider, (_, _) {});
  });
  tearDown(() async {
    container.dispose();
    await location.positions.close();
  });

  test(
    'permission is requested only on enable and pausing clears the GPS fix',
    () async {
      final controller = container.read(mapSessionProvider.notifier);
      expect(location.permissions, 0);
      expect(repo.trafficRequests, 0);
      await controller.enableGps();
      location.sendFix();
      await Future<void>.delayed(Duration.zero);
      expect(location.permissions, 1);
      expect(container.read(mapSessionProvider).fix!.speedKmh, 36);
      expect(repo.trafficRequests, 1);
      controller.pauseGps();
      expect(container.read(mapSessionProvider).gpsActive, isFalse);
      expect(container.read(mapSessionProvider).fix, isNull);
      location.sendFix();
      expect(container.read(mapSessionProvider).fix, isNull);
    },
  );

  test('denied GPS leaves a usable map and a readable error', () async {
    location.denied = true;
    await container.read(mapSessionProvider.notifier).enableGps();
    final state = container.read(mapSessionProvider);
    expect(state.gpsActive, isFalse);
    expect(state.requestingGps, isFalse);
    expect(state.message, 'Vị trí bị từ chối.');
    expect(repo.trafficRequests, 0);
  });

  test('an old route result cannot replace a newer destination', () async {
    final controller = container.read(mapSessionProvider.notifier);
    await controller.enableGps();
    location.sendFix();
    await Future<void>.delayed(Duration.zero);
    controller.selectDestination(const MapPlace('A', GeoPoint(21.01, 105.01)));
    repo.delayedRoute = Completer<RoutePlan>();
    final pending = controller.fetchRoute();
    controller.selectDestination(const MapPlace('B', GeoPoint(21.02, 105.02)));
    repo.delayedRoute!.complete(repo.sampleRoute);
    await pending;
    final state = container.read(mapSessionProvider);
    expect(state.destination!.name, 'B');
    expect(state.route, isNull);
    expect(state.loadingRoute, isFalse);
  });

  test(
    'routing requires an active GPS fix and service failures stay visible',
    () async {
      final controller = container.read(mapSessionProvider.notifier);
      controller.selectDestination(
        const MapPlace('A', GeoPoint(21.01, 105.01)),
      );
      await controller.fetchRoute();
      expect(repo.routes, 0);
      expect(container.read(mapSessionProvider).message, contains('Bật GPS'));
      repo.failTraffic = true;
      await controller.enableGps();
      location.sendFix();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(mapSessionProvider).trafficMessage,
        contains('Không tải được'),
      );
      expect(container.read(mapSessionProvider).loadingTraffic, isFalse);
      controller.stopFollowing();
      expect(container.read(mapSessionProvider).follow, isFalse);
      controller.toggle3D();
      expect(container.read(mapSessionProvider).is3D, isFalse);
    },
  );
}
