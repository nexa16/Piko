import 'dart:async';
import 'package:piko/data/vocabulary_repository.dart';
import 'vocabulary_opening_snapshot.dart';

class ControlledVocabularyRepository implements VocabularyRepository {
  VocabularyRecord? openingRecord;
  @override
  Future<VocabularyOpeningSnapshot> captureOpeningSnapshot({
    required String entryId,
    required String collectionId,
  }) async {
    final record = openingRecord!;
    if (record.id != entryId || record.collectionId != collectionId) {
      throw VocabularyValidation.entryNotFound;
    }
    return TestOpeningSnapshot(record);
  }

  @override
  Future<VocabularyRecord> restoreOpeningSnapshot(
    VocabularyOpeningSnapshot snapshot,
  ) => update(
    id: snapshot.entry.id,
    targetText: snapshot.entry.targetText,
    nativeText: snapshot.entry.nativeText,
  );
  var createCalls = 0;
  String? collectionId;
  String? targetText;
  String? nativeText;
  var pending = Completer<VocabularyRecord>();
  final updates =
      <
        ({
          String id,
          String target,
          String native,
          Completer<VocabularyRecord> result,
        })
      >[];
  @override
  Future<VocabularyRecord> create({
    required String collectionId,
    required String targetText,
    required String nativeText,
  }) {
    createCalls++;
    this.collectionId = collectionId;
    this.targetText = targetText;
    this.nativeText = nativeText;
    return pending.future;
  }

  @override
  Future<VocabularyRecord> update({
    required String id,
    required String targetText,
    required String nativeText,
  }) {
    final result = Completer<VocabularyRecord>();
    updates.add((
      id: id,
      target: targetText,
      native: nativeText,
      result: result,
    ));
    return result.future;
  }

  @override
  Stream<List<VocabularyRecord>> watchByCollection(String collectionId) =>
      Stream.value([]);
  @override
  Stream<VocabularyRecord?> watchById(String id) => Stream.value(null);
}
