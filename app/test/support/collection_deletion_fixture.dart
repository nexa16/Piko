import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/vocabulary/collection_vocabulary_mutations.dart';
import 'entry_deletion_fixture.dart' show GatedDeletion, GatedEntryRepository;
import 'mutable_clock.dart';

class CollectionDeletionFixture {
  final clock = MutablePikoClock(DateTime.utc(2026, 10, 14));
  late final db = PikoDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
    clock: clock,
  );
  late final collections = SqliteCollectionsRepository(db);
  late final real = SqliteVocabularyRepository(db);
  late final repository = GatedEntryRepository(real);
  late final deletion = GatedDeletion(SqliteVocabularyDeletionService(db));
  late CollectionRecord owner;
  late CollectionVocabularyMutations mutations;
  final entries = <VocabularyRecord>[];
  Future<void> initialize() async {
    owner = await collections.create(
      name: 'Words',
      targetLanguage: VocabularyLanguage.french,
      nativeLanguage: VocabularyLanguage.german,
    );
    for (final (target, native) in [
      ('One', 'Eins'),
      ('Two', 'Zwei'),
      ('Three', 'Drei'),
    ]) {
      entries.add(
        await real.create(
          collectionId: owner.id,
          targetText: target,
          nativeText: native,
        ),
      );
    }
    mutations = CollectionVocabularyMutations(
      collectionId: owner.id,
      service: deletion,
      clock: clock,
    );
  }

  Future<void> dispose() async {
    await mutations.end();
    await db.close();
  }
}
