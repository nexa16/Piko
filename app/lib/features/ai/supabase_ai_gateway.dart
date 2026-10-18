import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ai_content.dart';

/// This adapter is inert in ordinary builds. Only reviewed public connection
/// values may be supplied; provider and service-role keys belong on the server.
final class SupabaseAiGateway implements AiContentGateway {
  SupabaseAiGateway({
    this.url = const String.fromEnvironment('PIKO_AI_SUPABASE_URL'),
    this.publishableKey = const String.fromEnvironment(
      'PIKO_AI_PUBLISHABLE_KEY',
    ),
    this.liveApproved = const bool.fromEnvironment('PIKO_AI_LIVE_APPROVED'),
  });
  final String url, publishableKey;
  final bool liveApproved;
  SupabaseClient? _client;
  Future<void>? _connecting;
  int _generation = 0;
  @override
  bool get configured {
    final uri = Uri.tryParse(url);
    return liveApproved &&
        uri?.scheme == 'https' &&
        uri!.host.endsWith('.supabase.co') &&
        uri.path.isEmpty &&
        publishableKey.startsWith('sb_publishable_');
  }

  @override
  Future<void> connect() {
    if (!configured) return Future.error(AiFailure.unavailable);
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<void> _connect() async {
    final generation = _generation;
    final instance = await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
    _client = instance.client;
    if (generation != _generation) return;
    if (_client!.auth.currentSession == null) {
      await _client!.auth.signInAnonymously().timeout(
        const Duration(seconds: 30),
      );
    } else if (_client!.auth.currentSession!.isExpired) {
      await _client!.auth.refreshSession().timeout(const Duration(seconds: 30));
    }
    if (_client!.auth.currentUser?.isAnonymous != true) {
      throw AiFailure.authentication;
    }
  }

  @override
  Future<void> disconnect() async {
    _generation++;
    try {
      await _connecting;
    } catch (_) {
      /* No network retry on disconnect. */
    }
    // Local sign-out works offline and cannot touch the vocabulary database.
    await _client?.auth.signOut(scope: SignOutScope.local);
  }

  @override
  Future<Object?> generate(AiContentRequest request) async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) {
      throw AiFailure.authentication;
    }
    try {
      if (client.auth.currentSession!.isExpired) {
        await client.auth.refreshSession().timeout(const Duration(seconds: 30));
      }
      final result = await client.functions
          .invoke(
            'piko-content',
            body: request.toJson(),
            headers: {
              'Authorization':
                  'Bearer ${client.auth.currentSession!.accessToken}',
            },
          )
          .timeout(const Duration(seconds: 45));
      return result.data;
    } on FunctionException catch (failure) {
      throw switch (failure.status) {
        401 || 403 => AiFailure.authentication,
        409 => AiFailure.busy,
        429 => AiFailure.limit,
        503 => AiFailure.unavailable,
        _ => AiFailure.connection,
      };
    } on AuthException {
      throw AiFailure.authentication;
    } catch (_) {
      throw AiFailure.connection;
    }
  }
}
