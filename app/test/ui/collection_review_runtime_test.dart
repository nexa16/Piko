import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/features/collections/collection_review_count.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';

import '../data/regular_reviews_test.dart' show Fixture, instant;
import '../support/mutable_clock.dart';
import 'review_no_due_test.dart' show snapshot;

class RuntimeDatabase extends PikoDatabase {
  RuntimeDatabase(MutablePikoClock clock)
    : super(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
        clock: clock,
      );

  final closed = Completer<void>();

  @override
  Future<void> close() async {
    await super.close();
    if (!closed.isCompleted) closed.complete();
  }
}

Future<void> pumpRuntime(
  WidgetTester tester,
  RuntimeDatabase db,
  Fixture fixture,
) async {
  await tester.pumpWidget(
    PikoApp(home: PikoRuntime(databaseFactory: () => db)),
  );
  for (var attempt = 0; attempt < 8; attempt++) {
    await tester.runAsync(() => db.customSelect('SELECT 1').get());
    await tester.pumpAndSettle();
    if (find.byType(CollectionsHome).evaluate().isNotEmpty &&
        find
            .byKey(ValueKey('collection-${fixture.owner.id}'))
            .evaluate()
            .isNotEmpty) {
      return;
    }
  }
}

void main() {
  testWidgets(
    'runtime retains Detail scope and prepares filtered membership without narrowing Overview',
    (tester) async {
      final db = RuntimeDatabase(MutablePikoClock(instant));
      final f = Fixture(database: db);
      await tester.runAsync(f.initialize);
      final kept = await tester.runAsync(
        () => f.vocabulary.create(
          collectionId: f.owner.id,
          targetText: 'Keep',
          nativeText: 'Behalten',
        ),
      );
      try {
        await pumpRuntime(tester, db, f);
        final home = tester.widget<CollectionsHome>(
          find.byType(CollectionsHome),
        );
        final binding = home.queryBindingFactory!(f.owner.id);
        binding.scope.setSearch('keep');
        Future<void> settleQuery() async {
          for (var attempt = 0; attempt < 12; attempt++) {
            await tester.runAsync(() => db.customSelect('SELECT 1').get());
            await tester.pumpAndSettle();
            if (binding.ready) return;
          }
          fail('Collection query did not become ready');
        }

        await settleQuery();
        expect(binding.snapshot!.entries.map((entry) => entry.id), [kept!.id]);
        expect(binding.snapshot!.allEntries.length, 2);
        final detail = await tester.runAsync(
          () => home.detailReviewSessionFactory!(
            f.owner.id,
            LearningDirection.targetToNative,
          ),
        );
        final overview = await tester.runAsync(
          () => home.reviewSessionFactory!(
            f.owner.id,
            LearningDirection.targetToNative,
          ),
        );
        expect(detail!.members.map((item) => item.entryId), [kept.id]);
        expect(overview!.members.map((item) => item.entryId).toSet(), {
          f.entry.id,
          kept.id,
        });
        detail.dispose();
        overview.dispose();
        await tester.runAsync(
          () => f.vocabulary.create(
            collectionId: f.owner.id,
            targetText: 'Keep another',
            nativeText: 'Noch behalten',
          ),
        );
        await settleQuery();
        expect(binding.snapshot!.entries.length, 2);
        expect(binding.snapshot!.allEntries.length, 3);
        expect(home.queryBindingFactory!(f.owner.id), same(binding));
        expect(binding.scope.search, 'keep');
        expect(home.queryBindingFactory!(f.kept.id).scope.search, isEmpty);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.runAsync(() => db.closed.future);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('production runtime injects the accepted count composition', (
    tester,
  ) async {
    final db = RuntimeDatabase(MutablePikoClock(instant));
    final fixture = Fixture(database: db);
    await tester.runAsync(fixture.initialize);
    try {
      await pumpRuntime(tester, db, fixture);
      final home = tester.widget<CollectionsHome>(find.byType(CollectionsHome));
      expect(
        home.reviewCountPolicy,
        CollectionReviewCountPolicy.dueDirectionCards,
      );
      expect(home.reviewMembershipLoader, isNotNull);
      expect(identical(home.reviewCountClock, db.clock), isTrue);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.runAsync(() => db.closed.future);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'production runtime counts one vocabulary due in both directions as two repetitions with both enabled in Detail',
    (tester) async {
      final db = RuntimeDatabase(MutablePikoClock(instant));
      final f = Fixture(database: db);
      await tester.runAsync(f.initialize);
      await tester.runAsync(() => SqliteSettingsRepository(db).write(
        PreferredDirection.settingKey,
        PreferredDirection.both.name,
      ));
      final before = await tester.runAsync(() => snapshot(f));
      try {
        await pumpRuntime(tester, db, f);

        final ownerCard = find.byKey(ValueKey('collection-${f.owner.id}'));
        final ownerReview = find.descendant(
          of: ownerCard,
          matching: find.byKey(const ValueKey('collection-review-quick')),
        );
        expect(ownerReview, findsOneWidget);
        expect(
          find.descendant(of: ownerReview, matching: find.text('2')),
          findsOneWidget,
        );
        expect(await tester.runAsync(() => snapshot(f)), before);

        await tester.tap(
          find.descendant(of: ownerCard, matching: find.text(f.owner.name)),
        );
        for (var attempt = 0; attempt < 8; attempt++) {
          await tester.runAsync(() => db.customSelect('SELECT 1').get());
          await tester.pumpAndSettle();
          if (find.text('FR → DE · 1 to review').evaluate().isNotEmpty) {
            break;
          }
        }
        expect(find.text('FR → DE · 1 to review'), findsOneWidget);
        expect(find.text('DE → FR · 1 to review'), findsOneWidget);
        expect(await tester.runAsync(() => snapshot(f)), before);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.runAsync(() => db.closed.future);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
