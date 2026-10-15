import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'entry_stack_test.dart'
    show ScreenRepository, owner, mount, seed, field, clean;

class ValidationRepository extends ScreenRepository {
  Object? createFailure, updateFailure;
  int createCalls = 0, updateCalls = 0;
  @override
  Future<VocabularyRecord> create({
    required String collectionId,
    required String targetText,
    required String nativeText,
  }) {
    createCalls++;
    if (createFailure != null) return Future.error(createFailure!);
    return super.create(
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
  }) {
    updateCalls++;
    if (updateFailure != null) return Future.error(updateFailure!);
    return super.update(id: id, targetText: targetText, nativeText: nativeText);
  }
}

Future<void> press(WidgetTester tester, Finder button) async {
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language draft validation reopens without stale feedback and retries only storage failure',
      (tester) async {
        final repository = ValidationRepository();
        final session = EntrySessionController(
          collectionId: owner.id,
          repository: repository,
        );
        final locale = InterfaceLocaleController(Locale(language));
        addTearDown(locale.dispose);
        clean(tester, session);
        await seed(session, 1);
        await mount(tester, session, locale: locale, reduced: true);
        final copy = PikoCopy(language);
        final save = find.byTooltip(copy.text('action.saveNext'));
        await tester.enterText(field('draft', 'target'), ' Two ');
        await press(tester, save);
        expect(find.text(copy.text('entry.requiredNative')), findsOneWidget);
        expect(find.text(copy.text('action.retry')), findsNothing);
        await tester.enterText(field('draft', 'native'), ' Zwei ');
        repository.createFailure = VocabularyValidation.duplicatePair;
        await press(tester, save);
        expect(find.text(copy.text('vocab.inlineDuplicate')), findsOneWidget);
        expect(find.text(copy.text('entry.saveFailed')), findsNothing);
        expect(find.text(copy.text('action.retry')), findsNothing);
        final calls = repository.createCalls;
        session.selectSavedEntry('entry-0');
        await tester.pumpAndSettle();
        session.selectDraft();
        await tester.pumpAndSettle();
        expect(find.text(copy.text('vocab.inlineDuplicate')), findsNothing);
        expect(session.draft.targetText, ' Two ');
        expect(session.draft.nativeText, ' Zwei ');
        expect(repository.createCalls, calls);
        expect(session.confirmedEntries, hasLength(1));
        repository.createFailure = StateError('Transient storage failure');
        await press(tester, save);
        expect(find.text(copy.text('entry.saveFailed')), findsOneWidget);
        expect(find.text(copy.text('action.retry')), findsOneWidget);
        repository.createFailure = null;
        await press(tester, find.text(copy.text('action.retry')));
        expect(session.confirmedEntries, hasLength(2));
        expect(find.text(copy.text('entry.saveFailed')), findsNothing);
        expect(find.text(copy.text('action.retry')), findsNothing);
      },
    );

    testWidgets(
      '$language saved duplicate stays unsaved and reopens into automatic save',
      (tester) async {
        final repository = ValidationRepository();
        final session = EntrySessionController(
          collectionId: owner.id,
          repository: repository,
        );
        final locale = InterfaceLocaleController(Locale(language));
        addTearDown(locale.dispose);
        clean(tester, session);
        await seed(session, 2);
        await mount(tester, session, locale: locale, reduced: true);
        final copy = PikoCopy(language);
        session.selectSavedEntry('entry-0');
        repository.updateFailure = VocabularyValidation.duplicatePair;
        session.editSavedEntry(
          'entry-0',
          targetText: ' Word 1 ',
          nativeText: ' Wort 1 ',
        );
        await tester.pumpAndSettle();
        expect(find.text(copy.text('vocab.inlineDuplicate')), findsOneWidget);
        expect(find.text(copy.text('entry.unsaved')), findsWidgets);
        expect(find.text(copy.text('entry.saveFailed')), findsNothing);
        expect(find.text(copy.text('action.retry')), findsNothing);
        expect(
          session.savedEntryState('entry-0').committed.targetText,
          'Word 0',
        );
        session.selectSavedEntry('entry-1');
        await tester.pumpAndSettle();
        repository.updateFailure = null;
        session.selectSavedEntry('entry-0');
        await tester.pumpAndSettle();
        expect(find.text(copy.text('vocab.inlineDuplicate')), findsNothing);
        expect(session.savedEntryState('entry-0').draft.targetText, ' Word 1 ');
        expect(
          session.savedEntryState('entry-0').committed.targetText,
          ' Word 1 ',
        );
        repository.updateFailure = StateError('Transient storage failure');
        session.editSavedEntry('entry-0', targetText: 'Failed edit');
        await tester.pumpAndSettle();
        expect(find.text(copy.text('entry.saveFailed')), findsOneWidget);
        expect(find.text(copy.text('action.retry')), findsOneWidget);
        repository.updateFailure = null;
        await press(tester, find.text(copy.text('action.retry')));
        expect(session.savedEntryState('entry-0').error, isNull);
        expect(
          session.savedEntryState('entry-0').committed.targetText,
          'Failed edit',
        );
      },
    );
  }
}
