import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/entry/entry_session_controller.dart';

void main() {
  late PikoDatabase database;
  late VocabularyRecord first;
  late VocabularyRecord second;
  late VocabularyRecord foreign;
  EntrySessionController? session;

  setUp(() async {
    database = PikoDatabase(NativeDatabase.memory());
    final collections = SqliteCollectionsRepository(database);
    final owner = await collections.create(
      name: 'Words',
      targetLanguage: VocabularyLanguage.french,
      nativeLanguage: VocabularyLanguage.german,
    );
    final other = await collections.create(
      name: 'Other',
      targetLanguage: VocabularyLanguage.french,
      nativeLanguage: VocabularyLanguage.german,
    );
    final vocabulary = SqliteVocabularyRepository(database);
    first = await vocabulary.create(
      collectionId: owner.id,
      targetText: 'pomme',
      nativeText: 'Apfel',
    );
    second = await vocabulary.create(
      collectionId: owner.id,
      targetText: 'eau',
      nativeText: 'Wasser',
    );
    foreign = await vocabulary.create(
      collectionId: other.id,
      targetText: 'pomme',
      nativeText: 'Apfel',
    );
    session = EntrySessionController(collectionId: owner.id);
  });
  tearDown(() async {
    session?.dispose();
    await database.close();
  });

  test(
    'confirmed records keep session registration order and immutable snapshots',
    () {
      final controller = session!;
      expect(controller.confirmedEntries, isEmpty);
      controller.registerConfirmedEntry(second);
      final previous = controller.confirmedEntries;
      controller.registerConfirmedEntry(first);
      expect(controller.confirmedEntries.map((entry) => entry.id), [
        second.id,
        first.id,
      ]);
      expect(previous.map((entry) => entry.id), [second.id]);
      expect(
        () => controller.confirmedEntries.add(foreign),
        throwsUnsupportedError,
      );
      expect(controller.activeEntryId, isNull);
    },
  );

  test(
    'saved/draft navigation retains partial raw draft and never writes',
    () async {
      final controller = session!;
      controller.registerConfirmedEntry(first);
      controller.registerConfirmedEntry(second);
      controller.setTargetText(' \tCafe\u0301  ');
      final partial = controller.draft;
      controller.selectSavedEntry(second.id);
      expect(controller.activeEntryId, second.id);
      expect(identical(controller.draft, partial), isTrue);
      controller.selectSavedEntry(first.id);
      controller.selectDraft();
      expect(controller.activeEntryId, isNull);
      expect(identical(controller.draft, partial), isTrue);
      expect(controller.draft.nativeText, isEmpty);
      controller.setNativeText('  Kaffee\n');
      final complete = controller.draft;
      controller.selectSavedEntry(first.id);
      controller.selectDraft();
      expect(identical(controller.draft, complete), isTrue);
      expect(controller.draft.targetText, ' \tCafe\u0301  ');
      expect(controller.draft.nativeText, '  Kaffee\n');
      final stored = await SqliteVocabularyRepository(
        database,
      ).watchByCollection(first.collectionId).first;
      expect(stored.map((entry) => entry.id), [first.id, second.id]);
      expect(stored.map((entry) => entry.targetText), ['pomme', 'eau']);
      expect(stored.map((entry) => entry.nativeText), ['Apfel', 'Wasser']);
    },
  );

  test(
    'foreign and unknown records cannot become session navigation targets',
    () {
      final controller = session!;
      controller.registerConfirmedEntry(first);
      controller.selectSavedEntry(first.id);
      expect(
        () => controller.registerConfirmedEntry(foreign),
        throwsArgumentError,
      );
      expect(
        () => controller.selectSavedEntry(foreign.id),
        throwsArgumentError,
      );
      // A saved record is not in this session merely because it is in the Collection.
      expect(() => controller.selectSavedEntry(second.id), throwsArgumentError);
      expect(controller.activeEntryId, first.id);
      expect(controller.confirmedEntries.map((entry) => entry.id), [first.id]);
    },
  );

  test(
    'same registration and current selection do not notify or duplicate cards',
    () {
      final controller = session!;
      var notifications = 0;
      controller.addListener(() {
        notifications++;
      });
      controller.selectDraft();
      expect(notifications, 0);
      controller.registerConfirmedEntry(first);
      controller.registerConfirmedEntry(first);
      expect(notifications, 1);
      controller.selectSavedEntry(first.id);
      controller.selectSavedEntry(first.id);
      expect(notifications, 2);
      controller.selectDraft();
      controller.selectDraft();
      expect(notifications, 3);
      expect(controller.confirmedEntries, hasLength(1));
    },
  );

  test(
    'disposal clears current session cards and rejects later navigation',
    () {
      final controller = session!;
      controller.registerConfirmedEntry(first);
      controller.selectSavedEntry(first.id);
      final snapshot = controller.confirmedEntries;
      controller.dispose();
      session = null;
      expect(controller.confirmedEntries, isEmpty);
      expect(controller.activeEntryId, isNull);
      expect(snapshot.single.id, first.id);
      expect(() => controller.registerConfirmedEntry(second), throwsStateError);
      expect(() => controller.selectSavedEntry(first.id), throwsStateError);
      expect(controller.selectDraft, throwsStateError);
      final fresh = EntrySessionController(collectionId: first.collectionId);
      addTearDown(fresh.dispose);
      expect(fresh.confirmedEntries, isEmpty);
      expect(fresh.activeEntryId, isNull);
    },
  );
}
