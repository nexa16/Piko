import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_language_badge.dart';
import 'package:piko/ui/piko_theme.dart';

class BadgeRepository implements CollectionsRepository {
  @override
  Future<void> delete(String id) => throw UnimplementedError();
  @override
  Future<CollectionRecord> rename({required String id, required String name}) =>
      throw UnimplementedError();
  var watches = 0;
  final records = [
    for (final language in VocabularyLanguage.values)
      CollectionRecord(
        id: language.code,
        name: 'Collection ${language.code}',
        targetLanguage: language,
        nativeLanguage: language == VocabularyLanguage.german
            ? VocabularyLanguage.english
            : VocabularyLanguage.german,
      ),
  ];
  @override
  Stream<List<CollectionRecord>> watchAll() {
    watches++;
    return Stream.value(records);
  }

  @override
  Stream<CollectionRecord?> watchById(String id) =>
      Stream.value(records.where((r) => r.id == id).firstOrNull);
  @override
  Future<CollectionRecord> create({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
  }) => throw UnimplementedError('Badge fixture does not create');
}

void main() {
  testWidgets(
    'all target codes stay uppercase Latin across interface locale changes',
    (tester) async {
      final repository = BadgeRepository();
      final locale = InterfaceLocaleController();
      addTearDown(locale.dispose);
      await tester.pumpWidget(
        PikoApp(
          localeController: locale,
          home: CollectionsHome(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      for (final language in VocabularyLanguage.values) {
        final card = find.byKey(ValueKey('collection-${language.code}'));
        final badge = tester.widget<PikoLanguageBadge>(
          find.descendant(of: card, matching: find.byType(PikoLanguageBadge)),
        );
        expect(badge.language, language);
        expect(
          find.descendant(
            of: card,
            matching: find.text(language.badge),
          ),
          findsOneWidget,
        );
      }
      locale.value = const Locale('de');
      await tester.pumpAndSettle();
      for (final code in ['KO', 'FR', 'EN', 'DE']) {
        expect(find.text(code), findsOneWidget);
      }
      expect(repository.watches, 1);
    },
  );

  testWidgets(
    'badge consumes effective geometry, weight, tracking and semantic colors',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: PikoLanguageBadge(VocabularyLanguage.korean)),
          ),
        ),
      );
      final minimum = pikoDesign.dimension('components.languageBadge.size');
      final size = tester.getSize(find.byType(PikoLanguageBadge));
      expect(size, Size.square(minimum));
      final text = tester.widget<Text>(find.text('KO'));
      final fontSize = pikoDesign.dimension(
        'components.languageBadge.fontSize',
      );
      expect(text.style!.fontSize, fontSize);
      expect(
        text.style!.fontWeight,
        pikoDesign.weight('components.languageBadge.weight'),
      );
      expect(
        text.style!.letterSpacing,
        fontSize *
            pikoDesign.dimension('components.languageBadge.letterSpacingEm'),
      );
      expect(text.style!.color, pikoDesign.color('primary'));
      final box = tester.widget<Container>(find.byType(Container));
      expect(box.constraints!.minWidth, minimum);
      expect(box.constraints!.minHeight, minimum);
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, pikoDesign.color('tint'));
      expect(
        decoration.borderRadius,
        BorderRadius.circular(
          pikoDesign.dimension('components.languageBadge.radius'),
        ),
      );
    },
  );

  testWidgets(
    'card announces full localized pair without repeating decorative code',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = BadgeRepository();
      await tester.pumpWidget(
        PikoApp(
          locale: const Locale('de'),
          home: CollectionsHome(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('collection-ko'));
      final data = tester.getSemantics(card).getSemanticsData();
      expect(data.label, contains('Collection ko'));
      expect(data.label, contains('Koreanisch · Deutsch'));
      expect(data.label, isNot(contains('KO')));
      expect(find.bySemanticsLabel('KO'), findsNothing);
      expect(
        find.text(const PikoCopy('de').text('action.review')),
        findsNothing,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    '392px doubled German text grows badges and keeps every glyph inside',
    (tester) async {
      tester.view.physicalSize = const Size(392, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repository = BadgeRepository();
      await tester.pumpWidget(
        PikoApp(
          locale: const Locale('de'),
          home: CollectionsHome(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      for (final language in VocabularyLanguage.values) {
        final card = find.byKey(ValueKey('collection-${language.code}'));
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        final badge = find.descendant(
          of: card,
          matching: find.byType(PikoLanguageBadge),
        );
        final badgeBox = tester.getRect(badge);
        final textBox = tester.getRect(
          find.descendant(
            of: badge,
            matching: find.text(language.badge),
          ),
        );
        expect(
          badgeBox.width >
                  pikoDesign.dimension('components.languageBadge.size') ||
              badgeBox.height >
                  pikoDesign.dimension('components.languageBadge.size'),
          isTrue,
        );
        expect(textBox.left, greaterThanOrEqualTo(badgeBox.left));
        expect(textBox.right, lessThanOrEqualTo(badgeBox.right));
        expect(textBox.top, greaterThanOrEqualTo(badgeBox.top));
        expect(textBox.bottom, lessThanOrEqualTo(badgeBox.bottom));
        expect(tester.getRect(card).right, lessThanOrEqualTo(392));
      }
      expect(tester.takeException(), isNull);
    },
  );
}
