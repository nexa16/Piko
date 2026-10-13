import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';

Future<CollectionRecord> collection(PikoDatabase database) =>
    SqliteCollectionsRepository(database).create(
      name: 'Same collection',
      targetLanguage: VocabularyLanguage.french,
      nativeLanguage: VocabularyLanguage.german,
    );

void main() {
  test(
    'same normalized pair in matching collections has isolated identities and edits',
    () async {
      final database = PikoDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final first = await collection(database);
      final second = await collection(database);
      final repository = SqliteVocabularyRepository(database);
      final firstEntry = await repository.create(
        collectionId: first.id,
        targetText: ' Cafe\u0301 ',
        nativeText: ' Kaffee ',
      );
      final secondEntry = await repository.create(
        collectionId: second.id,
        targetText: 'CAFÉ',
        nativeText: 'KAFFEE',
      );
      expect(first.id, isNot(second.id));
      expect(firstEntry.id, isNot(secondEntry.id));
      expect(
        (await repository.watchByCollection(first.id).first).single.id,
        firstEntry.id,
      );
      expect(
        (await repository.watchByCollection(second.id).first).single.id,
        secondEntry.id,
      );
      for (final id in [first.id, second.id]) {
        await expectLater(
          repository.create(
            collectionId: id,
            targetText: 'café',
            nativeText: 'kaffee',
          ),
          throwsA(VocabularyValidation.duplicatePair),
        );
      }
      await repository.update(
        id: firstEntry.id,
        targetText: 'pomme',
        nativeText: 'Apfel',
      );
      final changed =
          (await repository.watchByCollection(first.id).first).single;
      final untouched =
          (await repository.watchByCollection(second.id).first).single;
      expect(changed.id, firstEntry.id);
      expect(changed.collectionId, first.id);
      expect(changed.targetText, 'pomme');
      expect(changed.nativeText, 'Apfel');
      expect(untouched.id, secondEntry.id);
      expect(untouched.collectionId, second.id);
      expect(untouched.targetText, 'CAFÉ');
      expect(untouched.nativeText, 'KAFFEE');
      // An owner may change its pair to one present in another Collection.
      await repository.update(
        id: firstEntry.id,
        targetText: 'Café',
        nativeText: 'Kaffee',
      );
      expect(
        (await repository.watchById(firstEntry.id).first)!.targetText,
        'Café',
      );
      expect(
        (await repository.watchById(secondEntry.id).first)!.targetText,
        'CAFÉ',
      );
    },
  );

  test(
    'identical normalized pairs and matching collection metadata survive file reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-cross-collection-test-',
      );
      final file = File('${directory.path}/test.sqlite');
      var database = PikoDatabase(NativeDatabase(file));
      try {
        final first = await collection(database);
        final second = await collection(database);
        final repository = SqliteVocabularyRepository(database);
        final one = await repository.create(
          collectionId: first.id,
          targetText: 'Café',
          nativeText: 'Kaffee',
        );
        final two = await repository.create(
          collectionId: second.id,
          targetText: 'CAFE\u0301',
          nativeText: 'KAFFEE',
        );
        await database.close();
        database = PikoDatabase(NativeDatabase(file));
        final owners = await SqliteCollectionsRepository(
          database,
        ).watchAll().first;
        expect(owners.map((r) => r.id), [first.id, second.id]);
        expect(owners.map((r) => r.name), [
          'Same collection',
          'Same collection',
        ]);
        expect(
          owners.map((r) => r.targetLanguage),
          everyElement(VocabularyLanguage.french),
        );
        expect(
          owners.map((r) => r.nativeLanguage),
          everyElement(VocabularyLanguage.german),
        );
        final reopened = SqliteVocabularyRepository(database);
        final firstRows = await reopened.watchByCollection(first.id).first;
        final secondRows = await reopened.watchByCollection(second.id).first;
        expect(firstRows.single.id, one.id);
        expect(secondRows.single.id, two.id);
        expect(firstRows.single.targetText, 'Café');
        expect(firstRows.single.nativeText, 'Kaffee');
        expect(secondRows.single.targetText, 'CAFÉ');
        expect(secondRows.single.nativeText, 'KAFFEE');
        await expectLater(
          reopened.create(
            collectionId: first.id,
            targetText: 'café',
            nativeText: 'kaffee',
          ),
          throwsA(VocabularyValidation.duplicatePair),
        );
        expect(
          await database.select(database.vocabularyEntries).get(),
          hasLength(2),
        );
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
