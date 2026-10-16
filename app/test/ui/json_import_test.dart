import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/vocabulary_json.dart';
import 'package:piko/features/interchange/vocabulary_json_page.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'json_transfer_test.dart'
    show
        JsonTestService,
        JsonTestPlatform,
        owner,
        input,
        inputText,
        pressJson,
        mountJson,
        mountJsonRoute,
        settleJson;

class TestPreview implements VocabularyJsonPreview {
  TestPreview({
    this.issues = const [],
    Set<VocabularyJsonGroup> selected = VocabularyJsonGroup.all,
    this.newCount = 1,
    this.updatedCount = 2,
    this.unchangedCount = 3,
  }) : groups = Set.unmodifiable(selected);
  @override
  final List<VocabularyJsonIssue> issues;
  @override
  final Set<VocabularyJsonGroup> groups;
  @override
  String get collectionId => owner.id;
  @override
  Set<VocabularyJsonNotice> get notices => const {
    VocabularyJsonNotice.importedLearningIgnored,
  };
  @override
  final int newCount, updatedCount, unchangedCount;
  @override
  int get errorCount => issues.length;
  @override
  bool get canApply => issues.isEmpty;
}

class ImportService extends JsonTestService {
  int analyses = 0, applies = 0;
  Set<VocabularyJsonGroup>? selected;
  Completer<VocabularyJsonPreview>? analyzeGate;
  Completer<VocabularyJsonApplyResult>? applyGate;
  VocabularyJsonPreview? response;
  Object? applyFailure;
  @override
  Future<VocabularyJsonPreview> analyzeImport({
    required String collectionId,
    required String json,
    Set<VocabularyJsonGroup> groups = VocabularyJsonGroup.all,
  }) async {
    analyses++;
    selected = Set.unmodifiable(groups);
    return analyzeGate == null
        ? response ?? TestPreview(selected: groups)
        : analyzeGate!.future;
  }

  @override
  Future<VocabularyJsonApplyResult> applyImport(
    VocabularyJsonPreview preview,
  ) async {
    applies++;
    if (applyFailure != null) throw applyFailure!;
    return applyGate == null
        ? const VocabularyJsonApplyResult(
            newCount: 1,
            updatedCount: 2,
            unchangedCount: 3,
          )
        : applyGate!.future;
  }
}

Future<void> confirmJson(WidgetTester tester, String language) async {
  final button = find.descendant(
    of: find.byType(PikoDialog).last,
    matching: find.text(PikoCopy(language).text('json.apply')),
  );
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await settleJson(tester);
}

