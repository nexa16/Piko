import 'package:unorm_dart/unorm_dart.dart' as unorm;
import 'package:uuid/uuid.dart';
import '../shared/generated_catalogs.dart';
import '../shared/generated_languages.dart';

/// Immutable Collection metadata. Catalog IDs and custom IDs never overlap.
final class VocabularyLanguage {
  const VocabularyLanguage._(this.code, this.copyKey, {this.customName});
  static const korean = VocabularyLanguage._('ko', 'language.korean');
  static const french = VocabularyLanguage._('fr', 'language.french');
  static const english = VocabularyLanguage._('en', 'language.english');
  static const german = VocabularyLanguage._('de', 'language.german');
  final String code, copyKey;
  final String? customName;
  bool get isCustom => customName != null;
  String get badge => isCustom
      ? String.fromCharCodes(
          languageNameKey(customName!).runes.take(2),
        ).toUpperCase()
      : code.split('-').first.toUpperCase();
  String get directionLabel => isCustom ? customName! : code.toUpperCase();
  static final List<VocabularyLanguage> values = List.unmodifiable([
    for (final item in languageCatalog.cast<Map<String, Object?>>())
      VocabularyLanguage._(item['id']! as String, item['copyKey']! as String),
  ]);

  String label(String locale) {
    if (customName != null) return customName!;
    final entry =
        (copyCatalog['entries']! as Map<String, Object?>)[copyKey]!
            as Map<String, Object?>;
    return (entry[locale] ?? entry['en'])! as String;
  }

  static VocabularyLanguage stored(String id, String? name) {
    if (name != null) {
      if (!id.startsWith('custom:') || languageNameKey(name).isEmpty) {
        throw const FormatException('Invalid custom language');
      }
      return VocabularyLanguage._(id, '', customName: name);
    }
    return values.singleWhere((value) => value.code == id);
  }

  /// Only initial selection resolves a name to the current interface catalog.
  static VocabularyLanguage fromName(String name, String locale) {
    final key = languageNameKey(name);
    if (key.isEmpty) throw const FormatException('Language name required');
    final matches = values
        .where((value) => languageNameKey(value.label(locale)) == key)
        .toList();
    if (matches.length > 1) {
      throw const FormatException('Select an explicit catalog language');
    }
    return matches.singleOrNull ??
        VocabularyLanguage._(
          'custom:${const Uuid().v4()}',
          '',
          customName: name,
        );
  }

  Map<String, Object?> toJson() => isCustom
      ? {'kind': 'custom', 'id': code, 'name': customName}
      : {'kind': 'catalog', 'id': code};

  static VocabularyLanguage fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['id'] is! String) {
      throw const FormatException('Explicit language identity required');
    }
    final id = value['id'] as String;
    if (value['kind'] == 'catalog' && !value.containsKey('name')) {
      return values.firstWhere(
        (language) => language.code == id,
        orElse: () => throw const FormatException('Unknown catalog language'),
      );
    }
    if (value['kind'] == 'custom' &&
        value['name'] is String &&
        RegExp(
          r'^custom:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(id)) {
      return stored(id, value['name'] as String);
    }
    throw const FormatException('Invalid language identity');
  }

  bool matches(VocabularyLanguage other) => isCustom && other.isCustom
      ? languageNameKey(customName!) == languageNameKey(other.customName!)
      : !isCustom && !other.isCustom && code == other.code;

  @override
  bool operator ==(Object other) =>
      other is VocabularyLanguage &&
      code == other.code &&
      customName == other.customName;
  @override
  int get hashCode => Object.hash(code, customName);
}

/// Deterministic name matching; no transliteration, translation or fuzzy aliases.
String languageNameKey(String text) => unorm
    .nfc(text.toLowerCase())
    .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
