import 'dart:convert';
import 'package:taxi_auto/features/media/domain/youtube_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_auto/features/media/data/youtube_bridge_codec.dart';

void main() {
  test(
    'YouTube app intents are converted without trusting external fallbacks',
    () {
      expect(
        YouTubeLocation.fromAppLink(
          Uri.parse('vnd.youtube:abcdefghijk'),
        )?.queryParameters['v'],
        'abcdefghijk',
      );
      expect(
        YouTubeLocation.fromAppLink(
          Uri.parse(
            'intent://www.youtube.com/watch?v=abcdefghijk#Intent;scheme=https;S.browser_fallback_url=https%3A%2F%2Fevil.example;end',
          ),
        )?.host,
        'm.youtube.com',
      );
      expect(
        YouTubeLocation.fromAppLink(
          Uri.parse('intent://evil.example/watch?v=abcdefghijk'),
        ),
        isNull,
      );
      expect(YouTubeLocation.fromAppLink(Uri.parse('vnd.youtube:bad')), isNull);
    },
  );

  test(
    'bridge rejects guessed iframe messages and accepts the current document',
    () {
      final codec = YouTubeBridgeCodec()..newDocument();
      final token = jsonDecode(codec.inject('__TAXI_BRIDGE_TOKEN__'));
      final data = {'id': 'abcdefghijk', 'playing': true, 'token': token};
      expect(codec.decode(jsonEncode({...data, 'token': 'guessed'})), isNull);
      expect(codec.decode(jsonEncode(data))?.media?.id, 'abcdefghijk');
      codec.newDocument();
      expect(codec.decode(jsonEncode(data)), isNull);
    },
  );
  test(
    'bridge bounds and sanitizes page errors and rejects malformed payloads',
    () {
      final codec = YouTubeBridgeCodec()..newDocument();
      final token = jsonDecode(codec.inject('__TAXI_BRIDGE_TOKEN__'));
      expect(codec.decode('x' * 8193), isNull);
      expect(codec.decode('[]'), isNull);
      final error = codec
          .decode(jsonEncode({'token': token, 'error': '\u0000${'a' * 400}'}))
          ?.error;
      expect(error?.length, 200);
      expect(error, isNot(contains('\u0000')));
    },
  );
}
