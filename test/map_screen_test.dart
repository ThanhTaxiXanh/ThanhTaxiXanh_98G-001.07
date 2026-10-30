import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_auto/features/map/presentation/driving_map.dart';
import 'package:taxi_auto/features/map/presentation/map_providers.dart';
import 'package:taxi_auto/features/map/presentation/native_map_surface.dart';

import 'support/map_fakes.dart';

void main() {
  testWidgets(
    'map controls support GPS, explicit search, route preview and directions',
    (tester) async {
      final repo = FakeMapRepository();
      final location = FakeLocationService();
      addTearDown(location.positions.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapRepositoryProvider.overrideWithValue(repo),
            locationServiceProvider.overrideWithValue(location),
            mapSurfaceBuilderProvider.overrideWithValue(
              (_) => const ColoredBox(color: Colors.blueGrey),
            ),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('GPS đang tắt'), findsOneWidget);
      expect(location.permissions, 0);
      await tester.tap(find.byKey(const Key('enable-gps')));
      await tester.pumpAndSettle();
      location.sendFix();
      await tester.pumpAndSettle();
      expect(find.text('36 km/h'), findsOneWidget);
      await tester.tap(find.byKey(const Key('toggle-map-3d')));
      await tester.pumpAndSettle();
      expect(find.text('2D'), findsOneWidget);
      await tester.tap(find.byKey(const Key('open-place-search')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('place-query')),
        'Địa điểm thử',
      );
      expect(repo.searches, 0);
      await tester.tap(find.byKey(const Key('search-places')));
      await tester.pumpAndSettle();
      expect(repo.searches, 1);
      await tester.tap(find.text('Điểm đến thử nghiệm'));
      await tester.pumpAndSettle();
      final preview = find.byKey(const Key('preview-route'));
      await tester.ensureVisible(preview);
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(find.textContaining('1.0 km'), findsOneWidget);
      final directions = find.text('Hướng đi');
      await tester.ensureVisible(directions);
      await tester.tap(directions);
      await tester.pumpAndSettle();
      expect(find.text('Rẽ phải vào Đường thử nghiệm'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrivingMap)),
        listen: false,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(container.read(mapSessionProvider).gpsActive, isFalse);
      expect(container.read(mapSessionProvider).fix, isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(container.read(mapSessionProvider).gpsActive, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
