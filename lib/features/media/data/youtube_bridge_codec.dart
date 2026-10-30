import 'dart:convert';
import 'dart:math';
import '../domain/youtube_media.dart';

/// A document nonce prevents third-party iframes using the global JS channel.
class YouTubeBridgeCodec {
  String _token = '';
  void newDocument() {
    final random = Random.secure();
    _token = base64UrlEncode(List.generate(24, (_) => random.nextInt(256)));
  }

  String inject(String source) =>
      source.replaceFirst('__TAXI_BRIDGE_TOKEN__', jsonEncode(_token));

  ({YouTubeMedia? media, String? error})? decode(String message) {
    if (_token.isEmpty || message.length > 8192) return null;
    try {
      final raw = jsonDecode(message);
      if (raw is! Map || raw['token'] != _token) return null;
      if (raw['error'] is String) {
        final error = (raw['error'] as String).replaceAll(
          RegExp(r'[\x00-\x1f]'),
          ' ',
        );
        return (
          media: null,
          error: error.substring(0, error.length.clamp(0, 200)),
        );
      }
      return (media: YouTubeMedia.parse(message), error: null);
    } on FormatException {
      return null;
    }
  }
}
