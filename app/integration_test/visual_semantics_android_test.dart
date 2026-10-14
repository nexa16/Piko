import 'dart:io';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/learning/review_launch.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/features/learning/review_summary_dialog.dart';
import 'package:piko/features/settings/settings_route.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_field.dart';

import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;

const _fixturePrefix = 'piko-visual-semantics-verification-';
const _screenshots = <String>[
  'piko-visual-home-de-200.png',
  'piko-visual-detail-de-200.png',
  'piko-visual-direction-de-200.png',
  'piko-visual-review-hidden-de-200.png',
  'piko-visual-review-revealed-de-200.png',
  'piko-visual-summary-de-200.png',
  'piko-visual-settings-de-200.png',
];

Finder _button(String label) => find.widgetWithText(PikoButton, label);

Finder _closeButton(String label) => find.byWidgetPredicate(
  (widget) => widget is PikoIconButton && widget.semanticLabel == label,
);

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  Directory support,
  String name,
) async {
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  final bytes = await binding.takeScreenshot(name.replaceAll('.png', ''));
  expect(bytes.take(8).toList(), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
  final file = File('${support.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  debugPrint('PIKO_VISUAL_ARTIFACT:${file.path}');
}

void _expectSemanticLabel(WidgetTester tester, Finder finder, String label) {
  expect(finder, findsOneWidget);
  expect(tester.getSemantics(finder).label, label);
}

void _expectDropdownSemantics<T>(WidgetTester tester, String label) {
  final dropdown = find.byType(PikoDropdown<T>);
  final labeledFinder = find.descendant(
    of: dropdown,
    matching: find.bySemanticsLabel(label),
  );
  final actionFinder = find.descendant(
    of: dropdown,
    matching: find.byType(DropdownButton<T>),
  );
  expect(labeledFinder, findsOneWidget);
  expect(actionFinder, findsOneWidget);
  final labeled = tester.getSemantics(labeledFinder);
  final action = tester.getSemantics(actionFinder);
  final diagnostic =
      'Labeled dropdown semantics subtree:\n${labeled.toStringDeep()}'
      '\nActionable dropdown semantics subtree:\n${action.toStringDeep()}';
  expect(labeled.label, label, reason: diagnostic);
  // Flutter merges the field's semantic label into the actionable control;
  // the visible caption remains a sibling rather than a semantic ancestor.
  expect(action.label.split('\n'), contains(label), reason: diagnostic);
  final data = action.getSemanticsData();
  expect(data.flagsCollection.isButton, isTrue, reason: diagnostic);
  expect(data.flagsCollection.isExpanded, Tristate.isFalse, reason: diagnostic);
  expect(
    data.flagsCollection.isEnabled,
    isNot(Tristate.isFalse),
    reason: diagnostic,
  );
  expect(data.hasAction(SemanticsAction.tap), isTrue, reason: diagnostic);
}

String _answerFor(String prompt) => switch (prompt) {
  'Bonjour' => 'Guten Tag',
  'Chat' => 'Katze',
  _ => throw StateError('Unexpected visual-review prompt: $prompt'),
};

/// Synthetic Android visual and semantics acceptance. The PNGs intentionally
/// remain in the application-support root for host retrieval after a
/// `--no-uninstall` run; the owned database directory is still removed.
/// Text scale and reduced motion are injected only into this test process.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android German 200% key screens keep real visuals and semantic targets',
    (tester) async {
      expect(binding.registerTestTextInput, isFalse);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final support = await getApplicationSupportDirectory();
      for (final name in _screenshots) {
        if (await File('${support.path}/$name').exists()) {
          throw StateError(
            'Refusing to overwrite an existing visual artifact: $name',
          );
        }
      }
      final directory = await support.createTemp(_fixturePrefix);
      final file = File('${directory.path}/test.sqlite');
      final clock = review.ReviewFixtureClock(
        DateTime.utc(2026, 10, 14, 9, 10, 11, 123, 456),
      );
      final db = review.ReviewFixtureDatabase(file, clock);
      var mounted = false;
      final semantics = tester.ensureSemantics();
      try {
        final collection = await SqliteCollectionsRepository(db).create(
          name: 'Android Sichtprüfung',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        );
        final vocabulary = SqliteVocabularyRepository(db);
        await vocabulary.create(
          collectionId: collection.id,
          targetText: 'Bonjour',
          nativeText: 'Guten Tag',
        );
        await vocabulary.create(
          collectionId: collection.id,
          targetText: 'Chat',
          nativeText: 'Katze',
        );
        await SqliteSettingsRepository(db).write('locale', 'de');

        mounted = true;
        await tester.pumpWidget(
          PikoApp(home: PikoRuntime(databaseFactory: () => db)),
        );
        final copy = await hydratedRuntimeCopy(tester);
        expect(copy.locale, 'de');
        await review.waitUntil(
          tester,
          () => find
              .byKey(const ValueKey('collection-review-quick'))
              .evaluate()
              .isNotEmpty,
          description: 'Home review count',
        );
        final home = find.byType(CollectionsHome);
        expect(
          MediaQuery.textScalerOf(tester.element(home)).scale(10),
          closeTo(20, .01),
        );
        expect(MediaQuery.disableAnimationsOf(tester.element(home)), isTrue);
        _expectSemanticLabel(
          tester,
          _button(copy.text('nav.settings')),
          copy.text('nav.settings'),
        );
        expect(
          find.bySemanticsLabel(RegExp('Android Sichtprüfung öffnen')),
          findsOneWidget,
        );
        await binding.convertFlutterSurfaceToImage();
        await tester.pump();
        await _capture(binding, tester, support, _screenshots[0]);

        await review.tapVisible(
          tester,
          find.byKey(ValueKey('collection-${collection.id}')),
        );
        await review.waitUntil(
          tester,
          () => find
              .byKey(const ValueKey('collection-review-card'))
              .evaluate()
              .isNotEmpty,
          description: 'Collection review card',
        );
        expect(find.byType(CollectionDetail), findsOneWidget);
        expect(find.text('Bonjour'), findsOneWidget);
        expect(find.text('Guten Tag'), findsOneWidget);
        expect(find.text('Chat'), findsOneWidget);
        expect(find.text('Katze'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            RegExp('${RegExp.escape(copy.text('action.reviewNow'))}\$'),
          ),
          findsOneWidget,
        );
        await _capture(binding, tester, support, _screenshots[1]);

        await review.tapVisible(
          tester,
          find.byKey(const ValueKey('collection-review-card')),
        );
        await review.waitUntil(
          tester,
          () => find.byType(ReviewDirectionDialog).evaluate().isNotEmpty,
          description: 'Direction dialog',
        );
        expect(find.text(copy.text('learn.setup')), findsOneWidget);
        _expectDropdownSemantics<LearningDirection>(
          tester,
          copy.text('settings.direction'),
        );
        _expectSemanticLabel(
          tester,
          _closeButton(copy.text('common.close')),
          copy.text('common.close'),
        );
        await _capture(binding, tester, support, _screenshots[2]);

        await review.tapVisible(tester, _button(copy.text('learn.start')));
        await review.waitUntil(
          tester,
          () => find.byType(ReviewSessionRoute).evaluate().isNotEmpty,
          description: 'Hidden review card',
        );
        final promptFinder = find.byKey(const ValueKey('review-prompt-text'));
        final prompt = tester.widget<Text>(promptFinder).data!;
        final answer = _answerFor(prompt);
        expect(find.text(answer), findsNothing);
        final hiddenSemantics = tester.getSemantics(review.revealTarget);
        expect(hiddenSemantics.label, prompt);
        expect(hiddenSemantics.hint, copy.text('learn.revealCue'));
        await _capture(binding, tester, support, _screenshots[3]);

        await review.reveal(tester);
        expect(find.text(answer), findsOneWidget);
        expect(
          tester.getSemantics(review.revealTarget).label,
          '$prompt\n$answer',
        );
        _expectSemanticLabel(
          tester,
          find.byKey(const ValueKey('review-grade-incorrect')),
          copy.text('action.incorrect'),
        );
        _expectSemanticLabel(
          tester,
          find.byKey(const ValueKey('review-grade-correct')),
          copy.text('action.correct'),
        );
        await _capture(binding, tester, support, _screenshots[4]);

        await review.tapVisible(
          tester,
          find.byKey(const ValueKey('review-grade-correct')),
        );
        await review.waitUntil(tester, () {
          final prompts = promptFinder.evaluate();
          return review.revealTarget.evaluate().isNotEmpty &&
              prompts.isNotEmpty &&
              tester.widget<Text>(promptFinder).data != prompt;
        }, description: 'Second hidden review card');
        await review.reveal(tester);
        await review.tapVisible(
          tester,
          find.byKey(const ValueKey('review-grade-correct')),
        );
        await review.waitUntil(
          tester,
          () => find.byType(ReviewSummaryDialog).evaluate().isNotEmpty,
          description: 'Review summary',
        );
        _expectSemanticLabel(
          tester,
          find.byKey(const ValueKey('summary-completed')),
          '2 ${copy.text('summary.completed')}',
        );
        _expectSemanticLabel(
          tester,
          find.byKey(const ValueKey('summary-first-try')),
          '2 ${copy.text('summary.firstTryCorrect')}',
        );
        await _capture(binding, tester, support, _screenshots[5]);

        await review.tapVisible(
          tester,
          _closeButton(copy.text('common.close')),
        );
        await review.waitUntil(
          tester,
          () =>
              find.byType(CollectionDetail).evaluate().isNotEmpty &&
              find.byType(ReviewSessionRoute).evaluate().isEmpty,
          description: 'Return to Collection detail',
        );
        await review.tapVisible(tester, _button(copy.text('common.back')));
        await review.waitUntil(
          tester,
          () => find.byType(CollectionsHome).evaluate().isNotEmpty,
          description: 'Return to Home',
        );
        await review.tapVisible(tester, _button(copy.text('nav.settings')));
        expect(find.byType(SettingsRoute), findsOneWidget);
        _expectDropdownSemantics<Locale>(
          tester,
          copy.text('settings.language'),
        );
        expect(
          tester
              .widget<PikoDropdown<Locale>>(find.byType(PikoDropdown<Locale>))
              .value,
          const Locale('de'),
        );
        await _capture(binding, tester, support, _screenshots[6]);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        await db.closed.future.timeout(const Duration(seconds: 10));
        mounted = false;
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox());
        if (mounted) {
          await db.closed.future.timeout(const Duration(seconds: 10));
        } else {
          await db.close();
        }
        if (directory.parent.absolute.path != support.absolute.path ||
            !directory.uri.pathSegments
                .where((part) => part.isNotEmpty)
                .last
                .startsWith(_fixturePrefix)) {
          throw StateError('Refusing cleanup outside owned visual fixture');
        }
        await directory.delete(recursive: true);
        // The named PNG artifacts are host-owned after this point.
      }
    },
  );
}
