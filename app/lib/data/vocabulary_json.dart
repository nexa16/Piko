/// Portable vocabulary interchange, not a whole-application backup.
abstract interface class VocabularyJsonService {
  /// Captures exactly one existing Collection in a consistent read transaction.
  Future<String> exportCollection(String collectionId);

  /// Synthetic, copyable version-one structure. Never reads user data.
  String sampleJson();
}

enum VocabularyJsonExportFailure { collectionNotFound, incompleteLearning }

abstract final class VocabularyJsonFormat {
  static const format = 'piko-vocabulary';
  static const schemaVersion = 1;
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
