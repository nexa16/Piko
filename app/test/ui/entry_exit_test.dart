import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_dialog.dart';

class GatedRepository implements VocabularyRepository {
  @override
  Future<VocabularyOpeningSnapshot> captureOpeningSnapshot({
    required String entryId,
    required String collectionId,
  }) =>
      real.captureOpeningSnapshot(entryId: entryId, collectionId: collectionId);
  @override
  Future<VocabularyRecord> restoreOpeningSnapshot(
    VocabularyOpeningSnapshot snapshot,
  ) => real.restoreOpeningSnapshot(snapshot);
  GatedRepository(this.real);
  final VocabularyRepository real;
  Completer<void>? createGate, updateGate;
  @override
  Future<VocabularyRecord> create({
    required String collectionId,
    required String targetText,
    required String nativeText,
  }) async {
    await createGate?.future;
    return real.create(
      collectionId: collectionId,
      targetText: targetText,
      nativeText: nativeText,
    );
  }

  @override
  Future<VocabularyRecord> update({
    required String id,
    required String targetText,
    required String nativeText,
  }) async {
    await updateGate?.future;
    return real.update(id: id, targetText: targetText, nativeText: nativeText);
  }

  @override
  Stream<List<VocabularyRecord>> watchByCollection(String id) =>
      real.watchByCollection(id);
  @override
  Stream<VocabularyRecord?> watchById(String id) => real.watchById(id);
}

