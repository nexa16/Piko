import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';

import '../test/data/speed_eligibility_test.dart' show completeSnapshot;
import 'review_correction_android_test.dart'
    show ReviewFixtureClock, ReviewFixtureDatabase, fixtureInstant, waitUntil;
import 'support/round2_catalogue_fixture.dart' show CatalogueConfiguration;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('long collection scrolls continuously and keeps an invalid draft', (
    tester,
  ) async {
    final config = CatalogueConfiguration();
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/scroll-${config.runId}');
    if (await directory.exists()) throw StateError('Fixture already exists');
    await directory.create();
    final file = File('${directory.path}/fixture.sqlite');
    final clock = ReviewFixtureClock(fixtureInstant);
    final db = ReviewFixtureDatabase(file, clock);
    final collections = SqliteCollectionsRepository(db);
    final vocabulary = SqliteVocabularyRepository(db);
    final owner = await collections.create(
      name: 'Scrolling check — 400 words',
      targetLanguage: VocabularyLanguage.french,
      nativeLanguage: VocabularyLanguage.german,
    );
    final ids = <String>[];
    await db.transaction(() async {
      for (var i = 0; i < 400; i++) {
        ids.add(
          (await vocabulary.create(
            collectionId: owner.id,
            targetText: 'Word $i',
            nativeText: 'Translation $i',
          )).id,
        );
      }
    });
    await SqliteSettingsRepository(db).write('locale', 'en');
    final before = await completeSnapshot(db);
    var mounted = false;
    try {
      mounted = true;
      await tester.pumpWidget(
        PikoApp(home: PikoRuntime(databaseFactory: () => db)),
      );
      await waitUntil(
        tester,
        () => find.byType(CollectionsHome).evaluate().isNotEmpty,
        description: 'Home hydration',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('collection-${owner.id}')));
      await waitUntil(
        tester,
        () => find.byType(CollectionDetail).evaluate().isNotEmpty,
        description: 'Collection Detail',
      );
      await tester.pumpAndSettle();
      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;
      final view = tester.getRect(scrollable);
      final start = Offset(view.center.dx, view.bottom - 90);
      final slowDeltas = <double>[];
      for (var i = 0; i < 5; i++) {
        final offset = position.pixels;
        await tester.timedDragFrom(
          start,
          const Offset(0, -160),
          const Duration(milliseconds: 600),
        );
        await tester.pumpAndSettle();
        slowDeltas.add(position.pixels - offset);
        expect(slowDeltas.last, inExclusiveRange(100, 250));
      }
      final offset = position.pixels;
      await tester.flingFrom(start, const Offset(0, -250), 10000);
      await tester.pumpAndSettle();
      final flingDistance = position.pixels - offset;
      expect(flingDistance, inExclusiveRange(250, 1800));
      await tester.flingFrom(start, const Offset(0, -200), 4000);
      await tester.pump(const Duration(milliseconds: 100));
      final coasting = position.pixels;
      await tester.flingFrom(start, const Offset(0, -200), 4000);
      await tester.pumpAndSettle();
      expect(position.pixels - coasting, inExclusiveRange(200, 1800));
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('vocabulary-${ids.last}')),
        600,
        scrollable: scrollable,
        maxScrolls: 150,
      );
      await tester.pumpAndSettle();
      expect(find.text('Word 399').hitTestable(), findsOneWidget);
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      final png = await binding.takeScreenshot('collection-last-word');
      await File(
        '${directory.path}/collection-last-word.png',
      ).writeAsBytes(png);

      position.jumpTo(0);
      await tester.pumpAndSettle();
      final first = find.byKey(ValueKey('vocabulary-${ids.first}'));
      await tester.scrollUntilVisible(first, 200, scrollable: scrollable);
      await tester.pumpAndSettle();
      await tester.tap(first);
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byKey(ValueKey('inline-${ids.first}-target')),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, '');
      await tester.pumpAndSettle();
      final controller = tester.widget<TextField>(field).controller!;
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      position.jumpTo(6000);
      await tester.pumpAndSettle();
      position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller, same(controller));
      expect(controller.text, '');
      expect(
        await completeSnapshot(db),
        before,
        reason:
            'Scrolling and an invalid draft must not write vocabulary or learning',
      );
      expect(tester.takeException(), isNull);
      await File('${directory.path}/manifest.json').writeAsString(
        jsonEncode({
          'sourceCommit': config.commit,
          'fixture': '400 synthetic vocabulary pairs',
          'slowDragDistances': slowDeltas,
          'fastFlingDistance': flingDistance,
          'successiveFlingsContinue': true,
          'lastWordReachable': true,
          'invalidDraftRetained': true,
          'storedDataUnchanged': true,
          'capture': 'collection-last-word.png',
          'physicalViewport': tester.view.physicalSize.toString(),
          'devicePixelRatio': tester.view.devicePixelRatio,
        }),
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      if (mounted) {
        await db.closed.future.timeout(const Duration(seconds: 15));
      } else {
        await db.close();
      }
    }
    final reopened = ReviewFixtureDatabase(file, clock);
    try {
      expect(await completeSnapshot(reopened), before);
    } finally {
      await reopened.close();
    }
  });
}
