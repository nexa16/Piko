import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/speed/speed_numbers_break.dart';
import 'package:piko/features/speed/speed_session_route.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import '../test/data/regular_reviews_test.dart' show Fixture;
import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart';

void main() {
  final integration = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native A–J alternation preserves learning and break boundaries', (
    tester,
  ) async {
    final config = CatalogueConfiguration(),
        copy = PikoCopy(CatalogueConfiguration().locale);
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/letters-${config.runId}');
    if (await directory.exists()) throw StateError('Evidence already exists');
    await directory.create();
    final db = review.ReviewFixtureDatabase(
      File('${directory.path}/fixture.sqlite'),
      review.ReviewFixtureClock(DateTime.utc(2026, 10, 18, 12)),
    );
    final fixture = Fixture(database: db);
    final manifest = <String, Object?>{
      'sourceCommit': config.commit,
      'locale': config.locale,
      'scale': config.scale,
    };
    var passed = false;
    Finder key(String value) => find.byKey(ValueKey(value));
    Future<void> tap(Finder finder) async {
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          finder,
          140,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 100,
        );
      }
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder.hitTestable().first);
      await tester.pumpAndSettle();
    }

    Future<Map<String, Object?>> snapshot() async => {
      for (final row
          in await db
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
              )
              .get())
        row.read<String>('name'): await review.rows(
          db,
          row.read<String>('name'),
        ),
    };
    Future<void> grade(String answer) async {
      await tap(key('review-reveal-target'));
      await tap(key('speed-grade-$answer'));
    }

    Future<void> start() async {
      final expanded = key('collection-speed-targetToNative');
      await tester.ensureVisible(expanded);
      await tester.pumpAndSettle();
      // Enlarged text can collapse the header while revealing the large action.
      // Activate the actual persistent compact action in that representation.
      await tap(
        expanded.hitTestable().evaluate().isNotEmpty
            ? expanded
            : key('collection-speed-compact'),
      );
      await tap(find.text(copy.text('learn.startSpeed')));
    }

    Future<void> game(bool letters, {bool keyboard = false}) async {
      expect(find.byType(SpeedNumbersBreak), findsOneWidget);
      final before = await snapshot();
      expect(
        find.text(copy.text(letters ? 'r2.letterGameHint' : 'r2.gameHint')),
        findsOneWidget,
      );
      Finder button(int ordinal) => key(
        letters
            ? 'speed-letter-${String.fromCharCode(64 + ordinal)}'
            : 'speed-number-$ordinal',
      );
      await tap(button(10));
      expect(
        find.text(copy.text('r2.gameNext', {'number': letters ? 'A' : '1'})),
        findsOneWidget,
      );
      for (var ordinal = 1; ordinal <= 10; ordinal++) {
        final target = button(ordinal);
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        if (keyboard) {
          Focus.of(
            tester.element(
              find.descendant(
                of: target,
                matching: find.text(String.fromCharCode(64 + ordinal)),
              ),
            ),
          ).requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(
            ordinal.isOdd ? LogicalKeyboardKey.enter : LogicalKeyboardKey.space,
          );
          await tester.pumpAndSettle();
        } else {
          await tap(target);
        }
      }
      expect(find.byType(SpeedNumbersBreak), findsNothing);
      expect(await snapshot(), before);
    }

    try {
      await fixture.initialize();
      await SqliteSettingsRepository(db).write('locale', config.locale);
      await tester.pumpWidget(
        PikoApp(
          locale: Locale(config.locale),
          home: PikoRuntime(
            databaseFactory: () => db,
            jsonPlatform: CatalogueJsonPlatform(),
          ),
        ),
      );
      await hydratedRuntimeCopy(tester);
      await review.waitUntil(
        tester,
        () => key('collection-${fixture.owner.id}').evaluate().isNotEmpty,
      );
      await tap(key('collection-${fixture.owner.id}'));
      final media = MediaQuery.of(
        tester.element(find.byType(CollectionDetail)),
      );
      manifest['width'] = media.size.width;
      manifest['textScale'] = media.textScaler.scale(14) / 14;
      if (config.scale == '200') {
        expect(media.size.width, closeTo(320, 1));
        expect(media.textScaler.scale(14), closeTo(28, 1));
      }
      final baseline = await snapshot();
      await start();
      await grade('incorrect');
      await game(false);
      await grade('correct');
      expect(key('speed-letter-A'), findsOneWidget);
      if (config.locale == 'en') {
        await settleCatalogueCapture(tester, 'letters-break');
        await integration.convertFlutterSurfaceToImage();
        await tester.pump();
        await File(
          '${directory.path}/letters-break.png',
        ).writeAsBytes(await integration.takeScreenshot('letters-break'));
      }
      await game(true, keyboard: true);
      expect(await snapshot(), baseline);
      await tap(key('speed-exit'));
      expect(find.byType(CollectionDetail), findsOneWidget);
      expect(await snapshot(), baseline);
      await start();
      await grade('incorrect');
      await game(false);
      await grade('correct');
      await game(true);
      await grade('correct');
      await review.waitUntil(
        tester,
        () => key('speed-completion-notice').evaluate().isNotEmpty,
      );
      expect(find.byType(SpeedSessionRoute), findsNothing);
      expect(find.byType(SpeedNumbersBreak), findsNothing);
      expect(
        (await review.rows(
          db,
          'statistics_activity',
        )).where((r) => r['mode'] == 'speed').length,
        1,
      );
      for (final table in [
        'regular_reviews',
        'retry_obligations',
        'scope_answer_ordinals',
      ]) {
        expect(await review.rows(db, table), baseline[table]);
      }
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(tester.takeException(), isNull);
      manifest['assertions'] = [
        'numbers first each launch',
        'A–J second break',
        'wrong taps do not advance',
        'native keyboard Enter/Space',
        'no game data writes',
        'exit discards game',
        'confirmed completion has no final game',
        'one Speed credit, Long-term history unchanged',
      ];
      passed = true;
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      if (!db.closed.isCompleted) await db.close();
      manifest['passed'] = passed;
      await File('${directory.path}/manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
        flush: true,
      );
      debugPrint('PIKO_LETTERS_EVIDENCE:${directory.path}');
    }
  });
}
