import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Canonical display text; retains case, punctuation and internal whitespace.
String normalizeVocabularyText(String text) => unorm.nfc(text.trim());

/// Locale-independent lowercase comparison, without full Unicode case folding.
/// German sharp S remains distinct from the two-character sequence `ss`.
String vocabularyComparisonKey(String text) =>
    unorm.nfc(normalizeVocabularyText(text).toLowerCase());
