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
import 'regular_reviews_test.dart' show Fixture;
import 'speed_eligibility_test.dart' show completeSnapshot;
import 'vocabulary_json_import_test.dart' show input;

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
    'activity survives content edits and Undo; validation/failure preserves exact learning and activity',
    () async {
      final f = await fixture();
      final before = await completeSnapshot(f.db);
      Future<void> edit({bool? active, VocabularyContent? content}) async {
        await f.vocabulary.updateWithContent(
          id: f.entry.id,
          targetText: f.entry.targetText,
          nativeText: f.entry.nativeText,
          assignments: {},
          content: content ?? f.entry.content,
          active: active,
        );
      }

      await edit(active: false);
      await edit(content: const VocabularyContent(hintText: 'Changed'));
      expect((await f.vocabulary.watchById(f.entry.id).first)!.active, isFalse);
      await f.vocabulary.update(
        id: f.entry.id,
        targetText: 'One revised',
        nativeText: 'Eins',
      );
      expect((await f.vocabulary.watchById(f.entry.id).first)!.active, isFalse);
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(f.entry.id);
      expect((await deletion.restore(receipt)).active, isFalse);
      await expectLater(
        edit(
          active: true,
          content: const VocabularyContent(
            examples: [ExamplePair(targetText: 'Incomplete', nativeText: '')],
          ),
        ),
        throwsA(VocabularyContentValidation.examplePairRequired),
      );
      expect((await f.vocabulary.watchById(f.entry.id).first)!.active, isFalse);
      await f.db.customStatement(
        "CREATE TRIGGER fail_activity BEFORE UPDATE OF active ON vocabulary_entries BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
      );
      final failedBefore = await completeSnapshot(f.db);
      await expectLater(edit(active: true), throwsA(anything));
      expect(await completeSnapshot(f.db), failedBefore);
      final after = await completeSnapshot(f.db);
      for (final table in [
        'learning_items',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
      ]) {
        expect(after[table], before[table], reason: table);
      }
    },
  );

  test(
    'current Activity is independent, validates booleans, preserves omissions and current input, and rolls back failed apply',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final before = await completeSnapshot(f.db);
      Future<VocabularyJsonPreview> preview(
        Map<String, Object?> fields, {
        int version = 5,
        Set<VocabularyJsonGroup> groups = VocabularyJsonGroup.all,
      }) => service.analyzeImport(
        collectionId: f.owner.id,
        json: input(
          [
            {'id': f.entry.id, ...fields},
          ],
          envelope: {'schemaVersion': version},
        ),
        groups: groups,
      );
      final change = await preview({'active': false});
      expect(change.updatedCount, 1);
      await service.applyImport(change);
      for (final version in [5]) {
        await service.applyImport(
          await preview({'targetText': 'One'}, version: version),
        );
        expect(
          (await f.vocabulary.watchById(f.entry.id).first)!.active,
          isFalse,
        );
      }
      await service.applyImport(
        await preview({'active': true}, groups: {VocabularyJsonGroup.hint}),
      );
      expect((await f.vocabulary.watchById(f.entry.id).first)!.active, isFalse);
      for (final invalid in [null, 'true', 1, 0]) {
        expect((await preview({'active': invalid})).canApply, isFalse);
      }
      final exported =
          jsonDecode(await service.exportCollection(f.owner.id)) as Map;
      expect(exported['schemaVersion'], 5);
      expect(exported['collections'][0]['entries'][0]['active'], isFalse);
      expect(
        exported['collections'][0].containsKey('automaticHintDefault'),
        isFalse,
      );
      await f.db.customStatement(
        "CREATE TRIGGER fail_activity BEFORE UPDATE OF active ON vocabulary_entries BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END",
      );
      final failedBefore = await completeSnapshot(f.db);
      await expectLater(
        service.applyImport(
          await preview({'active': true, 'targetText': 'Not saved'}),
        ),
        throwsA(anything),
      );
      expect(await completeSnapshot(f.db), failedBefore);
      final after = await completeSnapshot(f.db);
      for (final table in [
        'learning_items',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
      ]) {
        expect(after[table], before[table], reason: table);
      }
    },
  );

  test(
    'populated v15 migration and reopen preserve words and learning; defaults/offers stay Collection-local',
    () async {
      final f = await fixture();
      await f.vocabulary.updateWithContent(
        id: f.entry.id,
        targetText: f.entry.targetText,
        nativeText: f.entry.nativeText,
        assignments: {},
        content: const VocabularyContent(
          hintText: 'Visible',
          hintVisibility: HintVisibility.always,
        ),
      );
      await f.db.customStatement(
        "INSERT OR REPLACE INTO app_settings(key,value) VALUES('hintVisibility','always')",
      );
      final before = await completeSnapshot(f.db);
      final directory = await Directory.systemTemp.createTemp(
        'piko-round5-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/legacy.sqlite');
      final legacy = sqlite.sqlite3.open(file.path);
      try {
        final schema =
            jsonDecode(
                  await File(
                    'drift_schemas/drift_schema_v15.json',
                  ).readAsString(),
                )
                as Map;
        for (final group in schema['fixed_sql'] as List) {
          legacy.execute((group['sql'] as List).single['sql'] as String);
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
            if (table.key == 'vocabulary_entries') row.remove('active');row.remove('hint_key');
            final columns = row.keys
                .map((key) => key == 'stored_rowid' ? 'rowid' : key)
                .join(',');
            legacy.execute(
              'INSERT INTO ${table.key} ($columns) VALUES (${List.filled(row.length, '?').join(',')})',
              row.values.toList(),
            );
          }
        }
        legacy.execute('PRAGMA user_version=15');
      } finally {
        legacy.close();
      }
      var db = PikoDatabase(NativeDatabase(file));
      try {
        expect(await completeSnapshot(db), before);
        var repo = SqliteVocabularyRepository(db);
        expect((await repo.watchById(f.entry.id).first)!.active, isTrue);
        expect(
          (await repo.watchById(f.entry.id).first)!.content.hintVisibility,
          HintVisibility.always,
        );
        for (final id in [f.owner.id, f.kept.id]) {
          expect(
            await repo.readHintVisibilityDefault(collectionId: id),
            HintVisibility.hidden,
          );
          expect(await repo.hintDefaultOfferHandled(id), isFalse);
        }
        await repo.completeHintDefaultOffer(f.owner.id, accept: true);
        await repo.completeHintDefaultOffer(f.kept.id, accept: false);
        await db.close();
        db = PikoDatabase(NativeDatabase(file));
        repo = SqliteVocabularyRepository(db);
        expect(await repo.hintDefaultOfferHandled(f.owner.id), isTrue);
        expect(await repo.hintDefaultOfferHandled(f.kept.id), isTrue);
        final a = await repo.create(
          collectionId: f.owner.id,
          targetText: 'New',
          nativeText: 'Neu',
        );
        final b = await repo.create(
          collectionId: f.kept.id,
          targetText: 'New',
          nativeText: 'Neu',
        );
        expect(a.content.hintVisibility, HintVisibility.always);
        expect(b.content.hintVisibility, HintVisibility.hidden);
        final service = SqliteVocabularyJsonService(db);
        await service.applyImport(
          await service.analyzeImport(
            collectionId: f.kept.id,
            json: input(
              [
                {'targetText': 'Imported', 'nativeText': 'Importiert'},
              ],
              envelope: {'schemaVersion': 5},
            ),
          ),
        );
        final imported = (await repo.watchByCollection(f.kept.id).first).last;
        expect(imported.active, isTrue);
        expect(imported.content.hintVisibility, HintVisibility.hidden);
        expect(await repo.hintDefaultOfferHandled(f.kept.id), isTrue);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await db.close();
      }
    },
  );
}
