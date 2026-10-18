import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/settings/settings_route.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_card.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_field.dart';
import 'package:piko/ui/components/piko_page.dart';
import 'settings_test.dart' as settings;

void main() {
  testWidgets(
    'normal Settings title/card and field inset match binding box geometry',
    (tester) async {
      final h = settings.Harness();
      try {
        await h.mount(tester);
        await h.open(tester);
        await h.flush(tester);
        final title = tester.getRect(
          find.text(const PikoCopy('en').text('nav.settings')),
        );
        final languageCard = find.ancestor(
          of: settings.dropdown,
          matching: find.byType(PikoCard),
        );
        final card = tester.getRect(languageCard);
        final field = tester.getRect(
          find.descendant(of: languageCard, matching: find.byType(PikoField)),
        );
        // Binding h1 bottom margin collapses with section margin to 23px;
        // card border/padding 1+19 and field's 17px outer margins give 37px.
        expect(
          [
            card.top - title.bottom,
            field.top - card.top,
            card.bottom - field.bottom,
          ],
          [23, 37, 37],
        );
      } finally {
        await h.cleanup(tester);
      }
    },
  );
  for (final language in ['en', 'de']) {
    for (final width in [320.0, 392.0]) {
      testWidgets(
        '$language ${width.toInt()}px 200% Settings is singular, reachable and keyboard usable',
        (tester) async {
          final h = settings.Harness();
          final semantics = tester.ensureSemantics();
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          try {
            await tester.runAsync(
              () => h.repository.real.write('locale', language),
            );
            await h.mount(tester);
            final home = tester.state(find.byType(CollectionsHome));
            final controller = await h.open(tester);
            await h.flush(tester);
            final copy = PikoCopy(language);
            expect(find.byType(PikoHeading), findsOneWidget);
            expect(find.byType(PikoCard), findsNWidgets(4));
            expect(settings.dropdown, findsOneWidget);
            final direction = find.byType(DropdownButton<PreferredDirection>);
            expect(direction, findsOneWidget);
            expect(find.byType(PikoButton), findsNWidgets(2));
            expect(find.byKey(const ValueKey('settings-full-export')), findsOneWidget);
            expect(find.byKey(const ValueKey('ai-connection')), findsNothing);
            final title = find.text(copy.text('nav.settings'));
            expect(title, findsOneWidget);
            expect(
              tester.getSemantics(title).getSemanticsData().headingLevel,
              1,
            );
            expect(find.text(copy.text('settings.language')), findsOneWidget);
            expect(
              find.text(copy.text('settings.preferredDirection')),
              findsOneWidget,
            );
            for (final excluded in [
              'settings.learning',
              'settings.direction',
              'settings.developer',
              'settings.ai',
              'settings.answerMode',
            ]) {
              expect(find.text(copy.text(excluded)), findsNothing);
            }
            expect(find.byType(TextField), findsNothing);
            expect(find.byType(Checkbox), findsOneWidget);
            expect(find.byType(Switch), findsNothing);
            final allowed = {
              copy.text('nav.settings'),
              copy.text('settings.language'),
              copy.text('settings.questionExamples'),
              copy.text('settings.preferredDirection'),
              copy.text('settings.directionTargetToNative'),
              copy.text('settings.directionNativeToTarget'),
              copy.text('settings.directionBoth'),
              copy.text('common.back'),
              copy.text('fullExport.action'),
              copy.text('fullExport.description'),
              'English',
              'Deutsch',
            };
            for (final text in tester.widgetList<Text>(find.byType(Text))) {
              expect(allowed, contains(text.data));
            }
            final back = settings.button('common.back', language);
            final native = find.byType(DropdownButton<Locale>);
            for (final target in [back, native, direction]) {
              await tester.ensureVisible(target);
              await tester.pumpAndSettle();
              final rect = tester.getRect(target);
              expect(rect.height, greaterThanOrEqualTo(48));
              expect(rect.width, greaterThanOrEqualTo(48));
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(width));
              expect(rect.top, greaterThanOrEqualTo(0));
              expect(rect.bottom, lessThanOrEqualTo(900));
            }
            await tester.ensureVisible(back);
            await tester.pumpAndSettle();
            expect(
              // The passive geometry wrapper owns no accessibility node.
              tester.getSemantics(
                find.descendant(of: back, matching: find.byType(TextButton)),
              ),
              matchesSemantics(
                label: copy.text('common.back'),
                isButton: true,
                hasTapAction: true,
                hasFocusAction: true,
                isFocusable: true,
                hasEnabledState: true,
                isEnabled: true,
              ),
            );
            // Traverse to the real native dropdown, rather than invoking its callback.
            var reached = false;
            for (var pass = 0; pass < 5; pass++) {
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.pumpAndSettle();
              reached =
                  FocusManager.instance.primaryFocus?.context
                      ?.findAncestorWidgetOfExactType<
                        DropdownButton<Locale>
                      >() !=
                  null;
              if (reached) break;
            }
            expect(reached, isTrue);
            await tester.sendKeyEvent(LogicalKeyboardKey.space);
            await tester.pumpAndSettle();
            for (final option in ['English', 'Deutsch']) {
              final item = find
                  .ancestor(
                    of: find.text(option).last,
                    matching: find.byType(DropdownMenuItem<Locale>),
                  )
                  .first;
              final rect = tester.getRect(item);
              expect(rect.height, greaterThanOrEqualTo(48));
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(width));
              expect(find.bySemanticsLabel(RegExp(option)), findsWidgets);
            }
            final next = language == 'en' ? 'de' : 'en';
            await tester.sendKeyEvent(
              language == 'en'
                  ? LogicalKeyboardKey.arrowDown
                  : LogicalKeyboardKey.arrowUp,
            );
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            await h.drain(tester, controller);
            expect(h.selected!.value.languageCode, next);
            expect(
              find.text(PikoCopy(next).text('settings.language')),
              findsOneWidget,
            );
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.pump();
            var backFocused = false;
            for (var pass = 0; pass < 5; pass++) {
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.pumpAndSettle();
              backFocused =
                  tester
                      .getSemantics(
                        find.descendant(
                          of: settings.button('common.back', next),
                          matching: find.byType(TextButton),
                        ),
                      )
                      .getSemanticsData()
                      .flagsCollection
                      .isFocused ==
                  Tristate.isTrue;
              if (backFocused) break;
            }
            expect(backFocused, isTrue);
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(find.byType(SettingsRoute), findsNothing);
            expect(tester.state(find.byType(CollectionsHome)), same(home));
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
            await h.cleanup(tester);
          }
        },
      );
    }
  }
}
