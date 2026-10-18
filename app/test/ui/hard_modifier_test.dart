import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/learning/hard_modifier.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/main.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/shared/copy_scope.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_checkbox.dart';
import 'package:piko/ui/components/piko_page.dart';
import 'package:piko/ui/piko_theme.dart';
import '../data/regular_reviews_test.dart' show Fixture, instant;

class GatedReviewWriter implements RegularReviewWriter {
  GatedReviewWriter(this.real);
  final RegularReviewWriter real;
  final gate = Completer<void>();
  @override
  Future<RegularReviewReceipt> review({
    required ReviewKind kind,
    required LearningItemRecord expectedPrior,
    required LearningRating rating,
    required DateTime reviewedAt,
  }) async {
    await gate.future;
    return real.review(
      kind: kind,
      expectedPrior: expectedPrior,
      rating: rating,
      reviewedAt: reviewedAt,
    );
  }
}

class Harness {
  Harness(this.f, {this.writer});
  final Fixture f;
  final RegularReviewWriter? writer;
  late final coordinator = RegularGradingCoordinator(
    repository: writer ?? f.learning,
  );
  late GradingCardHandle handle;
  final focus = FocusNode(), locale = ValueNotifier('en');
  final failures = <Object>[];
  Future<void> grade(AnswerGrade grade) async {
    try {
      await coordinator.submit(handle, grade, reviewedAt: instant);
    } catch (error) {
      failures.add(error);
    }
  }

