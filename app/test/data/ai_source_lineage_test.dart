import 'package:piko/data/categories_repository.dart';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'ai_service_test.dart' show envelope, edit;
import 'regular_reviews_test.dart' show Fixture;
import 'statistics_test.dart' show stored;

void main() {
  test(
    'known Source UUID stays protected and excluded from Hint transport after all labels renamed',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c =
          await SqliteCollectionsRepository(
            db,
            interfaceLanguage: () => 'en',
          ).create(
            name: 'Synthetic',
            targetLanguage: VocabularyLanguage.french,
            nativeLanguage: VocabularyLanguage.german,
          );
      final cats = SqliteCategoriesRepository(db),
          v = SqliteVocabularyRepository(db),
          s = SqliteAiService(db, enabled: true);
      final source = (await cats.dimensions(
        c.id,
      )).singleWhere((g) => g.acquisitionSource);
      final values = await cats.values(source.id);
      await cats.renameDimension(id: source.id, name: 'Renamed acquisition');
      for (var i = 0; i < values.length; i++) {
        await cats.renameValue(id: values[i].id, name: 'Custom acquisition $i');
      }
      final a = await v.createWithContent(
        collectionId: c.id,
        targetText: 'bank',
        nativeText: 'Bank',
        assignments: {
          source.id: {values.first.id},
        },
        content: const VocabularyContent(),
      );
      await v.create(
        collectionId: c.id,
        targetText: 'bank',
        nativeText: 'Ufer',
      );
      final snapshot = await s.snapshot(c.id), before = await stored(db);
      final request = await s.request(
        collectionId: c.id,
        action: AiAction.hints,
        anchor: snapshot.entries.singleWhere((e) => e.record.id == a.id),
      );
      final payload = request.toJson().toString();
      expect(payload, isNot(contains(source.id)));
      expect(payload, isNot(contains('Custom acquisition')));
      expect((await cats.dimensionById(source.id))!.acquisitionSource, isTrue);
      expect(await stored(db), before);
      final review = await s.request(
        collectionId: c.id,
        action: AiAction.review,
      );
      final plan = AiPlan.parse(
        review,
        envelope(
          review,
          edits: [edit('source-change', a.id, 'assignments', <Object?>[])],
        ),
      );
      await expectLater(
        s.apply(plan, {'source-change'}),
        throwsA(AiFailure.dependency),
      );
      expect(await stored(db), before);
      await cats.deleteDimension(source.id);
      expect(
        (await cats.dimensions(c.id)).any((g) => g.acquisitionSource),
        isFalse,
      );
    },
  );
  test(
    'populated actual schema21 to22 preserves every prior rowid/field; no guessed Source role/provenance',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'piko-ai-source-upgrade-',
      );
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/fixture.sqlite');
      var db = PikoDatabase(NativeDatabase(file));
      final f = Fixture(database: db);
      await f.initialize();
      await f.review();
      final cats = SqliteCategoriesRepository(db);
      await cats.createDimension(
        collectionId: f.owner.id,
        name: 'Unknown legacy classification',
        mode: CategoryMode.multiple,
      );
      await db.close();
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('DROP TABLE vocabulary_trash');
      raw.execute('ALTER TABLE collections DROP COLUMN level');
      raw.execute(
        'ALTER TABLE category_group_preferences DROP COLUMN acquisition_source',
      );
      raw.execute('PRAGMA user_version=21');
      final tables = raw
          .select(
            "select name from sqlite_master where type='table' and name not like 'sqlite_%' order by name",
          )
          .map((r) => r['name'] as String)
          .toList();
      final before = {
        for (final table in tables)
          table: raw
              .select(
                'select rowid as kept_rowid,* from "$table" order by rowid',
              )
              .map((r) => Map<String, Object?>.from(r))
              .toList(),
      };
      raw.close();
      db = PikoDatabase(NativeDatabase(file));
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        db.schemaVersion,
      );
      for (final table in tables) {
        final after =
            (await db
                    .customSelect(
                      'select rowid as kept_rowid,* from "$table" order by rowid',
                    )
                    .get())
                .map(
                  (r) =>
                      Map<String, Object?>.from(r.data)
                        ..remove('level')
                        ..remove('acquisition_source'),
                )
                .toList();
        expect(after, before[table], reason: table);
      }
      expect(
        (await SqliteCategoriesRepository(
          db,
        ).dimensions(f.owner.id)).single.acquisitionSource,
        isFalse,
      );
      expect(
        (await db.select(db.categoryGroupPreferences).get()).every(
          (r) => !r.acquisitionSource,
        ),
        isTrue,
      );
      expect(
        (await db.customSelect('pragma integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
      expect(await db.customSelect('pragma foreign_key_check').get(), isEmpty);
      await db.close();
      db = PikoDatabase(NativeDatabase(file));
      expect(
        (await SqliteCategoriesRepository(
          db,
        ).dimensions(f.owner.id)).single.acquisitionSource,
        isFalse,
      );
      await db.close();
    },
  );
}