class ExitFixture {
  final db = PikoDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  late CollectionRecord collection;
  late GatedRepository repository;
  late EntrySessionController session;
  late ValueNotifier<EntrySessionController> current;
  final sessions = <EntrySessionController>[];
  Future<void> mount(WidgetTester tester) async {
    collection = await SqliteCollectionsRepository(db).create(
      name: 'Entries',
      targetLanguage: VocabularyLanguage.korean,
      nativeLanguage: VocabularyLanguage.german,
    );
    repository = GatedRepository(SqliteVocabularyRepository(db));
    session = newSession();
    current = ValueNotifier(session);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      for (final value in sessions) {
        value.dispose();
      }
      current.dispose();
      await db.close();
    });
    await tester.pumpWidget(
      PikoApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ValueListenableBuilder<EntrySessionController>(
                          valueListenable: current,
                          builder: (_, value, _) => EntrySessionScreen(
                            collection: collection,
                            session: value,
                          ),
                        ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  EntrySessionController newSession() {
    final value = EntrySessionController(
      collectionId: collection.id,
      repository: repository,
    );
    sessions.add(value);
    return value;
  }

  Future<void> back(WidgetTester tester, {bool system = false}) async {
    if (system) {
      await tester.binding.handlePopRoute();
    } else {
      await tester.tap(find.text('Back'));
    }
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'final storage failure retains raw text and selection, then correction completes',
    (tester) async {
      final f = ExitFixture();
      await f.mount(tester);
      final field = find.byType(TextField).first;
      await tester.enterText(field, '  학교  ');
      final editor = tester.widget<TextField>(field).controller!;
      editor.selection = const TextSelection(baseOffset: 2, extentOffset: 3);
      f.session.setNativeText(' Schule ');
      f.repository.createGate = Completer<void>();
      await tester.pumpAndSettle();
      final action = tester.widget<TextButton>(
        find.descendant(
          of: find.byTooltip(const PikoCopy('en').text('entry.complete')),
          matching: find.byType(TextButton),
        ),
      );
      action.onPressed!();
      action.onPressed!();
      await tester.pumpAndSettle();
      expect(f.session.isCompleting, isTrue);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Back'))
            .onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(PikoDialog), findsNothing);
      f.repository.createGate!.completeError(StateError('Disk failed'));
      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't save this entry. Please try again."),
        findsOneWidget,
      );
      expect(editor.text, '  학교  ');
      expect(
        editor.selection,
        const TextSelection(baseOffset: 2, extentOffset: 3),
      );
      expect(f.session.isCompleted, isFalse);
      f.repository.createGate = null;
      await tester.tap(find.byTooltip(const PikoCopy('en').text('entry.complete')));
      await f.db.customSelect('SELECT 1').get();
      await tester.pumpAndSettle();
      expect(find.byType(EntrySessionScreen), findsNothing);
      expect(await f.db.select(f.db.vocabularyEntries).get(), hasLength(1));
    },
  );
  testWidgets(
    'global completion saves a real final record once and exits without another draft',
    (tester) async {
      final f = ExitFixture();
      await f.mount(tester);
      f.session.setTargetText(' 학교 ');
      f.session.setNativeText(' Schule ');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(const PikoCopy('en').text('entry.complete')));
      await f.db.customSelect('SELECT 1').get();
      await tester.pumpAndSettle();
      expect(find.byType(EntrySessionScreen), findsNothing);
      expect(f.session.isCompleted, isTrue);
      expect(f.session.draft.targetText, ' 학교 ');
      final rows = await f.db.select(f.db.vocabularyEntries).get();
      expect(rows, hasLength(1));
      expect(rows.single.targetText, '학교');
      await f.session.completeSession();
      expect(await f.db.select(f.db.vocabularyEntries).get(), hasLength(1));
    },
  );

  testWidgets('empty final completion creates nothing and exits', (
    tester,
  ) async {
    final f = ExitFixture();
    await f.mount(tester);
    f.session.setTargetText(' \n');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(const PikoCopy('en').text('entry.complete')));
    await tester.pumpAndSettle();
    expect(find.byType(EntrySessionScreen), findsNothing);
    expect(await f.db.select(f.db.vocabularyEntries).get(), isEmpty);
  });

  testWidgets(
    'required and duplicate final input stays open with localized validation',
    (tester) async {
      final f = ExitFixture();
      await f.mount(tester);
      f.session.setTargetText('학교');
      f.session.setNativeText('Schule');
      await f.session.confirmAndNext();
      f.session.setTargetText('학교');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(const PikoCopy('en').text('entry.complete')));
      await tester.pumpAndSettle();
      expect(find.byType(EntrySessionScreen), findsOneWidget);
      expect(find.text('Enter the translation.'), findsOneWidget);
      f.session.setNativeText('SCHULE');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(const PikoCopy('en').text('entry.complete')));
      await f.db.customSelect('SELECT 1').get();
      await tester.pumpAndSettle();
      expect(find.byType(EntrySessionScreen), findsOneWidget);
      expect(f.session.draft.nativeText, 'SCHULE');
      expect(
        find.text(const PikoCopy('en').text('vocab.inlineDuplicate')),
        findsOneWidget,
      );
      expect(f.session.isCompleted, isFalse);
      expect(await f.db.select(f.db.vocabularyEntries).get(), hasLength(1));
    },
  );

  testWidgets(
    'failed saved edit activates its card; retry permits eventual final completion',
    (tester) async {
      final f = ExitFixture();
      await f.mount(tester);
      f.session.setTargetText('학교');
      f.session.setNativeText('Schule');
      final saved = await f.session.confirmAndNext();
      f.repository.updateGate = Completer<void>();
      f.session.editSavedEntry(saved.id, nativeText: 'School');
      f.session.setTargetText('물');
      f.session.setNativeText('Wasser');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(const PikoCopy('en').text('entry.complete')));
      await tester.pumpAndSettle();
      f.repository.updateGate!.completeError(StateError('Disk failed'));
      await f.session.awaitSavedEdits();
      await tester.pumpAndSettle();
      expect(f.session.activeEntryId, saved.id);
      expect(find.byType(EntrySessionScreen), findsOneWidget);
      expect(f.session.draft.targetText, '물');
      f.repository.updateGate = null;
      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await f.session.awaitSavedEdits();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(const PikoCopy('en').text('entry.complete')));
      await f.db.customSelect('SELECT 1').get();
      await tester.pumpAndSettle();
      expect(find.byType(EntrySessionScreen), findsNothing);
      final rows = await f.db.select(f.db.vocabularyEntries).get();
      expect(rows, hasLength(2));
      expect(rows.firstWhere((r) => r.id == saved.id).nativeText, 'School');
    },
  );

  testWidgets(
    'covered terminal completion resumes exit without another write; replacement is not popped',
    (tester) async {
      final f = ExitFixture();
      await f.mount(tester);
      f.session.setTargetText('학교');
      f.session.setNativeText('Schule');
      f.repository.createGate = Completer<void>();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(const PikoCopy('en').text('entry.complete')));
      await tester.pumpAndSettle();
      final navigator = Navigator.of(
        tester.element(find.byType(EntrySessionScreen)),
      );
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Covered completion')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      f.repository.createGate!.complete();
      await f.session.completeSession();
      await tester.pumpAndSettle();
      expect(find.text('Covered completion'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('Entry session ended'), findsOneWidget);
      await tester.tap(find.byTooltip(const PikoCopy('en').text('entry.complete')));
      await tester.pumpAndSettle();
      expect(find.byType(EntrySessionScreen), findsNothing);
      expect(await f.db.select(f.db.vocabularyEntries).get(), hasLength(1));
      // Reopen the caller-owned route with a new pending session.
      final old = f.newSession()
        ..setTargetText('물')
        ..setNativeText('Wasser');
      f.current.value = old;
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      f.repository.createGate = Completer<void>();
      await tester.tap(find.byTooltip(const PikoCopy('en').text('entry.complete')));
      await tester.pumpAndSettle();
      final replacement = f.newSession()..setTargetText('new');
      f.current.value = replacement;
      await tester.pumpAndSettle();
      f.repository.createGate!.complete();
      await old.completeSession();
      await tester.pumpAndSettle();
      expect(find.byType(EntrySessionScreen), findsOneWidget);
      expect(replacement.isCompleted, isFalse);
      expect(replacement.draft.targetText, 'new');
    },
  );
  testWidgets(
    'screen removal before the warning first builds cannot orphan a dialog',
    (tester) async {
      final f = ExitFixture();
      await f.mount(tester);
      f.session.setTargetText('draft');
      await tester.pumpAndSettle();
      final screenContext = tester.element(find.byType(EntrySessionScreen));
      final route = ModalRoute.of(screenContext)!;
      final navigator = Navigator.of(screenContext);
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Back'))
          .onPressed!();
      navigator.removeRoute(route);
      await tester.pumpAndSettle();
      expect(find.byType(PikoDialog, skipOffstage: false), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'removing the screen removes only its owned warning, not an unrelated route',
    (tester) async {
      final f = ExitFixture();
      await f.mount(tester);
      f.session.setTargetText('draft');
      await tester.pumpAndSettle();
      final screenContext = tester.element(find.byType(EntrySessionScreen));
      final screenRoute = ModalRoute.of(screenContext)!;
      final navigator = Navigator.of(screenContext);
      await f.back(tester);
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Unrelated route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.removeRoute(screenRoute);
      await tester.pumpAndSettle();
      expect(find.byType(PikoDialog, skipOffstage: false), findsNothing);
      expect(find.text('Unrelated route'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
    },
  );
  testWidgets(
    'Back exits empty and whitespace drafts without confirmation or writes',
    (tester) async {
      final f = ExitFixture();
      await f.mount(tester);
      f.session.setTargetText(' \n\t');
      f.session.setNativeText('  ');
      await tester.pumpAndSettle();
      await f.back(tester, system: true);
      expect(find.byType(EntrySessionScreen), findsNothing);
      expect(find.byType(PikoDialog), findsNothing);
      expect(await f.db.select(f.db.vocabularyEntries).get(), isEmpty);
      // Screen exit does not dispose a controller owned by its caller.
      f.session.setTargetText('still owned');
    },
  );

  for (final dismissal in ['continue', 'escape', 'barrier', 'system']) {
    testWidgets(
      '$dismissal safely preserves raw draft, selection and editing focus',
      (tester) async {
        final f = ExitFixture();
        await f.mount(tester);
        final field = find.byType(TextField).first;
        await tester.enterText(field, '  초안  ');
        final controller = tester.widget<TextField>(field).controller!;
        controller.selection = const TextSelection(
          baseOffset: 2,
          extentOffset: 3,
        );
        final focus = tester.widget<TextField>(field).focusNode!;
        await f.back(tester, system: true);
        expect(find.byType(PikoDialog), findsOneWidget);
        switch (dismissal) {
          case 'continue':
            await tester.tap(find.text('Continue editing'));
          case 'escape':
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          case 'barrier':
            await tester.tapAt(const Offset(1, 1));
          case 'system':
            await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(find.byType(PikoDialog), findsNothing);
        expect(find.byType(EntrySessionScreen), findsOneWidget);
        expect(f.session.draft.targetText, '  초안  ');
        expect(
          controller.selection,
          const TextSelection(baseOffset: 2, extentOffset: 3),
        );
        expect(focus.hasFocus, isTrue);
        expect(await f.db.select(f.db.vocabularyEntries).get(), isEmpty);
      },
    );
  }

  testWidgets(
    'repeated Back shows one dialog and explicit discard keeps confirmed SQLite records',
    (tester) async {
      final f = ExitFixture();
      await f.mount(tester);
      f.session.setTargetText('학교');
      f.session.setNativeText('Schule');
      final saved = await f.session.confirmAndNext();
      f.session.setNativeText('one-sided draft');
      await tester.pumpAndSettle();
      await f.back(tester);
      await tester.binding.handlePopRoute(); // Dismiss the one dialog safely.
      await tester.pumpAndSettle();
      await f.back(tester);
      final back = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Back'),
      );
      back.onPressed!();
      back.onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(PikoDialog), findsOneWidget);
      await tester.tap(find.text('Discard & exit'));
      await tester.pumpAndSettle();
      expect(find.byType(EntrySessionScreen), findsNothing);
      final rows = await f.db.select(f.db.vocabularyEntries).get();
      expect(rows.single.id, saved.id);
      expect(rows.single.targetText, '학교');
    },
  );

  testWidgets(
    'Back is blocked during confirmation and drains accepted saved writes before exit',
    (tester) async {
      final f = ExitFixture();
      await f.mount(tester);
      f.repository.createGate = Completer<void>();
      f.session.setTargetText('학교');
      f.session.setNativeText('Schule');
      final confirmation = f.session.confirmAndNext();
      await tester.pumpAndSettle();
      await f.back(tester, system: true);
      expect(find.byType(PikoDialog), findsNothing);
      expect(find.byType(EntrySessionScreen), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Back'))
            .onPressed,
        isNull,
      );
      f.repository.createGate!.complete();
      final saved = await confirmation;
      f.repository.updateGate = Completer<void>();
      f.session.editSavedEntry(saved.id, nativeText: 'School');
      await tester.pumpAndSettle();
      await f.back(tester);
      expect(find.byType(EntrySessionScreen), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Back'))
            .onPressed,
        isNull,
      );
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.enabled, isFalse);
      }
      await f.back(tester, system: true);
      expect(find.byType(PikoDialog), findsNothing);
      f.repository.updateGate!.complete();
      await f.session.awaitSavedEdits();
      await tester.pumpAndSettle();
      expect(find.byType(EntrySessionScreen), findsNothing);
      expect(
        (await f.db.select(f.db.vocabularyEntries).get()).single.nativeText,
        'School',
      );
    },
  );

  testWidgets(
    'empty draft exits without warning for invalid saved buffer and retains persisted values',
    (tester) async {
      final f = ExitFixture();
      await f.mount(tester);
      f.session.setTargetText('학교');
      f.session.setNativeText('Schule');
      final saved = await f.session.confirmAndNext();
      f.session.editSavedEntry(saved.id, targetText: ' ');
      await tester.pumpAndSettle();
      await f.back(tester);
      expect(find.byType(EntrySessionScreen), findsNothing);
      expect(find.byType(PikoDialog), findsNothing);
      expect(
        (await f.db.select(f.db.vocabularyEntries).get()).single.targetText,
        '학교',
      );
    },
  );

  testWidgets(
    'session replacement dismisses stale warning and cannot exit replacement',
    (tester) async {
      final f = ExitFixture();
      await f.mount(tester);
      f.session.setTargetText('old draft');
      await tester.pumpAndSettle();
      await f.back(tester);
      final replacement = f.newSession()..setTargetText('new draft');
      f.current.value = replacement;
      await tester.pumpAndSettle();
      expect(find.byType(PikoDialog), findsNothing);
      expect(find.byType(EntrySessionScreen), findsOneWidget);
      await f.back(tester);
      expect(find.byType(PikoDialog), findsOneWidget);
      await tester.tap(find.text('Continue editing'));
      await tester.pumpAndSettle();
      expect(replacement.draft.targetText, 'new draft');
    },
  );

  testWidgets(
    'late saved write cannot exit a replacement session or a covered route',
    (tester) async {
      final f = ExitFixture();
      await f.mount(tester);
      f.session.setTargetText('학교');
      f.session.setNativeText('Schule');
      final saved = await f.session.confirmAndNext();
      f.repository.updateGate = Completer<void>();
      f.session.editSavedEntry(saved.id, nativeText: 'School');
      await tester.pumpAndSettle();
      await f.back(tester);
      final replacement = f.newSession();
      f.current.value = replacement;
      await tester.pumpAndSettle();
      f.repository.updateGate!.complete();
      await f.session.awaitSavedEdits();
      await tester.pumpAndSettle();
      expect(find.byType(EntrySessionScreen), findsOneWidget);
      replacement.setTargetText('물');
      replacement.setNativeText('Wasser');
      final second = await replacement.confirmAndNext();
      f.repository.updateGate = Completer<void>();
      replacement.editSavedEntry(second.id, nativeText: 'Water');
      await tester.pumpAndSettle();
      await f.back(tester);
      final navigator = Navigator.of(
        tester.element(find.byType(EntrySessionScreen)),
      );
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Covered route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      f.repository.updateGate!.complete();
      await replacement.awaitSavedEdits();
      await tester.pumpAndSettle();
      expect(find.text('Covered route'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(EntrySessionScreen), findsOneWidget);
      await f.back(tester);
      expect(find.byType(EntrySessionScreen), findsNothing);
    },
  );

  testWidgets(
    'failed accepted saved write drains without confirming draft or losing last persisted text',
    (tester) async {
      final f = ExitFixture();
      await f.mount(tester);
      f.session.setTargetText('학교');
      f.session.setNativeText('Schule');
      final saved = await f.session.confirmAndNext();
      f.repository.updateGate = Completer<void>();
      f.session.editSavedEntry(saved.id, nativeText: 'School');
      await tester.pumpAndSettle();
      await f.back(tester);
      f.repository.updateGate!.completeError(StateError('Storage unavailable'));
      await f.session.awaitSavedEdits();
      await tester.pumpAndSettle();
      expect(find.byType(EntrySessionScreen), findsNothing);
      expect(
        (await f.db.select(f.db.vocabularyEntries).get()).single.nativeText,
        'Schule',
      );
      expect(f.session.savedEntryState(saved.id).error, isA<StateError>());
    },
  );
}
