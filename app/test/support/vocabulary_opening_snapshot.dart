import 'package:piko/data/vocabulary_repository.dart';

/// Test doubles only; the SQLite repository rejects this implementation.
class TestOpeningSnapshot implements VocabularyOpeningSnapshot {
  TestOpeningSnapshot(this.entry);
  @override
  final VocabularyRecord entry;
}
