import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/learning/learning_prompt_card.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'package:piko/ui/components/piko_interaction_anchor.dart';
import 'package:piko/ui/components/piko_page.dart';
import 'package:piko/ui/components/piko_field.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import '../features/entry_session_category_test.dart' show EntryCategoryFixture;
import 'entry_keyboard_layout_test.dart' show scrollActionIntoView;

import 'collection_inline_edit_test.dart' show LiveVocabulary, owner;

void main() {
  testWidgets('keyboard field focus replaces an older control anchor', (
    tester,
  ) async {
    final gap = ValueNotifier(100.0);
    final focus = FocusNode();
    final input = TextEditingController(text: 'retained');
    addTearDown(gap.dispose);
    addTearDown(focus.dispose);
    addTearDown(input.dispose);
    await tester.pumpWidget(
      PikoApp(
        home: Scaffold(
          body: PikoPage(
            child: ValueListenableBuilder<double>(
              valueListenable: gap,
              builder: (context, value, _) => Column(
                children: [
                  const SizedBox(height: 300),
                  PikoButton(label: 'Earlier action', onPressed: () {}),
                  SizedBox(height: value),
                  PikoTextField(
                    key: const ValueKey('focused-anchor-field'),
                    label: 'Word',
                    controller: input,
                    focusNode: focus,
                  ),
                  const SizedBox(height: 1800),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Earlier action'));
    focus.requestFocus();
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('focused-anchor-field'));
    final top = tester.getTopLeft(field).dy;
    input.selection = const TextSelection(baseOffset: 1, extentOffset: 4);
    gap.value += 140;
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(field).dy, closeTo(top, .1));
    expect(input.text, 'retained');
    expect(
      input.selection,
      const TextSelection(baseOffset: 1, extentOffset: 4),
    );
    expect(focus.hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'manual entry disclosures preserve header, raw text and selection',
    (tester) async {
      final f = EntryCategoryFixture();
      await tester.runAsync(f.initialize);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(f.close);
      });
      await tester.pumpWidget(
        PikoApp(
          home: EntrySessionScreen(
            collection: f.collection,
            session: f.session,
            categoriesRepository: f.categories,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final requiredField = find.descendant(
        of: find.byKey(const ValueKey('draft-target')),
        matching: find.byType(TextField),
      );
      await tester.enterText(requiredField, ' raw manual word ');
      final requiredController = tester
          .widget<TextField>(requiredField)
          .controller!;
      requiredController.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 5,
      );
      final disclosure = find.byKey(const ValueKey('content-examples-toggle'));
      await scrollActionIntoView(tester, disclosure);
      final top = tester.getTopLeft(disclosure).dy;
      await tester.tap(disclosure);
      for (var frame = 0; frame < 15; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getTopLeft(disclosure).dy, closeTo(top, .5));
      }
      expect(requiredController.text, ' raw manual word ');
      expect(
        requiredController.selection,
        const TextSelection(baseOffset: 2, extentOffset: 5),
      );
      expect(f.session.activeEntryId, isNull);
      expect(f.session.confirmedEntries, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dialog in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'shared ${dialog ? 'dialog' : 'page'} holds control throughout reflow at $scale',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 650);
          addTearDown(tester.view.reset);
          final height = ValueNotifier(700.0);
          final focus = FocusNode();
          addTearDown(height.dispose);
          addTearDown(focus.dispose);
          final body = ValueListenableBuilder<double>(
            valueListenable: height,
            builder: (context, value, _) => Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: value,
                ),
                PikoButton(
                  key: const ValueKey('anchor-action'),
                  label: 'Änderung / Change',
                  focusNode: focus,
                  onPressed: () => height.value += 180,
                ),
                const SizedBox(height: 1800),
              ],
            ),
          );
          await tester.pumpWidget(
            PikoApp(
              locale: const Locale('de'),
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: dialog
                        ? PikoDialog(
                            title: 'Optionen',
                            body: body,
                            actions: [
                              PikoDialogAction(
                                label: 'Apply',
                                onPressed: () {},
                              ),
                            ],
                          )
                        : PikoPage(child: body),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final scroll = tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position;
          scroll.jumpTo(500);
          await tester.pumpAndSettle();
          final action = find.byKey(const ValueKey('anchor-action'));
          final top = tester.getTopLeft(action).dy;
          await tester.tap(action);
          for (var i = 0; i < 12; i++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(
              tester.getTopLeft(action).dy,
              closeTo(top, .1),
              reason: 'painted frame $i',
            );
          }
          // A later repository/validation result belongs to the same interaction.
          height.value += 120;
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(action).dy, closeTo(top, .1));
          focus.requestFocus();
          await tester.pumpAndSettle();
          final keyboardTop = tester.getTopLeft(action).dy;
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(action).dy, closeTo(keyboardTop, .1));
          expect(focus.hasFocus, isTrue);
          // Explicit reveal/user navigation releases the earlier coordinate.
          scroll.jumpTo(scroll.pixels + 50);
          await tester.pumpAndSettle();
          final offset = scroll.pixels;
          height.value += 100;
          await tester.pumpAndSettle();
          expect(scroll.pixels, closeTo(offset, .1));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'short dialog stays content-sized without permanent anchor space',
    (tester) async {
      final expanded = ValueNotifier(false);
      addTearDown(expanded.dispose);
      await tester.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: expanded,
              builder: (context, value, _) => PikoDialog(
                title: 'Options',
                body: Column(
                  children: [
                    PikoButton(
                      label: 'Expand',
                      onPressed: () => expanded.value = !value,
                    ),
                    if (value) const SizedBox(height: 150),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final surface = find.byType(PikoAnchoredBoxScrollView);
      final small = tester.getSize(surface).height;
      await tester.tap(find.text('Expand'));
      await tester.pumpAndSettle();
      expect(tester.getSize(surface).height, closeTo(small + 150, .1));
      await tester.tap(find.text('Expand'));
      await tester.pumpAndSettle();
      expect(tester.getSize(surface).height, closeTo(small, .1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'learning hint and answer retain the card instead of its removed reveal control',
    (tester) async {
      final repository = LiveVocabulary()
        ..records = [
          VocabularyRecord(
            id: 'anchor-word',
            collectionId: owner.id,
            targetText: 'Café',
            nativeText: 'Kaffee',
            content: VocabularyContent(
              hintText: List.filled(15, 'A hot drink.').join(' '),
              hintVisibility: HintVisibility.hidden,
            ),
          ),
        ];
      addTearDown(repository.close);
      var grades = 0;
      await tester.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: PikoPage(
              child: Column(
                children: [
                  const SizedBox(height: 700),
                  LearningPromptCard(
                    presentation: 1,
                    entryId: 'anchor-word',
                    repository: repository,
                    collectionId: owner.id,
                    direction: LearningDirection.targetToNative,
                    canReveal: () => true,
                    onReveal: () {
                      grades++;
                      return true;
                    },
                  ),
                  const SizedBox(height: 1500),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('review-prompt'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(card).dy;
      await tester.tap(find.byKey(const ValueKey('learning-reveal-hint')));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(card).dy, closeTo(top, .1));
      expect(grades, 0);
      await tester.tap(find.byKey(const ValueKey('review-prompt-text')));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(card).dy, closeTo(top, .1));
      expect(grades, 1); // Reveal callback only; no repository learning write.
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
