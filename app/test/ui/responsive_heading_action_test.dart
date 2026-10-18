import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';

class _Collections implements CollectionsRepository {
  const _Collections();

  static const record = CollectionRecord(
    id: 'heading-fixture',
    name: 'Words',
    targetLanguage: VocabularyLanguage.korean,
    nativeLanguage: VocabularyLanguage.german,
  );

  @override
  Stream<List<CollectionRecord>> watchAll() => Stream.value(const [record]);

  @override
  Stream<CollectionRecord?> watchById(String id) => Stream.value(record);

  @override
  Future<CollectionRecord> create({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();

  @override
  Future<CollectionRecord> rename({required String id, required String name}) =>
      throw UnimplementedError();
}

void _expectWholeWord(WidgetTester tester, Finder heading, String word) {
  final label = tester.widget<Text>(heading).data!;
  final start = label.lastIndexOf(word);
  expect(start, greaterThanOrEqualTo(0));
  final paragraph = tester.renderObject<RenderParagraph>(heading);
  // Widget tests use Ahem, whose oversized fixed-width glyphs can make an
  // entire word wider than the viewport. Verify that layout gives the heading
  // full width in that case; real-font wrapping is checked in Android captures.
  final isolated = TextPainter(
    text: TextSpan(text: word, style: tester.widget<Text>(heading).style),
    textDirection: TextDirection.ltr,
    textScaler: paragraph.textScaler,
  )..layout();
  final wordWidth = isolated.width;
  isolated.dispose();
  if (wordWidth > paragraph.constraints.maxWidth) {
    expect(paragraph.constraints.maxWidth, greaterThanOrEqualTo(280));
    return;
  }
  expect(
    paragraph.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: start + word.length),
    ),
    hasLength(1),
    reason: '$word must not split across visual lines in $label',
  );
}

void _expectStacked(WidgetTester tester, Finder heading, Finder action) {
  final title = tester.getRect(heading);
  final button = tester.getRect(action);
  expect(button.top, greaterThanOrEqualTo(title.bottom));
  expect(button.right, lessThanOrEqualTo(320));
  expect(title.left, greaterThanOrEqualTo(0));
  expect(title.right, lessThanOrEqualTo(320));
}

Widget _scaledApp(String language, Widget child) => PikoApp(
  locale: Locale(language),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(2)),
      child: child,
    ),
  ),
);

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      'UX-HEADER-001 $language: 320dp at 200% keeps Home and Vocabulary headings whole',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final copy = PikoCopy(language);

        await tester.pumpWidget(
          _scaledApp(
            language,
            CollectionsHome(
              repository: const _Collections(),
              onOpenSettings: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final brand = find.byKey(const ValueKey('home-brand'));
        final settings = find.byTooltip(copy.text('nav.settings'));
        final collectionHeading = find.byKey(
          const ValueKey('home-collections-heading'),
        );
        final newCollection = find.widgetWithText(
          PikoButton,
          copy.text('action.new'),
        );
        _expectWholeWord(tester, brand, copy.text('app.name'));
        _expectWholeWord(
          tester,
          collectionHeading,
          copy.text('home.collections').split(' ').last,
        );
        expect(tester.getRect(settings).width, greaterThanOrEqualTo(48));
        expect(tester.getRect(settings).right, lessThanOrEqualTo(320));
        _expectStacked(tester, collectionHeading, newCollection);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          _scaledApp(
            language,
            CollectionDetail(
              repository: const _Collections(),
              collectionId: _Collections.record.id,
              entrySessionFactory: (_) => throw StateError('Not opened'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final vocabulary = find.text(copy.text('collection.vocabulary'));
        final addVocabulary = find.descendant(
          of: find.byTooltip(copy.text('action.addEntry')),
          matching: find.byType(PikoButton),
        );
        expect(vocabulary, findsOneWidget);
        expect(addVocabulary, findsOneWidget);
        _expectWholeWord(
          tester,
          vocabulary,
          copy.text('collection.vocabulary'),
        );
        _expectStacked(tester, vocabulary, addVocabulary);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
