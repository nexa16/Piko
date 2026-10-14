import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/piko_theme.dart';

class EmptyCollections implements CollectionsRepository {
  const EmptyCollections();

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
  @override
  Stream<List<CollectionRecord>> watchAll() => Stream.value(const []);
  @override
  Stream<CollectionRecord?> watchById(String id) => const Stream.empty();
}

void main() {
  testWidgets(
    'UX-HOME-001 uses compact Piko identity then binding section heading and ghost New',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        PikoApp(
          home: CollectionsHome(
            repository: const EmptyCollections(),
            onOpenSettings: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final brand = tester.widget<Text>(
        find.byKey(const ValueKey('home-brand')),
      );
      final heading = tester.widget<Text>(
        find.byKey(const ValueKey('home-collections-heading')),
      );
      expect(brand.data, 'Piko');
      expect(
        brand.style!.fontSize,
        pikoDesign.dimension('components.homeHeader.brandSize'),
      );
      expect(
        brand.style!.fontWeight,
        pikoDesign.weight('components.homeHeader.brandWeight'),
      );
      expect(heading.data, 'My collections');
      expect(
        heading.style!.fontSize,
        pikoDesign.dimension('components.sectionHeading.size'),
      );
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey('home-collections-heading')),
            )
            .getSemanticsData()
            .headingLevel,
        1,
      );
      expect(
        tester
            .widget<PikoButton>(find.widgetWithText(PikoButton, 'New'))
            .variant,
        PikoButtonVariant.ghost,
      );
      expect(
        tester.getRect(find.widgetWithText(PikoButton, 'Settings')).right,
        closeTo(
          tester.getRect(find.widgetWithText(PikoButton, 'New')).right,
          0.01,
        ),
      );
      expect(
        tester.getTopLeft(find.text('My collections')).dy -
            tester.getBottomLeft(find.text('Piko')).dy,
        greaterThanOrEqualTo(
          pikoDesign.dimension('components.homeHeader.sectionGap') - 1,
        ),
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'UX-HOME-001 German 392px 200% header actions wrap text without clipping',
    (tester) async {
      tester.view.physicalSize = const Size(392, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        PikoApp(
          locale: const Locale('de'),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: CollectionsHome(
                repository: const EmptyCollections(),
                onOpenSettings: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final finder in [
        find.text('Piko'),
        find.text('Einstellungen'),
        find.text('Meine Sammlungen'),
        find.text('Neu'),
      ]) {
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(392));
      }
      expect(tester.takeException(), isNull);
    },
  );
}
