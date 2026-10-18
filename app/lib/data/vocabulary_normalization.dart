import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Canonical display text; retains case, punctuation and internal whitespace.
String normalizeVocabularyText(String text) => unorm.nfc(text.trim());

/// Locale-independent lowercase comparison, without full Unicode case folding.
/// German sharp S remains distinct from the two-character sequence `ss`.
String vocabularyComparisonKey(String text) =>
    unorm.nfc(normalizeVocabularyText(text).toLowerCase());

/// NFC Unicode scalar lexical order, without accent folding or natural numbers.
int compareVocabularyLabels(String a, String b) {
  final left = vocabularyComparisonKey(a).runes.toList(),
      right = vocabularyComparisonKey(b).runes.toList();
  for (var i = 0; i < left.length && i < right.length; i++) {
    final difference = left[i].compareTo(right[i]);
    if (difference != 0) return difference;
  }
  return left.length.compareTo(right.length);
}

/// Identity only: search/sort/answer normalization retains its own contract.
final _identityWhitespace = RegExp(
  r'[\u0009-\u000D\u0020\u0085\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+',
);
String vocabularyIdentityKey(String? text) => unorm.nfc(
  (text ?? '').replaceAll(_identityWhitespace, ' ').trim().toLowerCase(),
);
