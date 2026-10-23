import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/ai/ai_connection_controller.dart';
import 'package:piko/data/ai/managed_ai_provider.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'package:piko/features/ai/ai_connection_control.dart';
import 'package:piko/features/ai/ai_page.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import '../data/ai_connection_test.dart'
    show AuthGateway, MemoryVault, config, session, userId;
import '../data/regular_reviews_test.dart' show Fixture;
import 'ai_page_test.dart' show tapVisible;

/// This transport never creates a socket. The real ManagedAiProvider and
/// connection controller still own token access, pilot calls and decoding.
class _PilotTransport implements HttpClient {
  bool consented = false;
  final operations = <String>[];
  final generationBodies = <Map<String, Object?>>[];

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    expect(method, 'POST');
    expect(url.host, 'synthetic.supabase.co');
    return _Request((bytes) {
      final body = Map<String, Object?>.from(
        jsonDecode(utf8.decode(bytes)) as Map,
      );
      final operation = url.queryParameters['pilot'];
      if (operation != null) {
        operations.add(operation);
        expect(['notice', 'consent'], contains(operation));
        if (operation == 'consent') {
          expect(body, {'version': 'synthetic-access-status-v1'});
          consented = true;
        }
        return {
          'version': 'synthetic-access-status-v1',
          'contact': 'Synthetic fixture contact',
          'processors': 'In-memory transport; no remote provider',
          'endsAt': '2026-11-01T00:00:00Z',
          'consented': consented,
        };
      }
      expect(consented, isTrue);
      generationBodies.add(body);
      return {
        'requestId': body['requestId'],
        'complete': true,
        'processedIds': [],
        'groups': [],
        'values': [],
        'edits': [],
        'cards': [
          {
            'id': 'approved-proposal',
            'target': 'Synthetic approved word',
            'native': 'Synthetisch freigegeben',
            'hint': null,
            'examples': [
              {
                'target': 'A synthetic word.',
                'native': 'Ein synthetisches Wort.',
              },
            ],
            'assignments': [],
            'reason': 'Synthetic approved generation',
          },
        ],
        'limitations': [],
      };
    });
  }

  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Headers implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  set contentType(ContentType? value) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.respond);
  final Map<String, Object?> Function(List<int>) respond;
  final bytes = <int>[];
  @override
  final headers = _Headers();
  @override
  bool followRedirects = false;
  @override
  void add(List<int> data) => bytes.addAll(data);
  @override
  Future<HttpClientResponse> close() async => _Response(respond(bytes));
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(Map<String, Object?> data) : bytes = utf8.encode(jsonEncode(data));
  final List<int> bytes;
  @override
  int get statusCode => 200;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> waitFor(WidgetTester t, Finder target) async {
    for (
      var attempt = 0;
      attempt < 100 && target.evaluate().isEmpty;
      attempt++
    ) {
      // SQLite and the HTTP response stream use actual event-queue work, which
      // pumpAndSettle alone does not promise to drain on host bindings.
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.pumpAndSettle();
    expect(target, findsOneWidget);
  }

  for (final locale in ['en', 'de']) {
    testWidgets(
      'managed access $locale updates confirmed status after consent and returns to explicit generation',
      (t) async {
        final f = Fixture();
        await f.initialize();
        final vault = MemoryVault()..value = session().serialized;
        final gateway = AuthGateway();
        final connection = AiConnectionController(
          configuration: config,
          vault: vault,
          gateway: gateway,
          enabled: true,
        );
        final transport = _PilotTransport();
        final provider = ManagedAiProvider(
          endpoint: Uri.parse(config.endpoint),
          access: connection,
          enabled: true,
          client: transport,
        );
        addTearDown(() async {
          await t.pumpWidget(const SizedBox.shrink());
          provider.close();
          connection.dispose();
          await f.db.close();
        });
        final copy = PikoCopy(locale);
        await t.pumpWidget(
          PikoApp(
            locale: Locale(locale),
            home: AiPage(
              service: SqliteAiService(f.db, enabled: true),
              provider: provider,
              collectionId: f.owner.id,
              collectionName: 'Synthetic managed access',
              installationIdentity: () async => 'synthetic-access-installation',
            ),
          ),
        );
        await t.pumpAndSettle();
        await waitFor(t, find.byType(AiConnectionControl));
        expect(connection.configured, isTrue);
        expect(connection.deviceAccessId, userId);
        expect(
          find.byType(AiConnectionControl),
          findsOneWidget,
          reason:
              'Pilot operations ${transport.operations}; gateway ${gateway.connections}; UI ${find.byKey(const ValueKey('ai-consent')).evaluate().length} consent controls',
        );
        expect(find.text(copy.text('ai.accessNotConfirmed')), findsOneWidget);
        expect(find.text(copy.text('ai.accessConfirmed')), findsNothing);
        expect(
          gateway.connections,
          0,
          reason: 'Opening must not enroll an identity',
        );
        expect(transport.generationBodies, isEmpty);
        await tapVisible(t, find.byKey(const ValueKey('ai-consent')));
        await tapVisible(t, find.byKey(const ValueKey('ai-pilot-notice')));
        await waitFor(t, find.byKey(const ValueKey('ai-pilot-consent')));
        expect(find.text(copy.text('ai.accessNotConfirmed')), findsOneWidget);
        await tapVisible(t, find.byKey(const ValueKey('ai-pilot-consent')));
        await waitFor(t, find.text(copy.text('ai.accessConfirmed')));
        expect(transport.consented, isTrue);
        expect(find.text(copy.text('ai.accessConfirmed')), findsOneWidget);
        expect(find.text(copy.text('ai.accessNotConfirmed')), findsNothing);
        expect(transport.generationBodies, isEmpty);
        await tapVisible(
          t,
          find.byWidgetPredicate(
            (w) =>
                w is PikoIconButton &&
                w.semanticLabel == copy.text('common.close'),
          ),
        );
        expect(find.byType(AiConnectionControl), findsNothing);
        final goal = find.byKey(const ValueKey('ai-goal'));
        await t.ensureVisible(goal);
        await t.enterText(goal, 'Synthetic travel vocabulary');
        await t.pumpAndSettle();
        final start = find.byKey(const ValueKey('ai-start'));
        expect(t.widget<PikoButton>(start).onPressed, isNotNull);
        await tapVisible(t, start, settle: false);
        await waitFor(
          t,
          find.byKey(const ValueKey('ai-select-approved-proposal')),
        );
        expect(transport.generationBodies, hasLength(1));
        expect(transport.generationBodies.single['action'], 'generate');
        expect(
          find.byKey(const ValueKey('ai-select-approved-proposal')),
          findsOneWidget,
        );
        expect(find.text(copy.text('ai.error.accessDenied')), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }
}
