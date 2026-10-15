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
  late VocabularyRecord history;
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
    session = EntrySessionController(
      collectionId: owner.id,
      repository: vocabulary,
    );
    session!.setTargetText('pomme');
    session!.setNativeText('Apfel');
    first = await session!.confirmAndNext();
    session!.setTargetText('eau');
    session!.setNativeText('Wasser');
    second = await session!.confirmAndNext();
    history = await vocabulary.create(
      collectionId: owner.id,
      targetText: 'livre',
      nativeText: 'Buch',
    );
    foreign = await vocabulary.create(
      collectionId: other.id,
      targetText: 'pomme',
      nativeText: 'Apfel',
    );
  });
  tearDown(() async {
    session?.dispose();
    await database.close();
  });

  test(
    'confirmed records keep session registration order and immutable snapshots',
    () async {
      final controller = session!;
      final previous = controller.confirmedEntries;
      controller.setTargetText('ami');
      controller.setNativeText('Freund');
      final third = await controller.confirmAndNext();
      expect(controller.confirmedEntries.map((entry) => entry.id), [
        first.id,
        second.id,
        third.id,
      ]);
      expect(previous.map((entry) => entry.id), [first.id, second.id]);
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
      expect(stored.map((entry) => entry.id), [
        first.id,
        second.id,
        history.id,
      ]);
      expect(stored.map((entry) => entry.targetText), [
        'pomme',
        'eau',
        'livre',
      ]);
      expect(stored.map((entry) => entry.nativeText), [
        'Apfel',
        'Wasser',
        'Buch',
      ]);
    },
  );

  test(
    'foreign and unknown records cannot become session navigation targets',
    () {
      final controller = session!;
      controller.selectSavedEntry(first.id);
      expect(
        () => controller.selectSavedEntry(foreign.id),
        throwsArgumentError,
      );
      // A saved record is not in this session merely because it is in the Collection.
      expect(
        () => controller.selectSavedEntry(history.id),
        throwsArgumentError,
      );
      expect(controller.activeEntryId, first.id);
      expect(controller.confirmedEntries.map((entry) => entry.id), [
        first.id,
        second.id,
      ]);
    },
  );

  test('current selection does not notify or duplicate confirmed cards', () {
    final controller = session!;
    var notifications = 0;
    controller.addListener(() {
      notifications++;
    });
    controller.selectDraft();
    expect(notifications, 0);
    controller.selectSavedEntry(first.id);
    controller.selectSavedEntry(first.id);
    expect(notifications, 1);
    controller.selectDraft();
    controller.selectDraft();
    expect(notifications, 2);
    expect(controller.confirmedEntries, hasLength(2));
  });

  test(
    'disposal clears current session cards and rejects later navigation',
    () {
      final controller = session!;
      controller.selectSavedEntry(first.id);
      final snapshot = controller.confirmedEntries;
      controller.dispose();
      session = null;
      expect(controller.confirmedEntries, isEmpty);
      expect(controller.activeEntryId, isNull);
      expect(snapshot.first.id, first.id);
      expect(controller.confirmAndNext, throwsStateError);
      expect(() => controller.selectSavedEntry(first.id), throwsStateError);
      expect(controller.selectDraft, throwsStateError);
      final fresh = EntrySessionController(
        collectionId: first.collectionId,
        repository: SqliteVocabularyRepository(database),
      );
      addTearDown(fresh.dispose);
      expect(fresh.confirmedEntries, isEmpty);
      expect(fresh.activeEntryId, isNull);
    },
  );
}
