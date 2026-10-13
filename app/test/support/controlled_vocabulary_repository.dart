import 'dart:async';
import 'package:piko/data/vocabulary_repository.dart';

class ControlledVocabularyRepository implements VocabularyRepository {
  var createCalls = 0;
  String? collectionId;
  String? targetText;
  String? nativeText;
  var pending = Completer<VocabularyRecord>();
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
  }) => throw UnsupportedError('Not used by entry confirmation tests.');
  @override
  Stream<List<VocabularyRecord>> watchByCollection(String collectionId) =>
      Stream.value([]);
  @override
  Stream<VocabularyRecord?> watchById(String id) => Stream.value(null);
}
