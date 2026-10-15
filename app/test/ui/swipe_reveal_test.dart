import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_swipe_reveal.dart';

void main() {
  Future<void> mount(
    WidgetTester t,
    VoidCallback delete, {
    bool enabled = true,
    String label = 'Delete vocabulary',
    double scale = 1,
  }) async {
    await t.pumpWidget(
      PikoApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: Center(
              child: SizedBox(
                width: 280,
                child: PikoSwipeReveal(
                  enabled: enabled,
                  label: label,
                  onDelete: delete,
                  child: const SizedBox(
                    height: 140,
                    width: 280,
                    child: Text('Vocabulary'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'touch reveals only; explicit delete, right close, Escape and hidden semantics',
    (t) async {
      var calls = 0;
      await mount(t, () => calls++);
      final semantics = t.ensureSemantics();
      expect(find.text('Delete vocabulary'), findsNothing);
      await t.drag(find.byType(PikoSwipeReveal), const Offset(-100, 0));
      await t.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Delete vocabulary'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(calls, 1);
      await t.drag(find.byType(PikoSwipeReveal), const Offset(-100, 0));
      await t.pumpAndSettle();
      expect(find.text('Delete vocabulary'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(find.text('Delete vocabulary'), findsNothing);
      await t.drag(find.byType(PikoSwipeReveal), const Offset(-100, 0));
      await t.pumpAndSettle();
      await t.drag(find.byType(PikoSwipeReveal), const Offset(100, 0));
      await t.pumpAndSettle();
      expect(find.text('Delete vocabulary'), findsNothing);
      semantics.dispose();
    },
  );
  testWidgets('vertical, diagonal and disabled swipes cannot expose deletion', (
    t,
  ) async {
    await mount(t, () => fail('gesture must not delete'));
    for (final offset in [const Offset(0, -100), const Offset(-100, -100)]) {
      await t.drag(find.byType(PikoSwipeReveal), offset);
      await t.pumpAndSettle();
      expect(find.text('Delete vocabulary'), findsNothing);
    }
    await mount(t, () => fail('disabled'), enabled: false);
    await t.drag(find.byType(PikoSwipeReveal), const Offset(-100, 0));
    await t.pumpAndSettle();
    expect(find.text('Delete vocabulary'), findsNothing);
  });
  testWidgets(
    'German 200% measured action fits narrow card with reduced motion',
    (t) async {
      await mount(t, () {}, label: 'Vokabel löschen', scale: 2);
      await t.drag(find.byType(PikoSwipeReveal), const Offset(-100, 0));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final action = t.getRect(find.byType(TextButton));
      final card = t.getRect(find.byType(PikoSwipeReveal));
      expect(action.left, greaterThanOrEqualTo(card.left));
      expect(action.right, lessThanOrEqualTo(card.right));
      expect(action.height, greaterThanOrEqualTo(44));
      expect(
        t.widget<AnimatedContainer>(find.byType(AnimatedContainer)).duration,
        Duration.zero,
      );
    },
  );
  testWidgets(
    'vertical scroll remains native and disabled editor selection is unchanged',
    (t) async {
      final scroll = ScrollController();
      final text = TextEditingController(text: '학교 Schule');
      final focus = FocusNode();
      await t.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    PikoSwipeReveal(
                      label: 'Delete vocabulary',
                      onDelete: () {},
                      child: const SizedBox(height: 200, child: Text('Saved')),
                    ),
                    PikoSwipeReveal(
                      enabled: false,
                      label: 'Delete vocabulary',
                      onDelete: () {},
                      child: TextField(controller: text, focusNode: focus),
                    ),
                    const SizedBox(height: 600),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await t.drag(find.text('Saved'), const Offset(-70, -120));
      await t.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(find.text('Delete vocabulary'), findsNothing);
      focus.requestFocus();
      text.selection = const TextSelection(baseOffset: 1, extentOffset: 3);
      await t.pump();
      expect(
        text.selection,
        const TextSelection(baseOffset: 1, extentOffset: 3),
      );
      expect(focus.hasFocus, isTrue);
      expect(find.text('Delete vocabulary'), findsNothing);
      await t.pumpWidget(const SizedBox());
      scroll.dispose();
      text.dispose();
      focus.dispose();
    },
  );
}
