import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/entry/entry_session_controller.dart';

void main() {
  test(
    'draft retains raw target/native values and immutable prior snapshots',
    () {
      final controller = EntrySessionController(collectionId: 'collection');
      addTearDown(controller.dispose);
      final empty = controller.draft;
      controller.setTargetText(' \tCafe\u0301  ');
      final targetOnly = controller.draft;
      controller.setNativeText('  Schule\n');
      expect(controller.draft.targetText, ' \tCafe\u0301  ');
      expect(controller.draft.nativeText, '  Schule\n');
      expect(empty.targetText, isEmpty);
      expect(empty.nativeText, isEmpty);
      expect(targetOnly.nativeText, isEmpty);
      controller.setTargetText('');
      expect(controller.draft.targetText, isEmpty);
      expect(controller.draft.nativeText, '  Schule\n');
      expect(targetOnly.targetText, ' \tCafe\u0301  ');
    },
  );

  test('listeners receive complete state once per actual field change', () {
    final controller = EntrySessionController(collectionId: 'collection');
    addTearDown(controller.dispose);
    final snapshots = <EntryDraft>[];
    controller.addListener(() => snapshots.add(controller.draft));
    controller.setTargetText('학교');
    controller.setNativeText('Schule');
    controller.setNativeText('Schule');
    expect(snapshots, hasLength(2));
    expect(snapshots.first.targetText, '학교');
    expect(snapshots.first.nativeText, isEmpty);
    expect(snapshots.last.nativeText, 'Schule');
  });

  test('same and different Collection sessions never share drafts', () {
    final first = EntrySessionController(collectionId: 'first');
    final sameOwner = EntrySessionController(collectionId: 'first');
    final otherOwner = EntrySessionController(collectionId: 'second');
    addTearDown(first.dispose);
    addTearDown(sameOwner.dispose);
    addTearDown(otherOwner.dispose);
    first.setTargetText('One');
    sameOwner.setNativeText('Two');
    otherOwner.setTargetText('Three');
    expect(first.collectionId, 'first');
    expect(first.draft.nativeText, isEmpty);
    expect(sameOwner.draft.targetText, isEmpty);
    expect(otherOwner.collectionId, 'second');
    expect(otherOwner.draft.targetText, 'Three');
  });

  test(
    'ending a lifetime clears its draft and a fresh lifetime starts empty',
    () {
      final controller = EntrySessionController(collectionId: 'collection');
      var notifications = 0;
      controller.addListener(() {
        notifications++;
      });
      controller.setTargetText('Unsaved');
      controller.setNativeText('Noch nicht gespeichert');
      controller.dispose();
      expect(controller.draft.targetText, isEmpty);
      expect(controller.draft.nativeText, isEmpty);
      expect(() => controller.setTargetText('Late input'), throwsStateError);
      expect(() => controller.setNativeText('Late input'), throwsStateError);
      expect(notifications, 2);
      final next = EntrySessionController(collectionId: 'collection');
      addTearDown(next.dispose);
      expect(next.draft.targetText, isEmpty);
      expect(next.draft.nativeText, isEmpty);
    },
  );

  test(
    'typing and ending a draft lifetime leave real stored vocabulary unchanged',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-entry-draft-test-',
      );
      final file = File('${directory.path}/test.sqlite');
      var database = PikoDatabase(NativeDatabase(file));
      try {
        final owner = await SqliteCollectionsRepository(database).create(
          name: 'Words',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        );
        final saved = await SqliteVocabularyRepository(database).create(
          collectionId: owner.id,
          targetText: 'pomme',
          nativeText: 'Apfel',
        );
        final controller = EntrySessionController(collectionId: owner.id);
        controller.setTargetText('Cafe\u0301');
        controller.setNativeText('Kaffee');
        var rows = await SqliteVocabularyRepository(
          database,
        ).watchByCollection(owner.id).first;
        expect(rows, hasLength(1));
        expect(rows.single.id, saved.id);
        controller.dispose();
        await database.close();
        database = PikoDatabase(NativeDatabase(file));
        rows = await SqliteVocabularyRepository(
          database,
        ).watchByCollection(owner.id).first;
        expect(rows, hasLength(1));
        expect(rows.single.id, saved.id);
        expect(rows.single.targetText, 'pomme');
        expect(rows.single.nativeText, 'Apfel');
        final newSession = EntrySessionController(collectionId: owner.id);
        addTearDown(newSession.dispose);
        expect(newSession.draft.targetText, isEmpty);
        expect(newSession.draft.nativeText, isEmpty);
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
