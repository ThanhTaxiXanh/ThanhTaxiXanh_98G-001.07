import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Cap bytes while streaming, rather than after buffering an untrusted body.
Future<Uint8List> boundedGet(
  http.Client client,
  Uri url, {
  Map<String, String>? headers,
  int maxBytes = 4 * 1024 * 1024,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final clock = Stopwatch()..start();
  final abort = Completer<void>();
  final timer = Timer(timeout, () => abort.complete());
  final request = http.AbortableRequest('GET', url, abortTrigger: abort.future);
  if (headers != null) request.headers.addAll(headers);
  StreamIterator<List<int>>? iterator;
  final bytes = BytesBuilder(copy: false);
  try {
    final response = await client.send(request).timeout(timeout);
    iterator = StreamIterator(response.stream);
    if (response.statusCode != 200 ||
        (response.contentLength ?? 0) > maxBytes) {
      throw const FormatException('HTTP response rejected.');
    }
    while (true) {
      final remaining = timeout - clock.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('Response timed out.');
      }
      if (!await iterator.moveNext().timeout(remaining)) break;
      if (bytes.length + iterator.current.length > maxBytes) {
        throw const FormatException('HTTP response exceeds byte limit.');
      }
      bytes.add(iterator.current);
    }
    return bytes.takeBytes();
  } finally {
    timer.cancel();
    if (!abort.isCompleted) abort.complete();
    await iterator?.cancel();
  }
}
