import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/core/learning_day.dart';
import 'package:piko/data/statistics_repository.dart';
import 'package:piko/features/statistics/statistics_binding.dart';
import 'package:piko/features/statistics/statistics_page.dart';
import 'package:piko/features/statistics/statistics_widgets.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/copy_scope.dart';
import 'package:piko/features/statistics/statistics_action.dart';
import 'package:piko/ui/piko_theme.dart';
import '../support/mutable_clock.dart';
import '../data/statistics_test.dart' show OffsetCalendar;
import '../features/statistics_binding_test.dart'
    show ControlledStatistics, sample;

final now = DateTime.utc(2026, 10, 18, 12);

Future<void> mount(
  WidgetTester tester,
  Widget child, {
  String locale = 'en',
  double scale = 1,
}) async {
  await tester.pumpWidget(
    PikoCopyScope(
      copy: PikoCopy(locale),
      child: MaterialApp(
        locale: Locale(locale),
        supportedLocales: const [Locale('en'), Locale('de')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: PikoTheme.build(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pump();
}

Future<void> settle(
  WidgetTester tester,
  ControlledStatistics repo,
  StatisticsSnapshot value,
) async {
  for (final request in repo.requests) {
    if (!request.$2.isCompleted) request.$2.complete(value);
  }
  await tester.pumpAndSettle();
}

Future<void> activate(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in ['en', 'de']) {
    testWidgets(
      '$locale statistics at 320dp / 200%: calendar, partial/unavailable/zero/future, month jump, mode retention',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = ControlledStatistics();
        final binding = StatisticsBinding(
          repository: repo,
          clock: MutablePikoClock(now),
          calendar: OffsetCalendar(),
        );
        final value = StatisticsSnapshot(
          asOf: now,
          startedAt: DateTime.utc(2026, 10, 15, 12),
          startDate: LearningDate(2026, 10, 15),
          today: LearningDate(2026, 10, 18),
          activity: {
            LearningDate(2026, 10, 15): const ActivityCounts(regular: 3),
            LearningDate(2026, 10, 17): const ActivityCounts(regular: 4),
            LearningDate(2026, 10, 18): const ActivityCounts(
              regular: 5,
              speed: 9,
            ),
          },
        );
        await mount(
          tester,
          StatisticsPage(binding: binding),
          locale: locale,
          scale: 2,
        );
        expect(find.byKey(const ValueKey('statistics-today')), findsNothing);
        await settle(tester, repo, value);
        expect(find.byKey(const ValueKey('statistics-star')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await activate(tester, 'statistics-calendar-toggle');
        expect(
          find.byKey(const ValueKey('statistics-calendar')),
          findsOneWidget,
        );
        final semantics = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        final partial = tester
            .getSemantics(
              find.byKey(const ValueKey('statistics-day-2026-10-15')),
            )
            .label;
        expect(partial, contains(PikoCopy(locale).text('statistics.partial')));
        expect(
          tester
              .getSemantics(
                find.byKey(const ValueKey('statistics-day-2026-10-14')),
              )
              .label,
          contains(PikoCopy(locale).text('statistics.unavailable')),
        );
        expect(
          tester
              .getSemantics(
                find.byKey(const ValueKey('statistics-day-2026-10-16')),
              )
              .label,
          contains(': 0.'),
        );
        expect(
          tester
              .getSemantics(
                find.byKey(const ValueKey('statistics-day-2026-10-19')),
              )
              .label,
          contains(PikoCopy(locale).text('statistics.future')),
        );
        semantics.dispose();
        expect(
          tester
              .widget<StatisticsAction>(
                find.byKey(const ValueKey('statistics-next')),
              )
              .onPressed,
          isNull,
        );
        await activate(tester, 'statistics-previous');
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('statistics-month')))
              .data,
          contains('2026'),
        );
        await activate(tester, 'statistics-month-jump');
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('statistics-jump-year')),
            matching: find.byType(TextField),
          ),
          '2025',
        );
        await tester.tap(find.text(PikoCopy(locale).text('r2.apply')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('statistics-month')))
              .data,
          contains('2025'),
        );
        await activate(tester, 'statistics-speed-mode');
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('statistics-speed-today')),
              )
              .data,
          '9',
        );
        expect(find.byKey(const ValueKey('statistics-star')), findsNothing);
        expect(find.byKey(const ValueKey('statistics-calendar')), findsNothing);
        await activate(tester, 'statistics-regular-mode');
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('statistics-month')))
              .data,
          contains('2025'),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        binding.dispose();
        await repo.events.close();
      },
    );
  }

  testWidgets(
    'loading/error do not fabricate zero; stale refresh retains month/mode/focus and disables data navigation',
    (tester) async {
      final repo = ControlledStatistics();
      final binding = StatisticsBinding(
        repository: repo,
        clock: MutablePikoClock(now),
        calendar: OffsetCalendar(),
      );
      await mount(tester, StatisticsPage(binding: binding));
      for (final request in repo.requests) {
        request.$2.completeError(StateError('synthetic'));
      }
      await tester.pumpAndSettle();
      expect(
        find.text(const PikoCopy('en').text('statistics.error')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('statistics-today')), findsNothing);
      await tester.tap(find.text(const PikoCopy('en').text('action.retry')));
      await settle(tester, repo, sample(now));
      await activate(tester, 'statistics-calendar-toggle');
      await activate(tester, 'statistics-previous');
      final month = tester
          .widget<Text>(find.byKey(const ValueKey('statistics-month')))
          .data;
      await activate(tester, 'statistics-help');
      final focus = Focus.of(
        tester.element(
          find.text(const PikoCopy('en').text('statistics.rules')),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      final before = FocusManager.instance.primaryFocus;
      expect(before, focus);
      repo.events.add(null);
      await tester.pump();
      expect(
        find.text(const PikoCopy('en').text('statistics.refreshing')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<StatisticsAction>(
              find.byKey(const ValueKey('statistics-previous')),
            )
            .onPressed,
        isNull,
      );
      repo.requests.last.$2.completeError(StateError('refresh failed'));
      await tester.pumpAndSettle();
      expect(
        find.text(const PikoCopy('en').text('statistics.stale')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('statistics-month')))
            .data,
        month,
      );
      expect(FocusManager.instance.primaryFocus, before);
      binding.refresh();
      await settle(tester, repo, sample(now, count: 8));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('statistics-month')))
            .data,
        month,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('statistics-today')))
            .data,
        '8',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      binding.dispose();
      await repo.events.close();
    },
  );

  testWidgets(
    'Activity preserves genuine empty Home, survives collection deletion, and reminds without a mascot',
    (tester) async {
      final repo = ControlledStatistics();
      final binding = StatisticsBinding(
        repository: repo,
        clock: MutablePikoClock(now),
        calendar: OffsetCalendar(),
      );
      var opened = 0;
      await mount(
        tester,
        Scaffold(
          body: StatisticsActivity(
            binding: binding,
            hasCollections: false,
            onOpen: () => opened++,
          ),
        ),
      );
      await settle(tester, repo, sample(now, count: 0, yesterday: 0));
      expect(find.text('Activity'), findsNothing);
      binding.refresh();
      await settle(tester, repo, sample(now, count: 0, yesterday: 1));
      expect(find.text('1 day'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.byKey(const ValueKey('statistics-star')), findsNothing);
      expect(find.byKey(const ValueKey('statistics-reminder')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('statistics-open')));
      expect(opened, 1);
      binding.refresh();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('statistics-open')));
      expect(opened, 1);
      await settle(tester, repo, sample(now, count: 1));
      expect(find.byKey(const ValueKey('statistics-star')), findsOneWidget);
      expect(find.byKey(const ValueKey('statistics-reminder')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      binding.dispose();
      await repo.events.close();
    },
  );

  testWidgets(
    'calendar navigation focus survives an explicitly disabled refresh',
    (tester) async {
      final repo = ControlledStatistics();
      final binding = StatisticsBinding(
        repository: repo,
        clock: MutablePikoClock(now),
        calendar: OffsetCalendar(),
      );
      await mount(tester, StatisticsPage(binding: binding));
      await settle(tester, repo, sample(now));
      await activate(tester, 'statistics-calendar-toggle');
      final previous = find.text(
        const PikoCopy('en').text('statistics.previous'),
      );
      await tester.ensureVisible(previous);
      final focus = Focus.of(tester.element(previous));
      focus.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, focus);
      final month = tester
          .widget<Text>(find.byKey(const ValueKey('statistics-month')))
          .data;
      binding.refresh();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, focus);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('statistics-month')))
            .data,
        month,
      );
      await settle(tester, repo, sample(now));
      expect(FocusManager.instance.primaryFocus, focus);
      await tester.pumpWidget(const SizedBox());
      binding.dispose();
      await repo.events.close();
    },
  );
}
