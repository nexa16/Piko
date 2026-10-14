import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'inline_edit_android_test.dart' as fixture;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android confirmed collection deletion cascades only owned learning data',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final directory = await support.createTemp('piko-delete-verification-');
      final file = File('${directory.path}/test.sqlite');
      final db = fixture.InlineFixtureDatabase(file);
      PikoDatabase? reopened;
      var mounted = false;
      try {
        final collections = SqliteCollectionsRepository(db);
        final vocabulary = SqliteVocabularyRepository(db);
        final learning = SqliteLearningRepository(db);
        final owners = <CollectionRecord>[];
        final ownedItems = <int>{};
        String? deletedEntry;
        for (var index = 0; index < 2; index++) {
          final owner = await collections.create(
            name: index == 0 ? 'Delete fixture' : 'Retain fixture',
            targetLanguage: VocabularyLanguage.french,
            nativeLanguage: VocabularyLanguage.german,
          );
          owners.add(owner);
          final entry = await vocabulary.create(
            collectionId: owner.id,
            targetText: 'école',
            nativeText: 'Schule',
          );
          final items = await learning.forEntry(entry.id);
          expect(items, hasLength(2));
          if (index == 0) {
            deletedEntry = entry.id;
            ownedItems.addAll(items.map((item) => item.id));
          }
          // Actual regular writes populate both directional FSRS states, history,
          // retry rounds and scope ordinals before exercising the destructive UI.
          for (final item in items) {
            await learning.review(
              kind: ReviewKind.regular,
              expectedPrior: item,
              rating: LearningRating.again,
              reviewedAt: db.clock.now(),
            );
          }
        }
        final before = await fixture.snapshot(db);
        mounted = true;
        await tester.pumpWidget(
          PikoApp(home: PikoRuntime(databaseFactory: () => db)),
        );
        final copy = await hydratedRuntimeCopy(tester);
        await fixture.tapVisible(
          tester,
          find.byKey(ValueKey('collection-${owners.first.id}')),
        );
        final action = find.byWidgetPredicate(
          (widget) =>
              widget is PikoButton &&
              widget.label == copy.text('collection.delete'),
        );
        await fixture.tapVisible(tester, action);
        expect(
          find.text(
            copy.text('collection.deleteWarning', {'name': owners.first.name}),
          ),
          findsOneWidget,
        );
        final close = find.descendant(
          of: find.byType(PikoDialog),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is PikoIconButton &&
                widget.semanticLabel == copy.text('common.close'),
          ),
        );
        await fixture.tapVisible(tester, close);
        expect(find.byType(PikoDialog), findsNothing);
        expect(await fixture.snapshot(db), before);

        await fixture.tapVisible(tester, action);
        await fixture.tapVisible(
          tester,
          find.descendant(of: find.byType(PikoDialog), matching: action),
        );
        await fixture.waitUntil(
          tester,
          () async => (await db.select(db.collections).get()).length == 1,
        );
        await fixture.waitUntil(
          tester,
          () => find
              .byKey(ValueKey('collection-${owners.last.id}'))
              .evaluate()
              .isNotEmpty,
        );
        final expected = <String, Object?>{...before};
        for (final table in [
          'collections',
          'vocabulary_entries',
          'learning_items',
          'regular_reviews',
          'retry_obligations',
          'scope_answer_ordinals',
        ]) {
          expected[table] = (before[table]! as List).where((value) {
            final row = value as Map;
            return switch (table) {
              'collections' => row['id'] != owners.first.id,
              'vocabulary_entries' => row['id'] != deletedEntry,
              'learning_items' => !ownedItems.contains(row['id']),
              'scope_answer_ordinals' =>
                row['collection_id'] != owners.first.id,
              _ => !ownedItems.contains(row['item_id']),
            };
          }).toList();
        }
        expect(await fixture.snapshot(db), expected);
        expect(
          find.byKey(ValueKey('collection-${owners.first.id}')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await db.closed.future.timeout(const Duration(seconds: 10));
        mounted = false;
        reopened = PikoDatabase(NativeDatabase(file));
        expect(await fixture.snapshot(reopened), expected);
        await reopened.close();
        reopened = null;
      } finally {
        await tester.pumpWidget(const SizedBox());
        if (mounted) {
          await db.closed.future.timeout(const Duration(seconds: 10));
        } else {
          await db.close();
        }
        await reopened?.close();
        if (directory.parent.absolute.path != support.absolute.path ||
            !directory.uri.pathSegments
                .where((part) => part.isNotEmpty)
                .last
                .startsWith('piko-delete-verification-')) {
          throw StateError('Refusing cleanup outside owned deletion fixture');
        }
        await directory.delete(recursive: true);
      }
    },
  );
}
