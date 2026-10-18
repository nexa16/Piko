import 'package:piko/features/entry/entry_session_controller.dart';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/data/vocabulary_deletion.dart';
import 'package:piko/data/vocabulary_normalization.dart';
import 'package:piko/data/vocabulary_json.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'regular_reviews_test.dart' show Fixture;
import 'statistics_test.dart' show stored;

Future<VocabularyRecord> meaning(
  SqliteVocabularyRepository repo,
  String owner,
  String? hint,
) => repo.createWithContent(
  collectionId: owner,
  targetText: 'run',
  nativeText: 'laufen',
  assignments: {},
  content: VocabularyContent(hintText: hint),
);

void main() {
  test(
    'catalog has exactly 128 immutable identities, localized labels and distinct Mandarin scripts',
    () {
      expect(VocabularyLanguage.values, hasLength(128));
      expect(
        VocabularyLanguage.values.map((v) => v.code).toSet(),
        hasLength(128),
      );
      for (final language in VocabularyLanguage.values) {
        expect(language.label('en'), isNotEmpty);
        expect(language.label('de'), isNotEmpty);
        expect(VocabularyLanguage.fromJson(language.toJson()), language);
      }
      expect(
        VocabularyLanguage.fromName(' Portugiesisch--BRASILIEN! ', 'de').code,
        'pt-BR',
      );
      expect(
        VocabularyLanguage.fromName('Portugiesisch BR', 'de').isCustom,
        isTrue,
      );
      expect(VocabularyLanguage.fromName('German', 'de').isCustom, isTrue);
      expect(
        VocabularyLanguage.fromName(
          ' Mandarin (traditionelle Schrift)',
          'de',
        ).code,
        'zh-Hant',
      );
      expect(
        () => VocabularyLanguage.fromName('?! ', 'en'),
        throwsFormatException,
      );
      final name = VocabularyLanguage.fromName('  Unser Dialekt!  ', 'de');
      expect(name.customName, '  Unser Dialekt!  ');
      expect(
        name.matches(VocabularyLanguage.fromName('unser-dialekt', 'de')),
        isTrue,
      );
      expect(name.matches(VocabularyLanguage.german), isFalse);
      expect(
        () => VocabularyLanguage.fromJson({'kind': 'catalog', 'id': 'unknown'}),
        throwsFormatException,
      );
    },
  );
  test(
    'identity collapses Unicode whitespace but retains display, separators, accents and sharp S',
    () {
      expect(
        vocabularyIdentityKey(' IN\u00a0\u0085Betrieb\nsein '),
        'in betrieb sein',
      );
      expect(vocabularyIdentityKey('a b'), isNot(vocabularyIdentityKey('ab')));
      expect(vocabularyIdentityKey('MAẞE'), vocabularyIdentityKey('Maße'));
      expect(
        vocabularyIdentityKey('Maße'),
        isNot(vocabularyIdentityKey('Masse')),
      );
      expect(
        vocabularyIdentityKey('café'),
        isNot(vocabularyIdentityKey('cafe')),
      );
      expect(normalizeVocabularyText(' a  b '), 'a  b');
      expect(
        vocabularyComparisonKey('a  b'),
        isNot(vocabularyComparisonKey('a b')),
      );
    },
  );
  test(
    'separate meanings start fresh; Hint edits, collision rollback and Undo preserve learning',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      await f.review(rating: LearningRating.again);
      await f.review(reverse: true, rating: LearningRating.good);
      final a = await meaning(f.vocabulary, f.owner.id, 'in Betrieb sein');
      final b = await meaning(f.vocabulary, f.owner.id, 'sich fortbewegen');
      expect(a.id, isNot(b.id));
      final bCards = (await stored(f.db))['learning_items'] as List;
      await f.review(word: a, rating: LearningRating.again);
      await f.review(word: a, reverse: true, rating: LearningRating.good);
      final learned = (await stored(f.db))['learning_items'] as List;
      expect(
        learned.where((row) => (row as Map)['entry_id'] == b.id).toList(),
        bCards.where((row) => (row as Map)['entry_id'] == b.id).toList(),
      );

      final before = await stored(f.db);
      final edited = await f.vocabulary.updateWithContent(
        id: a.id,
        targetText: 'run',
        nativeText: 'laufen',
        assignments: {},
        content: const VocabularyContent(hintText: 'Maschine'),
      );
      expect(edited.id, a.id);
      final after = await stored(f.db);
      for (final table in [
        'learning_items',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
        'statistics_activity',
      ]) {
        expect(after[table], before[table], reason: table);
      }
      await expectLater(
        meaning(f.vocabulary, f.owner.id, ' SICH\u00a0FORTBEWEGEN '),
        throwsA(VocabularyValidation.duplicatePair),
      );
      final stable = await stored(f.db);
      await expectLater(
        f.vocabulary.updateWithContent(
          id: a.id,
          targetText: 'run',
          nativeText: 'laufen',
          assignments: {},
          content: const VocabularyContent(hintText: 'sich fortbewegen'),
        ),
        throwsA(VocabularyValidation.duplicatePair),
      );
      expect(await stored(f.db), stable);
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(a.id);
      await deletion.restore(receipt);
      expect(await stored(f.db), stable);
      final empty = await meaning(f.vocabulary, f.owner.id, null);
      await expectLater(
        meaning(f.vocabulary, f.owner.id, ' \n\u00a0 '),
        throwsA(VocabularyValidation.duplicatePair),
      );
      final receipt2 = await deletion.delete(empty.id);
      await meaning(f.vocabulary, f.owner.id, null);
      await expectLater(
        deletion.restore(receipt2),
        throwsA(VocabularyUndoFailure.duplicatePair),
      );
    },
  );
  test(
    'effective imported Hint participates in collision checks and atomic Hint swaps',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final a = await meaning(f.vocabulary, f.owner.id, 'first'),
          b = await meaning(f.vocabulary, f.owner.id, 'second');
      final service = SqliteVocabularyJsonService(f.db);
      Map<String, dynamic> document(List<Object?> entries) => {
        'format': 'piko-vocabulary',
        'schemaVersion': 5,
        'collections': [
          {
            'targetLanguage': {'kind': 'catalog', 'id': 'fr'},
            'nativeLanguage': {'kind': 'catalog', 'id': 'de'},
            'entries': entries,
          },
        ],
      };
      final before = await stored(f.db);
      final collision = await service.analyzeImport(
        collectionId: f.owner.id,
        json: jsonEncode(
          document([
            {
              'id': a.id,
              'hint': {'text': 'second'},
            },
          ]),
        ),
      );
      expect(
        collision.issues.any(
          (i) => i.code == VocabularyJsonIssueCode.duplicatePair,
        ),
        isTrue,
      );
      expect(await stored(f.db), before);
      final swap = await service.analyzeImport(
        collectionId: f.owner.id,
        json: jsonEncode(
          document([
            {
              'id': a.id,
              'hint': {'text': 'second'},
            },
            {
              'id': b.id,
              'hint': {'text': 'first'},
            },
          ]),
        ),
      );
      expect(swap.canApply, isTrue, reason: swap.issues.toString());
      await service.applyImport(swap);
      expect(
        (await f.vocabulary.watchById(a.id).first)!.content.hintText,
        'second',
      );
      final after = await stored(f.db);
      for (final table in [
        'learning_items',
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
      ]) {
        expect(after[table], before[table]);
      }
      final unselected = await service.analyzeImport(
        collectionId: f.owner.id,
        json: jsonEncode(
          document([
            {
              'targetText': 'run',
              'nativeText': 'laufen',
              'hint': {'text': 'third'},
            },
            {
              'targetText': 'run',
              'nativeText': 'laufen',
              'hint': {'text': 'fourth'},
            },
          ]),
        ),
        groups: {
          VocabularyJsonGroup.targetText,
          VocabularyJsonGroup.nativeText,
        },
      );
      expect(unselected.canApply, isFalse);
    },
  );
  test(
    'catalog/custom export and template round-trip across independent installations without replacing names',
    () async {
      for (final target in [
        VocabularyLanguage.values.singleWhere((v) => v.code == 'pt-BR'),
        VocabularyLanguage.values.singleWhere((v) => v.code == 'pt-PT'),
        VocabularyLanguage.fromName(' Unser Dialekt! ', 'de'),
      ]) {
        final a = PikoDatabase(NativeDatabase.memory()),
            b = PikoDatabase(NativeDatabase.memory());
        addTearDown(a.close);
        addTearDown(b.close);
        final source = await SqliteCollectionsRepository(a).create(
          name: 'Source',
          targetLanguage: target,
          nativeLanguage: VocabularyLanguage.german,
        );
        final destination = await SqliteCollectionsRepository(b).create(
          name: 'Destination',
          targetLanguage: target.isCustom
              ? VocabularyLanguage.fromName('unser-dialekt', 'de')
              : target,
          nativeLanguage: VocabularyLanguage.german,
        );
        await meaning(SqliteVocabularyRepository(a), source.id, 'machine');
        final sa = SqliteVocabularyJsonService(a),
            sb = SqliteVocabularyJsonService(b);
        final dir = Directory.systemTemp.createTempSync('piko-current-json-');
        addTearDown(() => dir.deleteSync(recursive: true));
        final file = File('${dir.path}/collection.json');
        await file.writeAsString(await sa.exportCollection(source.id));
        final preview = await sb.analyzeImport(
          collectionId: destination.id,
          json: await file.readAsString(),
        );
        expect(preview.canApply, isTrue, reason: preview.issues.toString());
        await sb.applyImport(preview);
        expect(
          (await SqliteCollectionsRepository(
            b,
          ).watchById(destination.id).first)!.targetLanguage,
          destination.targetLanguage,
        );
        expect(
          (await SqliteVocabularyRepository(
            b,
          ).watchByCollection(destination.id).first).single.content.hintText,
          'machine',
        );
        final template = VocabularyJsonFormat.minimalSample(
          targetLanguage: destination.targetLanguage,
          nativeLanguage: destination.nativeLanguage,
        );
        expect(
          (await sb.analyzeImport(
            collectionId: destination.id,
            json: template,
          )).canApply,
          isTrue,
        );
        final old = jsonDecode(template) as Map<String, dynamic>;
        old['schemaVersion'] = 4;
        expect(
          (await sb.analyzeImport(
            collectionId: destination.id,
            json: jsonEncode(old),
          )).issues.any(
            (i) => i.code == VocabularyJsonIssueCode.unsupportedVersion,
          ),
          isTrue,
        );
      }
    },
  );
  test(
    'concurrent creates and Hint updates enforce the final tuple without merging identities',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      Future<Object> attempt(Future<VocabularyRecord> value) =>
          value.then<Object>((row) => row, onError: (Object error) => error);
      final same = await Future.wait([
        attempt(meaning(f.vocabulary, f.owner.id, 'in  Betrieb')),
        attempt(meaning(f.vocabulary, f.owner.id, 'IN\u00a0BETRIEB')),
      ]);
      expect(same.whereType<VocabularyRecord>(), hasLength(1));
      expect(
        same.where((v) => v == VocabularyValidation.duplicatePair),
        hasLength(1),
      );
      final a = await meaning(f.vocabulary, f.owner.id, 'first'),
          b = await meaning(f.vocabulary, f.owner.id, 'second');
      final before = await stored(f.db);
      Future<VocabularyRecord> edit(String id) =>
          f.vocabulary.updateWithContent(
            id: id,
            targetText: 'run',
            nativeText: 'laufen',
            assignments: {},
            content: const VocabularyContent(hintText: 'shared'),
          );
      final updates = await Future.wait([
        attempt(edit(a.id)),
        attempt(edit(b.id)),
      ]);
      expect(updates.whereType<VocabularyRecord>(), hasLength(1));
      expect(
        updates.where((v) => v == VocabularyValidation.duplicatePair),
        hasLength(1),
      );
      final after = await stored(f.db);
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
    'manual Entry Session validates effective Hint and retains duplicate draft',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final session = EntrySessionController(
        collectionId: f.owner.id,
        repository: f.vocabulary,
      );
      addTearDown(session.dispose);
      session.setTargetText('run');
      session.setNativeText('laufen');
      session.setContent(const VocabularyContent(hintText: 'machine'));
      final a = await session.confirmAndNext();
      session.setTargetText('run');
      session.setNativeText('laufen');
      session.setContent(const VocabularyContent(hintText: 'movement'));
      final b = await session.confirmAndNext();
      expect(a.id, isNot(b.id));
      session.setTargetText(' RUN ');
      session.setNativeText('LAUFEN');
      session.setContent(const VocabularyContent(hintText: ' MACHINE '));
      final draft = session.draft;
      await expectLater(
        session.confirmAndNext(),
        throwsA(VocabularyValidation.duplicatePair),
      );
      expect(session.draft, same(draft));
      expect(session.confirmedEntries, hasLength(2));
    },
  );

  for (final collision in [false, true]) {
    test(
      'populated schema19 upgrade preserves all tables; collision=$collision fails without changes',
      () async {
        final dir = Directory.systemTemp.createTempSync(
          'piko-sense-migration-',
        );
        addTearDown(() => dir.deleteSync(recursive: true));
        final file = File('${dir.path}/piko.sqlite');
        final db = PikoDatabase(NativeDatabase(file));
        final f = Fixture(database: db);
        await f.initialize();
        await f.review(rating: LearningRating.again);
        await f.review(reverse: true, rating: LearningRating.good);
        // The Collection/vocabulary definitions stayed unchanged from v16 to v19.
        // Freeze their actual old DDL instead of deriving old constraints from v20.
        final snapshot = await stored(db);
        await db.close();
        final raw = sqlite.sqlite3.open(file.path);
        final schema =
            jsonDecode(
                  File(
                    'drift_schemas/drift_schema_v16.json',
                  ).readAsStringSync(),
                )
                as Map;
        for (final table in ['collections', 'vocabulary_entries']) {
          final spec = (schema['fixed_sql'] as List).singleWhere(
            (x) => x['name'] == table,
          );
          final ddl = ((spec['sql'] as List).single['sql'] as String)
              .replaceFirst(
                'CREATE TABLE IF NOT EXISTS "$table"',
                'CREATE TABLE "${table}_legacy"',
              );
          raw.execute(ddl);
          final columns = raw
              .select('PRAGMA table_info(${table}_legacy)')
              .map((r) => r['name'] as String)
              .join(',');
          raw.execute(
            'INSERT INTO ${table}_legacy(rowid,$columns) SELECT rowid,$columns FROM $table',
          );
          raw.execute('DROP TABLE $table');
          raw.execute('ALTER TABLE ${table}_legacy RENAME TO $table');
        }
        raw.execute(
          'CREATE UNIQUE INDEX vocabulary_entry_ownership ON vocabulary_entries(id,collection_id)',
        );
        if (collision) {
          raw.execute(
            "INSERT INTO vocabulary_entries(id,collection_id,target_text,native_text,target_key,native_key,hint_visibility) SELECT 'legacy-second',collection_id,' one ',native_text,' one ',native_key,hint_visibility FROM vocabulary_entries LIMIT 1",
          );
        }
        raw.execute('PRAGMA user_version = 19');
        final oldRows = {
          for (final table
              in raw
                  .select(
                    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
                  )
                  .map((r) => r['name'] as String))
            table: raw
                .select(
                  'SELECT rowid AS original_rowid,* FROM $table ORDER BY rowid',
                )
                .map((r) => Map<String, Object?>.from(r))
                .toList(),
        };
        raw.close();
        final upgraded = PikoDatabase(NativeDatabase(file));
        if (collision) {
          await expectLater(
            upgraded.select(upgraded.collections).get(),
            throwsA(isA<VocabularyMigrationCollision>()),
          );
          await upgraded.close();
          final check = sqlite.sqlite3.open(file.path);
          expect(check.select('PRAGMA user_version').single.values.single, 19);
          for (final item in oldRows.entries) {
            expect(
              check
                  .select(
                    'SELECT rowid AS original_rowid,* FROM ${item.key} ORDER BY rowid',
                  )
                  .map((r) => Map<String, Object?>.from(r))
                  .toList(),
              item.value,
              reason: item.key,
            );
          }
          check.close();
        } else {
          final after = await stored(upgraded);
          for (final table in snapshot.keys.where(
            (k) => k != 'collections' && k != 'vocabulary_entries',
          )) {
            expect(after[table], snapshot[table], reason: table);
          }
          final migrated = (after['vocabulary_entries'] as List).first as Map;
          expect(migrated['id'], f.entry.id);
          expect(migrated['hint_key'], '');
          expect(
            (await upgraded.customSelect('PRAGMA foreign_key_check').get()),
            isEmpty,
          );
          await upgraded.close();
          final reopened = PikoDatabase(NativeDatabase(file));
          expect((await stored(reopened)), after);
          await reopened.close();
        }
      },
    );
  }
}
