import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collection_query.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/learning/learning_scheduler.dart';

import 'regular_reviews_test.dart' show Fixture, instant;
import 'speed_eligibility_test.dart' show completeSnapshot;

const content = VocabularyContent(
  exampleTargetText: 'Une pomme.',
  exampleNativeText: 'Ein Apfel.',
  hintText: 'A fruit',
  hintVisibility: HintVisibility.hidden,
);

void main() {
  Future<Fixture> fixture() async {
    final f = Fixture();
    await f.initialize();
    addTearDown(f.db.close);
    return f;
  }

  test(
    'content normalizes without changing raw input and counts Unicode scalar values',
    () {
      const raw = VocabularyContent(
        exampleTargetText: ' e\u0301 ',
        exampleNativeText: ' 예문 ',
        hintText: '  Hint\ntext  ',
      );
      expect(
        raw.normalized(),
        const VocabularyContent(
          exampleTargetText: 'é',
          exampleNativeText: '예문',
          hintText: 'Hint\ntext',
        ),
      );
      expect(raw.exampleTargetText, ' e\u0301 ');
      expect(
        VocabularyContent(
          exampleTargetText: 'e\u0301' * 1000,
          exampleNativeText: 'ok',
        ).normalized().exampleTargetText!.runes.length,
        1000,
      );
      expect(
        const VocabularyContent(
          exampleTargetText: ' ',
          exampleNativeText: '\t',
          hintText: '\n',
        ).normalized(),
        const VocabularyContent(),
      );
      final boundary = VocabularyContent(
        exampleTargetText: '🦊' * 1000,
        exampleNativeText: '🦊' * 1000,
        hintText: '🦊' * 2000,
      );
      expect(boundary.normalized(), boundary);
      expect(
        () => VocabularyContent(
          exampleTargetText: '🦊' * 1001,
          exampleNativeText: 'ok',
        ).normalized(),
        throwsA(VocabularyContentValidation.exampleTooLong),
      );
      expect(
        () => VocabularyContent(hintText: '🦊' * 2001).normalized(),
        throwsA(VocabularyContentValidation.hintTooLong),
      );
      expect(
        () =>
            const VocabularyContent(exampleTargetText: 'partial').normalized(),
        throwsA(VocabularyContentValidation.examplePairRequired),
      );
    },
  );

  test(
    'legacy edits preserve content while full edits, opening restore and query retain it exactly',
    () async {
      final f = await fixture();
      await f.review(rating: LearningRating.again);
      final initial = await completeSnapshot(f.db);
      final saved = await f.vocabulary.updateWithContent(
        id: f.entry.id,
        targetText: f.entry.targetText,
        nativeText: f.entry.nativeText,
        assignments: const {},
        content: content,
      );
      expect(saved.content, content);
      final opening = await f.vocabulary.captureOpeningSnapshot(
        entryId: saved.id,
        collectionId: saved.collectionId,
      );
      final before = await completeSnapshot(f.db);
      final changed = await f.vocabulary.update(
        id: saved.id,
        targetText: 'Changed',
        nativeText: 'Geändert',
      );
      expect(changed.content, content);
      await f.vocabulary.updateCategorized(
        id: saved.id,
        targetText: 'Changed twice',
        nativeText: 'Zweimal geändert',
        assignments: const {},
      );
      expect((await f.vocabulary.watchById(saved.id).first)!.content, content);
      await f.vocabulary.updateWithContent(
        id: saved.id,
        targetText: 'Other',
        nativeText: 'Anders',
        assignments: const {},
        content: const VocabularyContent(),
      );
      final restored = await f.vocabulary.restoreOpeningSnapshot(opening);
      expect(restored.content, content);
      expect(await completeSnapshot(f.db), before);
      final query = await SqliteCollectionQueryService(
        f.db,
      ).query(collectionId: f.owner.id, at: instant);
      expect(query.entries.single.content, content);
      expect(await completeSnapshot(f.db), before);
      for (final table in [
        'learning_items',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
      ]) {
        expect(before[table], initial[table]);
      }
    },
  );

  test(
    'explicit default make is atomic, applies only to new entries and preserves hidden without Hint text',
    () async {
      final f = await fixture();
      expect(
        await f.vocabulary.readHintVisibilityDefault(collectionId: f.owner.id),
        HintVisibility.hidden,
      );
      await f.vocabulary.updateWithContent(
        id: f.entry.id,
        targetText: f.entry.targetText,
        nativeText: f.entry.nativeText,
        assignments: const {},
        content: const VocabularyContent(hintVisibility: HintVisibility.hidden),
        makeHintVisibilityDefault: true,
      );
      expect(
        await f.vocabulary.readHintVisibilityDefault(collectionId: f.owner.id),
        HintVisibility.hidden,
      );
      expect(
        (await f.vocabulary.watchById(f.other.id).first)!
            .content
            .hintVisibility,
        HintVisibility.hidden,
      );
      final newWord = await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'Two',
        nativeText: 'Zwei',
      );
      expect(
        newWord.content,
        const VocabularyContent(hintVisibility: HintVisibility.hidden),
      );
      expect(
        (await f.vocabulary.watchById(newWord.id).first)!.content,
        newWord.content,
      );
      final assignments = <String, Set<String>>{};
      final creating = f.vocabulary.createWithContent(
        collectionId: f.owner.id,
        targetText: 'Three',
        nativeText: 'Drei',
        assignments: assignments,
        content: content,
      );
      assignments['missing-dimension'] = {'missing-value'};
      final richWord = await creating;
      expect(richWord.content, content);
      expect(await f.learning.forEntry(richWord.id), hasLength(2));
      final before = await completeSnapshot(f.db);
      await expectLater(
        f.vocabulary.createWithContent(
          collectionId: f.owner.id,
          targetText: 'Two',
          nativeText: 'Zwei',
          assignments: const {},
          content: const VocabularyContent(),
          makeHintVisibilityDefault: true,
        ),
        throwsA(VocabularyValidation.duplicatePair),
      );
      expect(await completeSnapshot(f.db), before);
      await f.db.customStatement(
        "CREATE TRIGGER reject_hint_default BEFORE UPDATE OF automatic_hint_default ON collections BEGIN SELECT RAISE(ABORT, 'injected default failure'); END",
      );
      await expectLater(
        f.vocabulary.updateWithContent(
          id: f.entry.id,
          targetText: 'Unsaved',
          nativeText: 'Ungespeichert',
          assignments: const {},
          content: const VocabularyContent(hintText: 'unsaved'),
          makeHintVisibilityDefault: true,
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'failed optional content leaves vocabulary and learning unchanged; clear is explicit',
    () async {
      final f = await fixture();
      await f.vocabulary.updateWithContent(
        id: f.entry.id,
        targetText: f.entry.targetText,
        nativeText: f.entry.nativeText,
        assignments: const {},
        content: content,
      );
      final before = await completeSnapshot(f.db);
      for (final invalid in [
        const VocabularyContent(exampleNativeText: 'partial'),
        VocabularyContent(hintText: 'x' * 2001),
      ]) {
        await expectLater(
          Future.sync(
            () => f.vocabulary.updateWithContent(
              id: f.entry.id,
              targetText: 'Unsaved',
              nativeText: 'Ungespeichert',
              assignments: const {},
              content: invalid,
              makeHintVisibilityDefault: true,
            ),
          ),
          throwsA(isA<VocabularyContentValidation>()),
        );
        expect(await completeSnapshot(f.db), before);
      }
      final cleared = await f.vocabulary.updateWithContent(
        id: f.entry.id,
        targetText: f.entry.targetText,
        nativeText: f.entry.nativeText,
        assignments: const {},
        content: const VocabularyContent(hintVisibility: HintVisibility.hidden),
      );
      expect(
        cleared.content,
        const VocabularyContent(hintVisibility: HintVisibility.hidden),
      );
    },
  );

  test(
    'Undo restores full content, entry order and exact learning history',
    () async {
      final f = await fixture();
      await f.review(rating: LearningRating.again);
      await f.vocabulary.updateWithContent(
        id: f.entry.id,
        targetText: f.entry.targetText,
        nativeText: f.entry.nativeText,
        assignments: const {},
        content: content,
      );
      final before = await completeSnapshot(f.db);
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(f.entry.id);
      expect(receipt.entry.content, content);
      expect((await deletion.restore(receipt)).content, content);
      expect(await completeSnapshot(f.db), before);
    },
  );

  test(
    'schema13 migration adds empty content without rewriting history, identities or an existing global default',
    () async {
      final f = Fixture();
      final directory = await Directory.systemTemp.createTemp(
        'piko-content-v13-',
      );
      final file = File('${directory.path}/legacy.sqlite');
      var sourceClosed = false;
      PikoDatabase? migrated;
      try {
        await f.initialize();
        await f.review(rating: LearningRating.again);
        await f.review(reverse: true, rating: LearningRating.good);
        await SqliteSettingsRepository(
          f.db,
        ).write(HintVisibility.settingKey, HintVisibility.hidden.name);
        final before = await completeSnapshot(f.db);
        // Recreate the historical schema, where addition dates were unknown.
        for (final row in before['vocabulary_entries'] as List) {
          (row as Map)['added_at'] = null;
          row['hint_visibility'] = 'always';
        }
        final legacy = sqlite.sqlite3.open(file.path);
        try {
          final schema =
              jsonDecode(
                    await File(
                      'drift_schemas/drift_schema_v13.json',
                    ).readAsString(),
                  )
                  as Map<String, dynamic>;
          for (final group in schema['fixed_sql'] as List) {
            legacy.execute((group['sql'] as List).single['sql'] as String);
          }
          for (final table in before.entries) {
            for (final stored in table.value! as List) {
              final row = Map<String, Object?>.of(
                stored as Map<String, Object?>,
              );
              if (table.key == 'collections') {
                row.remove('automatic_hint_default');
                row.remove('hint_default_offer_handled');
                row.remove('target_language_name');row.remove('native_language_name');
              }
              if (table.key == 'vocabulary_entries') {
                row.remove('active');row.remove('hint_key');
                for (final column in [
                  'added_at',
                  'example_target_text',
                  'example_native_text',
                  'hint_text',
                  'hint_visibility',
                ]) {
                  row.remove(column);
                }
              }
              final columns = row.keys
                  .map((key) => key == 'stored_rowid' ? 'rowid' : key)
                  .join(',');
              legacy.execute(
                'INSERT INTO ${table.key} ($columns) VALUES (${List.filled(row.length, '?').join(',')})',
                row.values.toList(),
              );
            }
          }
          legacy.execute('PRAGMA user_version = 13');
        } finally {
          legacy.close();
        }
        await f.db.close();
        sourceClosed = true;
        migrated = PikoDatabase(NativeDatabase(file));
        expect(await completeSnapshot(migrated), before);
        final repository = SqliteVocabularyRepository(migrated);
        expect(
          (await repository.watchById(f.entry.id).first)!.content,
          const VocabularyContent(),
        );
        expect(
          await repository.readHintVisibilityDefault(collectionId: f.owner.id),
          HintVisibility.hidden,
        );
        await migrated.close();
        migrated = PikoDatabase(NativeDatabase(file));
        expect(await completeSnapshot(migrated), before);
        final fresh = await SqliteVocabularyRepository(migrated).create(
          collectionId: f.owner.id,
          targetText: 'New',
          nativeText: 'Neu',
        );
        expect(fresh.content.hintVisibility, HintVisibility.hidden);
        await SqliteVocabularyRepository(migrated).updateWithContent(
          id: fresh.id,
          targetText: fresh.targetText,
          nativeText: fresh.nativeText,
          assignments: const {},
          content: content,
        );
        final storedContent = await completeSnapshot(migrated);
        await migrated.close();
        migrated = PikoDatabase(NativeDatabase(file));
        expect(
          (await SqliteVocabularyRepository(
            migrated,
          ).watchById(fresh.id).first)!.content,
          content,
        );
        expect(await completeSnapshot(migrated), storedContent);
        expect(
          await migrated.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await migrated?.close();
        if (!sourceClosed) await f.db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
