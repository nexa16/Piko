import 'package:piko/data/collections_repository.dart';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/vocabulary_json.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'regular_reviews_test.dart' show Fixture, instant;
import 'speed_eligibility_test.dart' show completeSnapshot;
import 'retry_gap_migration_test.dart' show storedRows;
import 'vocabulary_json_import_test.dart' show input;

const pairs = [
  ExamplePair(targetText: 'Premier.', nativeText: 'Erster.'),
  ExamplePair(targetText: 'Deuxième.', nativeText: 'Zweiter.'),
  ExamplePair(targetText: 'Troisième.', nativeText: 'Dritter.'),
];

void main() {
  Future<Fixture> fixture() async {
    final f = Fixture();
    await f.initialize();
    addTearDown(f.db.close);
    await f.review(rating: LearningRating.again);
    await f.review(reverse: true, rating: LearningRating.good);
    return f;
  }

  test(
    'ordered examples validate atomically; Discard and deletion/Undo preserve content, dates and exact learning',
    () async {
      final f = await fixture();
      final original = await completeSnapshot(f.db);
      final saved = await f.vocabulary.updateWithContent(
        id: f.entry.id,
        targetText: f.entry.targetText,
        nativeText: f.entry.nativeText,
        assignments: {},
        content: const VocabularyContent(examples: pairs, hintText: 'Hint'),
      );
      expect(saved.addedAt, instant);
      final opening = await f.vocabulary.captureOpeningSnapshot(
        entryId: saved.id,
        collectionId: f.owner.id,
      );
      final before = await completeSnapshot(f.db),
          children = await storedRows(f.db, 'vocabulary_examples');
      await expectLater(
        () => f.vocabulary.updateWithContent(
          id: saved.id,
          targetText: 'Changed',
          nativeText: saved.nativeText,
          assignments: {},
          content: const VocabularyContent(
            examples: [ExamplePair(targetText: 'partial', nativeText: '')],
          ),
        ),
        throwsA(VocabularyContentValidation.examplePairRequired),
      );
      expect(await completeSnapshot(f.db), before);
      expect(await storedRows(f.db, 'vocabulary_examples'), children);
      await f.vocabulary.updateWithContent(
        id: saved.id,
        targetText: 'Changed',
        nativeText: saved.nativeText,
        assignments: {},
        content: VocabularyContent(examples: pairs.skip(1).toList()),
      );
      await f.vocabulary.restoreOpeningSnapshot(opening);
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(saved.id);
      expect(await storedRows(f.db, 'vocabulary_examples'), isEmpty);
      final restored = await deletion.restore(receipt);
      expect(restored.content, saved.content);
      expect(restored.addedAt, saved.addedAt);
      expect(await completeSnapshot(f.db), before);
      for (final table in [
        'learning_items',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
      ]) {
        expect((await completeSnapshot(f.db))[table], original[table]);
      }
      // A late child-row failure rolls the preceding parent edit back as well.
      await f.db.customStatement(
        "CREATE TRIGGER fail_example BEFORE INSERT ON vocabulary_examples WHEN NEW.position=1 BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
      );
      await expectLater(
        f.vocabulary.updateWithContent(
          id: saved.id,
          targetText: 'Not committed',
          nativeText: saved.nativeText,
          assignments: {},
          content: const VocabularyContent(examples: pairs),
        ),
        throwsA(anything),
      );
      expect(await completeSnapshot(f.db), before);
      expect(
        (await f.vocabulary.watchById(saved.id).first)!.content,
        saved.content,
      );
    },
  );

  test(
    'v3 replaces whole lists; null/empty clear; omission/unselected preserve; dates are local and previews include examples',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final before = await completeSnapshot(f.db);
      Future<VocabularyJsonPreview> preview(
        Map<String, Object?> fields, {
        Set<VocabularyJsonGroup> groups = VocabularyJsonGroup.all,
      }) => service.analyzeImport(
        collectionId: f.owner.id,
        json: input(
          [
            {'id': f.entry.id, ...fields},
          ],
          envelope: {'schemaVersion': 5},
        ),
        groups: groups,
      );
      final list = [
        for (final pair in pairs)
          {'targetText': pair.targetText, 'nativeText': pair.nativeText},
      ];
      await service.applyImport(
        await preview({'examples': list, 'addedAt': '1900-01-01T00:00:00Z'}),
      );
      var entry = (await f.vocabulary.watchById(f.entry.id).first)!;
      expect(entry.content.examples, pairs);
      expect(entry.addedAt, f.entry.addedAt);
      await service.applyImport(await preview({'targetText': 'Nouveau'}));
      await service.applyImport(
        await preview({'examples': null}, groups: {VocabularyJsonGroup.hint}),
      );
      expect(
        (await f.vocabulary.watchById(entry.id).first)!.content.examples,
        pairs,
      );
      final stale = await preview({'examples': []});
      await f.db.customStatement(
        'UPDATE vocabulary_examples SET target_text=? WHERE entry_id=? AND position=0',
        ['Changed example', entry.id],
      );
      await expectLater(
        service.applyImport(stale),
        throwsA(VocabularyJsonApplyFailure.stalePreview),
      );
      for (final empty in [null, <Object?>[]]) {
        await service.applyImport(await preview({'examples': list}));
        await service.applyImport(await preview({'examples': empty}));
        expect(
          (await f.vocabulary.watchById(entry.id).first)!.content.examples,
          isEmpty,
        );
      }
      for (final table in [
        'learning_items',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
      ]) {
        expect((await completeSnapshot(f.db))[table], before[table]);
      }
      final minimal = VocabularyJsonFormat.minimalSample(
        targetLanguage: VocabularyLanguage.french,
        nativeLanguage: VocabularyLanguage.german,
      );
      expect(minimal, isNot(contains('learning')));
      expect(minimal, isNot(contains('addedAt')));
      final added = await service.analyzeImport(
        collectionId: f.owner.id,
        json: minimal,
      );
      expect(added.issues, isEmpty);
      await service.applyImport(added);
      expect(
        (await f.vocabulary.watchByCollection(f.owner.id).first).last.addedAt,
        instant,
      );
    },
  );

  test(
    'populated v14 migration backfills exactly once, leaves old dates unknown, survives reopen and ignores retired scalar columns',
    () async {
      final f = await fixture();
      final before = await completeSnapshot(f.db);
      final directory = await Directory.systemTemp.createTemp(
        'piko-examples-v14-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/legacy.sqlite');
      final old = sqlite.sqlite3.open(file.path);
      try {
        final schema =
            jsonDecode(
                  await File(
                    'drift_schemas/drift_schema_v14.json',
                  ).readAsString(),
                )
                as Map;
        for (final group in schema['fixed_sql'] as List) {
          old.execute((group['sql'] as List).single['sql'] as String);
        }
        for (final table in before.entries) {
          for (final stored in table.value as List) {
            final row = Map<String, Object?>.from(stored as Map);
            if (table.key == 'collections') {
                row.remove('level'); // Absent in the frozen legacy schema.
              row.remove('automatic_hint_default');
              row.remove('hint_default_offer_handled');
              row.remove('target_language_name');row.remove('native_language_name');
            }
            if (table.key == 'vocabulary_entries') {
              row.remove('active');row.remove('hint_key');
              row.remove('added_at');
              row['example_target_text'] = 'Premier.';
              row['example_native_text'] = 'Erster.';
            }
            final columns = row.keys
                .map((k) => k == 'stored_rowid' ? 'rowid' : k)
                .join(',');
            old.execute(
              'INSERT INTO ${table.key} ($columns) VALUES (${List.filled(row.length, '?').join(',')})',
              row.values.toList(),
            );
          }
        }
        old.execute('PRAGMA user_version=14');
      } finally {
        old.close();
      }
      for (var reopen = 0; reopen < 2; reopen++) {
        final db = PikoDatabase(NativeDatabase(file));
        try {
          final repo = SqliteVocabularyRepository(db),
              record = (await SqliteVocabularyRepository(
                db,
              ).watchById(f.entry.id).first)!;
          expect(record.addedAt, isNull);
          expect(record.content.examples, [pairs.first]);
          final after = await completeSnapshot(db);
          for (final table in before.keys.where(
            (k) => k != 'vocabulary_entries',
          )) {
            expect(after[table], before[table]);
          }
          await db.customStatement(
            "UPDATE vocabulary_entries SET example_target_text='Retired', example_native_text='Veraltet'",
          );
          expect((await repo.watchById(f.entry.id).first)!.content.examples, [
            pairs.first,
          ]);
          expect(
            await db.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        } finally {
          await db.close();
        }
      }
    },
  );
}
