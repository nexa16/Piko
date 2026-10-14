import 'dart:io';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/main.dart';

PikoDatabase fileDatabase(File file) => PikoDatabase(
  DatabaseConnection(
    NativeDatabase(file),
    closeStreamsSynchronously: true,
  ),
);

Future<void> flush(WidgetTester tester, PikoDatabase database) async {
  await tester.runAsync(() => database.customSelect('SELECT 1').get());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'COLL-013 Home shows persisted zero and live create count across file reopen',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'piko-entry-count-',
      );
      final file = File('${directory.path}/piko.sqlite');
      var database = fileDatabase(file);
      var databaseOpen = true;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 1));
        if (databaseOpen) await tester.runAsync(database.close);
        directory.deleteSync(recursive: true);
      });

      var collections = SqliteCollectionsRepository(database);
      var vocabulary = SqliteVocabularyRepository(database);
      late CollectionRecord collection;
      await tester.runAsync(() async {
        collection = await collections.create(
          name: 'Words',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        );
      });
      await tester.pumpWidget(
        PikoApp(
          home: CollectionsHome(
            repository: collections,
            vocabularyRepository: vocabulary,
          ),
        ),
      );
      await flush(tester, database);
      expect(find.text('French · German · 0 entries'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Open Words, French · German · 0 entries',
        ),
        findsOneWidget,
      );

      await tester.runAsync(
        () => vocabulary.create(
          collectionId: collection.id,
          targetText: 'pomme',
          nativeText: 'Apfel',
        ),
      );
      await flush(tester, database);
      expect(find.text('French · German · 1 entries'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.runAsync(database.close);
      databaseOpen = false;
      database = fileDatabase(file);
      databaseOpen = true;
      collections = SqliteCollectionsRepository(database);
      vocabulary = SqliteVocabularyRepository(database);
      await tester.pumpWidget(
        PikoApp(
          home: CollectionsHome(
            repository: collections,
            vocabularyRepository: vocabulary,
          ),
        ),
      );
      await flush(tester, database);
      expect(find.text('French · German · 1 entries'), findsOneWidget);
    },
  );
}
