import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_auto/features/settings/presentation/layout_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'layout changes survive reopening and reject unusable row sizes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = ProviderContainer();
      await first.read(layoutSettingsProvider.future);
      await first
          .read(layoutSettingsProvider.notifier)
          .save(DashboardLayout(30, 45, 25));
      first.dispose();
      final second = ProviderContainer();
      addTearDown(second.dispose);
      expect((await second.read(layoutSettingsProvider.future)).toJson(), {
        'calendar': 30,
        'payment': 45,
        'media': 25,
      });
      expect(() => DashboardLayout(0, 50, 50), throwsArgumentError);
      expect(() => DashboardLayout(30, 30, 30), throwsArgumentError);
    },
  );
  test('malformed stored layout safely uses the QR preset', () async {
    SharedPreferences.setMockInitialValues({LayoutSettings.key: '{broken'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      (await container.read(layoutSettingsProvider.future)).toJson(),
      DashboardLayout.qr.toJson(),
    );
    expect(
      DashboardLayout.read({'calendar': -1}).toJson(),
      DashboardLayout.qr.toJson(),
    );
  });
}
