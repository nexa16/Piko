import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart'
    show Selectable, QueryRow, Variable, ResultSetImplementation;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/features/collections/collection_compact_action.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/learning/learning_direction_choice.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/features/learning/review_session_route.dart';
import 'package:piko/features/speed/speed_setup_dialog.dart';
import 'package:piko/features/vocabulary/collection_vocabulary.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import '../test/data/regular_reviews_test.dart' show Fixture;
import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart';

// Delay/fail only a real category read in this isolated SQLite fixture. The
// production runtime, query service, launch owners and widgets are unchanged.
class _HeaderDatabase extends PikoDatabase {
  _HeaderDatabase(File file, review.ReviewFixtureClock clock)
    : super(NativeDatabase(file), clock: clock);
  Completer<void>? queryGate;
  bool failQuery = false;
  final closed = Completer<void>();
  bool closing = false;
  @override
  Selectable<QueryRow> customSelect(
    String query, {
    List<Variable> variables = const [],
    Set<ResultSetImplementation> readsFrom = const {},
  }) {
    final result = super.customSelect(
      query,
      variables: variables,
      readsFrom: readsFrom,
    );
    return query.startsWith('SELECT d.*, COALESCE(p.carry_over, 0)')
        ? _HeaderRead(result, this)
        : result;
  }

  @override
  Future<void> close() async {
    if (closing) return closed.future;
    closing = true;
    await super.close();
    closed.complete();
  }
}

class _HeaderRead extends Selectable<QueryRow> {
  _HeaderRead(this.inner, this.database);
  final Selectable<QueryRow> inner;
  final _HeaderDatabase database;
  @override
  Future<List<QueryRow>> get() async {
    await database.queryGate?.future;
    if (database.failQuery) throw StateError('Synthetic header query failure');
    return inner.get();
  }

  @override
  Stream<List<QueryRow>> watch() => inner.watch();
}

