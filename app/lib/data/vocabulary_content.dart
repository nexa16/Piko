import 'vocabulary_normalization.dart';

enum HintVisibility {
  always,
  hidden;

  static const settingKey = 'hintVisibility';
  static HintVisibility fromStored(String? value) =>
      value == 'hidden' ? hidden : always;
}

enum VocabularyContentValidation {
  examplePairRequired,
  exampleTooLong,
  hintTooLong,
}

/// May hold raw editing values; only [normalized] is accepted for persistence.
final class VocabularyContent {
  const VocabularyContent({
    this.exampleTargetText,
    this.exampleNativeText,
    this.hintText,
    this.hintVisibility = HintVisibility.always,
  });

  static const maxExampleLength = 1000;
  static const maxHintLength = 2000;
  final String? exampleTargetText, exampleNativeText, hintText;
  final HintVisibility hintVisibility;

  VocabularyContent normalized() {
    String? optional(String? value) {
      final normalized = normalizeVocabularyText(value ?? '');
      return normalized.isEmpty ? null : normalized;
    }

    final target = optional(exampleTargetText),
        native = optional(exampleNativeText);
    if ((target == null) != (native == null)) {
      throw VocabularyContentValidation.examplePairRequired;
    }
    if ((target?.runes.length ?? 0) > maxExampleLength ||
        (native?.runes.length ?? 0) > maxExampleLength) {
      throw VocabularyContentValidation.exampleTooLong;
    }
    final hint = optional(hintText);
    if ((hint?.runes.length ?? 0) > maxHintLength) {
      throw VocabularyContentValidation.hintTooLong;
    }
    return VocabularyContent(
      exampleTargetText: target,
      exampleNativeText: native,
      hintText: hint,
      hintVisibility: hintVisibility,
    );
  }

  factory VocabularyContent.fromStored({
    required String? exampleTargetText,
    required String? exampleNativeText,
    required String? hintText,
    required String hintVisibility,
  }) {
    if (!HintVisibility.values.any((value) => value.name == hintVisibility)) {
      throw const FormatException('Invalid stored Hint visibility');
    }
    final content = VocabularyContent(
      exampleTargetText: exampleTargetText,
      exampleNativeText: exampleNativeText,
      hintText: hintText,
      hintVisibility: HintVisibility.values.byName(hintVisibility),
    );
    try {
      if (content.normalized() != content) {
        throw const FormatException('Noncanonical stored vocabulary content');
      }
    } on VocabularyContentValidation {
      throw const FormatException('Invalid stored vocabulary content');
    }
    return content;
  }

  @override
  bool operator ==(Object other) =>
      other is VocabularyContent &&
      exampleTargetText == other.exampleTargetText &&
      exampleNativeText == other.exampleNativeText &&
      hintText == other.hintText &&
      hintVisibility == other.hintVisibility;
  @override
  int get hashCode => Object.hash(
    exampleTargetText,
    exampleNativeText,
    hintText,
    hintVisibility,
  );
}
