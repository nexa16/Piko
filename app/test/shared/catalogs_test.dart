import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/generated_catalogs.dart';

void main() {
  test(
    'copy uses canonical locale/default and substitutes arguments literally',
    () {
      expect(const PikoCopy('de').text('app.name'), 'Piko');
      expect(
        const PikoCopy('unknown').text('app.name'),
        const PikoCopy('en').text('app.name'),
      );
      expect(
        const PikoCopy('en').text('dialog.category', {'name': r'$name {test}'}),
        r'$name {test} Category',
      );
      expect(
        () => const PikoCopy('en').text('dialog.category'),
        throwsArgumentError,
      );
      expect(() => const PikoCopy('en').text('missing'), throwsArgumentError);
      expect(
        () => const PikoCopy('en').text('app.name', {'extra': 1}),
        throwsArgumentError,
      );
    },
  );

  test('every catalog entry is available in both supported locales', () {
    final entries = copyCatalog['entries']! as Map<String, Object?>;
    for (final key in entries.keys) {
      final entry = entries[key]! as Map<String, Object?>;
      final parameters = {
        for (final match in RegExp(
          r'\{([A-Za-z][A-Za-z0-9_]*)\}',
        ).allMatches(entry['en']! as String))
          match[1]!: 'value',
      };
      for (final locale in ['en', 'de']) {
        expect(PikoCopy(locale).text(key, parameters), isNotEmpty);
      }
    }
  });

  test('design adapter maps canonical numeric/color/weight values', () {
    const design = PikoDesign();
    expect(design.dimension('components.buttons.radius'), 24);
    expect(design.color('primary'), const Color(0xff2956b8));
    expect(design.weight('components.buttons.weight'), FontWeight.w700);
    expect(design.text('typography.family'), design.value('typography.family'));
    expect(() => design.value('missing.token'), throwsArgumentError);
  });
}
