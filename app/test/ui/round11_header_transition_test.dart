import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_collapsing_header.dart';

void main() {
  for (final reducedMotion in [false, true]) {
    testWidgets(
      'header transforms continuously with one interactive semantic owner; reduced=$reducedMotion',
      (tester) async {
        final controller = ScrollController();
        final compactChanges = <bool>[];
        final semantics = tester.ensureSemantics();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        });
        await tester.pumpWidget(
          PikoApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reducedMotion),
                child: Scaffold(
                  body: CustomScrollView(
                    controller: controller,
                    slivers: [
                      PikoCollapsingHeader(
                        onCompactChanged: compactChanges.add,
                        expanded: SizedBox(
                          key: const ValueKey('expanded-header'),
                          height: 240,
                          child: Semantics(
                            label: 'Expanded action',
                            button: true,
                            child: const ExcludeSemantics(
                              child: Text('Expanded'),
                            ),
                          ),
                        ),
                        compact: SizedBox(
                          height: 80,
                          child: Semantics(
                            label: 'Compact action',
                            button: true,
                            child: const ExcludeSemantics(
                              child: Text('Compact'),
                            ),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 2000)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final expanded = find.byKey(
          const ValueKey('expanded-header'),
          skipOffstage: false,
        );
        final initial = tester.getRect(expanded);
        controller.jumpTo(40);
        await tester.pumpAndSettle();
        final mid = tester.getRect(expanded);
        expect(
          mid.height,
          reducedMotion ? initial.height : lessThan(initial.height),
        );
        expect(find.bySemanticsLabel('Expanded action'), findsOneWidget);
        expect(find.bySemanticsLabel('Compact action'), findsNothing);
        controller.jumpTo(160);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Compact action'), findsOneWidget);
        expect(find.bySemanticsLabel('Expanded action'), findsNothing);
        expect(compactChanges.last, isTrue);
        controller.jumpTo(0);
        await tester.pumpAndSettle();
        expect(tester.getRect(expanded), initial);
        expect(compactChanges.last, isFalse);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
