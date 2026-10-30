import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:taxi_auto/features/media/data/android_pip_controller.dart';
import 'package:taxi_auto/features/media/data/youtube_history_repository.dart';
import 'package:taxi_auto/features/media/domain/youtube_media.dart';
import 'package:taxi_auto/features/media/domain/youtube_settings.dart';
import 'package:taxi_auto/features/media/presentation/youtube_browser.dart';

class MemoryYouTubeSettings implements YouTubeSettingsRepository {
  MemoryYouTubeSettings([this.value = const YouTubeSettings()]);
  YouTubeSettings value;
  @override
  Future<YouTubeSettings> load() async => value;
  @override
  Future<void> save(YouTubeSettings settings) async => value = settings;
}

class MemoryYouTubeHistory implements YouTubeHistoryRepository {
  MemoryYouTubeHistory([this.items = const []]);
  List<YouTubeMedia> items;
  @override
  Future<List<YouTubeMedia>> load() async => items;
  @override
  Future<void> save(List<YouTubeMedia> value) async => items = value;
}

class FakePipController implements PipController {
  final states = StreamController<bool>.broadcast(sync: true);
  bool supported = true;
  final configurations = <Map<String, bool>>[];
  @override
  Stream<bool> get changes => states.stream;
  @override
  Future<bool> enter() async {
    if (supported) states.add(true);
    return supported;
  }

  @override
  Future<void> configure({
    required bool playing,
    required bool visible,
    required bool autoEnter,
  }) async {
    configurations.add({
      'playing': playing,
      'visible': visible,
      'autoEnter': autoEnter,
    });
  }

  @override
  void dispose() {
    unawaited(states.close());
  }
}

class FakeYouTubeBrowser implements YouTubeBrowser {
  int? viewIdentifier = 42;
  @override
  int? get androidViewIdentifier => viewIdentifier;
  FakeYouTubeBrowser(this.callbacks);
  final YouTubeBrowserCallbacks callbacks;
  Completer<void>? initializationGate;
  final locations = <Uri>[];
  final compacts = <bool>[];
  int plays = 0, pauses = 0, reloads = 0;
  bool closed = false, filtering = true, backgroundAudio = true;
  Duration? seekPosition;
  @override
  Widget buildView(BuildContext context) =>
      const SizedBox.expand(key: Key('fake-youtube'));
  @override
  Future<void> initialize(Uri location) async {
    await initializationGate?.future;
    await load(location);
  }

  @override
  Future<void> load(Uri location) async {
    locations.add(location);
    callbacks.onLocation(location);
    callbacks.onProgress(100);
    callbacks.onReady();
  }

  @override
  Future<bool> canGoBack() async => locations.length > 1;
  @override
  Future<void> goBack() async {
    if (locations.length > 1) locations.removeLast();
  }

  @override
  Future<void> reload() async => reloads++;
  @override
  Future<void> play() async => plays++;
  @override
  Future<void> pause() async => pauses++;
  @override
  Future<void> seek(Duration position) async => seekPosition = position;
  @override
  Future<void> setFiltering(bool enabled) async => filtering = enabled;
  @override
  Future<void> setBackgroundAudio(bool enabled) async =>
      backgroundAudio = enabled;
  @override
  Future<void> setCompact(bool compact) async => compacts.add(compact);
  @override
  void exitFullscreen() => callbacks.onFullscreen(null);
  @override
  void close() => closed = true;
  void report(YouTubeMedia media) => callbacks.onMedia?.call(media);
}