void main() {
  testWidgets(
    'successful import stays explicit until Return sends the owning-Collection intent',
    (tester) async {
      final service = ImportService();
      final returns = <VocabularyJsonReturn?>[];
      await mountJsonRoute(
        tester,
        service,
        JsonTestPlatform(),
        returned: returns.add,
      );
      await tester.enterText(input, 'source JSON');
      await pressJson(tester, 'json.analyze');
      final check = tester.widget<PikoButton>(
        find.widgetWithText(PikoButton, PikoCopy('en').text('json.analyze')),
      );
      expect(check.variant, PikoButtonVariant.primary);
      await pressJson(tester, 'json.apply');
      await confirmJson(tester, 'en');
      expect(find.byType(VocabularyJsonPage), findsOneWidget);
      expect(returns, isEmpty);
      expect(
        find.text(
          PikoCopy('en').text('json.importApplied', {
            'added': 1,
            'updated': 2,
            'unchanged': 3,
          }),
        ),
        findsOneWidget,
      );
      await pressJson(tester, 'json.returnToCollection');
      expect(returns, [VocabularyJsonReturn.collection]);
      expect(service.applies, 1);
      expect(find.byType(VocabularyJsonPage), findsNothing);
    },
  );

  testWidgets(
    'pending apply blocks switching and Back; failure preserves source and no success return',
    (tester) async {
      final service = ImportService()
        ..applyGate = Completer<VocabularyJsonApplyResult>();
      final returns = <VocabularyJsonReturn?>[];
      await mountJsonRoute(
        tester,
        service,
        JsonTestPlatform(),
        returned: returns.add,
      );
      await tester.enterText(input, 'recoverable JSON');
      await pressJson(tester, 'json.analyze');
      final switchView = tester
          .widget<PikoButton>(find.byKey(const ValueKey('json-export-tab')))
          .onPressed!;
      final staleBack = tester
          .widget<PikoButton>(
            find.widgetWithText(PikoButton, PikoCopy('en').text('common.back')),
          )
          .onPressed!;
      await pressJson(tester, 'json.apply');
      await confirmJson(tester, 'en');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<PikoButton>(find.byKey(const ValueKey('json-export-tab')))
            .onPressed,
        isNull,
      );
      expect(tester.widget<TextField>(input).enabled, isFalse);
      switchView();
      staleBack();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(returns, isEmpty);
      expect(find.byType(VocabularyJsonPage), findsOneWidget);
      expect(find.text(PikoCopy('en').text('json.copy')), findsNothing);
      service.applyGate!.completeError(StateError('write failed'));
      await tester.pumpAndSettle();
      expect(inputText(tester), 'recoverable JSON');
      expect(tester.widget<TextField>(input).enabled, isTrue);
      expect(
        find.text(PikoCopy('en').text('json.applyFailed')),
        findsOneWidget,
      );
      expect(
        find.text(PikoCopy('en').text('json.returnToCollection')),
        findsNothing,
      );
      expect(returns, isEmpty);
      expect(service.applies, 1);
    },
  );

  testWidgets(
    '320px German at 200% keeps grouped review, confirmation and export fallback reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = ImportService();
      final platform = JsonTestPlatform()
        ..copyFailure = StateError('Clipboard unavailable');
      await tester.pumpWidget(
        PikoApp(
          localeController: InterfaceLocaleController(const Locale('de')),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: VocabularyJsonPage(
                collection: owner,
                service: service,
                platform: platform,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(input, 'raw JSON');
      await pressJson(tester, 'json.analyze', language: 'de');
      await pressJson(tester, 'json.apply', language: 'de');
      await confirmJson(tester, 'de');
      expect(service.applies, 1);
      await pressJson(tester, 'json.exportTab', language: 'de');
      await pressJson(tester, 'json.copy', language: 'de');
      final output = tester.widget<TextField>(
        find.byKey(const ValueKey('json-fallback')),
      );
      expect(output.controller!.text, service.exported);
      await pressJson(tester, 'json.importTab', language: 'de');
      expect(tester.widget<TextField>(input).controller!.text, 'raw JSON');
      expect(tester.takeException(), isNull);
    },
  );
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language whole-batch defaults, aggregate review and one safe confirmation precede apply',
      (tester) async {
        final service = ImportService();
        final copied = <VocabularyJsonApplyResult>[];
        final pending = <Future<void>>[];
        await tester.pumpWidget(
          PikoApp(
            localeController: InterfaceLocaleController(Locale(language)),
            home: VocabularyJsonPage(
              collection: owner,
              service: service,
              platform: JsonTestPlatform(),
              onImported: copied.add,
              onPendingWrites: pending.add,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(input, 'editable source');
        expect(
          tester
              .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
              .every((tile) => tile.value == true),
          isTrue,
        );
        await pressJson(tester, 'json.analyze', language: language);
        expect(service.selected, VocabularyJsonGroup.all);
        expect(service.applies, 0);
        expect(
          find.text(
            PikoCopy(language).text('r2.jsonSummary', {
              'added': 1,
              'updated': 2,
              'unchanged': 3,
              'errors': 0,
            }),
          ),
          findsOneWidget,
        );
        await pressJson(tester, 'json.apply', language: language);
        expect(find.byType(PikoDialog), findsOneWidget);
        expect(
          find.byTooltip(PikoCopy(language).text('common.close')),
          findsNothing,
        );
        expect(service.applies, 0);
        await tester.tap(find.text(PikoCopy(language).text('action.cancel')));
        await tester.pumpAndSettle();
        expect(service.applies, 0);
        await pressJson(tester, 'json.apply', language: language);
        await confirmJson(tester, language);
        expect(service.applies, 1);
        expect(copied, hasLength(1));
        expect(
          find.text(
            PikoCopy(language).text('json.importApplied', {
              'added': 1,
              'updated': 2,
              'unchanged': 3,
            }),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(input).controller!.text,
          'editable source',
        );
        await Future.wait(pending);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$language groups and input invalidate preview; actionable aggregate errors never offer apply',
      (tester) async {
        final service = ImportService();
        await mountJson(
          tester,
          service,
          JsonTestPlatform(),
          language: language,
        );
        await pressJson(tester, 'json.analyze', language: language);
        final native = find.byKey(const ValueKey('json-group-nativeText'));
        await tester.ensureVisible(native);
        await tester.tap(native);
        await tester.pumpAndSettle();
        expect(find.text(PikoCopy(language).text('json.apply')), findsNothing);
        await pressJson(tester, 'json.analyze', language: language);
        expect(service.selected, {
          VocabularyJsonGroup.targetText,
          VocabularyJsonGroup.categoryAssignments,
          VocabularyJsonGroup.example,
          VocabularyJsonGroup.hint,
          VocabularyJsonGroup.activity,
        });
        final staleApply = tester
            .widget<PikoButton>(
              find.widgetWithText(
                PikoButton,
                PikoCopy(language).text('json.apply'),
              ),
            )
            .onPressed!;
        await tester.enterText(input, 'new input');
        await tester.pumpAndSettle();
        staleApply();
        await tester.pumpAndSettle();
        expect(find.byType(PikoDialog), findsNothing);
        expect(find.text(PikoCopy(language).text('json.apply')), findsNothing);
        service.response = TestPreview(
          selected: service.selected!,
          issues: const [
            VocabularyJsonIssue(
              code: VocabularyJsonIssueCode.foreignId,
              path: r'$.collections[0].entries[1].id',
              row: 2,
            ),
          ],
        );
        await pressJson(tester, 'json.analyze', language: language);
        expect(
          find.text(PikoCopy(language).text('json.foreignId')),
          findsOneWidget,
        );
        expect(
          find.text(
            PikoCopy(language).text('json.issueLocation', {
              'row': 2,
              'path': r'$.collections[0].entries[1].id',
            }),
          ),
          findsOneWidget,
        );
        expect(find.text(PikoCopy(language).text('json.apply')), findsNothing);
        expect(service.applies, 0);
      },
    );
  }

  testWidgets(
    'empty batch group selection reports groupsRequired instead of allowing import',
    (tester) async {
      final service = ImportService();
      await mountJson(tester, service, JsonTestPlatform());
      for (final group in VocabularyJsonGroup.values) {
        final tile = find.byKey(ValueKey('json-group-${group.name}'));
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
      }
      service.response = TestPreview(
        selected: {},
        issues: const [
          VocabularyJsonIssue(
            code: VocabularyJsonIssueCode.groupsRequired,
            path: 'groups',
          ),
        ],
      );
      await pressJson(tester, 'json.analyze');
      expect(service.selected, isEmpty);
      expect(
        find.text(PikoCopy('en').text('r2.jsonGroupsRequired')),
        findsOneWidget,
      );
      expect(find.text(PikoCopy('en').text('json.apply')), findsNothing);
      expect(service.applies, 0);
    },
  );

  testWidgets(
    'new typing rejects late analysis; stale apply requires fresh analysis and pending apply freezes editing',
    (tester) async {
      final service = ImportService()
        ..analyzeGate = Completer<VocabularyJsonPreview>();
      await mountJson(tester, service, JsonTestPlatform());
      await pressJson(tester, 'json.analyze');
      await tester.enterText(input, 'newer source');
      service.analyzeGate!.complete(TestPreview());
      await tester.pumpAndSettle();
      expect(find.text(PikoCopy('en').text('json.apply')), findsNothing);
      service.analyzeGate = null;
      service.applyFailure = VocabularyJsonApplyFailure.stalePreview;
      await pressJson(tester, 'json.analyze');
      await pressJson(tester, 'json.apply');
      await confirmJson(tester, 'en');
      expect(
        find.text(PikoCopy('en').text('json.stalePreview')),
        findsOneWidget,
      );
      expect(find.text(PikoCopy('en').text('json.apply')), findsNothing);
      service.applyFailure = null;
      service.applyGate = Completer<VocabularyJsonApplyResult>();
      await pressJson(tester, 'json.analyze');
      await pressJson(tester, 'json.apply');
      await confirmJson(tester, 'en');
      expect(tester.widget<TextField>(input).enabled, isFalse);
      expect(
        tester
            .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
            .every((tile) => tile.onChanged == null),
        isTrue,
      );
      service.applyGate!.complete(
        const VocabularyJsonApplyResult(
          newCount: 1,
          updatedCount: 0,
          unchangedCount: 0,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).enabled, isTrue);
    },
  );

  testWidgets(
    'accepted apply drains after disposal without stale imported callback or route effects',
    (tester) async {
      final service = ImportService()
        ..applyGate = Completer<VocabularyJsonApplyResult>();
      final notifications = <VocabularyJsonApplyResult>[];
      final pending = <Future<void>>[];
      await tester.pumpWidget(
        PikoApp(
          home: VocabularyJsonPage(
            collection: owner,
            service: service,
            platform: JsonTestPlatform(),
            onImported: notifications.add,
            onPendingWrites: pending.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await pressJson(tester, 'json.analyze');
      await pressJson(tester, 'json.apply');
      await confirmJson(tester, 'en');
      expect(service.applies, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      service.applyGate!.complete(
        const VocabularyJsonApplyResult(
          newCount: 1,
          updatedCount: 2,
          unchangedCount: 3,
        ),
      );
      await Future.wait(pending);
      await tester.pump();
      expect(notifications, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real validated batch updates UUID content and adds fresh word only after confirmation without changing existing learning',
    (tester) async {
      final db = PikoDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await db.close();
      });
      final collection = await SqliteCollectionsRepository(db).create(
        name: 'French',
        targetLanguage: VocabularyLanguage.french,
        nativeLanguage: VocabularyLanguage.german,
      );
      final vocabulary = SqliteVocabularyRepository(db);
      final original = await vocabulary.create(
        collectionId: collection.id,
        targetText: 'pomme',
        nativeText: 'Apfel',
      );
      final before =
          (await db
                  .customSelect('SELECT * FROM learning_items ORDER BY id')
                  .get())
              .map((row) => row.data)
              .toList();
      expect(before, hasLength(2));
      await mountJson(
        tester,
        SqliteVocabularyJsonService(db),
        JsonTestPlatform(),
        collection: collection,
      );
      await tester.enterText(
        input,
        jsonEncode({
          'format': 'piko-vocabulary',
          'schemaVersion': 1,
          'collections': [
            {
              'targetLanguage': 'fr',
              'nativeLanguage': 'de',
              'entries': [
                {
                  'id': original.id,
                  'targetText': 'pear',
                  'nativeText': 'Birne',
                  'learning': {'ignored': true},
                },
                {'targetText': 'eau', 'nativeText': 'Wasser'},
              ],
            },
          ],
        }),
      );
      await pressJson(tester, 'json.analyze');
      final beforeRows = await tester.runAsync(
        () => vocabulary.watchByCollection(collection.id).first,
      );
      expect(beforeRows!.single.targetText, 'pomme');
      await pressJson(tester, 'json.apply');
      await confirmJson(tester, 'en');
      final after = (await tester.runAsync(
        () => vocabulary.watchByCollection(collection.id).first,
      ))!;
      expect(after, hasLength(2));
      expect(after.first.id, original.id);
      expect(after.first.targetText, 'pear');
      expect(after.last.targetText, 'eau');
      // Compare original identities directly; added words have independent new cards.
      final allLearning =
          (await db
                  .customSelect('SELECT * FROM learning_items ORDER BY id')
                  .get())
              .map((row) => row.data)
              .toList();
      expect(allLearning.take(2).toList(), before);
      expect(allLearning, hasLength(4));
    },
  );
}
