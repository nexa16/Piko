import 'vocabulary_content.dart';

final class VocabularyRecord {
  const VocabularyRecord({
    required this.id,
    required this.collectionId,
    required this.targetText,
    required this.nativeText,
    this.content = const VocabularyContent(),
    this.addedAt,
    this.active = true,
  });
  final String id;
  final String collectionId;
  final String targetText;
  final String nativeText;
  final VocabularyContent content;
  final DateTime? addedAt;
  final bool active;
}

enum VocabularyValidation {
  requiredTarget,
  requiredNative,
  collectionNotFound,
  entryNotFound,
  duplicatePair,
}

abstract interface class VocabularyOpeningSnapshot {
  VocabularyRecord get entry;
}

/// Optional round-2 capability; text-only repositories and callers stay valid.
abstract interface class CategorizedVocabularyOpeningSnapshot
    implements VocabularyOpeningSnapshot {
  Map<String, Set<String>> get assignments;
}

abstract interface class CategorizedVocabularyRepository
    implements VocabularyRepository {
  Future<Map<String, Set<String>>> categorizedAssignments(String entryId);
  Future<VocabularyRecord> createCategorized({
    required String collectionId,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
  });
  Future<VocabularyRecord> updateCategorized({
    required String id,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
  });
}

abstract interface class VocabularyRepository {
  Future<VocabularyOpeningSnapshot> captureOpeningSnapshot({
    required String entryId,
    required String collectionId,
  });
  Future<VocabularyRecord> restoreOpeningSnapshot(
    VocabularyOpeningSnapshot snapshot,
  );
  Future<VocabularyRecord> create({
    required String collectionId,
    required String targetText,
    required String nativeText,
  });
  Future<VocabularyRecord> update({
    required String id,
    required String targetText,
    required String nativeText,
  });
  Stream<List<VocabularyRecord>> watchByCollection(String collectionId);
  Stream<VocabularyRecord?> watchById(String id);
}

/// Optional content capability; legacy text-only implementations stay valid.
abstract interface class VocabularyContentRepository
    implements CategorizedVocabularyRepository {
  Future<HintVisibility> readHintVisibilityDefault({
    required String collectionId,
  });
  Future<VocabularyRecord> createWithContent({
    required String collectionId,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
    required VocabularyContent content,
    bool makeHintVisibilityDefault = false,
    bool active = true,
  });
  Future<VocabularyRecord> updateWithContent({
    required String id,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
    required VocabularyContent content,
    bool makeHintVisibilityDefault = false,
    bool? active,
  });
}

abstract interface class CollectionHintPreferences {
  Future<bool> hintDefaultOfferHandled(String collectionId);
  Future<void> setCollectionHintDefault(String collectionId, bool automatic);
  Future<void> completeHintDefaultOffer(
    String collectionId, {
    required bool accept,
  });
}

/// Confirmation and the next draft's carry-over share one committed snapshot.
final class EntryConfirmation {
  EntryConfirmation(this.entry, Map<String, Set<String>> nextAssignments)
    : nextAssignments = Map.unmodifiable({
        for (final group in nextAssignments.entries)
          group.key: Set<String>.unmodifiable(group.value),
      });
  final VocabularyRecord entry;
  final Map<String, Set<String>> nextAssignments;
}

abstract interface class EntryConfirmationRepository {
  Future<EntryConfirmation> confirmNewEntry({
    required String collectionId,
    required String targetText,
    required String nativeText,
    required Map<String, Set<String>> assignments,
    required VocabularyContent content,
    bool makeHintVisibilityDefault = false,
    bool active = true,
  });
}

/// Optional read capability; captured once per learning-card presentation.
abstract interface class QuestionExamplesRepository {
  Future<bool> readQuestionExamples();
}
