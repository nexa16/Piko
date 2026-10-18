import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:piko/features/ai/ai_http_client.dart';

class HeldHttp extends http.BaseClient {
  final response = Completer<http.StreamedResponse>();
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      response.future;
  @override
  void close() {
    closed = true;
  }
}

void main() {
  test(
    'cancel before headers rejects once; a late response cannot reach the SDK',
    () async {
      final clients = <HeldHttp>[];
      final transport = AiHttpClient(
        factory: () {
          final client = HeldHttp();
          clients.add(client);
          return client;
        },
      );
      var applied = 0;
      final pending = transport.get(Uri.https('example.invalid', '/auth'));
      unawaited(
        pending.then<void>((_) {
          applied++;
        }, onError: (Object _) {}),
      );
      transport.cancelAll();
      await expectLater(pending, throwsA(isA<http.ClientException>()));
      expect(clients.single.closed, isTrue);
      clients.single.response.complete(
        http.StreamedResponse(Stream.value([1]), 200),
      );
      await Future<void>.delayed(Duration.zero);
      expect(applied, 0);
      final retry = transport.get(Uri.https('example.invalid', '/auth'));
      clients.last.response.complete(
        http.StreamedResponse(Stream.value([111, 107]), 200),
      );
      expect((await retry).body, 'ok');
      transport.close();
    },
  );
  test(
    'cancel during body collection cannot deliver a partial success',
    () async {
      final client = HeldHttp(), body = StreamController<List<int>>();
      final transport = AiHttpClient(factory: () => client);
      final pending = transport.get(Uri.https('example.invalid', '/function'));
      client.response.complete(http.StreamedResponse(body.stream, 200));
      body.add([1, 2]);
      await Future<void>.delayed(Duration.zero);
      transport.cancelAll();
      await expectLater(pending, throwsA(isA<http.ClientException>()));
      body.add([3]);
      await body.close();
      transport.close();
    },
  );
  test(
    'deadline closes hung headers and oversized responses fail without raw data',
    () async {
      final client = HeldHttp();
      final transport = AiHttpClient(
        factory: () => client,
        deadline: const Duration(milliseconds: 20),
      );
      await expectLater(
        transport.get(Uri.https('example.invalid', '/auth')),
        throwsA(isA<http.ClientException>()),
      );
      expect(client.closed, isTrue);
      transport.close();
      final oversized = HeldHttp(),
          bounded = AiHttpClient(factory: () => oversized);
      final pending = bounded.get(Uri.https('example.invalid', '/function'));
      oversized.response.complete(
        http.StreamedResponse(Stream.value(List.filled(131073, 1)), 200),
      );
      await expectLater(pending, throwsA(isA<http.ClientException>()));
      bounded.close();
    },
  );
}
