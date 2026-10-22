import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'ai_contract.dart';
import 'ai_wire.dart';

abstract interface class AiAccess {
  Future<String?> accessToken();
}

abstract interface class AiPilotLocalStop {
  Future<void> stopPilotLocally();
  Future<String?> withdrawalAccessToken();
}

final class UnavailableAiAccess implements AiAccess {
  const UnavailableAiAccess();
  @override
  Future<String?> accessToken() async => null;
}

/// One explicit POST followed only by status GETs for that paid attempt. No
/// replay, fallback model, background restart or automatic paid retry exists.
final class ManagedAiProvider
    implements AiProvider, CancelableAiProvider, AiPilotAccess {
  ManagedAiProvider({
    required this.endpoint,
    required this.access,
    this.publishableKey,
    this.enabled = pikoAiEnabled,
    HttpClient? client,
    this.waitTimeout = const Duration(minutes: 5),
    this.pollInterval = const Duration(seconds: 2),
  }) : assert(
         waitTimeout > Duration.zero &&
             waitTimeout <= const Duration(minutes: 5),
       ),
       assert(pollInterval > Duration.zero),
       _client = client ?? HttpClient();
  final Uri? endpoint;
  final AiAccess access;
  final String? publishableKey;
  final bool enabled;
  final Duration waitTimeout, pollInterval;
  final HttpClient _client;
  static const maxInputBytes = 192000, maxResponseBytes = 2000000;
  bool _busy = false, _closed = false;
  int _revision = 0;
  String? _activeId;
  HttpClientRequest? _outgoing;
  void _current(int owner) {
    if (_closed || owner != _revision) throw AiFailure.stale;
  }

  Duration _remaining(Stopwatch clock) {
    final left = waitTimeout - clock.elapsed;
    if (left <= Duration.zero) throw AiFailure.timeout;
    return left < const Duration(seconds: 30)
        ? left
        : const Duration(seconds: 30);
  }

  Future<(int, Map<String, Object?>)> _http(
    String method,
    Uri uri,
    List<int>? body,
    String? digest,
    int owner,
    Stopwatch clock,
  ) async {
    _current(owner);
    final token =
        await (uri.queryParameters['pilot'] == 'withdraw' &&
                    access is AiPilotLocalStop
                ? (access as AiPilotLocalStop).withdrawalAccessToken()
                : access.accessToken())
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw AiFailure.network,
            );
    _current(owner);
    if (token == null || token.isEmpty) throw AiFailure.accessDenied;
    final request = await _client
        .openUrl(method, uri)
        .timeout(_remaining(clock));
    try {
      _current(owner);
      _outgoing = request;
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set(
        'X-Piko-App-Version',
        const String.fromEnvironment(
          'PIKO_APP_SOURCE',
          defaultValue: 'development-r2',
        ),
      );
      if (publishableKey?.isNotEmpty ?? false) {
        request.headers.set('apikey', publishableKey!);
      }
      if (digest != null) request.headers.set('X-Piko-Request-Digest', digest);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.add(body);
      }
      final response = await request.close().timeout(_remaining(clock));
      _current(owner);
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw AiFailure.accessDenied;
      }
      if (response.statusCode == 429) throw AiFailure.limit;
      if (response.statusCode == 413) throw AiFailure.contextLimit;
      if (response.statusCode == 410) throw AiFailure.expired;
      if (response.statusCode == 422) throw AiFailure.invalidResponse;
      if (response.statusCode != 200 && response.statusCode != 202) {
        throw AiFailure.unavailable;
      }
      final bytes = <int>[];
      await for (final part in response.timeout(_remaining(clock))) {
        _current(owner);
        _remaining(clock);
        if (bytes.length + part.length > maxResponseBytes) {
          throw AiFailure.invalidResponse;
        }
        bytes.addAll(part);
      }
      _current(owner);
      try {
        return (response.statusCode, aiObject(jsonDecode(utf8.decode(bytes))));
      } on FormatException {
        throw AiFailure.invalidResponse;
      }
    } catch (_) {
      request.abort();
      rethrow;
    }
  }

  @override
  Future<Map<String, Object?>> pilot(
    String operation, [
    Map<String, Object?> data = const {},
  ]) async {
    if (!enabled) throw AiFailure.disabled;
    if (operation == 'withdraw' && _busy) {
      ++_revision;
      _outgoing?.abort();
      _activeId = null;
      _busy = false;
    }
    if (_closed ||
        _busy ||
        endpoint == null ||
        endpoint!.scheme != 'https' ||
        endpoint!.hasQuery ||
        endpoint!.hasFragment ||
        endpoint!.userInfo.isNotEmpty) {
      throw AiFailure.unavailable;
    }
    if (operation == 'withdraw' && access is AiPilotLocalStop) {
      await (access as AiPilotLocalStop).stopPilotLocally();
    }
    final owner = ++_revision;
    _busy = true;
    try {
      final result = await _http(
        'POST',
        endpoint!.replace(queryParameters: {'pilot': operation}),
        utf8.encode(jsonEncode(data)),
        null,
        owner,
        Stopwatch()..start(),
      );
      if (result.$1 != 200) throw AiFailure.invalidResponse;
      return result.$2;
    } on SocketException {
      throw AiFailure.network;
    } on TimeoutException {
      throw AiFailure.timeout;
    } on HttpException {
      throw AiFailure.network;
    } finally {
      if (owner == _revision) {
        _busy = false;
        _outgoing = null;
      }
    }
  }

  @override
  Future<Map<String, Object?>> generate(AiRequest request) async {
    if (!enabled) throw AiFailure.disabled;
    if (_closed || _busy || endpoint == null) throw AiFailure.unavailable;
    final uri = endpoint!;
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasQuery ||
        (publishableKey != null &&
            !publishableKey!.startsWith('sb_publishable_'))) {
      throw AiFailure.unavailable;
    }
    final wire = AiWire(request);
    final body = utf8.encode(jsonEncode(wire.body));
    if (body.length > maxInputBytes) throw AiFailure.contextLimit;
    final owner = ++_revision, clock = Stopwatch()..start();
    _busy = true;
    _activeId = request.id;
    try {
      var response = await _http('POST', uri, body, null, owner, clock);
      String? digest;
      while (response.$1 == 202) {
        final pending = response.$2;
        if (pending['requestId'] != request.id ||
            pending['state'] != 'pending' ||
            pending['requestDigest'] is! String ||
            !RegExp(
              r'^[a-f0-9]{64}$',
            ).hasMatch(pending['requestDigest'] as String)) {
          throw AiFailure.invalidResponse;
        }
        final next = pending['requestDigest'] as String;
        if (digest != null && digest != next) throw AiFailure.invalidResponse;
        digest = next;
        _current(owner);
        final left = waitTimeout - clock.elapsed;
        if (left <= pollInterval) throw AiFailure.timeout;
        await Future<void>.delayed(pollInterval);
        _current(owner);
        response = await _http(
          'GET',
          uri.replace(queryParameters: {'requestId': request.id}),
          null,
          digest,
          owner,
          clock,
        );
      }
      return wire.result(response.$2);
    } on TimeoutException {
      _current(owner);
      if (owner == _revision) _outgoing?.abort();
      throw AiFailure.timeout;
    } on SocketException {
      _current(owner);
      throw AiFailure.network;
    } on HandshakeException {
      _current(owner);
      throw AiFailure.network;
    } on HttpException {
      _current(owner);
      throw AiFailure.network;
    } finally {
      if (owner == _revision) {
        _busy = false;
        _activeId = null;
        _outgoing = null;
      }
    }
  }

  /// Stops local waiting and invalidates late results. A submitted provider job
  /// may already be charged; the server retains its conservative reservation.
  @override
  void cancel(String requestId) {
    if (_activeId != requestId) return;
    ++_revision;
    _activeId = null;
    _busy = false;
    _outgoing?.abort();
    _outgoing = null;
  }

  @override
  void close() {
    _closed = true;
    ++_revision;
    _client.close(force: true);
  }
}