void main() {
  final integration = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native compact header preserves mode, state and stored learning', (
    tester,
  ) async {
    final config = CatalogueConfiguration(),
        copy = PikoCopy(CatalogueConfiguration().locale);
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/header-${config.runId}');
    if (await directory.exists()) throw StateError('Evidence already exists');
    await directory.create();
    final file = File('${directory.path}/fixture.sqlite');
    final clock = review.ReviewFixtureClock(DateTime.utc(2026, 10, 18, 12));
    final db = _HeaderDatabase(file, clock);
    final fixture = Fixture(database: db);
    final manifest = <String, Object?>{
      'sourceCommit': config.commit,
      'locale': config.locale,
      'scale': config.scale,
      'normalProductionDatabaseOpened': false,
    };
    var passed = false, converted = false;
    Finder key(String id) => find.byKey(ValueKey(id));
    CollectionDetail detail() =>
        tester.widget<CollectionDetail>(find.byType(CollectionDetail));
    ScrollPosition position() =>
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    CollectionCompactAction action(String mode) =>
        tester.widget<CollectionCompactAction>(key('collection-$mode-compact'));
    Future<void> settle() async {
      await review.waitUntil(tester, () => detail().queryBinding!.ready);
      await tester.pumpAndSettle();
    }

    Future<void> top() async {
      position().jumpTo(0);
      await tester.pumpAndSettle();
    }

    Future<void> collapse() async {
      for (
        var i = 0;
        i < 40 &&
            key('collection-review-compact').hitTestable().evaluate().isEmpty;
        i++
      ) {
        final viewport = tester.getRect(find.byType(Scrollable).first);
        await tester.dragFrom(
          Offset(viewport.center.dx, viewport.bottom - 24),
          const Offset(0, -140),
        );
        await tester.pumpAndSettle();
      }
      expect(key('collection-review-compact').hitTestable(), findsOneWidget);
      expect(key('collection-speed-compact').hitTestable(), findsOneWidget);
    }

    Future<void> tap(Finder target) async {
      if (target.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          target,
          120,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 80,
        );
      }
      if (target.hitTestable().evaluate().isEmpty) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
      }
      expect(target.hitTestable(), findsOneWidget);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Future<void> closePopup() => tap(find.byTooltip(copy.text('common.close')));
    Future<void> capture(String name) async {
      if (config.locale != 'en') return;
      await settleCatalogueCapture(tester, name);
      if (!converted) {
        await integration.convertFlutterSurfaceToImage();
        await tester.pump();
        converted = true;
      }
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(await integration.takeScreenshot(name));
    }

    Future<Map<String, Object?>> stored(PikoDatabase store) async => {
      for (final table in store.allTables)
        table.actualTableName: await review.rows(store, table.actualTableName),
    };
    void step(String name) {
      manifest['lastStep'] = name;
      debugPrint('HEADER_STEP:$name');
    }

    try {
      step('seed');
      await fixture.initialize();
      await fixture.collections.rename(id: fixture.owner.id, name: 'Sprachen');
      for (var i = 0; i < 18; i++) {
        await fixture.vocabulary.create(
          collectionId: fixture.owner.id,
          targetText: 'Word $i',
          nativeText: 'Wort $i',
        );
      }
      await db.customStatement(
        'UPDATE learning_items SET speed_completed=1 WHERE entry_id=? AND direction=?',
        [fixture.entry.id, 'targetToNative'],
      );
      final settings = SqliteSettingsRepository(db);
      await settings.write('locale', config.locale);
      await settings.write(
        PreferredDirection.settingKey,
        PreferredDirection.both.name,
      );
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
      await settle();
      final media = MediaQuery.of(
        tester.element(find.byType(CollectionDetail)),
      );
      manifest['width'] = media.size.width;
      manifest['textScale'] = media.textScaler.scale(14) / 14;
      if (config.scale == '200') {
        expect(media.size.width, closeTo(320, 1));
        expect(media.textScaler.scale(14), closeTo(28, 1));
      }
      final before = await stored(db);
      step('collapse and independent counts');
      final transition = <Map<String, Object?>>[];
      var sampling = true;
      void frame(Duration _) {
        if (!sampling) return;
        final compact = key('collection-compact-header');
        transition.add({
          'offset': position().pixels,
          'compact': compact.evaluate().isNotEmpty,
          if (compact.evaluate().isNotEmpty)
            'top': tester.getTopLeft(compact).dy,
        });
        tester.binding.addPostFrameCallback(frame);
      }

      tester.binding.addPostFrameCallback(frame);
      await collapse();
      sampling = false;
      manifest['collapseFrames'] = transition;
      var reachedCompact = false;
      double? compactTop;
      for (final sample in transition) {
        final compact = sample['compact']! as bool;
        if (reachedCompact) expect(compact, isTrue);
        if (compact) {
          reachedCompact = true;
          compactTop ??= sample['top']! as double;
          expect(sample['top'], closeTo(compactTop, .5));
        }
      }
      expect(reachedCompact, isTrue);
      final snapshot = detail().queryBinding!.snapshot!;
      expect(
        action('review').count,
        snapshot.directions.values
            .fold(0, (sum, d) => sum + d.dueCount)
            .toString(),
      );
      expect(
        action('speed').count,
        snapshot.directions.values
            .fold(0, (sum, d) => sum + d.newSpeedItems.length)
            .toString(),
      );
      expect(action('review').count, isNot(action('speed').count));
      expect(
        find.descendant(
          of: key('collection-compact-header'),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
      for (final mode in ['review', 'speed']) {
        final size = tester.getSize(key('collection-$mode-compact'));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      await capture('collection-compact');
      final offset = position().pixels;
      step('two direction pickers and cancellation');
      await tap(key('collection-review-compact'));
      expect(find.byType(LearningDirectionChoice), findsOneWidget);
      await closePopup();
      expect(position().pixels, closeTo(offset, .5));
      await tap(key('collection-speed-compact'));
      expect(find.byType(LearningDirectionChoice), findsOneWidget);
      await tap(key('learning-direction-nativeToTarget'));
      expect(find.byType(SpeedSetupDialog), findsOneWidget);
      expect(tester.widget<Text>(key('speed-fixed-direction')).data, 'DE → FR');
      await closePopup();
      expect(position().pixels, closeTo(offset, .5));
      expect(await stored(db), before);
      step('loading failure retry without scroll jump');
      final gate = db.queryGate = Completer<void>();
      detail().queryBinding!.refresh();
      await tester.pump(const Duration(milliseconds: 100));
      expect(action('review').count, '…');
      expect(action('speed').onPressed, isNull);
      db.failQuery = true;
      gate.complete();
      await review.waitUntil(
        tester,
        () => detail().queryBinding!.error != null,
      );
      expect(action('review').count, '!');
      expect(position().pixels, closeTo(offset, .5));
      db.queryGate = null;
      db.failQuery = false;
      await tap(find.text(copy.text('action.retry')));
      await settle();
      expect(position().pixels, closeTo(offset, .5));
      step('selection and no-result zeros');
      await top();
      final card = key('vocabulary-${fixture.entry.id}');
      await tester.scrollUntilVisible(
        card,
        100,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 80,
      );
      await tester.pumpAndSettle();
      await tester.longPress(card.hitTestable().first);
      await tester.pumpAndSettle();
      final selection = tester
          .widget<CollectionVocabulary>(
            find.byType(CollectionVocabulary, skipOffstage: false),
          )
          .selection!;
      expect(selection.ids, {fixture.entry.id});
      await collapse();
      final selectedOffset = position().pixels;
      await tap(key('collection-speed-compact'));
      await closePopup();
      expect(selection.ids, {fixture.entry.id});
      expect(position().pixels, closeTo(selectedOffset, .5));
      detail().queryBinding!.scope.setSearch('no matching word');
      await settle();
      await collapse();
      expect(action('review').count, '0');
      expect(action('speed').count, '0');
      expect(action('review').onPressed, isNull);
      expect(action('speed').onPressed, isNull);
      expect(selection.ids, {fixture.entry.id});
      detail().queryBinding!.scope.setSearch('');
      await settle();
      selection.clear();
      step('one direction launches directly');
      await detail().directionBinding!.value!.select(
        PreferredDirection.targetToNative,
      );
      await settle();
      await collapse();
      await tap(key('collection-review-compact'));
      await review.waitUntil(
        tester,
        () => find.byType(ReviewSessionRoute).evaluate().isNotEmpty,
      );
      expect(find.byType(LearningDirectionChoice), findsNothing);
      await tap(key('review-exit'));
      await settle();
      await collapse();
      await tap(key('collection-speed-compact'));
      expect(find.byType(SpeedSetupDialog), findsOneWidget);
      expect(tester.widget<Text>(key('speed-fixed-direction')).data, 'FR → DE');
      await closePopup();
      await detail().directionBinding!.value!.select(PreferredDirection.both);
      await settle();
      expect(await stored(db), before);
      step('keyboard raw draft and native viewport');
      await top();
      final search = key('collection-search');
      await tap(search);
      final field = tester.widget<TextField>(search);
      field.controller!.value = const TextEditingValue(
        text: '  Word  ',
        selection: TextSelection(baseOffset: 2, extentOffset: 6),
      );
      field.onChanged!(field.controller!.text);
      final raw = field.controller!.value;
      await tester.pumpAndSettle();
      expect(field.focusNode!.hasFocus, isTrue);
      await review.waitUntil(
        tester,
        () =>
            MediaQuery.of(
              tester.element(find.byType(CollectionDetail)),
            ).viewInsets.bottom >
            0,
        description: 'native search keyboard',
      );
      manifest['keyboardInset'] = MediaQuery.of(
        tester.element(find.byType(CollectionDetail)),
      ).viewInsets.bottom;
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pumpAndSettle();
      await collapse();
      expect(field.controller!.value, raw);
      await tap(key('collection-review-compact'));
      await closePopup();
      expect(field.controller!.value, raw);
      field.focusNode!.unfocus();
      field.controller!.clear();
      detail().queryBinding!.scope.setSearch('');
      await settle();
      step('real pending retry distinguishes settled zero');
      await fixture.review(rating: LearningRating.again, at: clock.now());
      await fixture.review(
        reverse: true,
        rating: LearningRating.again,
        at: clock.now(),
      );
      detail().queryBinding!.scope.setSearch('One');
      await settle();
      await collapse();
      expect(action('review').count, '0');
      expect(action('review').label, copy.text('collection.compactPending'));
      expect(action('speed').count, '0');
      final after = await stored(db);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await db.closed.future;
      final reopened = PikoDatabase(NativeDatabase(file), clock: clock);
      try {
        expect(await stored(reopened), after);
      } finally {
        await reopened.close();
      }
      manifest['assertions'] = [
        'independent directional sums',
        '48px controls without compact art',
        'two/one mode-specific launches',
        'cancellation preserves exact data, selection and scroll',
        'loading/error/retry without fabricated zero',
        'real keyboard retains raw text and cursor',
        'pending retry is not settled no-work',
        'reopened database exact',
      ];
      passed = true;
    } finally {
      if (db.queryGate?.isCompleted == false) db.queryGate!.complete();
      db.queryGate = null;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      if (!db.closed.isCompleted) await db.close();
      manifest['passed'] = passed;
      await File('${directory.path}/manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest),
        flush: true,
      );
      debugPrint('PIKO_HEADER_EVIDENCE:${directory.path}');
    }
  });
}
