import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/vocabulary_json.dart';
import 'package:piko/features/learning/learning_scheduler.dart';

import 'regular_reviews_test.dart' show Fixture;
import 'speed_eligibility_test.dart' show completeSnapshot;
import 'vocabulary_json_import_test.dart' show input, newId;

const rich = VocabularyContent(
  exampleTargetText: 'Une pomme.',
  exampleNativeText: 'Ein Apfel.',
  hintText: 'A fruit',
  hintVisibility: HintVisibility.hidden,
);
String v2(List<Object?> entries) =>
    input(entries, envelope: {'schemaVersion': 2});

void main() {
  Future<Fixture> fixture() async {
    final f = Fixture();
    await f.initialize();
    await f.review(rating: LearningRating.again);
    await f.review(reverse: true, rating: LearningRating.good);
    await f.vocabulary.updateWithContent(
      id: f.entry.id,
      targetText: f.entry.targetText,
      nativeText: f.entry.nativeText,
      assignments: const {},
      content: rich,
    );
    addTearDown(f.db.close);
    return f;
  }

  test(
    'v3 export and round-trip retain visibility even with absent Hint text and preserve learning',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      const emptyHint = VocabularyContent(
        exampleTargetText: 'Une pomme.',
        exampleNativeText: 'Ein Apfel.',
        hintVisibility: HintVisibility.hidden,
      );
      await f.vocabulary.updateWithContent(
        id: f.entry.id,
        targetText: f.entry.targetText,
        nativeText: f.entry.nativeText,
        assignments: const {},
        content: emptyHint,
      );
      final before = await completeSnapshot(f.db);
      final encoded = await service.exportCollection(f.owner.id);
      final document = jsonDecode(encoded) as Map;
      expect(document['schemaVersion'], 4);
      final row =
          ((document['collections'] as List).single['entries'] as List).single
              as Map;
      expect(row['examples'], [
        {'targetText': 'Une pomme.', 'nativeText': 'Ein Apfel.'},
      ]);
      expect(row['hint'], {'text': null, 'visibility': 'hidden'});
      expect(encoded, isNot(contains(HintVisibility.settingKey)));
      expect(await completeSnapshot(f.db), before);
      await f.vocabulary.updateWithContent(
        id: f.entry.id,
        targetText: f.entry.targetText,
        nativeText: f.entry.nativeText,
        assignments: const {},
        content: const VocabularyContent(hintText: 'Changed'),
      );
      final preview = await service.analyzeImport(
        collectionId: f.owner.id,
        json: encoded,
      );
      expect(preview.canApply, isTrue);
      expect(preview.updatedCount, 1);
      await service.applyImport(preview);
      expect(
        (await f.vocabulary.watchById(f.entry.id).first)!.content,
        emptyHint,
      );
      expect(await completeSnapshot(f.db), before);
      expect((jsonDecode(service.sampleJson()) as Map)['schemaVersion'], 1);
    },
  );

  for (final version in [1, 2]) {
    test(
      'v$version omission preserves content; v1 ignores unknown optional fields',
      () async {
        final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
        final before = await completeSnapshot(f.db);
        final preview = await service.analyzeImport(
          collectionId: f.owner.id,
          json: input(
            [
              {
                'id': f.entry.id,
                if (version == 1) 'example': 123,
                if (version == 1) 'hint': ['unknown'],
              },
            ],
            envelope: {'schemaVersion': version},
          ),
        );
        expect(preview.canApply, isTrue);
        expect(preview.unchangedCount, 1);
        await service.applyImport(preview);
        expect(await completeSnapshot(f.db), before);
      },
    );
  }

  test(
    'explicit null clears selected content while an unselected group preserves text and visibility',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final before = await completeSnapshot(f.db);
      final ignored = await service.analyzeImport(
        collectionId: f.owner.id,
        json: v2([
          {
            'id': f.entry.id,
            'example': 123,
            'hint': {'text': null, 'visibility': 'always'},
          },
        ]),
        groups: const {VocabularyJsonGroup.targetText},
      );
      expect(ignored.canApply, isTrue);
      expect(ignored.unchangedCount, 1);
      await service.applyImport(ignored);
      expect(await completeSnapshot(f.db), before);
      final clear = await service.analyzeImport(
        collectionId: f.owner.id,
        json: v2([
          {'id': f.entry.id, 'example': null, 'hint': null},
        ]),
      );
      expect(clear.updatedCount, 1);
      await service.applyImport(clear);
      expect(
        (await f.vocabulary.watchById(f.entry.id).first)!.content,
        const VocabularyContent(hintVisibility: HintVisibility.hidden),
      );
      final after = await completeSnapshot(f.db);
      for (final table in [
        'learning_items',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
      ]) {
        expect(after[table], before[table]);
      }
    },
  );

  test(
    'v2 normalizes content and retains existing visibility when omitted',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final preview = await service.analyzeImport(
        collectionId: f.owner.id,
        json: v2([
          {
            'id': f.entry.id,
            'example': {'targetText': ' e\u0301 ', 'nativeText': ' 예문 '},
            'hint': {'text': '  \n  '},
          },
        ]),
      );
      expect(preview.canApply, isTrue);
      await service.applyImport(preview);
      expect(
        (await f.vocabulary.watchById(f.entry.id).first)!.content,
        const VocabularyContent(
          exampleTargetText: 'é',
          exampleNativeText: '예문',
          hintVisibility: HintVisibility.hidden,
        ),
      );
      final exactLimit = await service.analyzeImport(
        collectionId: f.owner.id,
        json: v2([
          {
            'id': f.entry.id,
            'example': {
              'targetText': 'e\u0301' * 1000,
              'nativeText': '🦊' * 1000,
            },
            'hint': {'text': '🦊' * 2000},
          },
        ]),
      );
      expect(exactLimit.canApply, isTrue);
      await service.applyImport(exactLimit);
      final visibilityOnly = await service.analyzeImport(
        collectionId: f.owner.id,
        json: v2([
          {
            'id': f.entry.id,
            'hint': {'visibility': 'always'},
          },
        ]),
      );
      await service.applyImport(visibilityOnly);
      final changed = (await f.vocabulary.watchById(f.entry.id).first)!.content;
      expect(changed.hintVisibility, HintVisibility.always);
      expect(changed.hintText, '🦊' * 2000);
    },
  );

  test(
    'new entries derive the global default; selected explicit visibility overrides and groups remain independent',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      await SqliteSettingsRepository(
        f.db,
      ).write(HintVisibility.settingKey, 'hidden');
      final preview = await service.analyzeImport(
        collectionId: f.owner.id,
        json: v2([
          {
            'id': newId,
            'targetText': 'New',
            'nativeText': 'Neu',
            'hint': {'text': ' clue '},
          },
          {
            'targetText': 'Other',
            'nativeText': 'Andere',
            'hint': {'text': null, 'visibility': 'always'},
          },
        ]),
      );
      expect(preview.canApply, isTrue);
      expect(preview.newCount, 2);
      await service.applyImport(preview);
      final words = await f.vocabulary.watchByCollection(f.owner.id).first;
      expect(
        words[1].content,
        const VocabularyContent(
          hintText: 'clue',
          hintVisibility: HintVisibility.hidden,
        ),
      );
      expect(words[2].content, const VocabularyContent());
      for (final word in words.skip(1)) {
        final items = await f.learning.forEntry(word.id);
        expect(
          items.every(
            (item) =>
                item.card.lastReview == null &&
                item.generation == 0 &&
                !item.speedCompleted,
          ),
          isTrue,
        );
      }
      final unselected = await service.analyzeImport(
        collectionId: f.owner.id,
        json: v2([
          {
            'targetText': 'Unselected',
            'nativeText': 'Nicht ausgewählt',
            'example': {'targetText': 'ignored'},
            'hint': {'text': 'ignored', 'visibility': 'always'},
          },
        ]),
        groups: const {VocabularyJsonGroup.targetText},
      );
      expect(unselected.canApply, isTrue);
      await service.applyImport(unselected);
      final last =
          (await f.vocabulary.watchByCollection(f.owner.id).first).last;
      expect(
        last.content,
        const VocabularyContent(hintVisibility: HintVisibility.hidden),
      );
    },
  );

  test(
    'invalid v2 content has actionable paths and never changes storage',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final before = await completeSnapshot(f.db);
      for (final (fields, path) in <(Map<String, Object?>, String)>[
        (
          {
            'example': {'targetText': 'partial'},
          },
          'example.nativeText',
        ),
        (
          {
            'example': {'targetText': ' ', 'nativeText': 'partial'},
          },
          'example',
        ),
        (
          {
            'example': {'targetText': '🦊' * 1001, 'nativeText': 'ok'},
          },
          'example.targetText',
        ),
        (
          {
            'hint': {'text': '🦊' * 2001},
          },
          'hint.text',
        ),
        (
          {
            'hint': {'text': 3},
          },
          'hint.text',
        ),
        (
          {
            'hint': {'text': null, 'visibility': 'future'},
          },
          'hint.visibility',
        ),
      ]) {
        final preview = await service.analyzeImport(
          collectionId: f.owner.id,
          json: v2([
            {'id': f.entry.id, ...fields},
          ]),
        );
        expect(preview.canApply, isFalse);
        expect(
          preview.issues.any(
            (issue) => issue.path == 'collections[0].entries[0].$path',
          ),
          isTrue,
        );
        await expectLater(
          service.applyImport(preview),
          throwsA(VocabularyJsonApplyFailure.invalidPreview),
        );
        expect(await completeSnapshot(f.db), before);
      }
    },
  );

  test(
    'only a relevant new-entry default change invalidates the preview',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final settings = SqliteSettingsRepository(f.db);
      final derived = await service.analyzeImport(
        collectionId: f.owner.id,
        json: v2([
          {
            'id': newId,
            'targetText': 'New',
            'nativeText': 'Neu',
            'hint': {'text': 'clue'},
          },
        ]),
      );
      await f.vocabulary.setCollectionHintDefault(f.owner.id, true);
      final afterSetting = await completeSnapshot(f.db);
      await expectLater(
        service.applyImport(derived),
        throwsA(VocabularyJsonApplyFailure.stalePreview),
      );
      expect(await completeSnapshot(f.db), afterSetting);
      final explicit = await service.analyzeImport(
        collectionId: f.owner.id,
        json: v2([
          {
            'id': newId,
            'targetText': 'New',
            'nativeText': 'Neu',
            'hint': {'text': null, 'visibility': 'always'},
          },
        ]),
      );
      await f.vocabulary.setCollectionHintDefault(f.owner.id, false);
      expect((await service.applyImport(explicit)).newCount, 1);
      final existing = await service.analyzeImport(
        collectionId: f.owner.id,
        json: v2([
          {
            'id': f.entry.id,
            'hint': {'text': 'replacement'},
          },
        ]),
      );
      await f.vocabulary.setCollectionHintDefault(f.owner.id, true);
      await settings.write('locale', 'de');
      expect((await service.applyImport(existing)).updatedCount, 1);
      expect(
        (await f.vocabulary.watchById(f.entry.id).first)!
            .content
            .hintVisibility,
        HintVisibility.hidden,
      );
    },
  );

  test(
    'optional-content write failure rolls back the whole batch and keeps preview retryable',
    () async {
      final f = await fixture(), service = SqliteVocabularyJsonService(f.db);
      final before = await completeSnapshot(f.db);
      final preview = await service.analyzeImport(
        collectionId: f.owner.id,
        json: v2([
          {'id': newId, 'targetText': 'New', 'nativeText': 'Neu'},
          {
            'id': f.entry.id,
            'hint': {'text': 'replacement'},
          },
        ]),
      );
      await f.db.customStatement(
        "CREATE TRIGGER reject_json_hint BEFORE UPDATE ON vocabulary_entries WHEN NEW.hint_text = 'replacement' BEGIN SELECT RAISE(ABORT, 'injected content failure'); END",
      );
      await expectLater(
        service.applyImport(preview),
        throwsA(isA<sqlite.SqliteException>()),
      );
      expect(await completeSnapshot(f.db), before);
      await f.db.customStatement('DROP TRIGGER reject_json_hint');
      expect((await service.applyImport(preview)).newCount, 1);
      expect(
        (await f.vocabulary.watchById(f.entry.id).first)!.content.hintText,
        'replacement',
      );
    },
  );
}
