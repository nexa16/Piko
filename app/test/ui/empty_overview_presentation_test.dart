import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_card.dart';
import 'package:piko/ui/piko_theme.dart';

class EmptyOverviewRepository implements CollectionsRepository {
  @override
  Future<CollectionRecord> rename({required String id, required String name}) =>
      throw UnimplementedError();
  var watches = 0;
  @override
  Stream<List<CollectionRecord>> watchAll() {
    watches++;
    return Stream.value([]);
  }

  @override
  Stream<CollectionRecord?> watchById(String id) => Stream.value(null);
  @override
  Future<CollectionRecord> create({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
  }) => throw UnimplementedError('Presentation fixture never submits');
}

Future<void> overview(
  WidgetTester tester,
  String language, {
  InterfaceLocaleController? controller,
  EmptyOverviewRepository? repository,
}) async {
  await tester.pumpWidget(
    PikoApp(
      locale: Locale(language),
      localeController: controller,
      home: CollectionsHome(
        repository: repository ?? EmptyOverviewRepository(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language invitation matches canonical card and semantic actions',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final copy = PikoCopy(language);
        await overview(tester, language);
        expect(find.byType(PikoCard), findsOneWidget);
        final descriptionFinder = find.text(copy.text('home.emptyDescription'));
        final description = tester.widget<Text>(descriptionFinder);
        expect(
          description.style!.fontSize,
          pikoDesign.dimension('typography.body'),
        );
        expect(
          description.style!.height,
          pikoDesign.dimension('components.emptyState.descriptionLineHeight'),
        );
        expect(description.style!.color, pikoDesign.color('muted'));
        final actionFinder = find.widgetWithText(
          PikoButton,
          copy.text('action.firstCollection'),
        );
        expect(
          tester.widget<PikoButton>(actionFinder).variant,
          PikoButtonVariant.primary,
        );
        final cardBox = tester.getRect(find.byType(PikoCard));
        final descriptionBox = tester.getRect(descriptionFinder);
        expect(
          descriptionBox.left - cardBox.left,
          pikoDesign.dimension('components.cards.padding') +
              pikoDesign.dimension('states.borderWidth'),
        );
        expect(
          tester.getRect(actionFinder).top - descriptionBox.bottom,
          pikoDesign.dimension('spacing.5'),
        );
        for (final key in ['action.firstCollection', 'action.new']) {
          final button = find.widgetWithText(TextButton, copy.text(key));
          final node = tester.getSemantics(button);
          expect(node.getSemanticsData().label, contains(copy.text(key)));
          expect(
            node.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );
          node.owner!.performAction(node.id, SemanticsAction.tap);
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsOneWidget);
          await tester.tap(find.byTooltip(copy.text('common.close')));
          await tester.pumpAndSettle();
        }
        semantics.dispose();
      },
    );

    testWidgets(
      '$language keyboard reaches and activates New and first-collection action',
      (tester) async {
        final copy = PikoCopy(language);
        await overview(tester, language);
        final reached = <String>{};
        for (var i = 0; i < 10 && reached.length < 2; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          final button = FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<PikoButton>();
          if (button == null || reached.contains(button.label)) continue;
          expect([
            copy.text('action.new'),
            copy.text('action.firstCollection'),
          ], contains(button.label));
          reached.add(button.label);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsOneWidget);
          await tester.tap(find.byTooltip(copy.text('common.close')));
          await tester.pumpAndSettle();
        }
        expect(reached, {
          copy.text('action.new'),
          copy.text('action.firstCollection'),
        });
      },
    );
  }

  testWidgets(
    '392px doubled German invitation wraps and remains scroll reachable',
    (tester) async {
      tester.view.physicalSize = const Size(392, 500);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await overview(tester, 'de');
      final copy = const PikoCopy('de');
      final descriptionFinder = find.text(copy.text('home.emptyDescription'));
      final description = tester.widget<Text>(descriptionFinder);
      expect(description.maxLines, isNull);
      expect(description.overflow, isNull);
      expect(
        tester.getSize(descriptionFinder).height,
        greaterThan(pikoDesign.dimension('typography.body') * 4),
      );
      final button = find.widgetWithText(
        PikoButton,
        copy.text('action.firstCollection'),
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      final box = tester.getRect(button);
      expect(box.left, greaterThanOrEqualTo(0));
      expect(box.right, lessThanOrEqualTo(392));
      expect(box.bottom, lessThanOrEqualTo(500));
      expect(tester.takeException(), isNull);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'live locale updates empty invitation without restarting repository watch',
    (tester) async {
      final locale = InterfaceLocaleController();
      addTearDown(locale.dispose);
      final repository = EmptyOverviewRepository();
      await overview(tester, 'en', controller: locale, repository: repository);
      expect(
        find.text(const PikoCopy('en').text('home.emptyDescription')),
        findsOneWidget,
      );
      locale.value = const Locale('de');
      await tester.pumpAndSettle();
      expect(
        find.text(const PikoCopy('de').text('home.emptyDescription')),
        findsOneWidget,
      );
      expect(
        find.text(const PikoCopy('de').text('action.firstCollection')),
        findsOneWidget,
      );
      expect(find.text('Neu'), findsOneWidget);
      expect(repository.watches, 1);
    },
  );
}
