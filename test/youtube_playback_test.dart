import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_auto/features/media/data/youtube_history_repository.dart';
import 'package:taxi_auto/features/media/domain/youtube_media.dart';
import 'package:taxi_auto/features/media/presentation/youtube_audio_handler.dart';
import 'package:taxi_auto/features/media/presentation/youtube_providers.dart';
import 'package:taxi_auto/features/media/presentation/youtube_browser.dart';
import 'package:taxi_auto/features/media/presentation/youtube_session.dart';
import 'support/media_fakes.dart';

YouTubeMedia video(String id, {bool playing = true}) => YouTubeMedia(
  id: id,
  title: 'Bài hát $id',
  artist: 'Kênh thử nghiệm',
  playing: playing,
  position: const Duration(seconds: 12),
  duration: const Duration(minutes: 4),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late FakePipController pip;
  late MemoryYouTubeHistory history;
  late FakeYouTubeBrowser browser;
  setUp(() {
    pip = FakePipController();
    history = MemoryYouTubeHistory();
    container = ProviderContainer(
      overrides: [
        pipControllerProvider.overrideWithValue(pip),
        youTubeHistoryRepositoryProvider.overrideWithValue(history),
        youTubeSettingsRepositoryProvider.overrideWithValue(
          MemoryYouTubeSettings(),
        ),
        youTubeBrowserFactoryProvider.overrideWithValue((callbacks) {
          browser = FakeYouTubeBrowser(callbacks);
          return browser;
        }),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    pip.dispose();
  });

  test(
    'backgrounding and leaving the video route preserve the session by default',
    () async {
      final session = container.read(youTubeSessionProvider.notifier);
      await session.ensureInitialized();
      browser.report(video('abcdefghijk'));
      final pauses = browser.pauses;
      session.setVisible(true);
      session.didChangeAppLifecycleState(AppLifecycleState.inactive);
      session.didChangeAppLifecycleState(AppLifecycleState.paused);
      session.setVisible(false);
      await Future<void>.delayed(Duration.zero);
      expect(browser.pauses, pauses);
      expect(browser.closed, isFalse);
      expect(container.read(youTubeSessionProvider).media?.playing, isTrue);
      expect(pip.configurations.last['visible'], isFalse);

      await container
          .read(youTubeSettingsProvider.notifier)
          .setBackgroundAudio(false);
      session.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(browser.pauses, pauses + 1);
      expect(container.read(youTubeSessionProvider).media?.playing, isFalse);
    },
  );

  test(
    'PiP uses compact content, restores it on exit and handles unsupported devices',
    () async {
      final session = container.read(youTubeSessionProvider.notifier);
      await session.ensureInitialized();
      session.setVisible(true);
      browser.report(video('abcdefghijk'));
      await session.enterPip();
      expect(container.read(youTubeSessionProvider).inPip, isTrue);
      expect(browser.compacts.last, isTrue);
      pip.states.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(youTubeSessionProvider).inPip, isFalse);
      expect(browser.compacts.last, isFalse);
      pip.supported = false;
      await session.enterPip();
      expect(browser.compacts.last, isFalse);
      expect(
        container.read(youTubeSessionProvider).message,
        contains('PiP chưa khả dụng'),
      );
    },
  );

  test(
    'media browser exposes real history and media-session commands reach the player',
    () async {
      final session = container.read(youTubeSessionProvider.notifier);
      final handler = TaxiAudioHandler(session);
      session.attachHandler(handler);
      await session.ensureInitialized();
      expect(handler.playbackState.value.playing, isFalse);
      browser.report(video('abcdefghijk'));
      await Future<void>.delayed(Duration.zero);
      expect(handler.mediaItem.value?.title, 'Bài hát abcdefghijk');
      expect(handler.playbackState.value.playing, isTrue);
      final root = await handler.getChildren(AudioService.browsableRootId);
      expect(root.single.id, 'recent');
      final recent = await handler.getChildren('recent');
      expect(recent.single.id, 'youtube:abcdefghijk');
      expect(recent.single.duration, const Duration(minutes: 4));
      await handler.pause();
      expect(browser.pauses, greaterThan(0));
      expect(handler.playbackState.value.playing, isFalse);
      await handler.play();
      expect(browser.plays, 1);
      // A play request alone must not fabricate successful playback.
      expect(handler.playbackState.value.playing, isFalse);
      await handler.seek(const Duration(seconds: 42));
      expect(browser.seekPosition, const Duration(seconds: 42));
      await handler.stop();
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.idle,
      );
    },
  );

  test(
    'browser playback and transport controls do not claim competing focus',
    () async {
      final calls = <String>[];
      const channel = MethodChannel('com.ryanheise.audio_session');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final session = container.read(youTubeSessionProvider.notifier);
      final handler = TaxiAudioHandler(session);
      session.attachHandler(handler);
      await handler.initializeAudioEvents();
      await session.ensureInitialized();
      browser.report(video('abcdefghijk'));
      await Future<void>.delayed(Duration.zero);
      expect(browser.pauses, 0);
      expect(handler.playbackState.value.playing, isTrue);
      await handler.pause();
      await handler.play();
      browser.report(video('abcdefghijk'));
      expect(browser.plays, 1);
      expect(handler.playbackState.value.playing, isTrue);
      expect(calls, isNot(contains('setConfiguration')));
    },
  );

  test(
    'car output handoff disables phone PiP and detaches before restoring phone',
    () async {
      const channel = MethodChannel('vn.thanhtaxixanh/car');
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final session = container.read(youTubeSessionProvider.notifier);
      await session.ensureInitialized();
      session.setVisible(true);
      browser.report(video('abcdefghijk'));
      await session.showOnCar(true);
      session.confirmCarVideo(42);
      expect(container.read(youTubeSessionProvider).carViewId, 42);
      expect(pip.configurations.last['visible'], isFalse);
      await session.toggleCarPip();
      expect(container.read(youTubeSessionProvider).carPip, isTrue);
      await session.showOnCar(false);
      expect(calls, ['prepareCarVideo', 'releaseCarVideo']);
      expect(container.read(youTubeSessionProvider).carVideo, isFalse);
      expect(container.read(youTubeSessionProvider).carViewId, isNull);
      expect(container.read(youTubeSessionProvider).carPip, isFalse);
      expect(container.read(youTubeSessionProvider).media?.playing, isTrue);
    },
  );
  test('unsupported car output keeps the phone player available', () async {
    final session = container.read(youTubeSessionProvider.notifier);
    await session.ensureInitialized();
    browser.viewIdentifier = null;
    await session.showOnCar(true);
    expect(container.read(youTubeSessionProvider).carVideo, isFalse);
    expect(
      container.read(youTubeSessionProvider).message,
      contains('Chưa kết nối'),
    );
    expect(browser.closed, isFalse);
  });

  test(
    'skip progresses through the queue even when recent history reorders',
    () async {
      final session = container.read(youTubeSessionProvider.notifier);
      await session.ensureInitialized();
      browser.report(video('wxyz0123456'));
      browser.report(video('lmnopqrstuv'));
      browser.report(video('abcdefghijk'));
      await session.skip(1);
      expect(browser.locations.last.queryParameters['v'], 'lmnopqrstuv');
      browser.report(video('lmnopqrstuv'));
      await session.skip(1);
      expect(browser.locations.last.queryParameters['v'], 'wxyz0123456');
    },
  );

  test('media messages reject invalid IDs and bound untrusted metadata', () {
    expect(
      () => YouTubeMedia.parse('{"id":"bad","playing":true}'),
      throwsFormatException,
    );
    expect(() => YouTubeMedia.parse('[]'), throwsFormatException);
    expect(() => YouTubeMedia.parse('x' * 8193), throwsFormatException);
    final parsed = YouTubeMedia.parse(
      jsonEncode({
        'id': 'abcdefghijk',
        'title': 'A' * 500,
        'playing': true,
        'position': -3,
        'duration': -1,
      }),
    );
    expect(parsed.title.length, 160);
    expect(parsed.position, Duration.zero);
    expect(parsed.duration, isNull);
    expect(parsed.uri.host, 'm.youtube.com');
  });

  test(
    'public recent video records survive repository recreation and malformed entries',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = PreferencesYouTubeHistory();
      await repository.save([video('abcdefghijk'), video('lmnopqrstuv')]);
      final restored = await PreferencesYouTubeHistory().load();
      expect(restored.map((v) => v.id), ['abcdefghijk', 'lmnopqrstuv']);
      expect(restored.every((v) => !v.playing), isTrue);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        PreferencesYouTubeHistory.key,
        jsonEncode([
          video('abcdefghijk').toJson(),
          {'id': 'bad', 'playing': true},
          video('abcdefghijk').toJson(),
        ]),
      );
      expect((await repository.load()).length, 1);
    },
  );
}
