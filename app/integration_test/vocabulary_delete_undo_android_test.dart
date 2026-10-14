import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';

import 'inline_edit_android_test.dart' as fixture;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;

Map<String, Object?> withoutEntry(
  Map<String, Object?> source, {
  required String entryId,
  required Set<int> itemIds,
}) {
  final result = <String, Object?>{...source};
  for (final table in [
    'vocabulary_entries',
    'learning_items',
    'regular_reviews',
    'retry_obligations',
  ]) {
    result[table] = (source[table]! as List).where((value) {
      final row = value as Map;
      return switch (table) {
        'vocabulary_entries' => row['id'] != entryId,
        'learning_items' => row['entry_id'] != entryId,
        _ => !itemIds.contains(row['item_id']),
      };
    }).toList();
  }
  return result;
}

Map<String, Object?> withoutPhysicalRowId(Object? value) {
  final row = Map<String, Object?>.from(value! as Map);
  row.remove('stored_rowid');
  return row;
}

void expectRestoredSnapshot(
  Map<String, Object?> actual,
  Map<String, Object?> expected, {
  required Set<int> restoredItemIds,
}) {
  expect(
    actual.keys,
    expected.keys,
    reason: 'restored snapshot table/schema keys',
  );
  const physicallyStable = [
    'app_settings',
    'collections',
    'vocabulary_entries',
    'learning_items',
    'scope_answer_ordinals',
    'learning_identity_sequence',
    'vocabulary_order_sequence',
    'schema',
  ];
  expect(
    expected.keys.toSet(),
    {...physicallyStable, 'regular_reviews', 'retry_obligations'},
    reason: 'every persisted table must have an explicit restoration check',
  );
  for (final table in physicallyStable) {
    expect(
      actual[table],
      expected[table],
      reason: '$table must restore exactly, including physical row order',
    );
  }
  for (final table in ['regular_reviews', 'retry_obligations']) {
    final actualRows = (actual[table]! as List).cast<Map>();
    final expectedRows = (expected[table]! as List).cast<Map>();
    expect(
      actualRows
          .where((row) => !restoredItemIds.contains(row['item_id']))
          .toList(),
      expectedRows
          .where((row) => !restoredItemIds.contains(row['item_id']))
          .toList(),
      reason: '$table unrelated rows and physical rowids must stay exact',
    );
    for (final itemId in restoredItemIds) {
      expect(
        actualRows
            .where((row) => row['item_id'] == itemId)
            .map(withoutPhysicalRowId)
            .toList(),
        expectedRows
            .where((row) => row['item_id'] == itemId)
            .map(withoutPhysicalRowId)
            .toList(),
        reason:
            '$table item $itemId must preserve logical identity, fields, and history order; SQLite rowid is not domain identity',
      );
    }
  }
}

