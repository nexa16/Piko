import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/ai/ai_connection_controller.dart';
import 'package:piko/platform/ai_credential_vault.dart';

const config = AiConnectionConfiguration(
  'https://synthetic.supabase.co',
  'sb_publishable_synthetic',
  'https://synthetic.supabase.co/functions/v1/piko-ai',
);
const userId = '00000000-0000-4000-8000-000000000001';
String token({bool expired = false}) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': userId, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + (expired ? -3600 : 3600)})}.synthetic';
}

AiAuthSession session({bool expired = false}) => AiAuthSession(
  userId: userId,
  serialized: jsonEncode(
    Session(
      accessToken: token(expired: expired),
      refreshToken: 'synthetic-refresh-only',
      tokenType: 'bearer',
      user: const User(
        id: userId,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-10-18T00:00:00Z',
        isAnonymous: true,
      ),
    ).toJson(),
  ),
);

class MemoryVault implements AiCredentialVault {
  String? value;
  int reads = 0, writes = 0, deletes = 0;
  bool failRead = false, failWrite = false;
  Completer<String?>? held;
  @override
  Future<String?> read() async {
    reads++;
    if (failRead) throw StateError('Synthetic unavailable vault');
    return held == null ? value : held!.future;
  }

  @override
  Future<void> write(String v) async {
    writes++;
    if (failWrite) throw StateError('Synthetic write fault');
    value = v;
  }

  @override
  Future<void> delete() async {
    deletes++;
    value = null;
  }
}

class AuthGateway implements AiAuthGateway {
  int connections = 0, inspections = 0, closures = 0;
  String? supplied;
  Object? failure;
  Completer<AiAuthSession>? held;
  @override
  AiAuthSession inspect(String serialized) {
    inspections++;
    return AiAuthSession(userId: userId, serialized: serialized);
  }

  @override
  Future<AiAuthSession> connect(String? stored) async {
    connections++;
    supplied = stored;
    if (failure != null) throw failure!;
    return held == null ? session() : held!.future;
  }

  @override
  Future<void> close() async {
    closures++;
  }
}

