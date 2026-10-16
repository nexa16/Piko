import 'package:flutter_test/flutter_test.dart';
import 'package:piko/shared/catalogs.dart';

void main() {
  test('JSON preview counts use number-neutral labels in both languages', () {
    for (final count in [0, 1, 2]) {
      final arguments = {
        'added': count,
        'updated': count,
        'unchanged': count,
        'errors': count,
      };
      expect(
        const PikoCopy('en').text('r2.jsonSummary', arguments),
        'New: $count · Updated: $count · Unchanged: $count · Errors: $count',
      );
      expect(
        const PikoCopy('de').text('r2.jsonSummary', arguments),
        'Neu: $count · Aktualisiert: $count · Unverändert: $count · Fehler: $count',
      );
    }
  });
}
