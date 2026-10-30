import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/youtube_location.dart';
import '../domain/youtube_settings.dart';

class PreferencesYouTubeRepository implements YouTubeSettingsRepository {
  static const storageKey = 'youtube_settings_v1';
  @override
  Future<YouTubeSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.get(storageKey);
    if (saved is! String) return const YouTubeSettings();
    try {
      final json = jsonDecode(saved);
      if (json is! Map<String, dynamic>) return const YouTubeSettings();
      final link = json['lastLocation'];
      final uri = link is String ? Uri.tryParse(link) : null;
      return YouTubeSettings(
        filterAds: json['filterAds'] is bool ? json['filterAds'] as bool : true,
        lastLocation: uri == null ? null : YouTubeLocation.forStorage(uri),
      );
    } on FormatException {
      return const YouTubeSettings();
    }
  }

  @override
  Future<void> save(YouTubeSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    final last = settings.lastLocation;
    final saved = await preferences.setString(
      storageKey,
      jsonEncode({
        'filterAds': settings.filterAds,
        'lastLocation': last == null
            ? null
            : YouTubeLocation.forStorage(last)?.toString(),
      }),
    );
    if (!saved) throw StateError('Không lưu được cài đặt YouTube.');
  }
}
