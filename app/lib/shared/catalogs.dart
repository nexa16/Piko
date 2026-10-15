import 'package:flutter/material.dart';

import 'generated_catalogs.dart';

/// Accesses generated canonical data without independent app defaults.
final class PikoDesign {
  const PikoDesign();

  Object? value(String path) {
    Object? current = designCatalog;
    for (final segment in path.split('.')) {
      if (current is! Map<String, Object?> || !current.containsKey(segment)) {
        throw ArgumentError.value(path, 'path', 'Unknown design token');
      }
      current = current[segment];
    }
    return current;
  }

  double dimension(String path) => (value(path) as num).toDouble();
  String text(String path) => value(path) as String;
  Color color(String name) => Color(
    0xff000000 | int.parse(text('colors.$name').substring(1), radix: 16),
  );
  FontWeight weight(String path) {
    final weight = dimension(path);
    return FontWeight.values[(weight / 100).round().clamp(1, 9) - 1];
  }
}

final class PikoCopy {
  const PikoCopy(this.locale);

  final String locale;
  static final _placeholder = RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)\}');

  String text(String key, [Map<String, Object> arguments = const {}]) {
    final entries = copyCatalog['entries']! as Map<String, Object?>;
    final entry = entries[key] as Map<String, Object?>?;
    if (entry == null) {
      throw ArgumentError.value(key, 'key', 'Unknown copy key');
    }
    final template =
        (entry[locale] ?? entry[copyCatalog['defaultLocale']])! as String;
    final required = _placeholder
        .allMatches(template)
        .map((match) => match[1]!)
        .toSet();
    if (required.length != arguments.length ||
        !required.containsAll(arguments.keys)) {
      throw ArgumentError(
        'Arguments must match placeholders for $key: $required',
      );
    }
    return template.replaceAllMapped(
      _placeholder,
      (match) => arguments[match[1]]!.toString(),
    );
  }
}
