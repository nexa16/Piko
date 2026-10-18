import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'ai_contract.dart';

/// Credentials are per-session backend access, never provider keys. Concrete
/// enrollment/storage is separate from content generation and requires consent.
abstract interface class AiAccess {
  Future<String?> accessToken();
}

final class UnavailableAiAccess implements AiAccess {
  const UnavailableAiAccess();
  @override
  Future<String?> accessToken() async => null;
}

final class ManagedAiProvider implements AiProvider {
  ManagedAiProvider({
    required this.endpoint,
    required this.access,
    this.enabled = pikoAiEnabled,
    HttpClient? client,
  }) : _client = client ?? HttpClient();
  final Uri? endpoint;
  final AiAccess access;
  final bool enabled;
  final HttpClient _client;
  bool _busy = false, _closed = false;
  static const maxInputBytes = 192000, maxResponseBytes = 2000000;
  @override
  Future<Map<String, Object?>> generate(AiRequest request) async {
    if (!enabled) throw AiFailure.disabled;
    if (_closed || _busy || endpoint == null) throw AiFailure.unavailable;
    final uri = endpoint!;
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasQuery) {
      throw AiFailure.unavailable;
    }
    final body = utf8.encode(jsonEncode(request.toJson()));
    if (body.length > maxInputBytes) throw AiFailure.contextLimit;
    _busy = true;
    HttpClientRequest? outgoing;
    try {
      final token = await access.accessToken();
      if (token == null || token.isEmpty) throw AiFailure.accessDenied;
      outgoing = await _client
          .postUrl(uri)
          .timeout(const Duration(seconds: 30));
      outgoing.followRedirects = false;
      outgoing.headers.contentType = ContentType.json;
      outgoing.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      outgoing.add(body);
      final response = await outgoing.close().timeout(
        const Duration(minutes: 5),
      );
      final bytes = <int>[];
      await for (final part in response.timeout(const Duration(seconds: 30))) {
        if (bytes.length + part.length > maxResponseBytes) {
          throw AiFailure.invalidResponse;
        }
        bytes.addAll(part);
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw AiFailure.accessDenied;
      }
      if (response.statusCode == 429) throw AiFailure.limit;
      if (response.statusCode == 413) throw AiFailure.contextLimit;
      if (response.statusCode != 200) throw AiFailure.unavailable;
      try {
        return aiObject(jsonDecode(utf8.decode(bytes)));
      } on FormatException {
        throw AiFailure.invalidResponse;
      }
    } on TimeoutException {
      outgoing?.abort();
      throw AiFailure.timeout;
    } on SocketException {
      throw AiFailure.network;
    } on HandshakeException {
      throw AiFailure.network;
    } finally {
      _busy = false;
    }
  }

  @override
  void close() {
    _closed = true;
    _client.close(force: true);
  }
}
