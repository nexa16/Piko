import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'statistics_test.dart' show stored;

void main() {
  for (final locale in ['en', 'de']) {
    test(
      'new $locale Collection has exactly four removable starter groups; no retrofit',
      () async {
        final db = PikoDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final collections = SqliteCollectionsRepository(
              db,
              interfaceLanguage: () => locale,
            ),
            cats = SqliteCategoriesRepository(db);
        final c = await collections.create(
          name: 'Owned',
          targetLanguage: VocabularyLanguage.korean,
          nativeLanguage: VocabularyLanguage.german,
        );
        final groups = await cats.dimensions(c.id);
        expect(
          groups.map((g) => g.name),
          locale == 'en'
              ? ['CEFR level', 'Topic', 'Word type', 'Source']
              : ['GER-Stufe', 'Thema', 'Wortart', 'Quelle'],
        );
        expect((await cats.values(groups[0].id)).map((v) => v.name).toSet(), {
          'A1',
          'A2',
          'B1',
          'B2',
          'C1',
          'C2',
        });
        expect(
          (await cats.values(groups[1].id)).map((v) => v.name).toSet(),
          locale == 'en'
              ? {'Food', 'Home', 'Time'}
              : {'Essen', 'Wohnen', 'Zeit'},
        );
        expect((await cats.values(groups[2].id)).length, 4);
        expect(
          (await cats.values(groups[2].id)).map((v) => v.name),
          locale == 'en'
              ? ['Adjective', 'Fixed expression', 'Noun', 'Verb']
              : ['Adjektiv', 'Feste Wendung', 'Nomen', 'Verb'],
        );
        expect(
          (await db.select(db.categoryGroupPreferences).get()).every(
            (p) => !p.customValueOrder,
          ),
          true,
        );
        expect((await cats.values(groups[3].id)).length, 2);
        await cats.deleteDimension(groups[1].id);
        await collections.rename(id: c.id, name: 'Renamed');
        expect((await cats.dimensions(c.id)).length, 3);
        final other = await collections.create(
          name: 'Another',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        );
        expect((await cats.dimensions(other.id)).length, 4);
        expect((await cats.dimensions(c.id)).length, 3);
      },
    );
  }
  test(
    'manual confirmation labels known acquisition; imports, legacy and deleted/customized Source stay unchanged',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c =
          await SqliteCollectionsRepository(
            db,
            interfaceLanguage: () => 'de',
          ).create(
            name: 'Owned',
            targetLanguage: VocabularyLanguage.french,
            nativeLanguage: VocabularyLanguage.german,
          );
      final cats = SqliteCategoriesRepository(db),
          v = SqliteVocabularyRepository(db);
      final source = (await cats.dimensions(
        c.id,
      )).singleWhere((g) => g.name == 'Quelle');
      final manual = (await cats.values(
        source.id,
      )).singleWhere((v) => v.name == 'Manuell erfasst');
      final first = await v.confirmNewEntry(
        collectionId: c.id,
        targetText: 'un',
        nativeText: 'eins',
        assignments: {},
        content: const VocabularyContent(),
      );
      expect(await v.categorizedAssignments(first.entry.id), {
        source.id: {manual.id},
      });
      final imported = await v.createWithContent(
        collectionId: c.id,
        targetText: 'deux',
        nativeText: 'zwei',
        assignments: {},
        content: const VocabularyContent(),
      );
      expect(await v.categorizedAssignments(imported.id), isEmpty);
      await cats.renameValue(id: manual.id, name: 'My customized acquisition');
      final customized = await v.confirmNewEntry(
        collectionId: c.id,
        targetText: 'trois',
        nativeText: 'drei',
        assignments: {},
        content: const VocabularyContent(),
      );
      expect(await v.categorizedAssignments(customized.entry.id), isEmpty);
      await cats.deleteDimension(source.id);
      await v.confirmNewEntry(
        collectionId: c.id,
        targetText: 'quatre',
        nativeText: 'vier',
        assignments: {},
        content: const VocabularyContent(),
      );
      expect((await cats.dimensions(c.id)).length, 3);
    },
  );
  test(
    'starter catalog failure rolls back Collection, dimensions and local color assignments',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      await db.customStatement(
        "CREATE TRIGGER fail_seed BEFORE INSERT ON category_values WHEN NEW.name='Verb' BEGIN SELECT RAISE(ABORT,'synthetic'); END",
      );
      final before = await stored(db);
      await expectLater(
        SqliteCollectionsRepository(db, interfaceLanguage: () => 'en').create(
          name: 'Failure',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        ),
        throwsA(anything),
      );
      expect(await stored(db), before);
    },
  );
}
