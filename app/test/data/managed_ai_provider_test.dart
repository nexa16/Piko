import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/ai/managed_ai_provider.dart';

class SyntheticAccess implements AiAccess {
  int calls = 0;
  @override
  Future<String?> accessToken() async {
    calls++;
    return 'synthetic-owner-session';
  }
}

AiRequest request({String goal = 'Hotel B1'}) => AiRequest(
  id: '00000000-0000-4000-8000-000000000001',
  action: AiAction.generate,
  goal: goal,
  snapshot: AiSnapshot(
    collectionId: 'synthetic',
    targetLanguage: 'en',
    nativeLanguage: 'de',
    entries: [],
    groups: [],
  ),
);
Map<String, Object?> answer(AiRequest r) => {
  'requestId': r.id,
  'complete': true,
  'processedIds': [],
  'groups': [],
  'values': [],
  'cards': [],
  'edits': [],
  'limitations': [],
};

void main() {
  late Directory directory;
  late String pem;
  late SecurityContext security;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('piko-synthetic-ai-tls-');
    final config = File('${directory.path}/openssl.cnf');
    await config.writeAsString(
      '[req]\ndistinguished_name=dn\nx509_extensions=v3\nprompt=no\n[dn]\nCN=localhost\n[v3]\nsubjectAltName=IP:127.0.0.1,DNS:localhost\n',
    );
    var openssl = 'openssl';
    if (Platform.isWindows) {
      final candidate =
          '${Platform.environment['ProgramFiles']}/Git/usr/bin/openssl.exe';
      if (File(candidate).existsSync()) openssl = candidate;
    }
    final generated = await Process.run(openssl, [
      'req',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-x509',
      '-days',
      '1',
      '-keyout',
      '${directory.path}/key.pem',
      '-out',
      '${directory.path}/cert.pem',
      '-config',
      config.path,
    ]);
    if (generated.exitCode != 0) {
      throw StateError('Synthetic local TLS fixture generation failed');
    }
    pem = await File('${directory.path}/cert.pem').readAsString();
    security = SecurityContext()
      ..useCertificateChain('${directory.path}/cert.pem')
      ..usePrivateKey('${directory.path}/key.pem');
  });
  tearDownAll(() async {
    // Only exact files in this freshly created, resolved fixture directory.
    if (await directory.resolveSymbolicLinks() != directory.absolute.path) {
      throw StateError('Unexpected fixture symlink');
    }
    for (final name in ['openssl.cnf', 'key.pem', 'cert.pem']) {
      final file = File('${directory.path}/$name');
      if (await file.exists()) await file.delete();
    }
    await directory.delete();
  });
  Future<({HttpServer server, Uri uri, HttpClient client})> server(
    Future<void> Function(HttpRequest) handler,
  ) async {
    final failures = <Object>[];
    final hosted = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      security,
    );
    hosted.listen(
      (r) => unawaited(
        handler(r).catchError((Object failure) {
          if (failure is! HttpException && failure is! SocketException) {
            failures.add(failure);
          }
        }),
      ),
      onError: (Object failure) {
        if (failure is! HandshakeException) failures.add(failure);
      },
    );
    addTearDown(() async {
      await hosted.close(force: true);
      expect(failures, isEmpty);
    });
    final client = HttpClient()
      ..badCertificateCallback = (cert, host, port) =>
          host == '127.0.0.1' &&
          port == hosted.port &&
          cert.pem.trim() == pem.trim();
    return (
      server: hosted,
      uri: Uri.parse('https://127.0.0.1:${hosted.port}/piko-ai'),
      client: client,
    );
  }

  Future<void> respond(HttpRequest r, int code, Object value) async {
    r.response.statusCode = code;
    r.response.headers.contentType = ContentType.json;
    r.response.write(jsonEncode(value));
    await r.response.close();
  }

  test(
    'disabled path rejects before credentials or any HTTP request',
    () async {
      var calls = 0;
      final host = await server((r) async {
            calls++;
            await respond(r, 500, {});
          }),
          access = SyntheticAccess();
      final p = ManagedAiProvider(
        endpoint: host.uri,
        access: access,
        enabled: false,
        client: host.client,
      );
      addTearDown(p.close);
      await expectLater(p.generate(request()), throwsA(AiFailure.disabled));
      expect(access.calls, 0);
      expect(calls, 0);
    },
  );
  test(
    'real local TLS POST then only owned status GETs; publishable/session headers and digest remain bound',
    () async {
      var posts = 0, gets = 0;
      final r = request(), hash = 'a' * 64;
      final host = await server((http) async {
        expect(
          http.headers.value('Authorization'),
          'Bearer synthetic-owner-session',
        );
        expect(http.headers.value('apikey'), 'sb_publishable_synthetic');
        if (http.method == 'POST') {
          posts++;
          final body = jsonDecode(await utf8.decoder.bind(http).join()) as Map;
          expect(body['requestId'], r.id);
          expect(body['scope'], 'ordinary');
          expect(body.containsKey('model'), isFalse);
          await respond(http, 202, {
            'requestId': r.id,
            'state': 'pending',
            'requestDigest': hash,
          });
        } else {
          gets++;
          expect(http.method, 'GET');
          expect(http.uri.queryParameters, {'requestId': r.id});
          expect(http.headers.value('X-Piko-Request-Digest'), hash);
          await respond(
            http,
            gets == 1 ? 202 : 200,
            gets == 1
                ? {'requestId': r.id, 'state': 'pending', 'requestDigest': hash}
                : answer(r),
          );
        }
      });
      final p = ManagedAiProvider(
        endpoint: host.uri,
        access: SyntheticAccess(),
        enabled: true,
        client: host.client,
        publishableKey: 'sb_publishable_synthetic',
        pollInterval: const Duration(milliseconds: 1),
      );
      addTearDown(p.close);
      expect(await p.generate(r), answer(r));
      expect(posts, 1);
      expect(gets, 2);
    },
  );
  test(
    'access denial and service limits never trigger another POST or automatic retry',
    () async {
      for (final (status, failure) in [
        (403, AiFailure.accessDenied),
        (429, AiFailure.limit),
        (413, AiFailure.contextLimit),
      ]) {
        var posts = 0;
        final host = await server((http) async {
          posts++;
          await respond(http, status, {'private': 'synthetic not to echo'});
        });
        final p = ManagedAiProvider(
          endpoint: host.uri,
          access: SyntheticAccess(),
          enabled: true,
          client: host.client,
        );
        addTearDown(p.close);
        await expectLater(p.generate(request()), throwsA(failure));
        expect(posts, 1);
      }
    },
  );
  test(
    'cancel stops waiting/polling and cannot revive an old request',
    () async {
      var posts = 0, gets = 0;
      final r = request(), ready = Completer<void>();
      final host = await server((http) async {
        if (http.method == 'POST') {
          posts++;
          await respond(http, 202, {
            'requestId': r.id,
            'state': 'pending',
            'requestDigest': 'a' * 64,
          });
          if (!ready.isCompleted) ready.complete();
        } else {
          gets++;
          await respond(http, 202, {
            'requestId': r.id,
            'state': 'pending',
            'requestDigest': 'a' * 64,
          });
        }
      });
      final p = ManagedAiProvider(
        endpoint: host.uri,
        access: SyntheticAccess(),
        enabled: true,
        client: host.client,
        pollInterval: const Duration(milliseconds: 100),
      );
      addTearDown(p.close);
      final operation = p.generate(r),
          assertion = expectLater(operation, throwsA(AiFailure.stale));
      await ready.future;
      p.cancel(r.id);
      await assertion;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(posts, 1);
      expect(gets, 0);
    },
  );
  test(
    'bounded pending response times out without creating another paid attempt',
    () async {
      var posts = 0;
      final r = request();
      final host = await server((http) async {
        if (http.method == 'POST') posts++;
        await respond(http, 202, {
          'requestId': r.id,
          'state': 'pending',
          'requestDigest': 'a' * 64,
        });
      });
      final p = ManagedAiProvider(
        endpoint: host.uri,
        access: SyntheticAccess(),
        enabled: true,
        client: host.client,
        waitTimeout: const Duration(seconds: 2),
        pollInterval: const Duration(milliseconds: 200),
      );
      addTearDown(p.close);
      await expectLater(p.generate(r), throwsA(AiFailure.timeout));
      expect(posts, 1);
    },
  );
  test(
    'oversized complete context is rejected before auth and transmission; invalid UTF8 never becomes a result',
    () async {
      var calls = 0;
      final host = await server((http) async {
            calls++;
            http.response.statusCode = 200;
            http.response.add([255, 254]);
            await http.response.close();
          }),
          access = SyntheticAccess();
      final p = ManagedAiProvider(
        endpoint: host.uri,
        access: access,
        enabled: true,
        client: host.client,
      );
      addTearDown(p.close);
      await expectLater(
        p.generate(request(goal: 'x' * 200000)),
        throwsA(AiFailure.contextLimit),
      );
      expect(calls, 0);
      expect(access.calls, 0);
      await expectLater(
        p.generate(request()),
        throwsA(AiFailure.invalidResponse),
      );
      expect(calls, 1);
    },
  );
  test(
    'production TLS verification rejects an untrusted certificate; only explicit fixture client pins it',
    () async {
      var posts = 0;
      final host = await server((http) async {
        posts++;
        await respond(http, 200, answer(request()));
      });
      host.client.close(force: true);
      final p = ManagedAiProvider(
        endpoint: host.uri,
        access: SyntheticAccess(),
        enabled: true,
      );
      addTearDown(p.close);
      await expectLater(p.generate(request()), throwsA(AiFailure.network));
      expect(posts, 0);
    },
  );
}
