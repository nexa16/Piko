import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/vocabulary_normalization.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/features/interchange/vocabulary_json_page.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/platform/vocabulary_json_platform.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'package:uuid/uuid.dart';

import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;

// Coordinator protocol (emulator, --no-uninstall only):
// Required --dart-define=PIKO_NATIVE_RUN=<unique safe ID> and
// --dart-define=PIKO_NATIVE_COMMIT=<tested commit>; optional PIKO_NATIVE_LOCALE=en|de.
// Optional PIKO_NATIVE_MODE=import-only narrows a diagnostic rerun to NEW fixture
// Save/Open/Analyze/confirmed Apply/reopen. It does not verify IME, clipboard or
// cancellation and emits PIKO_NATIVE_IMPORT_ONLY_PASSED, never the full marker.
// Clipboard mutation is disabled by default. PIKO_NATIVE_OWNED_CLIPBOARD=true
// is only for an explicitly owned clipboard on a separate disposable emulator;
// available plaintext cannot prove a shared ClipData has no other private items.
// PIKO_NATIVE_DIRECTORY gives the newly owned app-support directory. At every
// PIKO_NATIVE_PHASE:<run>:<phase>, capture a DEVICE screenshot, perform the named
// OS action, then create an empty ack-<phase> file in that directory (run-as).
// ACKs are synchronization, never substitutes for the assertions below.
// Save uses the DEFAULT production platform and filename. In the OS Save dialog
// change it to piko-native-<run>-<locale>.json in an approved scratch destination;
// never overwrite an existing file. Open selects exactly that synthetic file.
// No production database, personal file, or original clipboard text is logged.
// The fixture DB/manifest are retained. No uninstall, clearing or cleanup occurs.

Finder _key(String key) => find.byKey(ValueKey(key));
Finder _field(String side) =>
    find.descendant(of: _key('draft-$side'), matching: find.byType(TextField));
Finder _button(String label) => find.widgetWithText(PikoButton, label);

class _NativeDatabase extends PikoDatabase {
  _NativeDatabase(File file) : super(NativeDatabase(file));
  final closed = Completer<void>();
  bool closing = false;
  @override
  Future<void> close() async {
    if (closing) return closed.future;
    closing = true;
    try {
      await super.close();
      closed.complete();
    } catch (error, stack) {
      closed.completeError(error, stack);
      rethrow;
    }
  }
}

