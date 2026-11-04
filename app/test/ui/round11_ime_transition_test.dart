import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/vocabulary/collection_vocabulary.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'collection_inline_edit_test.dart' show LiveVocabulary, owner, one;

void main() {
  testWidgets(
    'German enlarged editor retains invalid draft through IME resize and safe close',
    (tester) async {
      final repository = LiveVocabulary();
      tester.view.physicalSize = const Size(392, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await repository.close();
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(
        PikoApp(
          locale: const Locale('de'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CollectionVocabulary(
                collection: owner,
                repository: repository,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('vocabulary-${one.id}')));
      await tester.pumpAndSettle();
      final field = find.byKey(ValueKey('inline-${one.id}-target'));
      final textField = find.descendant(
        of: field,
        matching: find.byType(TextField),
      );
      await tester.enterText(textField, '  ');
      final controller = tester.widget<TextField>(textField).controller!;
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 1,
      );
      for (final inset in [100.0, 300.0, 150.0, 0.0, 300.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(controller.text, '  ');
        expect(
          controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: 1),
        );
      }
      final close = find.byWidgetPredicate(
        (widget) =>
            widget is PikoIconButton && widget.semanticLabel == 'Schließen',
      );
      await tester.ensureVisible(close);
      await tester.pumpAndSettle();
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(textField, findsOneWidget);
      expect(controller.text, '  ');
      expect(repository.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
