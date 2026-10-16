import 'dart:convert';

/// Portable vocabulary interchange, not a whole-application backup.
abstract interface class VocabularyJsonService {
  /// Captures exactly one existing Collection in a consistent read transaction.
  Future<String> exportCollection(String collectionId);

  /// Synthetic, copyable version-one structure. Never reads user data.
  String sampleJson();

  Future<VocabularyJsonPreview> analyzeImport({
    required String collectionId,
    required String json,
    Set<VocabularyJsonGroup> groups = VocabularyJsonGroup.all,
  });

  /// Call only after explicit confirmation of this service's preview.
  Future<VocabularyJsonApplyResult> applyImport(VocabularyJsonPreview preview);
}

enum VocabularyJsonGroup {
  targetText,
  nativeText,
  categoryAssignments,
  example,
  hint;

  static const all = {
    targetText,
    nativeText,
    categoryAssignments,
    example,
    hint,
  };
}

enum VocabularyJsonIssueCode {
  groupsRequired,
  tooLarge,
  invalidJson,
  invalidEnvelope,
  unsupportedFormat,
  unsupportedVersion,
  exactlyOneCollection,
  languageMismatch,
  collectionNotFound,
  invalidId,
  duplicateId,
  foreignId,
  invalidField,
  requiredTarget,
  requiredNative,
  duplicatePair,
  unknownDimension,
  unknownValue,
  invalidOwnership,
  duplicateName,
  cardinalityViolation,
}

final class VocabularyJsonIssue {
  const VocabularyJsonIssue({required this.code, required this.path, this.row});
  final VocabularyJsonIssueCode code;
  final String path;

  /// One-based entry row, or null for envelope/definition errors.
  final int? row;
}

enum VocabularyJsonNotice {
  importedLearningIgnored,
  destinationCategoryMetadataRetained,
}

abstract interface class VocabularyJsonPreview {
  String get collectionId;
  Set<VocabularyJsonGroup> get groups;
  List<VocabularyJsonIssue> get issues;
  Set<VocabularyJsonNotice> get notices;
  int get newCount;
  int get updatedCount;
  int get unchangedCount;
  int get errorCount;
  bool get canApply;
}

enum VocabularyJsonApplyFailure {
  invalidPreview,
  stalePreview,
  alreadyApplied,
  inProgress,
}

final class VocabularyJsonApplyResult {
  const VocabularyJsonApplyResult({
    required this.newCount,
    required this.updatedCount,
    required this.unchangedCount,
  });
  final int newCount;
  final int updatedCount;
  final int unchangedCount;
}

enum VocabularyJsonExportFailure { collectionNotFound, incompleteLearning }

abstract final class VocabularyJsonFormat {
  static String minimalSample({
    required String targetLanguage,
    required String nativeLanguage,
    String topic = 'Topic',
    String food = 'Food',
    String difficulty = 'Difficulty',
    String easy = 'Easy',
  }) {
    const words = {'ko': '사과', 'fr': 'pomme', 'en': 'apple', 'de': 'Apfel'};
    const collection = '8f8ce022-4a25-47ed-8944-8955dcf353da',
        entry = '13e76e74-a952-4c30-b7d7-3016087ad6f1';
    const topicId = 'd1db8c92-bd21-4c04-90d5-83eb2ad9e121',
        foodId = 'b8376a27-ab64-41aa-974e-a56a16db1471';
    const difficultyId = '2317a250-a3ae-4f8f-8d02-cd5516331962',
        easyId = '1e56de42-7a49-4ef9-906a-a3bc7ba998e9';
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'schemaVersion': 3,
      'collections': [
        {
          'id': collection,
          'name': 'Example',
          'targetLanguage': targetLanguage,
          'nativeLanguage': nativeLanguage,
          'categoryDimensions': [
            {
              'id': topicId,
              'name': topic,
              'mode': 'multiple',
              'values': [
                {'id': foodId, 'name': food},
              ],
            },
            {
              'id': difficultyId,
              'name': difficulty,
              'mode': 'single',
              'values': [
                {'id': easyId, 'name': easy},
              ],
            },
          ],
          'entries': [
            {
              'id': entry,
              'targetText': words[targetLanguage],
              'nativeText': words[nativeLanguage],
              'categoryAssignments': [
                {
                  'dimensionId': topicId,
                  'valueIds': [foodId],
                },
                {
                  'dimensionId': difficultyId,
                  'valueIds': [easyId],
                },
              ],
            },
          ],
        },
      ],
    });
  }

  static const format = 'piko-vocabulary';
  static const schemaVersion = 3;
  static const schedulerLibrary = 'fsrs';
  static const schedulerVersion = '2.0.1';
  static const maxImportBytes = 1000000;

  /// Mirrors the canonical example, including both complete initial cards.
  static const sample = '''{
  "format": "piko-vocabulary",
  "schemaVersion": 1,
  "exportedAt": "2026-10-14T12:00:00.000000Z",
  "scheduler": {"library": "fsrs", "version": "2.0.1", "cardFormatVersion": 1},
  "collections": [{
    "id": "8f8ce022-4a25-47ed-8944-8955dcf353da",
    "name": "French",
    "targetLanguage": "fr",
    "nativeLanguage": "de",
    "reviewScopes": {"targetToNative": null, "nativeToTarget": null},
    "categoryDimensions": [],
    "entries": [{
      "id": "13e76e74-a952-4c30-b7d7-3016087ad6f1",
      "targetText": "pomme",
      "nativeText": "Apfel",
      "categoryAssignments": [],
      "learning": {
        "targetToNative": {
          "id": 1, "formatVersion": 1, "generation": 0, "reviewRevision": 0,
          "card": {"cardId": 1, "state": 1, "step": 0, "stability": null, "difficulty": null, "due": "2026-10-14T12:00:00.000000Z", "lastReview": null},
          "reviews": [], "retry": null, "speedCompleted": false
        },
        "nativeToTarget": {
          "id": 2, "formatVersion": 1, "generation": 0, "reviewRevision": 0,
          "card": {"cardId": 2, "state": 1, "step": 0, "stability": null, "difficulty": null, "due": "2026-10-14T12:00:00.000000Z", "lastReview": null},
          "reviews": [], "retry": null, "speedCompleted": false
        }
      }
    }]
  }]
}''';
}