  Future<void> mount(
    WidgetTester tester, {
    double width = 392,
    double scale = 1,
    double? modifierWidth,
  }) async {
    handle = coordinator.activate(
      await tester.runAsync(f.current) ?? (throw StateError('Missing item')),
    )!;
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      await flush(tester, f);
      await tester.runAsync(coordinator.awaitPending);
      await tester.pumpWidget(const SizedBox());
      coordinator.dispose();
      focus.dispose();
      locale.dispose();
      await tester.runAsync(f.db.close);
    });
    await tester.pumpWidget(
      ValueListenableBuilder<String>(
        valueListenable: locale,
        builder: (_, language, _) => PikoApp(
          locale: Locale(language),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: PikoPage(
                  child: Column(
                    children: [
                      SizedBox(
                        width: modifierWidth,
                        child: HardModifier(
                          coordinator: coordinator,
                          handle: handle,
                          focusNode: focus,
                        ),
                      ),
                      PikoButton(
                        label: PikoCopyScope.of(context).text('action.correct'),
                        onPressed: () => grade(AnswerGrade.correct),
                      ),
                      PikoButton(
                        label: PikoCopyScope.of(
                          context,
                        ).text('action.incorrect'),
                        onPressed: () => grade(AnswerGrade.incorrect),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Finder action(String label) => find.byWidgetPredicate(
  (widget) => widget is PikoButton && widget.label == label,
);
Future<void> flush(WidgetTester tester, Fixture f) async {
  await tester.runAsync(() => f.db.customSelect('SELECT 1').get());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'German200% Hard remains reachable in170px and shared checkbox wraps long text in the same bound',
    (tester) async {
      final f = Fixture();
      await tester.runAsync(f.initialize);
      final h = Harness(f)..locale.value = 'de';
      await h.mount(tester, scale: 2, modifierWidth: 170);
      expect(tester.getSize(find.byType(PikoCheckbox)).width, 170);
      expect(
        tester.getSize(find.byType(PikoCheckbox)).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.text('Schwer'));
      await tester.pumpAndSettle();
      expect(h.coordinator.hard, isTrue);
      await tester.pumpWidget(
        PikoApp(
          locale: const Locale('de'),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const PikoPage(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 170,
                    child: PikoCheckbox(
                      label:
                          'Schwer – ein längerer optionaler Kontrolltext zum Prüfen des Umbruchs',
                      value: false,
                      onChanged: null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(PikoCheckbox)).width, 170);
      expect(tester.getSize(find.byType(PikoCheckbox)).height, greaterThan(44));
      expect(tester.takeException(), isNull);
    },
  );
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language default-off optional label/checkbox/keyboard toggles one semantic target without grading, locale/focus stable',
      (tester) async {
        final f = Fixture();
        await tester.runAsync(f.initialize);
        final h = Harness(f)..locale.value = language;
        await h.mount(tester, scale: 2);
        final label = language == 'en' ? 'Hard' : 'Schwer';
        final semantics = tester.ensureSemantics();
        try {
          expect(
            tester.getSemantics(find.bySemanticsLabel(label)),
            matchesSemantics(
              label: label,
              hasCheckedState: true,
              hasEnabledState: true,
              isEnabled: true,
              isFocusable: true,
              hasTapAction: true,
            ),
          );
          expect(find.bySemanticsLabel(label), findsOneWidget);
          expect(h.coordinator.hard, isFalse);
          final initialRect = tester.getRect(find.byType(PikoCheckbox));
          expect(tester.getSize(find.byType(PikoCheckbox)).width, 356);
          expect(
            tester.getSize(find.byType(PikoCheckbox)).height,
            greaterThanOrEqualTo(44),
          );
          final visual = Rect.fromPoints(
            tester.getTopLeft(find.byType(Checkbox)),
            tester.getBottomRight(find.byType(Checkbox)),
          );
          expect(visual.width, 24);
          expect(visual.height, 24);
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(h.coordinator.hard, isTrue);
          await tester.tapAt(tester.getCenter(find.byType(Checkbox)));
          await tester.pumpAndSettle();
          expect(h.coordinator.hard, isFalse);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          expect(h.focus.hasFocus, isTrue);
          expect(tester.getRect(find.byType(PikoCheckbox)), initialRect);
          final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
          expect(
            checkbox.fillColor!.resolve({WidgetState.selected}),
            pikoDesign.color('success'),
          );
          expect(checkbox.checkColor, pikoDesign.color('onPrimary'));
          final side = (checkbox.side! as WidgetStateBorderSide).resolve({
            WidgetState.selected,
          });
          expect(
            side!.width * 24 / Checkbox.width,
            pikoDesign.dimension('states.borderWidth'),
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pumpAndSettle();
          expect(h.coordinator.hard, isTrue);
          final decorated = tester
              .widgetList<DecoratedBox>(
                find.descendant(
                  of: find.byType(PikoCheckbox),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .first;
          expect(
            (decorated.decoration as BoxDecoration).border,
            Border.all(
              color: pikoDesign.color('primary'),
              width: pikoDesign.dimension('states.focusWidth'),
            ),
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(h.coordinator.hard, isFalse);
          h.locale.value = language == 'en' ? 'de' : 'en';
          await tester.pumpAndSettle();
          expect(h.focus.hasFocus, isTrue);
          expect(h.coordinator.hard, isFalse);
          expect(
            find.text(language == 'en' ? 'Schwer' : 'Hard'),
            findsOneWidget,
          );
          final item = (await tester.runAsync(f.current))!;
          expect(item.reviewRevision, 0);
          expect(
            (await tester.runAsync(() => f.learning.reviewsForItem(item.id)))!,
            isEmpty,
          );
        } finally {
          semantics.dispose();
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (select, toggleOff, grade, rating) in [
    (false, false, AnswerGrade.correct, LearningRating.good),
    (true, false, AnswerGrade.correct, LearningRating.hard),
    (true, true, AnswerGrade.correct, LearningRating.good),
    (true, false, AnswerGrade.incorrect, LearningRating.again),
  ]) {
    testWidgets(
      'actual Hard control selected=$select toggledOff=$toggleOff + ${grade.name} persists $rating',
      (tester) async {
        final f = Fixture();
        await tester.runAsync(f.initialize);
        final h = Harness(f);
        await h.mount(tester);
        if (select) {
          await tester.tap(find.text('Hard'));
          await tester.pumpAndSettle();
        }
        if (toggleOff) {
          await tester.tap(find.text('Hard'));
          await tester.pumpAndSettle();
        }
        await tester.tap(
          action(grade == AnswerGrade.correct ? 'Correct' : 'Incorrect'),
        );
        await flush(tester, f);
        final item = (await tester.runAsync(f.current))!;
        expect(
          (await tester.runAsync(
            () => f.learning.reviewsForItem(item.id),
          ))!.single.rating,
          rating,
        );
        expect(item.reviewRevision, 1);
        expect(h.failures, isEmpty);
        expect(
          tester.widget<PikoCheckbox>(find.byType(PikoCheckbox)).onChanged,
          isNull,
        );
        expect(h.coordinator.hard, select && !toggleOff);
      },
    );
  }

  testWidgets(
    'pending disables control and preserves selection; stale presentation remains disabled',
    (tester) async {
      final f = Fixture();
      await tester.runAsync(f.initialize);
      final writer = GatedReviewWriter(f.learning);
      final h = Harness(f, writer: writer);
      await h.mount(tester);
      addTearDown(() async {
        if (!writer.gate.isCompleted) writer.gate.complete();
        await tester.pump();
        await tester.runAsync(h.coordinator.awaitPending);
      });
      await tester.tap(find.text('Hard'));
      await tester.pumpAndSettle();
      final stale = tester
          .widget<PikoCheckbox>(find.byType(PikoCheckbox))
          .onChanged!;
      unawaited(h.grade(AnswerGrade.correct));
      expect(h.coordinator.isSubmitting, isTrue);
      await tester.pump();
      expect(h.coordinator.isSubmitting, isTrue);
      expect(
        tester.widget<PikoCheckbox>(find.byType(PikoCheckbox)).onChanged,
        isNull,
      );
      stale(false);
      await tester.pump();
      expect(h.coordinator.hard, isTrue);
      final held = (await tester.runAsync(f.current))!;
      expect(held.reviewRevision, 0);
      expect(
        (await tester.runAsync(() => f.learning.reviewsForItem(held.id)))!,
        isEmpty,
      );
      writer.gate.complete();
      await tester.pump();
      await tester.runAsync(h.coordinator.awaitPending);
      await tester.pumpAndSettle();
      expect(h.coordinator.accepted!.event.rating, LearningRating.hard);
      final next = (await tester.runAsync(() => f.current(f.other)))!;
      h.coordinator.activate(next);
      await tester.pumpAndSettle();
      expect(
        tester.widget<PikoCheckbox>(find.byType(PikoCheckbox)).onChanged,
        isNull,
      );
      stale(true);
      expect(h.coordinator.hard, isFalse);
    },
  );

  testWidgets(
    'failed grade retains checked modifier with enabled retry and no hidden event',
    (tester) async {
      final f = Fixture();
      await tester.runAsync(f.initialize);
      final h = Harness(f);
      await h.mount(tester);
      await tester.tap(find.text('Hard'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => f.db.customStatement(
          "CREATE TRIGGER fail_modifier AFTER INSERT ON regular_reviews BEGIN SELECT RAISE(FAIL,'blocked'); END",
        ),
      );
      await tester.tap(action('Correct'));
      await flush(tester, f);
      expect(h.coordinator.hard, isTrue);
      expect(h.failures, hasLength(1));
      expect(
        tester.widget<PikoCheckbox>(find.byType(PikoCheckbox)).onChanged,
        isNotNull,
      );
      final item = (await tester.runAsync(f.current))!;
      expect(item.reviewRevision, 0);
      expect(
        (await tester.runAsync(() => f.learning.reviewsForItem(item.id)))!,
        isEmpty,
      );
      await tester.runAsync(
        () => f.db.customStatement('DROP TRIGGER fail_modifier'),
      );
      await tester.tap(action('Correct'));
      await flush(tester, f);
      expect(
        (await tester.runAsync(
          () => f.learning.reviewsForItem(item.id),
        ))!.single.rating,
        LearningRating.hard,
      );
    },
  );

  testWidgets(
    'shared checkbox wraps a long enlarged label at narrow width without clipping',
    (tester) async {
      tester.view.physicalSize = const Size(392, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const PikoPage(
                child: PikoCheckbox(
                  label:
                      'A much longer optional checkbox label that wraps naturally',
                  value: false,
                  onChanged: null,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(PikoCheckbox)).height, greaterThan(44));
      expect(tester.getRect(find.byType(PikoCheckbox)).right, 374);
      expect(tester.takeException(), isNull);
    },
  );
}