Future<void> _wait(
  WidgetTester tester,
  FutureOr<bool> Function() ready,
  String description, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (await ready()) return;
    // Give actual platform events and host filesystem acknowledgments wall time.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('Native acceptance timeout: $description');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _wait(tester, () => finder.evaluate().isNotEmpty, '$finder present');
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(
    finder.hitTestable(),
    findsOneWidget,
    reason: 'Native fixture action must receive its tap',
  );
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'round 2 real Android IME, clipboard and document pickers',
    (tester) async {
      const run = String.fromEnvironment('PIKO_NATIVE_RUN');
      const commit = String.fromEnvironment('PIKO_NATIVE_COMMIT');
      const locale = String.fromEnvironment(
        'PIKO_NATIVE_LOCALE',
        defaultValue: 'en',
      );
      const mode = String.fromEnvironment(
        'PIKO_NATIVE_MODE',
        defaultValue: 'full',
      );
      const ownedClipboard = bool.fromEnvironment(
        'PIKO_NATIVE_OWNED_CLIPBOARD',
      );
      final fullNative = mode == 'full';
      if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{3,63}$').hasMatch(run) ||
          !RegExp(r'^[a-fA-F0-9]{7,40}$').hasMatch(commit) ||
          !['en', 'de'].contains(locale) ||
          !['full', 'import-only'].contains(mode)) {
        throw ArgumentError(
          'Required safe PIKO_NATIVE_RUN/COMMIT and en/de locale',
        );
      }
      expect(binding.registerTestTextInput, isFalse);
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/round2-native-$run-$locale');
      if (await directory.exists()) {
        throw StateError('Refusing to reuse existing native fixture directory');
      }
      await directory.create();
      debugPrint('PIKO_NATIVE_DIRECTORY:${directory.path}');
      final db = _NativeDatabase(File('${directory.path}/fixture.sqlite'));
      final phases = <Map<String, Object?>>[];
      var status = 'running';
      var mounted = false;
      var clipboardCaptured = false;
      var clipboardRestored = false;
      var clipboardVerification = 'not-yet-verified';
      String? previousPlaintext;
      final savedName = 'piko-native-$run-$locale.json';
      Future<void> manifest() => File('${directory.path}/manifest.json')
          .writeAsString(
            const JsonEncoder.withIndent('  ').convert({
              'schemaVersion': 1,
              'runId': run,
              'commit': commit,
              'locale': locale,
              'acceptanceScope': mode,
              'fixture':
                  'synthetic Korean Basics, five exported entries; confirmed import updates one and appends one',
              'database': 'fixture.sqlite',
              'platform':
                  'default SystemVocabularyJsonPlatform, real Android services',
              'savedFileNameRequested': savedName,
              'screenshots': 'host captures device screenshots before each ACK',
              'status': status,
              'clipboardRestored': clipboardRestored,
              'clipboardVerification': clipboardVerification,
              'ownedDisposableClipboardOptIn': ownedClipboard,
              'clipboardPolicy':
                  'default no clipboard access or mutation; only explicitly owned disposable-emulator clipboard may opt in, with plaintext restored from memory',
              'specRevisions': {
                'UX-ENTRY-001': 4,
                'IMPORT-JSON-001': 1,
                'IMPORT-JSON-002': 1,
              },
              'phases': phases,
            }),
            flush: true,
          )
          .then((_) {});
      Future<void> phase(
        String id,
        String action, {
        Map<String, Object?> metadata = const {},
      }) async {
        phases.add({
          'id': id,
          'action': action,
          'atUtc': DateTime.now().toUtc().toIso8601String(),
          ...metadata,
        });
        await manifest();
        debugPrint('PIKO_NATIVE_PHASE:$run:$id ACTION:$action');
        final ack = File('${directory.path}/ack-$id');
        await _wait(
          tester,
          ack.exists,
          'host ACK for $id: $action',
          timeout: const Duration(minutes: 5),
        );
        phases.last['acknowledgedAtUtc'] = DateTime.now()
            .toUtc()
            .toIso8601String();
        await manifest();
      }

      double inset() => MediaQuery.viewInsetsOf(
        tester.element(find.byType(EntrySessionScreen)),
      ).bottom;
      bool focused(String side) =>
          tester.widget<TextField>(_field(side)).focusNode!.hasFocus;
      Map<String, Object?> entryGeometry() {
        final bounds = tester.getRect(_key('draft-target'));
        return {
          'targetBounds': {
            'left': bounds.left,
            'top': bounds.top,
            'right': bounds.right,
            'bottom': bounds.bottom,
          },
          'imeInset': inset(),
          'logicalHeight':
              tester.view.physicalSize.height / tester.view.devicePixelRatio,
        };
      }

      try {
        await manifest();
        final owner = await SqliteCollectionsRepository(db).create(
          name: 'Korean Basics',
          targetLanguage: VocabularyLanguage.korean,
          nativeLanguage: VocabularyLanguage.german,
        );
        final vocabulary = SqliteVocabularyRepository(db);
        for (final pair in const [
          ('사과', 'Apfel'),
          ('물', 'Wasser'),
          ('학교', 'Schule'),
          ('친구', 'Freund'),
          ('책', 'Buch'),
        ]) {
          await vocabulary.create(
            collectionId: owner.id,
            targetText: pair.$1,
            nativeText: pair.$2,
          );
        }
        await SqliteSettingsRepository(db).write('locale', locale);
        mounted = true;
        // Deliberately no jsonPlatform injection: exercise production defaults.
        await tester.pumpWidget(
          PikoApp(home: PikoRuntime(databaseFactory: () => db)),
        );
        final copy = await hydratedRuntimeCopy(tester);
        expect(copy.locale, locale);
        await _tap(tester, _key('collection-${owner.id}'));
        await _tap(tester, _button(copy.text('action.new')));
        if (fullNative) {
          await phase(
            'ime-configuration',
            'Ensure the emulator uses a docked software keyboard, not a hardware-keyboard toolbar; ACK only after configuration',
          );
          await _wait(
            tester,
            () =>
                _field('target').evaluate().isNotEmpty &&
                focused('target') &&
                inset() > 0,
            'real IME on new target field',
          );
          expect(
            tester.widget<TextField>(_field('target')).textInputAction,
            TextInputAction.next,
          );
          expect(
            tester.widget<TextField>(_field('native')).textInputAction,
            TextInputAction.done,
          );
          final bounds = tester.getRect(_key('draft-target'));
          final height =
              tester.view.physicalSize.height / tester.view.devicePixelRatio;
          expect(bounds.top, greaterThanOrEqualTo(0));
          expect(bounds.bottom, lessThanOrEqualTo(height - inset()));
          await phase(
            'ime-target-next',
            'Capture real keyboard; press native IME Next, then ACK',
            metadata: entryGeometry(),
          );
          await _wait(
            tester,
            () => focused('native') && inset() > 0,
            'native Next focuses second field with IME retained',
          );
          expect(focused('target'), isFalse);
          await phase(
            'ime-native-done',
            'Capture second-field keyboard; press native IME Done, then ACK',
          );
          await _wait(
            tester,
            () => !focused('native') && inset() == 0,
            'native Done unfocuses second field and closes IME',
          );
          await phase('ime-closed', 'Capture keyboard closed; ACK only');
        } else {
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        }
        await _tap(tester, _button(copy.text('json.title')));
        await _wait(
          tester,
          () => find.byType(VocabularyJsonPage).evaluate().isNotEmpty,
          'real JSON route',
        );
        final page = tester.widget<VocabularyJsonPage>(
          find.byType(VocabularyJsonPage),
        );
        expect(page.platform, isA<SystemVocabularyJsonPlatform>());
        Future<Map<String, Object?>> snapshot([PikoDatabase? connection]) {
          final store = connection ?? db;
          return store.transaction(() async {
            final rows = <String, Object?>{};
            for (final table in store.allTables) {
              rows[table.actualTableName] =
                  (await store
                          .customSelect(
                            'SELECT rowid AS fixture_rowid, * FROM ${table.actualTableName} ORDER BY rowid',
                          )
                          .get())
                      .map((row) => row.data)
                      .toList();
            }
            return rows;
          });
        }

        final baseline = await snapshot();
        final expectedCollections =
            (jsonDecode(await page.service.exportCollection(owner.id))
                as Map)['collections'];
        String input() =>
            tester.widget<TextField>(_key('json-input')).controller!.text;
        Future<void> enterJson(String value, String stage) async {
          final field = _key('json-input');
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          await tester.tap(field);
          // Let the real IME/caret reveal settle before replacing a long buffer.
          await tester.pumpAndSettle();
          await tester.enterText(field, value);
          await tester.pumpAndSettle();
          expect(
            input() == value,
            isTrue,
            reason: '$stage exact JSON buffer must be retained after typing',
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          expect(
            input() == value,
            isTrue,
            reason: '$stage exact JSON buffer must survive real IME dismissal',
          );
          debugPrint(
            'PIKO_NATIVE_JSON_INPUT:$run:$stage exact=true bytes=${utf8.encode(value).length}',
          );
        }

        Future<void> analyzeJson(
          Map<String, Object> counts,
          String stage,
        ) async {
          final summaryPattern = RegExp(
            '^${RegExp.escape(copy.text('r2.jsonSummary', {'added': 'COUNTADDED', 'updated': 'COUNTUPDATED', 'unchanged': 'COUNTUNCHANGED', 'errors': 'COUNTERRORS'})).replaceAll('COUNTADDED', r'\d+').replaceAll('COUNTUPDATED', r'\d+').replaceAll('COUNTUNCHANGED', r'\d+').replaceAll('COUNTERRORS', r'\d+')}\$',
          );
          Finder summaries() => find.descendant(
            of: find.byType(VocabularyJsonPage),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Text && summaryPattern.hasMatch(widget.data ?? ''),
            ),
          );
          await _tap(tester, _button(copy.text('json.analyze')));
          await _wait(
            tester,
            () =>
                tester
                        .widget<PikoButton>(_button(copy.text('json.analyze')))
                        .onPressed !=
                    null &&
                (summaries().evaluate().isNotEmpty ||
                    find
                        .text(copy.text('json.analyzeFailed'))
                        .evaluate()
                        .isNotEmpty),
            '$stage Analyze settles with a visible result or explicit failure',
          );
          if (find
              .text(copy.text('json.analyzeFailed'))
              .evaluate()
              .isNotEmpty) {
            throw StateError(
              '$stage UI Analyze reported its canonical failure',
            );
          }
          final actual = tester.widget<Text>(summaries()).data!;
          final visibleIssueKeys = [
            for (final key in const [
              'r2.jsonGroupsRequired',
              'json.tooLarge',
              'json.invalidSyntax',
              'json.unsupportedVersion',
              'json.oneCollection',
              'json.languages',
              'json.collectionMissing',
              'json.foreignId',
              'r2.jsonIdentity',
              'json.invalidField',
              'entry.requiredTarget',
              'entry.requiredNative',
              'r2.jsonDuplicate',
              'r2.jsonCategory',
              'r2.jsonInvalid',
            ])
              if (find.text(copy.text(key)).evaluate().isNotEmpty) key,
          ];
          debugPrint(
            'PIKO_NATIVE_JSON_PREVIEW:$run:$stage $actual issueKeys=${visibleIssueKeys.join(',')}',
          );
          expect(
            actual,
            copy.text('r2.jsonSummary', counts),
            reason:
                '$stage actual UI preview counts must match the validated fixture',
          );
        }

        void expectSyntheticFive(String json) {
          final envelope = jsonDecode(json) as Map<String, dynamic>;
          expect(envelope['format'], 'piko-vocabulary');
          expect(envelope['schemaVersion'], 1);
          final collection = (envelope['collections'] as List).single as Map;
          expect(collection['id'], owner.id);
          expect(collection['targetLanguage'], 'ko');
          expect(collection['nativeLanguage'], 'de');
          final entries = collection['entries'] as List;
          expect(entries.length, 5);
          expect(
            entries.map((e) => ((e as Map)['targetText'], e['nativeText'])),
            [
              ('사과', 'Apfel'),
              ('물', 'Wasser'),
              ('학교', 'Schule'),
              ('친구', 'Freund'),
              ('책', 'Buch'),
            ],
          );
          expect(envelope['collections'], expectedCollections);
        }

        // Clipboard access stays strictly inside try/finally. Never serialize or
        // interpolate the prior value into assertions, messages or artifacts.
        if (fullNative) {
          if (ownedClipboard) {
            try {
              previousPlaintext = (await Clipboard.getData(
                Clipboard.kTextPlain,
              ))?.text;
            } catch (_) {
              // Unreadable clipboard is also not safely restorable. Do not mutate it.
            }
            if (previousPlaintext != null) {
              clipboardCaptured = true;
              clipboardVerification = 'in-progress';
              await _tap(tester, _button(copy.text('json.copy')));
              await _wait(
                tester,
                () => find.text(copy.text('json.copied')).evaluate().isNotEmpty,
                'real clipboard copy completion',
              );
              await _tap(tester, _button(copy.text('json.paste')));
              await _wait(
                tester,
                () => input().isNotEmpty,
                'real clipboard paste',
              );
              expectSyntheticFive(input());
              await Clipboard.setData(ClipboardData(text: previousPlaintext));
              clipboardRestored = true;
              previousPlaintext = null;
              clipboardVerification = 'verified';
            } else {
              clipboardVerification = 'not-verified-no-restorable-plaintext';
            }
          } else {
            clipboardVerification =
                'not-verified-shared-clipboard-mutation-disabled';
          }
          await phase(
            'clipboard-roundtrip',
            clipboardVerification == 'verified'
                ? 'Capture JSON route after verified real Copy/Paste; clipboard restored; ACK only'
                : 'Clipboard NOT VERIFIED: mutation disabled or no restorable owned plaintext; capture JSON route and ACK only',
            metadata: {'clipboardVerification': clipboardVerification},
          );
        } else {
          clipboardVerification = 'not-verified-import-only-mode';
        }
        final inputBeforeFileOperations = input();
        Future<void> idle() => _wait(
          tester,
          () =>
              tester
                  .widget<PikoButton>(_button(copy.text('json.download')))
                  .onPressed !=
              null,
          'native operation completes and actions recover',
        );
        if (fullNative) {
          await _tap(tester, _button(copy.text('json.download')));
          await phase(
            'save-cancel',
            'Capture real Save dialog; cancel with Android Back, then ACK',
          );
          await idle();
          expect(
            input() == inputBeforeFileOperations,
            isTrue,
            reason: 'Save cancellation must retain editable input',
          );
          expect(find.text(copy.text('json.saveFailed')), findsNothing);
          expect(find.text(copy.text('json.fileSaved')), findsNothing);
        }
        await _tap(tester, _button(copy.text('json.download')));
        await phase(
          'save-confirm',
          'Capture real Save dialog; choose NEW scratch filename $savedName and confirm, then ACK',
        );
        await idle();
        await _wait(
          tester,
          () => find.text(copy.text('json.fileSaved')).evaluate().isNotEmpty,
          'real document save success',
        );
        if (fullNative) {
          await _tap(tester, _button(copy.text('json.file')));
          await phase(
            'open-cancel',
            'Capture real Open dialog; cancel with Android Back, then ACK',
          );
          await idle();
          expect(
            input() == inputBeforeFileOperations,
            isTrue,
            reason: 'Open cancellation must retain editable input',
          );
          expect(find.text(copy.text('json.fileFailed')), findsNothing);
        }
        // Clear any existing input so a later read cannot falsely pass.
        await enterJson('', 'clear-before-real-open');
        await _tap(tester, _button(copy.text('json.file')));
        await phase(
          'open-confirm',
          'Capture real Open dialog; select only $savedName, then ACK',
        );
        await idle();
        await _wait(
          tester,
          () => input().isNotEmpty,
          'real saved document read',
        );
        // Verify the file independently of clipboard availability or payload.
        expectSyntheticFive(input());
        await analyzeJson({
          'added': 0,
          'updated': 0,
          'unchanged': 5,
          'errors': 0,
        }, 'unchanged-file');
        final summary = copy.text('r2.jsonSummary', {
          'added': 0,
          'updated': 0,
          'unchanged': 5,
          'errors': 0,
        });
        await tester.ensureVisible(find.text(summary));
        await tester.pumpAndSettle();
        await phase(
          'file-preview-unchanged',
          'Capture analyzed preview with five unchanged entries; ACK only (do not Apply)',
        );
        expect(await snapshot(), baseline);
        // Derive the import from the file actually reopened through Android,
        // retaining UUIDs and original export bytes in the saved document.
        final importEnvelope = jsonDecode(input()) as Map<String, dynamic>;
        final importCollection =
            (importEnvelope['collections'] as List).single as Map;
        final importEntries = importCollection['entries'] as List;
        final firstImported = importEntries.first as Map;
        final changedId = firstImported['id'] as String;
        const changedNative = 'Apfel (Android Import)';
        firstImported['nativeText'] = changedNative;
        final newId = const Uuid().v4();
        importEntries.add({
          'id': newId,
          'targetText': '하늘',
          'nativeText': 'Himmel',
          'categoryAssignments': <Object?>[],
          // No imported learning: both directional items must initialize fresh.
        });
        final changedJson = jsonEncode(importEnvelope);
        final expectedCounts = <String, Object>{
          'added': 1,
          'updated': 1,
          'unchanged': 4,
          'errors': 0,
        };
        // Read-only fixture sanity check distinguishes invalid source data from
        // a UI input/tap race; only the UI-created preview is ever applied.
        final validation = await page.service.analyzeImport(
          collectionId: owner.id,
          json: changedJson,
        );
        debugPrint(
          'PIKO_NATIVE_JSON_VALIDATION:$run new=${validation.newCount} updated=${validation.updatedCount} unchanged=${validation.unchangedCount} errors=${validation.errorCount} codes=${validation.issues.map((issue) => issue.code.name).join(',')}',
        );
        expect(
          [
            validation.newCount,
            validation.updatedCount,
            validation.unchangedCount,
            validation.errorCount,
          ],
          [1, 1, 4, 0],
        );
        expect(await snapshot(), baseline);
        await enterJson(changedJson, 'changed-file-import');
        await analyzeJson(expectedCounts, 'changed-file');
        expect(
          await snapshot(),
          baseline,
          reason: 'Analyze must not apply the synthetic edits',
        );
        await _tap(tester, _button(copy.text('json.apply')));
        await _wait(
          tester,
          () => find.text(copy.text('json.confirmTitle')).evaluate().isNotEmpty,
          'explicit aggregate import confirmation',
        );
        expect(
          await snapshot(),
          baseline,
          reason: 'Opening confirmation must not apply the import',
        );
        final confirm = find.descendant(
          of: find.byType(PikoDialog),
          matching: _button(copy.text('json.apply')),
        );
        final applyStarted = DateTime.now().toUtc();
        await _tap(tester, confirm);
        final appliedMessage = copy.text('json.importApplied', {
          'added': 1,
          'updated': 1,
          'unchanged': 4,
        });
        await _wait(
          tester,
          () => find.text(appliedMessage).evaluate().isNotEmpty,
          'confirmed Android import success counts',
        );
        final applyFinished = DateTime.now().toUtc();
        final afterImport = await snapshot();
        List<Map<String, Object?>> rows(
          Map<String, Object?> state,
          String name,
        ) => (state[name] as List).cast<Map<String, Object?>>();
        final oldWords = rows(baseline, 'vocabulary_entries');
        final newWords = rows(afterImport, 'vocabulary_entries');
        expect(newWords.length, 6);
        expect(
          newWords.take(5).toList(),
          [
            for (final row in oldWords)
              if (row['id'] == changedId)
                {
                  ...row,
                  'native_text': changedNative,
                  'native_key': vocabularyComparisonKey(changedNative),
                }
              else
                row,
          ],
          reason:
              'Existing UUIDs, order, targets and unchanged content remain exact',
        );
        expect(newWords.last['id'], newId);
        expect(newWords.last['collection_id'], owner.id);
        expect(newWords.last['target_text'], '하늘');
        expect(newWords.last['native_text'], 'Himmel');
        expect(
          newWords.last['fixture_rowid'] as int,
          greaterThan(oldWords.last['fixture_rowid'] as int),
        );
        final allLearning = rows(afterImport, 'learning_items');
        final freshLearning = allLearning
            .where((row) => row['entry_id'] == newId)
            .toList();
        expect(freshLearning.length, 2);
        expect(
          allLearning.where((row) => row['entry_id'] != newId).toList(),
          baseline['learning_items'],
          reason:
              'All existing directional learning bytes and identities remain exact',
        );
        expect(freshLearning.map((row) => row['direction']).toSet(), {
          'targetToNative',
          'nativeToTarget',
        });
        for (final item in freshLearning) {
          expect(item['generation'], 0);
          expect(item['review_revision'], 0);
          expect(item['speed_completed'], 0);
          expect(item['format_version'], LearningCardCodec.version);
          LearningCardCodec.decode(
            item['card_json'] as String,
            expectedId: item['id'] as int,
            formatVersion: item['format_version'] as int,
          );
          final card = jsonDecode(item['card_json'] as String) as Map;
          expect(card['state'], 1);
          expect(card['step'], 0);
          expect(card['stability'], isNull);
          expect(card['difficulty'], isNull);
          expect(card['lastReview'], isNull);
          final due = DateTime.parse(card['due'] as String);
          expect(due.isBefore(applyStarted), isFalse);
          expect(due.isAfter(applyFinished), isFalse);
        }
        for (final table in baseline.keys.where(
          (name) => !{
            'vocabulary_entries',
            'learning_items',
            'learning_identity_sequence',
            'vocabulary_order_sequence',
          }.contains(name),
        )) {
          expect(
            afterImport[table],
            baseline[table],
            reason:
                '$table unchanged by confirmed import, including history/retry/counters',
          );
        }
        await tester.ensureVisible(find.text(appliedMessage));
        await tester.pumpAndSettle();
        await phase(
          'import-applied',
          'Capture confirmed import: one new, one updated, four unchanged; ACK only',
          metadata: {
            'added': 1,
            'updated': 1,
            'unchanged': 4,
            'existingLearningPreserved': true,
            'freshDirectionalItems': 2,
          },
        );
        // Let the real runtime drain and close before opening this same owned
        // file independently. Never mount a second runtime or production DB.
        await tester.pumpWidget(const SizedBox());
        await db.closed.future.timeout(const Duration(seconds: 30));
        mounted = false;
        final reopened = PikoDatabase(
          NativeDatabase(File('${directory.path}/fixture.sqlite')),
        );
        try {
          expect(
            await snapshot(reopened),
            afterImport,
            reason:
                'Confirmed content and all preserved state survive file reopen',
          );
        } finally {
          await reopened.close();
        }
        expect(tester.takeException(), isNull);
        status = 'passed';
        debugPrint(
          '${fullNative ? 'PIKO_NATIVE_PASSED' : 'PIKO_NATIVE_IMPORT_ONLY_PASSED'}:$run:$locale',
        );
      } catch (_) {
        status = 'failed';
        // Deliberately avoid exception serialization: clipboard contents must never
        // enter artifacts, even if a platform error includes unexpected payloads.
        rethrow;
      } finally {
        try {
          if (clipboardCaptured &&
              !clipboardRestored &&
              previousPlaintext != null) {
            await Clipboard.setData(ClipboardData(text: previousPlaintext));
            clipboardRestored = true;
          }
        } finally {
          previousPlaintext = null;
          await tester.pumpWidget(const SizedBox());
          if (mounted) {
            await db.closed.future.timeout(const Duration(seconds: 30));
          } else {
            await db.close();
          }
          await manifest();
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 50)),
  );
}
