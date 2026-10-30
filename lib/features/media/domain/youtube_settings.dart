import 'youtube_location.dart';

class YouTubeSettings {
  const YouTubeSettings({this.filterAds = true, this.lastLocation});
  final bool filterAds;
  final Uri? lastLocation;
  Uri get startLocation => lastLocation ?? YouTubeLocation.home;

  YouTubeSettings copy({bool? filterAds, Uri? lastLocation}) => YouTubeSettings(
    filterAds: filterAds ?? this.filterAds,
    lastLocation: lastLocation ?? this.lastLocation,
  );
}

abstract interface class YouTubeSettingsRepository {
  Future<YouTubeSettings> load();
  Future<void> save(YouTubeSettings settings);
}
