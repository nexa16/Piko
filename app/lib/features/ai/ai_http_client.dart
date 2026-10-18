import 'dart:async';
import 'package:http/http.dart' as http;

/// Auth and function calls deliver a complete bounded response or fail. A late
/// socket/body result can never continue into the SDK after cancellation.
final class AiHttpClient extends http.BaseClient {
  AiHttpClient({
    http.Client Function()? factory,
    this.deadline = const Duration(seconds: 30),
  }) : _factory = factory ?? http.Client.new;
  final http.Client Function() _factory;
  final Duration deadline;
  final _active = <Completer<void>, http.Client>{};
  bool _closed = false;
  void cancelAll() {
    for (final cancellation in _active.keys.toList()) {
      if (!cancellation.isCompleted) cancellation.complete();
      _active[cancellation]?.close();
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw http.ClientException('AI transport closed');
    final inner = _factory(), cancel = Completer<void>();
    _active[cancel] = inner;
    final timer = Timer(deadline, () {
      if (!cancel.isCompleted) cancel.complete();
    });
    Future<http.StreamedResponse> collect() async {
      final response = await inner.send(request);
      final chunks = <List<int>>[];
      var size = 0;
      await for (final chunk in response.stream) {
        size += chunk.length;
        if (size > 131072) throw http.ClientException('AI response too large');
        chunks.add(chunk);
      }
      return http.StreamedResponse(
        Stream.value([for (final chunk in chunks) ...chunk]),
        response.statusCode,
        headers: response.headers,
        reasonPhrase: response.reasonPhrase,
        isRedirect: response.isRedirect,
        persistentConnection: false,
        request: response.request,
      );
    }

    try {
      return await Future.any([
        collect(),
        cancel.future.then<http.StreamedResponse>(
          (_) => throw http.ClientException('AI request cancelled'),
        ),
      ]);
    } finally {
      timer.cancel();
      _active.remove(cancel);
      inner.close();
    }
  }

  @override
  void close() {
    _closed = true;
    cancelAll();
  }
}
