import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/preferences_youtube_repository.dart';
import '../domain/youtube_location.dart';
import '../domain/youtube_settings.dart';

final youTubeSettingsRepositoryProvider = Provider<YouTubeSettingsRepository>(
  (ref) => PreferencesYouTubeRepository(),
);
final youTubeSettingsProvider =
    AsyncNotifierProvider<YouTubeSettingsController, YouTubeSettings>(
      YouTubeSettingsController.new,
    );

class YouTubeSettingsController extends AsyncNotifier<YouTubeSettings> {
  Future<void> _pendingWrite = Future.value();

  @override
  Future<YouTubeSettings> build() =>
      ref.watch(youTubeSettingsRepositoryProvider).load();

  Future<void> setFilter(bool enabled) async {
    final current = state.asData?.value;
    if (current == null) return;
    await _save(current.copy(filterAds: enabled));
  }

  Future<void> setBackgroundAudio(bool enabled) async {
    final current = state.asData?.value;
    if (current != null) await _save(current.copy(backgroundAudio: enabled));
  }

  Future<void> setAutoPip(bool enabled) async {
    final current = state.asData?.value;
    if (current != null) await _save(current.copy(autoPip: enabled));
  }

  Future<void> remember(Uri uri) async {
    final location = YouTubeLocation.forStorage(uri);
    final current = state.asData?.value;
    if (current == null ||
        location == null ||
        current.lastLocation == location) {
      return;
    }
    await _save(current.copy(lastLocation: location));
  }

  Future<void> _save(YouTubeSettings settings) {
    final repository = ref.read(youTubeSettingsRepositoryProvider);
    state = AsyncData(settings);
    // Keep rapid toggles and page changes in order, even after a failed write.
    final write = _pendingWrite.then((_) => repository.save(settings));
    _pendingWrite = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return write;
  }
}
