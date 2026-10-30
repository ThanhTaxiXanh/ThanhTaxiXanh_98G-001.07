import 'dart:convert';

class YouTubeMedia {
  const YouTubeMedia({
    required this.id,
    required this.title,
    required this.artist,
    required this.playing,
    required this.position,
    this.duration,
    this.buffering = false,
    this.ended = false,
  });
  final String id, title, artist;
  final bool playing, buffering, ended;
  final Duration position;
  final Duration? duration;
  Uri get uri => Uri.https('m.youtube.com', '/watch', {'v': id});
  YouTubeMedia paused() => YouTubeMedia(
    id: id,
    title: title,
    artist: artist,
    playing: false,
    position: position,
    duration: duration,
    ended: ended,
  );

  static YouTubeMedia parse(String message) {
    if (message.length > 8192) {
      throw const FormatException('Media message too long');
    }
    final value = jsonDecode(message);
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(value['id'] as String) ||
        value['playing'] is! bool) {
      throw const FormatException('Invalid media message');
    }
    Duration? seconds(Object? value) {
      if (value is! num || !value.isFinite || value < 0 || value > 31536000) {
        return null;
      }
      return Duration(milliseconds: (value * 1000).round());
    }

    String label(Object? value, String fallback, int limit) {
      if (value is! String || value.trim().isEmpty) return fallback;
      final cleaned = value.replaceAll(RegExp(r'[\x00-\x1f]'), ' ').trim();
      return cleaned.length <= limit ? cleaned : cleaned.substring(0, limit);
    }

    return YouTubeMedia(
      id: value['id'] as String,
      title: label(value['title'], 'YouTube', 160),
      artist: label(value['artist'], 'YouTube', 100),
      playing: value['playing'] as bool,
      buffering: value['buffering'] == true,
      ended: value['ended'] == true,
      position: seconds(value['position']) ?? Duration.zero,
      duration: seconds(value['duration']),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'playing': playing,
    'buffering': buffering,
    'ended': ended,
    'position': position.inMilliseconds / 1000,
    'duration': duration == null ? null : duration!.inMilliseconds / 1000,
  };
}
