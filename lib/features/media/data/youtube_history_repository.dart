import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/youtube_media.dart';

abstract interface class YouTubeHistoryRepository {
  Future<List<YouTubeMedia>> load();
  Future<void> save(List<YouTubeMedia> media);
}

class PreferencesYouTubeHistory implements YouTubeHistoryRepository {
  static const key = 'youtube_recent_v1';
  @override
  Future<List<YouTubeMedia>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.get(key);
    if (raw is! String) return [];
    try {
      final values = jsonDecode(raw);
      if (values is! List) return [];
      final result = <YouTubeMedia>[];
      for (final item in values.take(20)) {
        try {
          final media = YouTubeMedia.parse(jsonEncode(item));
          if (!result.any((entry) => entry.id == media.id)) result.add(media);
        } on FormatException {
          // Keep valid public video entries if an older cache is incomplete.
        }
      }
      return result;
    } on FormatException {
      return [];
    }
  }

  @override
  Future<void> save(List<YouTubeMedia> media) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(
      key,
      jsonEncode(
        media
            .take(20)
            .map(
              (item) => {
                ...item.toJson(),
                'playing': false,
                'buffering': false,
                'ended': false,
                'position': 0,
              },
            )
            .toList(),
      ),
    );
    if (!ok) throw StateError('Không lưu được video gần đây.');
  }
}
