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
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/features/interchange/vocabulary_json_page.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/platform/vocabulary_json_platform.dart';
import 'package:piko/ui/components/piko_button.dart';

import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;

// Coordinator protocol (emulator, --no-uninstall only):
// Required --dart-define=PIKO_NATIVE_RUN=<unique safe ID> and
// --dart-define=PIKO_NATIVE_COMMIT=<tested commit>; optional PIKO_NATIVE_LOCALE=en|de.
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
      if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{3,63}$').hasMatch(run) ||
          !RegExp(r'^[a-fA-F0-9]{7,40}$').hasMatch(commit) ||
          !['en', 'de'].contains(locale)) {
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
      String? previousPlaintext;
      final savedName = 'piko-native-$run-$locale.json';
      Future<void> manifest() => File('${directory.path}/manifest.json')
          .writeAsString(
            const JsonEncoder.withIndent('  ').convert({
              'schemaVersion': 1,
              'runId': run,
              'commit': commit,
              'locale': locale,
              'fixture':
                  'synthetic Korean Basics, five entries, no applied imports',
              'database': 'fixture.sqlite',
              'platform':
                  'default SystemVocabularyJsonPlatform, real Android services',
              'savedFileNameRequested': savedName,
              'screenshots': 'host captures device screenshots before each ACK',
              'status': status,
              'clipboardRestored': clipboardRestored,
              'clipboardPolicy':
                  'prior plaintext retained in memory only; absent plaintext restored as empty plaintext',
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
        Future<Map<String, Object?>> snapshot() => db.transaction(() async {
          final rows = <String, Object?>{};
          for (final table in db.allTables) {
            rows[table.actualTableName] =
                (await db
                        .customSelect(
                          'SELECT rowid AS fixture_rowid, * FROM ${table.actualTableName} ORDER BY rowid',
                        )
                        .get())
                    .map((row) => row.data)
                    .toList();
          }
          return rows;
        });
        final baseline = await snapshot();
        // Clipboard access stays strictly inside try/finally. Never serialize or
        // interpolate the prior value into assertions, messages or artifacts.
        previousPlaintext = (await Clipboard.getData(
          Clipboard.kTextPlain,
        ))?.text;
        clipboardCaptured = true;
        await _tap(tester, _button(copy.text('json.copy')));
        await _wait(
          tester,
          () => find.text(copy.text('json.copied')).evaluate().isNotEmpty,
          'real clipboard copy completion',
        );
        await _tap(tester, _button(copy.text('json.paste')));
        String input() =>
            tester.widget<TextField>(_key('json-input')).controller!.text;
        await _wait(tester, () => input().isNotEmpty, 'real clipboard paste');
        final pasted = jsonDecode(input()) as Map<String, dynamic>;
        final entries =
            ((pasted['collections'] as List).single as Map)['entries'] as List;
        expect(entries.length, 5);
        expect(entries.map((e) => (e as Map)['targetText']), [
          '사과',
          '물',
          '학교',
          '친구',
          '책',
        ]);
        final copiedInput = input();
        await Clipboard.setData(ClipboardData(text: previousPlaintext ?? ''));
        clipboardRestored = true;
        previousPlaintext = null;
        await phase(
          'clipboard-roundtrip',
          'Capture JSON route after real Copy/Paste; clipboard already restored; ACK only',
        );
        Future<void> idle() => _wait(
          tester,
          () =>
              tester
                  .widget<PikoButton>(_button(copy.text('json.download')))
                  .onPressed !=
              null,
          'native operation completes and actions recover',
        );
        await _tap(tester, _button(copy.text('json.download')));
        await phase(
          'save-cancel',
          'Capture real Save dialog; cancel with Android Back, then ACK',
        );
        await idle();
        expect(
          input() == copiedInput,
          isTrue,
          reason: 'Save cancellation must retain editable input',
        );
        expect(find.text(copy.text('json.saveFailed')), findsNothing);
        expect(find.text(copy.text('json.fileSaved')), findsNothing);
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
        await _tap(tester, _button(copy.text('json.file')));
        await phase(
          'open-cancel',
          'Capture real Open dialog; cancel with Android Back, then ACK',
        );
        await idle();
        expect(
          input() == copiedInput,
          isTrue,
          reason: 'Open cancellation must retain editable input',
        );
        expect(find.text(copy.text('json.fileFailed')), findsNothing);
        // Remove the existing pasted input so a later read cannot falsely pass.
        await tester.enterText(_key('json-input'), '');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
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
        // exportedAt may differ between Copy and Save; compare collection content.
        expect(
          (jsonDecode(input()) as Map)['collections'],
          pasted['collections'],
        );
        await _tap(tester, _button(copy.text('json.analyze')));
        final summary = copy.text('r2.jsonSummary', {
          'added': 0,
          'updated': 0,
          'unchanged': 5,
          'errors': 0,
        });
        await _wait(
          tester,
          () => find.text(summary).evaluate().isNotEmpty,
          'real file preview is five unchanged entries',
        );
        await tester.ensureVisible(find.text(summary));
        await tester.pumpAndSettle();
        await phase(
          'file-preview-unchanged',
          'Capture analyzed preview with five unchanged entries; ACK only (do not Apply)',
        );
        expect(await snapshot(), baseline);
        expect(tester.takeException(), isNull);
        status = 'passed';
        debugPrint('PIKO_NATIVE_PASSED:$run:$locale');
      } catch (_) {
        status = 'failed';
        // Deliberately avoid exception serialization: clipboard contents must never
        // enter artifacts, even if a platform error includes unexpected payloads.
        rethrow;
      } finally {
        try {
          if (clipboardCaptured && !clipboardRestored) {
            await Clipboard.setData(
              ClipboardData(text: previousPlaintext ?? ''),
            );
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
