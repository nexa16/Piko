import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase/supabase.dart';
import 'ai_contract.dart';
import 'managed_ai_provider.dart';
import '../../platform/ai_credential_vault.dart';

final class AiConnectionConfiguration {
  const AiConnectionConfiguration(this.url, this.publishableKey, this.endpoint);
  static const environment = AiConnectionConfiguration(
    String.fromEnvironment('PIKO_AI_SUPABASE_URL'),
    String.fromEnvironment('PIKO_AI_PUBLISHABLE_KEY'),
    String.fromEnvironment('PIKO_AI_SERVICE_URL'),
  );
  final String url, publishableKey, endpoint;
  bool get available {
    final base = Uri.tryParse(url), service = Uri.tryParse(endpoint);
    return base != null &&
        service != null &&
        base.scheme == 'https' &&
        service.scheme == 'https' &&
        RegExp(r'^[a-z0-9-]+\.supabase\.co$').hasMatch(base.host) &&
        base.userInfo.isEmpty &&
        !base.hasQuery &&
        !base.hasFragment &&
        (base.path.isEmpty || base.path == '/') &&
        service.host == base.host &&
        service.userInfo.isEmpty &&
        !service.hasQuery &&
        !service.hasFragment &&
        service.path == '/functions/v1/piko-ai' &&
        publishableKey.startsWith('sb_publishable_');
  }
}

final class AiAuthSession {
  const AiAuthSession({required this.userId, required this.serialized});
  final String userId, serialized;
}

abstract interface class AiAuthGateway {
  AiAuthSession inspect(String serialized);
  Future<AiAuthSession> connect(String? serialized);
  Future<void> close();
}

