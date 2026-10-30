import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_auto/app/app.dart';

void main() {
  testWidgets('the initial companion screen starts without layout errors', (
    tester,
  ) async {
    for (final size in [const Size(400, 800), const Size(1280, 720)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: TaxiAutoApp()));
      await tester.pumpAndSettle();

      expect(find.text('Thanh Taxi Xanh'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
