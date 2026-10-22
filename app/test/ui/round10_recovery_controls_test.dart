import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/learning_reset.dart';
import 'package:piko/data/vocabulary_deletion.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/vocabulary/vocabulary_reset_control.dart';
import 'package:piko/features/vocabulary/vocabulary_trash_page.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';

const owner = CollectionRecord(
  id: 'collection',
  name: 'Vocabulary',
  targetLanguage: VocabularyLanguage.korean,
  nativeLanguage: VocabularyLanguage.german,
);
const one = VocabularyRecord(
  id: 'one',
  collectionId: 'collection',
  targetText: 'One',
  nativeText: 'Eins',
);
const two = VocabularyRecord(
  id: 'two',
  collectionId: 'collection',
  targetText: 'Two',
  nativeText: 'Zwei',
);

class Reset implements LearningResetRepository {
  final calls = <Set<LearningDirection>>[];
  @override
  Future<void> resetLearning({
    required String entryId,
    required Set<LearningDirection> directions,
  }) async => calls.add({...directions});
}

class Trash implements VocabularyTrashService {
  int clears = 0;
  final restored = <String>[];
  @override
  Future<List<VocabularyTrashGroup>> trashGroups({
    required String collectionId,
  }) async => clears == 0
      ? [
          VocabularyTrashGroup(
            id: 'group',
            collectionId: collectionId,
            deletedAt: DateTime.utc(2026, 10, 21),
            expiresAt: DateTime.utc(2026, 10, 22),
            entries: const [one, two],
          ),
        ]
      : [];
  @override
  Future<VocabularyTrashRestoreResult> restoreTrashGroup(String id) async {
    restored.add(id);
    return VocabularyTrashRestoreResult(
      restoredIds: ['one'],
      conflicts: {'two': VocabularyUndoFailure.duplicatePair},
      omittedCategoryEntryIds: ['one'],
    );
  }

  @override
  Future<VocabularyTrashRestoreResult> restoreTrashEntry(String id) async {
    restored.add(id);
    return VocabularyTrashRestoreResult(restoredIds: [id]);
  }

  @override
  Future<void> clearTrash(String id) async {
    clears++;
  }

  @override
  Future<void> purgeExpiredTrash() async {}
}

Finder action(String label) => find.descendant(
  of: find.byType(PikoDialog).last,
  matching: find.widgetWithText(PikoButton, label),
);

void main({bool nativeViewport = false}) {
  for (final locale in ['en', 'de']) {
    testWidgets(
      '$locale reset Cancel writes nothing and confirms only chosen direction',
      (tester) async {
        if (nativeViewport && locale == 'de') {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }
        final repository = Reset(), copy = PikoCopy(locale);
        final notifications = <Set<LearningDirection>>[];
        var drains = 0;
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(locale),
            home: Scaffold(
              body: VocabularyResetControl(
                entryId: one.id,
                repository: repository,
                enabled: true,
                beforeReset: () async {
                  drains++;
                },
                onLearningReset: notifications.add,
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('vocabulary-reset-one')));
        await tester.pumpAndSettle();
        await tester.tap(action(copy.text('action.cancel')));
        await tester.pumpAndSettle();
        expect(repository.calls, isEmpty);
        expect(drains, 0);
        await tester.tap(find.byKey(const ValueKey('vocabulary-reset-one')));
        await tester.pumpAndSettle();
        final direction = find.descendant(
          of: find.byKey(const ValueKey('reset-direction-nativeToTarget')),
          matching: find.byType(Checkbox),
        );
        await tester.ensureVisible(direction);
        await tester.pumpAndSettle();
        await tester.tap(direction);
        await tester.pumpAndSettle();
        await tester.tap(action(copy.text('vocab.resetLearning')));
        await tester.pumpAndSettle();
        expect(repository.calls, [
          {LearningDirection.targetToNative},
        ]);
        expect(drains, 1);
        expect(notifications.single, {LearningDirection.targetToNative});
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '$locale trash restores group valid subset, reports conflicts and confirms clear',
      (tester) async {
        if (nativeViewport && locale == 'de') {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }
        final repository = Trash(), copy = PikoCopy(locale);
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(locale),
            home: VocabularyTrashPage(
              collection: owner,
              repository: repository,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('One'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('trash-group-group')));
        await tester.pumpAndSettle();
        expect(find.text('One'), findsOneWidget);
        final restore = find.byKey(const ValueKey('trash-restore-group-group'));
        await tester.ensureVisible(restore);
        await tester.pumpAndSettle();
        await tester.tap(restore);
        await tester.pumpAndSettle();
        expect(repository.restored, ['group']);
        expect(
          find.text(
            copy.text('trash.restoreSummary', {'restored': 1, 'conflicts': 1}),
          ),
          findsOneWidget,
        );
        expect(
          find.text(copy.text('trash.categoryWarning', {'count': 1})),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip(copy.text('common.close')));
        await tester.pumpAndSettle();
        final clear = find.byKey(const ValueKey('trash-clear'));
        await tester.ensureVisible(clear);
        await tester.pumpAndSettle();
        await tester.tap(clear);
        await tester.pumpAndSettle();
        await tester.tap(action(copy.text('action.cancel')));
        await tester.pumpAndSettle();
        expect(repository.clears, 0);
        await tester.tap(clear);
        await tester.pumpAndSettle();
        await tester.tap(action(copy.text('trash.clear')));
        await tester.pumpAndSettle();
        expect(repository.clears, 1);
        expect(find.text(copy.text('trash.empty')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