final class SupabaseAiAuthGateway implements AiAuthGateway {
  SupabaseAiAuthGateway(this.configuration);
  final AiConnectionConfiguration configuration;
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _events;
  SupabaseClient get client {
    if (!configuration.available) throw AiFailure.unavailable;
    if (_client == null) {
      _client = SupabaseClient(
        configuration.url,
        configuration.publishableKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      _events = _client!.auth.onAuthStateChange.listen(
        (_) {},
        onError: (Object _, StackTrace _) {},
      );
    }
    return _client!;
  }

  AiAuthSession _session(Session? session) {
    if (session == null || session.user.isAnonymous != true) {
      throw AiFailure.accessDenied;
    }
    return AiAuthSession(
      userId: session.user.id,
      serialized: jsonEncode(session.toJson()),
    );
  }

  @override
  AiAuthSession inspect(String serialized) => _session(
    Session.fromJson(Map<String, dynamic>.from(jsonDecode(serialized) as Map)),
  );
  @override
  Future<AiAuthSession> connect(String? serialized) async {
    if (serialized != null) await client.auth.setInitialSession(serialized);
    var session = client.auth.currentSession;
    if (session == null) {
      session = (await client.auth.signInAnonymously()).session;
    } else if (session.isExpired) {
      session = (await client.auth.refreshSession()).session;
    }
    return _session(session);
  }

  @override
  Future<void> close() async {
    await _events?.cancel();
    _events = null;
    final old = _client;
    _client = null;
    await old?.dispose();
  }
}

/// No anonymous signup, refresh or provider request occurs on app launch.
/// Activation happens only at an explicit AI-connect/request boundary.
final class AiConnectionController extends ChangeNotifier
    implements AiAccess, AiPilotLocalStop {
  AiConnectionController({
    required this.configuration,
    required this.vault,
    required this.gateway,
    this.enabled = pikoAiEnabled,
  });
  final AiConnectionConfiguration configuration;
  final AiCredentialVault vault;
  final AiAuthGateway gateway;
  final bool enabled;
  String? deviceAccessId;
  AiFailure? error;
  bool busy = false, _disposed = false, _disconnected = false;
  int _revision = 0;
  Future<void>? _pending;
  String? _serialized;
  bool _pilotStopped = false;
  bool _stopped(String? value) =>
      value != null && (jsonDecode(value) as Map)['pikoPilotWithdrawn'] == true;
  bool get configured => enabled && configuration.available;
  Future<void> loadLocal() async {
    if (!enabled || !configured || _disposed) return;
    final owner = _revision;
    try {
      final saved = await vault.read();
      if (_disposed || owner != _revision) return;
      _serialized = saved;
      _pilotStopped = _stopped(saved);
      deviceAccessId = saved == null ? null : gateway.inspect(saved).userId;
    } catch (_) {
      if (!_disposed && owner == _revision) error = AiFailure.unavailable;
    }
    if (!_disposed && owner == _revision) notifyListeners();
  }

  Future<void> connect() {
    if (!enabled) return Future.error(AiFailure.disabled);
    if (!configured || _disposed) return Future.error(AiFailure.unavailable);
    if (_pending != null) return _pending!;
    final result = Completer<void>(), owner = ++_revision;
    _pending = result.future;
    busy = true;
    error = null;
    _disconnected = false;
    notifyListeners();
    unawaited(() async {
      try {
        final stored = await vault.read();
        if (_disposed || owner != _revision) throw AiFailure.accessDenied;
        _pilotStopped = _pilotStopped || _stopped(stored);
        if (_pilotStopped) throw AiFailure.accessDenied;
        final session = await gateway
            .connect(stored)
            .timeout(const Duration(seconds: 30));
        if (_disposed || owner != _revision) throw AiFailure.accessDenied;
        await vault.write(session.serialized);
        if (_disposed || owner != _revision) throw AiFailure.accessDenied;
        _serialized = session.serialized;
        deviceAccessId = session.userId;
        result.complete();
      } catch (failure, stack) {
        final mapped = failure is AiFailure
            ? failure
            : failure is AuthException
            ? AiFailure.accessDenied
            : failure is SocketException || failure is TimeoutException
            ? AiFailure.network
            : AiFailure.unavailable;
        if (!_disposed && owner == _revision) error = mapped;
        result.completeError(mapped, stack);
      } finally {
        if (owner == _revision) {
          _pending = null;
          busy = false;
          if (!_disposed) notifyListeners();
        }
      }
    }());
    return result.future;
  }

  @override
  Future<String?> accessToken() async {
    if (!enabled) throw AiFailure.disabled;
    if (_disconnected || _disposed || _pilotStopped) {
      throw AiFailure.accessDenied;
    }
    if (error != null) throw error!;
    if (_serialized != null) {
      final current = Session.fromJson(
        Map<String, dynamic>.from(jsonDecode(_serialized!) as Map),
      );
      if (current != null && !current.isExpired) return current.accessToken;
    }
    await connect();
    final session = Session.fromJson(
      Map<String, dynamic>.from(jsonDecode(_serialized!) as Map),
    );
    return session?.accessToken;
  }

  @override
  Future<void> stopPilotLocally() async {
    if (!enabled || _disposed) throw AiFailure.disabled;
    _pilotStopped = true;
    ++_revision;
    final pending = _pending;
    _pending = null;
    busy = false;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    final saved = await vault.read();
    if (saved == null) throw AiFailure.accessDenied;
    final content = Map<String, dynamic>.from(jsonDecode(saved) as Map)
      ..['pikoPilotWithdrawn'] = true;
    _serialized = jsonEncode(content);
    await vault.write(_serialized!);
    notifyListeners();
  }

  @override
  Future<String?> withdrawalAccessToken() async {
    if (!enabled || _disposed) throw AiFailure.disabled;
    final saved = await vault.read();
    if (saved == null) throw AiFailure.accessDenied;
    final session = await gateway
        .connect(saved)
        .timeout(const Duration(seconds: 30));
    final content = Map<String, dynamic>.from(
      jsonDecode(session.serialized) as Map,
    )..['pikoPilotWithdrawn'] = true;
    _pilotStopped = true;
    _serialized = jsonEncode(content);
    await vault.write(_serialized!);
    return Session.fromJson(content)?.accessToken;
  }

  Future<void> disconnect() async {
    if (!enabled || _disposed) throw AiFailure.disabled;
    if (busy) throw AiFailure.unavailable;
    ++_revision;
    _disconnected = true;
    await gateway.close();
    if (!_pilotStopped) await vault.delete();
    _serialized = null;
    deviceAccessId = null;
    error = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_revision;
    unawaited(gateway.close().catchError((Object _) {}));
    super.dispose();
  }
}