Finder button(String label) => find.byWidgetPredicate(
  (widget) => widget is PikoButton && widget.label == label,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android swipe only reveals; explicit vocabulary deletion and eight-second Undo restore the exact file-backed graph',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final directory = await support.createTemp(
        'piko-vocabulary-delete-undo-verification-',
      );
      final file = File('${directory.path}/test.sqlite');
      final db = fixture.InlineFixtureDatabase(file);
      PikoDatabase? reopened;
      var runtimeMounted = false;
      try {
        final collections = SqliteCollectionsRepository(db);
        final vocabulary = SqliteVocabularyRepository(db);
        final learning = SqliteLearningRepository(db);
        final owner = await collections.create(
          name: 'Delete and Undo fixture',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        );
        final leading = await vocabulary.create(
          collectionId: owner.id,
          targetText: 'avant',
          nativeText: 'vorher',
        );
        final target = await vocabulary.create(
          collectionId: owner.id,
          targetText: 'école',
          nativeText: 'Schule',
        );
        final trailing = await vocabulary.create(
          collectionId: owner.id,
          targetText: 'après',
          nativeText: 'nachher',
        );
        final otherOwner = await collections.create(
          name: 'Unrelated fixture',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        );
        final unrelated = await vocabulary.create(
          collectionId: otherOwner.id,
          targetText: 'ailleurs',
          nativeText: 'anderswo',
        );

        final targetItems = await learning.forEntry(target.id);
        expect(targetItems, hasLength(2));
        for (final item in targetItems) {
          await learning.review(
            kind: ReviewKind.regular,
            expectedPrior: item,
            rating: item.direction == LearningDirection.targetToNative
                ? LearningRating.again
                : LearningRating.hard,
            reviewedAt: db.clock.now().toUtc(),
          );
        }
        final unrelatedItems = await learning.forEntry(unrelated.id);
        expect(unrelatedItems, hasLength(2));
        for (final item in unrelatedItems) {
          await learning.review(
            kind: ReviewKind.regular,
            expectedPrior: item,
            rating: item.direction == LearningDirection.targetToNative
                ? LearningRating.good
                : LearningRating.again,
            reviewedAt: db.clock.now().toUtc(),
          );
        }

        final targetItemIds = targetItems.map((item) => item.id).toSet();
        final before = await fixture.snapshot(db);
        expect(
          (before['regular_reviews'] as List).where(
            (row) => targetItemIds.contains((row as Map)['item_id']),
          ),
          hasLength(2),
        );
        expect(
          (before['regular_reviews'] as List)
              .where((row) => targetItemIds.contains((row as Map)['item_id']))
              .map((row) => (row as Map)['rating'])
              .toSet(),
          {LearningRating.again.name, LearningRating.hard.name},
        );
        expect(
          (before['retry_obligations'] as List).where(
            (row) => targetItemIds.contains((row as Map)['item_id']),
          ),
          hasLength(1),
        );

        runtimeMounted = true;
        await tester.pumpWidget(
          PikoApp(home: PikoRuntime(databaseFactory: () => db)),
        );
        final copy = await hydratedRuntimeCopy(tester);
        await fixture.tapVisible(
          tester,
          find.byKey(ValueKey('collection-${owner.id}')),
        );
        final targetCard = find.byKey(ValueKey('vocabulary-${target.id}'));
        await fixture.waitUntil(tester, () => targetCard.evaluate().isNotEmpty);
        final delete = find.descendant(
          of: find.byKey(ValueKey('vocabulary-row-${target.id}')),
          matching: button(copy.text('vocab.delete')),
        );
        expect(delete, findsNothing);

        await tester.ensureVisible(targetCard);
        await tester.drag(targetCard, const Offset(-150, 0));
        await tester.pumpAndSettle();
        expect(delete, findsOneWidget);
        expect(
          tester.widget<PikoButton>(delete).variant,
          PikoButtonVariant.dangerGhost,
        );
        expect(targetCard, findsOneWidget);
        expect(await fixture.snapshot(db), before);

        await fixture.tapVisible(tester, delete);
        await fixture.waitUntil(
          tester,
          () async =>
              await (db.select(
                db.vocabularyEntries,
              )..where((row) => row.id.equals(target.id))).getSingleOrNull() ==
              null,
        );
        expect(targetCard, findsNothing);
        expect(
          await fixture.snapshot(db),
          withoutEntry(before, entryId: target.id, itemIds: targetItemIds),
        );
        expect(
          find.byKey(ValueKey('vocabulary-${leading.id}')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('vocabulary-${trailing.id}')),
          findsOneWidget,
        );

        final undoBar = find.byKey(ValueKey('collection-undo-${target.id}'));
        final undo = find.descendant(
          of: undoBar,
          matching: button(copy.text('vocab.undo')),
        );
        expect(undoBar, findsOneWidget);
        await fixture.tapVisible(tester, undo);
        await fixture.waitUntil(
          tester,
          () async =>
              await (db.select(
                db.vocabularyEntries,
              )..where((row) => row.id.equals(target.id))).getSingleOrNull() !=
              null,
        );
        expectRestoredSnapshot(
          await fixture.snapshot(db),
          before,
          restoredItemIds: targetItemIds,
        );
        expect(targetCard, findsOneWidget);
        expect(
          find.byKey(ValueKey('vocabulary-row-${target.id}')),
          findsOneWidget,
        );
        final restoredOwnerRows = await db
            .customSelect(
              'SELECT id, target_text, native_text FROM vocabulary_entries '
              'WHERE collection_id = ? ORDER BY rowid',
              variables: [Variable.withString(owner.id)],
            )
            .get();
        expect(restoredOwnerRows.map((row) => row.read<String>('id')), [
          leading.id,
          target.id,
          trailing.id,
        ]);
        expect(restoredOwnerRows[1].read<String>('target_text'), 'école');
        expect(restoredOwnerRows[1].read<String>('native_text'), 'Schule');
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        await db.closed.future.timeout(const Duration(seconds: 10));
        runtimeMounted = false;
        reopened = PikoDatabase(NativeDatabase(file));
        expectRestoredSnapshot(
          await fixture.snapshot(reopened),
          before,
          restoredItemIds: targetItemIds,
        );
        await reopened.close();
        reopened = null;
      } finally {
        await tester.pumpWidget(const SizedBox());
        if (runtimeMounted) {
          await db.closed.future.timeout(const Duration(seconds: 10));
        } else {
          await db.close();
        }
        await reopened?.close();
        if (directory.parent.absolute.path != support.absolute.path ||
            !directory.uri.pathSegments
                .where((part) => part.isNotEmpty)
                .last
                .startsWith('piko-vocabulary-delete-undo-verification-')) {
          throw StateError(
            'Refusing cleanup outside owned vocabulary deletion fixture',
          );
        }
        await directory.delete(recursive: true);
      }
    },
  );
}
