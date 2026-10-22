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

final class ExamplePair {
  const ExamplePair({required this.targetText, required this.nativeText});
  final String targetText, nativeText;
  @override
  bool operator ==(Object other) =>
      other is ExamplePair &&
      targetText == other.targetText &&
      nativeText == other.nativeText;
  @override
  int get hashCode => Object.hash(targetText, nativeText);
}

/// Raw editing values; only normalized content crosses the storage boundary.
final class VocabularyContent {
  const VocabularyContent({
    List<ExamplePair>? examples,
    String? exampleTargetText,
    String? exampleNativeText,
    this.hintText,
    this.hintVisibility = HintVisibility.always,
  // Preserve the public examples argument while storing its backing list privately.
  // ignore: prefer_initializing_formals
  }) : _examples = examples,
       _legacyTarget = exampleTargetText,
       _legacyNative = exampleNativeText;
  static const maxExampleLength = 1000;
  static const maxHintLength = 2000;
  final List<ExamplePair>? _examples;
  final String? _legacyTarget, _legacyNative, hintText;
  final HintVisibility hintVisibility;
  List<ExamplePair> get examples => _examples != null
      ? List.unmodifiable(_examples)
      : _legacyTarget == null && _legacyNative == null
      ? const []
      : [
          ExamplePair(
            targetText: _legacyTarget ?? '',
            nativeText: _legacyNative ?? '',
          ),
        ];
  // Source compatibility for older callers; production presentation uses examples.
  String? get exampleTargetText => examples.firstOrNull?.targetText;
  String? get exampleNativeText => examples.firstOrNull?.nativeText;
  VocabularyContent normalized() {
    final pairs = <ExamplePair>[];
    for (final pair in examples) {
      final target = normalizeVocabularyText(pair.targetText),
          native = normalizeVocabularyText(pair.nativeText);
      if (target.isEmpty && native.isEmpty) continue;
      if (target.isEmpty || native.isEmpty) {
        throw VocabularyContentValidation.examplePairRequired;
      }
      if (target.runes.length > maxExampleLength ||
          native.runes.length > maxExampleLength) {
        throw VocabularyContentValidation.exampleTooLong;
      }
      pairs.add(ExamplePair(targetText: target, nativeText: native));
    }
    final hint = normalizeVocabularyText(hintText ?? '');
    if (hint.runes.length > maxHintLength) {
      throw VocabularyContentValidation.hintTooLong;
    }
    return VocabularyContent(
      examples: List.unmodifiable(pairs),
      hintText: hint.isEmpty ? null : hint,
      hintVisibility: hintVisibility,
    );
  }

  factory VocabularyContent.fromStored({
    List<ExamplePair>? examples,
    String? exampleTargetText,
    String? exampleNativeText,
    required String? hintText,
    required String hintVisibility,
  }) {
    if (!HintVisibility.values.any((v) => v.name == hintVisibility)) {
      throw const FormatException('Invalid stored Hint visibility');
    }
    final value = VocabularyContent(
      examples: examples,
      exampleTargetText: exampleTargetText,
      exampleNativeText: exampleNativeText,
      hintText: hintText,
      hintVisibility: HintVisibility.values.byName(hintVisibility),
    );
    try {
      if (value.normalized() != value) {
        throw const FormatException('Noncanonical stored vocabulary content');
      }
    } on VocabularyContentValidation {
      throw const FormatException('Invalid stored vocabulary content');
    }
    return value;
  }
  @override
  bool operator ==(Object other) =>
      other is VocabularyContent &&
      hintText == other.hintText &&
      hintVisibility == other.hintVisibility &&
      examples.length == other.examples.length &&
      Iterable<int>.generate(
        examples.length,
      ).every((i) => examples[i] == other.examples[i]);
  @override
  int get hashCode =>
      Object.hash(Object.hashAll(examples), hintText, hintVisibility);
}
