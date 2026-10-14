import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/learning/review_progress.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_page.dart';

import 'review_launch_test.dart' as launch;
import 'review_prompt_test.dart' as prompt;

void main() {
  for (final configuration in [
    (language: 'en', name: 'My deliberately long Collection name', scale: 1.0),
    (language: 'de', name: 'Meine außergewöhnlich lange Sammlung', scale: 2.0),
  ]) {
    launch.testWidgets(
      '${configuration.language} review uses the Collection name as its sole page title',
      (tester) async {
        final f = launch.fixture();
        await tester.runAsync(f.initialize);
        f.owner = (await tester.runAsync(
          () => f.collections.rename(id: f.owner.id, name: configuration.name),
        ))!;
        final h = launch.Harness(f)
          ..locale.value = Locale(configuration.language);
        await h.mount(tester, scale: configuration.scale);
        await prompt.start(tester, h, language: configuration.language);

        expect(find.byType(ReviewSessionRoute), findsOneWidget);
        expect(find.byType(PikoHeading), findsOneWidget);
        expect(find.text(configuration.name), findsOneWidget);
        expect(
          find.text(PikoCopy(configuration.language).text('learn.longTitle')),
          findsNothing,
        );
        expect(find.byType(ReviewProgress), findsOneWidget);
        expect(
          find.byKey(const ValueKey('review-fixed-direction')),
          findsOneWidget,
        );

        final semantics = tester.ensureSemantics();
        try {
          expect(
            tester
                .getSemantics(find.text(configuration.name))
                .getSemanticsData()
                .headingLevel,
            1,
          );
        } finally {
          semantics.dispose();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
