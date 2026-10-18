import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/core/clock.dart';
import 'package:piko/core/learning_day.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/data/statistics_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_statistics_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/statistics/statistics_binding.dart';
import 'package:piko/features/statistics/statistics_page.dart';
import 'package:piko/main.dart';
import 'package:piko/platform/device_clock_changes.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/features/statistics/statistics_action.dart';
import 'support/round2_catalogue_fixture.dart';

class _Clock implements PikoClock {
  _Clock(this.value);
  DateTime value;
  @override
  DateTime now() => value;
}

class _UtcCalendar implements LearningDayCalendar {
  @override
  DateTime localDateTime(DateTime utc) => utc;
  @override
  DateTime localFourUtc(int year, int month, int day) =>
      DateTime.utc(year, month, day, 4);
}

class _DelayedStatistics implements StatisticsRepository {
  _DelayedStatistics(this.real);
  final StatisticsRepository real;
  Completer<void>? gate;
  bool fail = false;
  @override
  Stream<void> get changes => real.changes;
  @override
  Future<StatisticsSnapshot> snapshot({required DateTime at}) async {
    await gate?.future;
    if (fail) throw StateError('Synthetic statistics read failure');
    return real.snapshot(at: at);
  }
}

void main() {
  final integration = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'statistics migration, native storage, actual pages and system clock invalidation',
    (tester) async {
      final config = CatalogueConfiguration();
      final support = await getApplicationSupportDirectory();
      final directory = Directory('${support.path}/statistics-${config.runId}');
      if (await directory.exists()) throw StateError('Evidence already exists');
      await directory.create();
      final input = File(
        '${support.path}/statistics-input-${config.runId}.sqlite',
      );
      if (!await input.exists()) {
        throw StateError('Synthetic schema16 input is required');
      }
      final file = await input.copy('${directory.path}/fixture.sqlite');
      final raw = sqlite.sqlite3.open(file.path);
      expect(raw.userVersion, 16);
      final oldTables = raw
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((r) => r['name'] as String)
          .toList();
      final old = {
        for (final table in oldTables)
          table: raw
              .select('SELECT * FROM $table ORDER BY rowid')
              .map(Map<String, Object?>.from)
              .toList(),
      };
      expect((old['regular_reviews'] as List), isNotEmpty);
      raw.close();
      final clock = _Clock(DateTime.utc(2026, 9, 1, 12));
      var db = PikoDatabase(
        NativeDatabase(file),
        clock: clock,
        learningDayCalendar: _UtcCalendar(),
      );
      StatisticsBinding? binding;
      StreamSubscription<void>? nativeClock;
      final records = <Object?>[];
      bool passed = false, converted = false;
      Future<void> capture(String name) async {
        await settleCatalogueCapture(tester, name);
        if (!converted) {
          await integration.convertFlutterSurfaceToImage();
          await tester.pump();
          converted = true;
        }
        final png = await integration
            .takeScreenshot(name)
            .timeout(const Duration(seconds: 20));
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(png, flush: true);
      }

      try {
        var stats = SqliteStatisticsRepository(db);
        final first = await stats.snapshot(at: clock.now());
        expect(first.hasRecordedActivity, isFalse);
        for (final table in oldTables) {
          final rows =
              (await db
                      .customSelect('SELECT * FROM $table ORDER BY rowid')
                      .get())
                  .map((r) => r.data)
                  .toList();
          expect(rows, old[table], reason: 'Schema16 $table is preserved');
        }
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        records.add({
          'stage': 'native-schema16-upgrade',
          'oldTablesExact': oldTables,
          'noHistoricalCredit': true,
        });
        final collections = SqliteCollectionsRepository(db);
        final owner = await collections.create(
          name: 'French',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        );
        final vocabulary = SqliteVocabularyRepository(db);
        final entry = await vocabulary.create(
          collectionId: owner.id,
          targetText: 'bonjour',
          nativeText: 'hallo',
        );
        final learning = SqliteLearningRepository(db);
        // Actual committed regular answers under an injected calendar, not fake totals.
        for (var i = 0; i < 47; i++) {
          clock.value = DateTime.utc(2026, 9, 1 + i, 12);
          final item = (await learning.forEntry(entry.id)).first;
          await learning.review(
            kind: ReviewKind.regular,
            expectedPrior: item,
            rating: LearningRating.good,
            reviewedAt: clock.now(),
          );
        }
        clock.value = DateTime.utc(2026, 10, 18, 12);
        final beforeToday = await stats.snapshot(at: clock.now());
        expect(beforeToday.todayCounts.regular, 0);
        expect(beforeToday.streak, 47);
        final speedSource = await learning.forCollection(
          collectionId: owner.id,
          direction: LearningDirection.targetToNative,
        );
        final beforeSpeed = (await learning.forEntry(entry.id)).first;
        final history =
            (await db
                    .customSelect(
                      'SELECT * FROM regular_reviews ORDER BY rowid',
                    )
                    .get())
                .map((row) => row.data)
                .toList();
        await speedSource.completeSpeedItem(
          expectedPrior: beforeSpeed,
          errors: 3,
          completedAt: clock.now(),
        );
        final afterSpeed = (await learning.forEntry(entry.id)).first;
        expect(afterSpeed.cardJson, beforeSpeed.cardJson);
        expect(afterSpeed.generation, beforeSpeed.generation);
        expect(afterSpeed.reviewRevision, beforeSpeed.reviewRevision);
        expect(
          (await db
                  .customSelect('SELECT * FROM regular_reviews ORDER BY rowid')
                  .get())
              .map((row) => row.data)
              .toList(),
          history,
        );
        expect((await stats.snapshot(at: clock.now())).todayCounts.speed, 1);
        await db.close();
        db = PikoDatabase(
          NativeDatabase(file),
          clock: clock,
          learningDayCalendar: _UtcCalendar(),
        );
        stats = SqliteStatisticsRepository(db);
        expect((await stats.snapshot(at: clock.now())).streak, 47);
        expect(
          await stats.recordSpeed(entry.id, beforeSpeed.direction, clock.now()),
          isFalse,
        );
        records.add({
          'stage': 'native-activity-reopen',
          'regularDays': 47,
          'speed': 1,
          'longTermExact': true,
          'replay': true,
        });
        final delayed = _DelayedStatistics(stats)
          ..gate = Completer<void>()
          ..fail = true;
        binding = StatisticsBinding(
          repository: delayed,
          clock: clock,
          calendar: _UtcCalendar(),
        );

        for (final enlarged in [false, true]) {
          final locale = enlarged ? 'de' : 'en';
          final copy = PikoCopy(locale);
          final currentBinding = binding;
          await tester.pumpWidget(
            PikoApp(
              key: UniqueKey(),
              locale: Locale(locale),
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(enlarged ? 2 : 1),
                    disableAnimations: enlarged,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: enlarged ? 320 : 390,
                      child: CollectionsHome(
                        repository: SqliteCollectionsRepository(db),
                        statisticsBinding: currentBinding,
                        onOpenStatistics: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                textScaler: TextScaler.linear(enlarged ? 2 : 1),
                                disableAnimations: enlarged,
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: enlarged ? 320 : 390,
                                  child: StatisticsPage(
                                    binding: currentBinding,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (!enlarged) {
            expect(find.text(copy.text('statistics.loading')), findsOneWidget);
            expect(
              find.byKey(const ValueKey('statistics-today')),
              findsNothing,
            );
            delayed.gate!.complete();
            await tester.pumpAndSettle();
            expect(find.text(copy.text('statistics.error')), findsOneWidget);
            delayed.gate = null;
            delayed.fail = false;
            currentBinding.refresh();
            await tester.pumpAndSettle();
          }

          expect(
            find.byKey(const ValueKey('statistics-reminder')),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('statistics-star')), findsNothing);
          expect(
            tester.getTopLeft(find.text(copy.text('statistics.activity'))).dy,
            lessThan(
              tester
                  .getTopLeft(
                    find.byKey(const ValueKey('home-collections-heading')),
                  )
                  .dy,
            ),
          );
          if (!enlarged) await capture('home-open-streak');
          await tester.tap(find.byKey(const ValueKey('statistics-open')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('statistics-average')),
            findsOneWidget,
          );
          Future<void> activate(String key) async {
            final target = find.byKey(ValueKey(key));
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            await tester.tap(target);
            await tester.pumpAndSettle();
          }

          Future<void> anchored(String key) async {
            final target = find.byKey(ValueKey(key));
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            final top = tester.getTopLeft(target).dy;
            await tester.tap(target);
            final deltas = <double>[];
            final clamped = <int>[];
            for (var frame = 0; frame < 24; frame++) {
              await tester.pump(const Duration(milliseconds: 20));
              final delta = tester.getTopLeft(target).dy - top;
              final position = Scrollable.of(tester.element(target)).position;
              final atBound =
                  position.pixels <= position.minScrollExtent + .5 ||
                  position.pixels >= position.maxScrollExtent - .5;
              if (delta.abs() > .5) {
                expect(atBound, isTrue, reason: '$key frame $frame');
                clamped.add(frame);
              }
              deltas.add(delta);
            }
            records.add({
              'surface': key,
              'locale': locale,
              'scale': enlarged ? 2 : 1,
              'frameDeltas': deltas,
              'boundClamps': clamped,
            });
            await tester.pumpAndSettle();
          }

          await anchored('statistics-calendar-toggle');
          expect(
            find.byKey(const ValueKey('statistics-calendar')),
            findsOneWidget,
          );
          expect(
            tester
                .widget<StatisticsAction>(
                  find.byKey(const ValueKey('statistics-next')),
                )
                .onPressed,
            isNull,
          );
          if (!enlarged) {
            await tester.ensureVisible(
              find.byKey(const ValueKey('statistics-month-jump')),
            );
            await capture('statistics-calendar');
          }
          await activate('statistics-previous');
          final selectedMonth = tester
              .widget<Text>(find.byKey(const ValueKey('statistics-month')))
              .data;
          final navigationFocus = Focus.of(
            tester.element(find.text(copy.text('statistics.previous'))),
          );
          navigationFocus.requestFocus();
          await tester.pump();
          delayed.gate = Completer<void>();
          currentBinding.refresh();
          await tester.pumpAndSettle();
          expect(FocusManager.instance.primaryFocus, navigationFocus);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('statistics-month')))
                .data,
            selectedMonth,
          );
          delayed.gate!.complete();
          delayed.gate = null;
          await tester.pumpAndSettle();
          expect(FocusManager.instance.primaryFocus, navigationFocus);
          records.add({
            'stage': 'disabled-calendar-focus',
            'locale': locale,
            'focusRetained': true,
            'activationBlocked': true,
          });
          await anchored('statistics-help');
          final focus = Focus.of(
            tester.element(find.text(copy.text('statistics.rules'))),
          );
          focus.requestFocus();
          await tester.pump();
          final top = tester
              .getTopLeft(find.byKey(const ValueKey('statistics-help')))
              .dy;
          delayed.gate = Completer<void>();
          delayed.fail = true;
          currentBinding.refresh();
          await tester.pumpAndSettle();
          expect(find.text(copy.text('statistics.refreshing')), findsOneWidget);
          delayed.gate!.complete();
          await tester.pumpAndSettle();
          expect(find.text(copy.text('statistics.stale')), findsOneWidget);
          expect(FocusManager.instance.primaryFocus, focus);
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('statistics-month')))
                .data,
            selectedMonth,
          );
          expect(
            tester.getTopLeft(find.byKey(const ValueKey('statistics-help'))).dy,
            closeTo(top, .5),
          );
          delayed.gate = null;
          delayed.fail = false;
          currentBinding.refresh();
          await tester.pumpAndSettle();
          await activate('statistics-speed-mode');
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('statistics-speed-today')),
                )
                .data,
            '1',
          );
          expect(
            find.byKey(const ValueKey('statistics-calendar')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('statistics-reminder')),
            findsNothing,
          );
          if (!enlarged) {
            Scrollable.of(
              tester.element(
                find.byKey(const ValueKey('statistics-speed-mode')),
              ),
            ).position.jumpTo(0);
            await tester.pumpAndSettle();
            await capture('statistics-speed');
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
        final savedActivity = await db.select(db.statisticsActivity).get();
        final ownerRepository = SqliteCollectionsRepository(db);
        for (final collection in await ownerRepository.watchAll().first) {
          await ownerRepository.delete(collection.id);
        }
        await tester.pumpWidget(
          PikoApp(
            key: UniqueKey(),
            home: CollectionsHome(
              repository: ownerRepository,
              statisticsBinding: binding,
              onOpenStatistics: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('statistics-open')), findsOneWidget);
        expect(await db.select(db.statisticsActivity).get(), savedActivity);
        records.add({
          'stage': 'all-collections-deleted',
          'activityAccessible': true,
          'creditsExact': true,
        });
        await tester.pumpWidget(const SizedBox());

        // The host changes only this isolated emulator's timezone and acknowledges
        // after restoring it. Protected broadcasts cannot be simulated by the app.
        final nativeEvents = <String>[];
        final nativeDates = <String>[
          LearningDay.dateFor(DateTime.now().toUtc()).key,
        ];
        nativeClock = deviceClockChanges().listen((_) {
          nativeEvents.add(DateTime.now().toUtc().toIso8601String());
          nativeDates.add(LearningDay.dateFor(DateTime.now().toUtc()).key);
        });
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await File(
          '${directory.path}/clock-ready',
        ).writeAsString('ready', flush: true);
        final deadline = DateTime.now().add(const Duration(seconds: 60));
        while (!await File('${directory.path}/clock-ack').exists() &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
        expect(
          await File('${directory.path}/clock-ack').exists(),
          isTrue,
          reason: 'Host clock protocol acknowledgment',
        );
        expect(
          nativeEvents,
          isNotEmpty,
          reason: 'Actual Android timezone broadcast',
        );
        expect(
          nativeDates.toSet().length,
          greaterThan(1),
          reason: 'Device calendar actually follows the changed timezone',
        );
        records.add({
          'stage': 'native-system-clock-broadcast',
          'events': nativeEvents,
          'learningDates': nativeDates,
        });
        await File(
          '${directory.path}/assertions.json',
        ).writeAsString(jsonEncode(records), flush: true);
        passed = true;
      } finally {
        await tester.pumpWidget(const SizedBox());
        binding?.dispose();
        await nativeClock?.cancel().timeout(const Duration(seconds: 10));
        await db.close();
        await File('${directory.path}/manifest.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'sourceCommit': config.commit,
            'classification': 'instrumented-android',
            'passed': passed,
            'measurements': records,
            'timeFixture':
                'injected UTC calendar for historical activity; real system timezone broadcast checked separately',
          }),
          flush: true,
        );
        debugPrint('PIKO_STATISTICS_EVIDENCE:${directory.path}');
      }
    },
  );
}
