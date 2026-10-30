import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_auto/features/media/domain/youtube_location.dart';
import 'package:taxi_auto/features/media/domain/youtube_settings.dart';
import 'package:taxi_auto/features/media/presentation/youtube_browser.dart';
import 'package:taxi_auto/features/media/presentation/youtube_providers.dart';
import 'package:taxi_auto/features/media/presentation/youtube_screen.dart';

void main() {
  testWidgets(
    'passenger browser searches, filters, handles history and fullscreen',
    (tester) async {
      final settings = _MemorySettings();
      late _Browser browser;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            youTubeSettingsRepositoryProvider.overrideWithValue(settings),
            youTubeBrowserFactoryProvider.overrideWithValue((callbacks) {
              browser = _Browser(callbacks);
              return browser;
            }),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const YouTubeScreen(),
                    ),
                  ),
                  child: const Text('Mở YouTube'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở YouTube'));
      await tester.pumpAndSettle();
      expect(browser.locations.single, YouTubeLocation.home);
      expect(browser.filtering, isTrue);

      await tester.enterText(
        find.byKey(const Key('youtube-search')),
        'nhạc Việt',
      );
      await tester.tap(find.byKey(const Key('youtube-submit')));
      await tester.pumpAndSettle();
      expect(
        browser.locations.last.queryParameters['search_query'],
        'nhạc Việt',
      );
      await tester.tap(find.byKey(const Key('youtube-filter')));
      await tester.pumpAndSettle();
      expect(browser.filtering, isFalse);
      expect(settings.value.filterAds, isFalse);

      final count = browser.locations.length;
      await tester.enterText(
        find.byKey(const Key('youtube-search')),
        'https://evil.example',
      );
      await tester.tap(find.byKey(const Key('youtube-submit')));
      await tester.pumpAndSettle();
      expect(browser.locations, hasLength(count));
      expect(find.text('Chỉ nhận liên kết HTTPS của YouTube.'), findsOneWidget);

      browser.callbacks.onFullscreen(
        const ColoredBox(key: Key('fullscreen-video'), color: Colors.black),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fullscreen-video')), findsOneWidget);
      expect(find.byKey(const Key('youtube-search')), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fullscreen-video')), findsNothing);
      expect(find.text('YouTube • Khách'), findsOneWidget);
      await tester.tap(find.byKey(const Key('youtube-back')));
      await tester.pumpAndSettle();
      expect(browser.backCalls, 1);
      expect(find.text('YouTube • Khách'), findsOneWidget);
      await tester.tap(find.byKey(const Key('youtube-back')));
      await tester.pumpAndSettle();
      expect(find.text('Mở YouTube'), findsOneWidget);
      expect(browser.closed, isTrue);
    },
  );

  testWidgets(
    'load errors can retry, backgrounding pauses and narrow layouts fit',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late _Browser browser;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            youTubeSettingsRepositoryProvider.overrideWithValue(
              _MemorySettings(),
            ),
            youTubeBrowserFactoryProvider.overrideWithValue((callbacks) {
              browser = _Browser(callbacks);
              return browser;
            }),
          ],
          child: const MaterialApp(home: YouTubeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      browser.callbacks.onError('Không tải được YouTube.');
      await tester.pumpAndSettle();
      expect(find.text('Không tải được YouTube.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('youtube-reload')));
      await tester.pumpAndSettle();
      expect(browser.reloads, 1);
      expect(find.text('Không tải được YouTube.'), findsNothing);
      final pauses = browser.pauses;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(browser.pauses, greaterThan(pauses));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      for (final size in [const Size(800, 480), const Size(1280, 720)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('browser-test-surface')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}

class _MemorySettings implements YouTubeSettingsRepository {
  YouTubeSettings value = const YouTubeSettings();
  @override
  Future<YouTubeSettings> load() async => value;
  @override
  Future<void> save(YouTubeSettings settings) async => value = settings;
}

class _Browser implements YouTubeBrowser {
  _Browser(this.callbacks);
  final YouTubeBrowserCallbacks callbacks;
  final locations = <Uri>[];
  bool filtering = true, closed = false;
  int backCalls = 0, pauses = 0, reloads = 0;
  @override
  Widget buildView(BuildContext context) =>
      const ColoredBox(key: Key('browser-test-surface'), color: Colors.white);
  @override
  Future<void> initialize(Uri location) => load(location);
  @override
  Future<void> load(Uri location) async {
    locations.add(location);
    callbacks.onProgress(100);
    callbacks.onLocation(location);
    callbacks.onReady();
  }

  @override
  Future<bool> canGoBack() async => locations.length > 1;
  @override
  Future<void> goBack() async {
    backCalls++;
    locations.removeLast();
    callbacks.onLocation(locations.last);
  }

  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> reload() async => reloads++;
  @override
  Future<void> setFiltering(bool enabled) async => filtering = enabled;
  @override
  void exitFullscreen() => callbacks.onFullscreen(null);
  @override
  void close() => closed = true;
}
