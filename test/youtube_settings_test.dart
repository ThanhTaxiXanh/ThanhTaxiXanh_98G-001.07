import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxi_auto/features/media/data/preferences_youtube_repository.dart';
import 'package:taxi_auto/features/media/domain/youtube_location.dart';
import 'package:taxi_auto/features/media/domain/youtube_settings.dart';
import 'package:taxi_auto/features/media/presentation/youtube_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'searches are encoded and public video links retain playback parameters',
    () {
      final search = YouTubeLocation.fromInput('nhạc Việt & taxi');
      expect(search.host, 'm.youtube.com');
      expect(search.queryParameters['search_query'], 'nhạc Việt & taxi');
      final link = YouTubeLocation.fromInput(
        'https://youtu.be/abcdefghijk?t=30&si=tracking#fragment',
      );
      expect(link.toString(), 'https://m.youtube.com/watch?t=30&v=abcdefghijk');
      expect(
        YouTubeLocation.fromInput('www.youtube.com/watch?v=abcdefghijk').host,
        'm.youtube.com',
      );
    },
  );

  test('navigation does not accept lookalike hosts or unsafe schemes', () {
    for (final input in [
      'https://youtube.com.evil.example/watch?v=abcdefghijk',
      'https://youtube.com@evil.example/',
      'http://youtube.com/watch?v=abcdefghijk',
      'javascript:alert(1)',
      'file:///etc/passwd',
      'intent://youtube.com',
      'https://m.youtube.com:444/watch',
    ]) {
      expect(() => YouTubeLocation.fromInput(input), throwsFormatException);
      expect(YouTubeLocation.allowsNavigation(Uri.parse(input)), isFalse);
    }
    expect(
      YouTubeLocation.allowsNavigation(
        Uri.parse('https://accounts.google.com/'),
      ),
      isTrue,
    );
    expect(
      YouTubeLocation.forStorage(
        Uri.parse('https://accounts.google.com/signin?code=secret'),
      ),
      isNull,
    );
    expect(
      YouTubeLocation.forStorage(
        Uri.parse(
          'https://m.youtube.com/redirect?q=https://example.com&token=secret',
        ),
      ),
      isNull,
    );
    expect(
      YouTubeLocation.forStorage(
        Uri.parse('https://m.youtube.com/watch?v=abcdefghijk&token=secret'),
      )!.queryParameters,
      {'v': 'abcdefghijk'},
    );
  });

  test(
    'settings survive repository recreation without storing auth data',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = PreferencesYouTubeRepository();
      expect((await repository.load()).filterAds, isTrue);
      await repository.save(
        YouTubeSettings(
          filterAds: false,
          lastLocation: Uri.parse(
            'https://www.youtube.com/watch?v=abcdefghijk&si=secret',
          ),
        ),
      );
      final restored = await PreferencesYouTubeRepository().load();
      expect(restored.filterAds, isFalse);
      expect(
        restored.startLocation.toString(),
        'https://m.youtube.com/watch?v=abcdefghijk',
      );
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(PreferencesYouTubeRepository.storageKey),
        isNot(contains('secret')),
      );
      await repository.save(
        YouTubeSettings(
          lastLocation: Uri.parse('https://accounts.google.com/?code=secret'),
        ),
      );
      expect((await repository.load()).startLocation, YouTubeLocation.home);
    },
  );

  test('malformed settings recover to defaults', () async {
    for (final value in [
      '{invalid',
      '[]',
      12,
      jsonEncode({'filterAds': 'yes', 'lastLocation': 'https://evil.example'}),
    ]) {
      SharedPreferences.setMockInitialValues({
        PreferencesYouTubeRepository.storageKey: value,
      });
      final settings = await PreferencesYouTubeRepository().load();
      expect(settings.filterAds, isTrue);
      expect(settings.startLocation, YouTubeLocation.home);
    }
  });

  test(
    'overlapping preference writes remain ordered and recover after failure',
    () async {
      final repository = _DelayedSettings();
      final container = ProviderContainer(
        overrides: [
          youTubeSettingsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(youTubeSettingsProvider.future);
      final controller = container.read(youTubeSettingsProvider.notifier);
      final first = controller.setFilter(false);
      final second = controller.remember(
        Uri.parse('https://m.youtube.com/watch?v=abcdefghijk'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(repository.writes, hasLength(1));
      repository.firstWrite.complete();
      await Future.wait([first, second]);
      expect(repository.writes.last.filterAds, isFalse);
      expect(
        repository.writes.last.lastLocation?.queryParameters['v'],
        'abcdefghijk',
      );

      repository.failNext = true;
      await expectLater(controller.setFilter(true), throwsStateError);
      await controller.setFilter(false);
      expect(repository.writes.last.filterAds, isFalse);
    },
  );
}

class _DelayedSettings implements YouTubeSettingsRepository {
  final firstWrite = Completer<void>();
  final writes = <YouTubeSettings>[];
  bool failNext = false;
  @override
  Future<YouTubeSettings> load() async => const YouTubeSettings();
  @override
  Future<void> save(YouTubeSettings settings) async {
    writes.add(settings);
    if (writes.length == 1) await firstWrite.future;
    if (failNext) {
      failNext = false;
      throw StateError('disk error');
    }
  }
}
