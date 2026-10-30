import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:taxi_auto/core/network/bounded_http.dart';

class StreamingClient extends http.BaseClient {
  StreamingClient(this.body);
  final Future<http.StreamedResponse> Function(http.BaseRequest) body;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => body(request);
}

void main() {
  final url = Uri.https('example.com', '/data');
  test(
    'oversized streaming responses cancel before buffering the full body',
    () async {
      var cancelled = false;
      final stream = StreamController<List<int>>(
        onCancel: () => cancelled = true,
      );
      final client = StreamingClient(
        (_) async => http.StreamedResponse(stream.stream, 200),
      );
      final future = boundedGet(client, url, maxBytes: 10);
      stream.add(List.filled(8, 1));
      stream.add(List.filled(8, 2));
      await expectLater(future, throwsFormatException);
      expect(cancelled, isTrue);
      await stream.close();
    },
  );
  test('declared oversized bodies are rejected without reading them', () async {
    var read = false;
    final client = StreamingClient(
      (_) async => http.StreamedResponse(
        Stream.multi((c) {
          read = true;
          c.add([1]);
          c.close();
        }),
        200,
        contentLength: 500,
      ),
    );
    await expectLater(
      boundedGet(client, url, maxBytes: 10),
      throwsFormatException,
    );
    expect(read, isFalse);
  });
}
