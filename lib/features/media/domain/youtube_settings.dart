import 'youtube_location.dart';

class YouTubeSettings {
  const YouTubeSettings({
    this.filterAds = true,
    this.lastLocation,
    this.backgroundAudio = true,
    this.autoPip = true,
  });
  final bool filterAds;
  final bool backgroundAudio, autoPip;
  final Uri? lastLocation;
  Uri get startLocation => lastLocation ?? YouTubeLocation.home;

  YouTubeSettings copy({
    bool? filterAds,
    Uri? lastLocation,
    bool? backgroundAudio,
    bool? autoPip,
  }) => YouTubeSettings(
    filterAds: filterAds ?? this.filterAds,
    lastLocation: lastLocation ?? this.lastLocation,
    backgroundAudio: backgroundAudio ?? this.backgroundAudio,
    autoPip: autoPip ?? this.autoPip,
  );
}

abstract interface class YouTubeSettingsRepository {
  Future<YouTubeSettings> load();
  Future<void> save(YouTubeSettings settings);
}
