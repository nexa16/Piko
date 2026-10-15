import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/vocabulary_normalization.dart';

void main() {
  test('NFC equates composed and decomposed Latin accents and Hangul', () {
    expect(normalizeVocabularyText('Cafe\u0301'), 'Café');
    expect(
      vocabularyComparisonKey('CAFÉ'),
      vocabularyComparisonKey('Cafe\u0301'),
    );
    expect(normalizeVocabularyText('\u1109\u1161\u1100\u116a'), '사과');
    expect(
      vocabularyComparisonKey('\u1109\u1161\u1100\u116a'),
      vocabularyComparisonKey('사과'),
    );
  });

  test(
    'display case remains intact while ordinary capitals compare equally',
    () {
      expect(normalizeVocabularyText('  APPLE  '), 'APPLE');
      expect(vocabularyComparisonKey('  APPLE  '), 'apple');
      expect(
        vocabularyComparisonKey('ÉCOLE'),
        vocabularyComparisonKey('école'),
      );
    },
  );

  test('capital sharp S lowercases to sharp S while ss stays distinct', () {
    expect(vocabularyComparisonKey('MAẞE'), vocabularyComparisonKey('Maße'));
    expect(
      vocabularyComparisonKey('Maße'),
      isNot(vocabularyComparisonKey('Masse')),
    );
    expect(vocabularyComparisonKey('ẞ'), 'ß');
    expect(vocabularyComparisonKey('SS'), 'ss');
  });

  test(
    'Unicode surrounding whitespace trims without changing internal text',
    () {
      const text = '\u00a0\u2003\t\n\ufeff École  du\u00a0soir! \u3000\u202f';
      expect(normalizeVocabularyText(text), 'École  du\u00a0soir!');
      expect(vocabularyComparisonKey(text), 'école  du\u00a0soir!');
    },
  );

  test(
    'internal spacing, punctuation and compatibility forms stay distinct',
    () {
      expect(
        vocabularyComparisonKey('a  b'),
        isNot(vocabularyComparisonKey('a b')),
      );
      expect(
        vocabularyComparisonKey('a\u00a0b'),
        isNot(vocabularyComparisonKey('a b')),
      );
      expect(
        vocabularyComparisonKey('word!'),
        isNot(vocabularyComparisonKey('word')),
      );
      expect(
        vocabularyComparisonKey('café'),
        isNot(vocabularyComparisonKey('cafe')),
      );
      expect(vocabularyComparisonKey('①'), isNot(vocabularyComparisonKey('1')));
    },
  );

  test('normalization keeps empty normalized values empty', () {
    for (final text in ['', ' \t\n', '\u00a0\u2003\ufeff\u3000']) {
      expect(normalizeVocabularyText(text), isEmpty);
      expect(vocabularyComparisonKey(text), isEmpty);
    }
  });

  test('display and comparison transformations are idempotent', () {
    for (final text in [
      ' Cafe\u0301 ',
      'MAẞE',
      'a  b!',
      '\u1109\u1161\u1100\u116a',
      'ÉCOLE',
      'İ',
      '①',
      '',
    ]) {
      final display = normalizeVocabularyText(text);
      final key = vocabularyComparisonKey(text);
      expect(normalizeVocabularyText(display), display);
      expect(vocabularyComparisonKey(key), key);
      expect(vocabularyComparisonKey(display), key);
    }
  });
}
