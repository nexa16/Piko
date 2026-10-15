import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/vocabulary_normalization.dart';
import 'package:piko/main.dart';

/// Storage verification only. Manual-entry interaction and application
/// termination durability retain their own later acceptance evidence.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android saves vocabulary offline and retains it after file reopen', (
    tester,
  ) async {
    var networkAttempts = 0;
    await HttpOverrides.runZoned<Future<void>>(
      () async {
        // Prove the guard is active, then require zero calls from the save path.
        expect(() => HttpClient(), throwsA(isA<StateError>()));
        expect(networkAttempts, 1);
        networkAttempts = 0;
        final support = await getApplicationSupportDirectory();
        final directory = await support.createTemp(
          'piko-offline-verification-',
        );
        final file = File('${directory.path}/test.sqlite');
        var db = PikoDatabase(NativeDatabase(file));
        try {
          // Inject a neutral home so this fixture never opens runtime's piko DB.
          await tester.pumpWidget(const PikoApp(home: Scaffold()));
          final owner = await SqliteCollectionsRepository(db).create(
            name: 'Offline verification',
            targetLanguage: VocabularyLanguage.korean,
            nativeLanguage: VocabularyLanguage.german,
          );
          final saved = await SqliteVocabularyRepository(db).create(
            collectionId: owner.id,
            targetText: '  학교  ',
            nativeText: '  Schule  ',
          );
          expect(saved.targetText, '학교');
          expect(saved.nativeText, 'Schule');
          final original = await db.select(db.vocabularyEntries).getSingle();
          expect(original.targetKey, vocabularyComparisonKey(saved.targetText));
          expect(original.nativeKey, 'schule');
          await tester.pumpWidget(const SizedBox());
          await db.close();
          db = PikoDatabase(NativeDatabase(file));
          final reopenedOwner = await SqliteCollectionsRepository(
            db,
          ).watchById(owner.id).first;
          expect(reopenedOwner!.id, owner.id);
          expect(reopenedOwner.targetLanguage, VocabularyLanguage.korean);
          expect(reopenedOwner.nativeLanguage, VocabularyLanguage.german);
          final repository = SqliteVocabularyRepository(db);
          final list = await repository.watchByCollection(owner.id).first;
          final actual = await repository.watchById(saved.id).first;
          expect(list, hasLength(1));
          expect(list.single.id, saved.id);
          expect(actual!.id, saved.id);
          expect(actual.collectionId, owner.id);
          expect(actual.targetText, '학교');
          expect(actual.nativeText, 'Schule');
          final row = await db.select(db.vocabularyEntries).getSingle();
          expect(row.targetKey, original.targetKey);
          expect(row.nativeKey, original.nativeKey);
          expect(networkAttempts, 0);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await db.close();
          // Delete only this exact newly created fixture-owned subdirectory.
          if (directory.parent.absolute.path != support.absolute.path ||
              !directory.uri.pathSegments
                  .where((s) => s.isNotEmpty)
                  .last
                  .startsWith('piko-offline-verification-')) {
            throw StateError('Refusing cleanup outside the isolated fixture');
          }
          await directory.delete(recursive: true);
        }
      },
      createHttpClient: (_) {
        networkAttempts++;
        throw StateError('HTTP is disabled in offline storage verification');
      },
    );
  });
}