void main() {
  test('late explicit reactivation cannot overtake a newer withdrawal', () async {
    final v=MemoryVault()..value=session().serialized,g=AuthGateway();
    final c=AiConnectionController(configuration:config,vault:v,gateway:g,enabled:true);
    await c.stopPilotLocally();
    v.held=Completer<String?>();
    final resume=c.resumeExistingPilot();
    final rejection=expectLater(resume,throwsA(AiFailure.accessDenied));
    final stop=c.stopPilotLocally();
    final held=v.held!;v.held=null;held.complete(v.value);
    await rejection;await stop;
    expect(c.pilotStopped,isTrue);expect(g.connections,0);
    expect(jsonDecode(v.value!)['pikoPilotWithdrawn'],isTrue);
    c.dispose();
  });
  test(
    'explicit reactivation reuses retained identity without granting consent',
    () async {
      final v = MemoryVault()..value = session().serialized, g = AuthGateway();
      final c = AiConnectionController(
        configuration: config,
        vault: v,
        gateway: g,
        enabled: true,
      );
      await c.stopPilotLocally();
      expect(c.pilotStopped, isTrue);
      await expectLater(c.accessToken(), throwsA(AiFailure.accessDenied));
      await c.resumeExistingPilot();
      expect(g.connections, 1);
      expect(g.supplied, isNotNull);
      expect(c.deviceAccessId, userId);
      expect(c.pilotStopped, isFalse);
      c.dispose();
    },
  );
  test(
    'withdrawal denial survives restart/disconnect and only deletion can refresh its retained session',
    () async {
      final v = MemoryVault()..value = session().serialized, g = AuthGateway();
      final c = AiConnectionController(
        configuration: config,
        vault: v,
        gateway: g,
        enabled: true,
      );
      await c.loadLocal();
      await c.stopPilotLocally();
      await expectLater(c.accessToken(), throwsA(AiFailure.accessDenied));
      await c.disconnect();
      expect(v.deletes, 0);
      c.dispose();
      final resumed = AiConnectionController(
        configuration: config,
        vault: v,
        gateway: g,
        enabled: true,
      );
      addTearDown(resumed.dispose);
      await resumed.loadLocal();
      await expectLater(resumed.connect(), throwsA(AiFailure.accessDenied));
      expect(g.connections, 0);
      expect(await resumed.withdrawalAccessToken(), isNotNull);
      expect(g.connections, 1);
      expect((jsonDecode(v.value!) as Map)['pikoPilotWithdrawn'], true);
      await expectLater(resumed.accessToken(), throwsA(AiFailure.accessDenied));
    },
  );

  test(
    'disabled and unconfigured access never touches credentials or enrolls, including restored token path',
    () async {
      final v = MemoryVault()..value = session().serialized, g = AuthGateway();
      final off = AiConnectionController(
        configuration: config,
        vault: v,
        gateway: g,
        enabled: false,
      );
      addTearDown(off.dispose);
      await off.loadLocal();
      await expectLater(off.accessToken(), throwsA(AiFailure.disabled));
      expect(v.reads, 0);
      expect(g.connections, 0);
      final unavailable = AiConnectionController(
        configuration: const AiConnectionConfiguration('', '', ''),
        vault: v,
        gateway: g,
        enabled: true,
      );
      addTearDown(unavailable.dispose);
      await expectLater(unavailable.connect(), throwsA(AiFailure.unavailable));
      expect(v.reads, 0);
      expect(g.connections, 0);
    },
  );
  test(
    'local session inspection has no enrollment/refresh/network; valid user request reuses it without writing',
    () async {
      final v = MemoryVault()..value = session().serialized, g = AuthGateway();
      final c = AiConnectionController(
        configuration: config,
        vault: v,
        gateway: g,
        enabled: true,
      );
      addTearDown(c.dispose);
      expect(v.reads, 0);
      expect(g.connections, 0);
      await c.loadLocal();
      expect(c.deviceAccessId, userId);
      expect(g.connections, 0);
      expect(await c.accessToken(), token());
      expect(g.connections, 0);
      expect(v.writes, 0);
    },
  );
  test(
    'explicit connection is single flight and persists only one encrypted-vault session',
    () async {
      final v = MemoryVault(),
          g = AuthGateway()..held = Completer<AiAuthSession>();
      final c = AiConnectionController(
        configuration: config,
        vault: v,
        gateway: g,
        enabled: true,
      );
      addTearDown(c.dispose);
      final a = c.connect(), b = c.connect();
      await Future<void>.delayed(Duration.zero);
      expect(g.connections, 1);
      g.held!.complete(session());
      await Future.wait([a, b]);
      expect(v.writes, 1);
      expect(c.deviceAccessId, userId);
      expect(c.busy, isFalse);
    },
  );
  test(
    'unreadable or unwritable saved access is retained and never silently replaced with another identity',
    () async {
      final v = MemoryVault()
            ..value = 'synthetic existing ciphertext representation'
            ..failRead = true,
          g = AuthGateway();
      final c = AiConnectionController(
        configuration: config,
        vault: v,
        gateway: g,
        enabled: true,
      );
      addTearDown(c.dispose);
      await expectLater(c.connect(), throwsA(AiFailure.unavailable));
      expect(g.connections, 0);
      expect(v.deletes, 0);
      expect(v.value, isNotNull);
      v.failRead = false;
      // A readable session reaches the independent encrypted-vault write fault.
      v.value = session().serialized;
      v.failWrite = true;
      final old = v.value;
      await expectLater(c.connect(), throwsA(AiFailure.unavailable));
      expect(g.supplied, old);
      expect(v.value, old);
      expect(v.deletes, 0);
    },
  );
  test(
    'expired access refresh is explicit; auth rejection preserves saved credential instead of anonymous rotation',
    () async {
      final v = MemoryVault()..value = session(expired: true).serialized,
          g = AuthGateway()
            ..failure = const AuthException('Synthetic access denied');
      final c = AiConnectionController(
        configuration: config,
        vault: v,
        gateway: g,
        enabled: true,
      );
      addTearDown(c.dispose);
      await c.loadLocal();
      final old = v.value;
      await expectLater(c.accessToken(), throwsA(AiFailure.accessDenied));
      expect(g.supplied, old);
      expect(v.value, old);
      expect(v.deletes, 0);
      expect(g.connections, 1);
    },
  );
  test(
    'disconnect clears only connection state and prevents implicit re-enrollment; late local read cannot enroll after disposal',
    () async {
      final v = MemoryVault()..value = session().serialized, g = AuthGateway();
      final c = AiConnectionController(
        configuration: config,
        vault: v,
        gateway: g,
        enabled: true,
      );
      await c.loadLocal();
      await c.disconnect();
      expect(v.deletes, 1);
      expect(v.value, isNull);
      expect(c.deviceAccessId, isNull);
      await expectLater(c.accessToken(), throwsA(AiFailure.accessDenied));
      expect(g.connections, 0);
      c.dispose();
      final held = MemoryVault()..held = Completer<String?>(),
          gateway = AuthGateway();
      final late = AiConnectionController(
        configuration: config,
        vault: held,
        gateway: gateway,
        enabled: true,
      );
      final pending = late.connect(),
          assertion = expectLater(pending, throwsA(AiFailure.accessDenied));
      late.dispose();
      held.held!.complete(null);
      await assertion;
      expect(gateway.connections, 0);
      expect(held.writes, 0);
    },
  );
  test(
    'client config accepts only the same managed HTTPS project and publishable key, never a server/provider secret',
    () {
      expect(config.available, isTrue);
      for (final bad in [
        const AiConnectionConfiguration(
          'http://synthetic.supabase.co',
          'sb_publishable_synthetic',
          'http://synthetic.supabase.co/functions/v1/piko-ai',
        ),
        const AiConnectionConfiguration(
          'https://synthetic.supabase.co',
          'sb_secret_not_allowed',
          'https://synthetic.supabase.co/functions/v1/piko-ai',
        ),
        const AiConnectionConfiguration(
          'https://synthetic.supabase.co',
          'sk-provider-not-allowed',
          'https://synthetic.supabase.co/functions/v1/piko-ai',
        ),
        const AiConnectionConfiguration(
          'https://synthetic.supabase.co',
          'sb_publishable_synthetic',
          'https://other.supabase.co/functions/v1/piko-ai',
        ),
      ]) {
        expect(bad.available, isFalse);
      }
    },
  );
}
