import 'dart:async';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';

final copy = const PikoCopy('en');

class ControlledEmptyRepository implements CollectionsRepository {
  final watches = <StreamController<List<CollectionRecord>>>[];
  @override
  Stream<List<CollectionRecord>> watchAll() {
    final stream = StreamController<List<CollectionRecord>>.broadcast();
    watches.add(stream);
    return stream.stream;
  }

  @override
  Stream<CollectionRecord?> watchById(String id) => Stream.value(null);
  @override
  Future<CollectionRecord> create({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
  }) => throw UnimplementedError('This fixture only drives read states');
}

Future<PikoDatabase> emptyDatabase(WidgetTester tester) async {
  final db = PikoDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  addTearDown(db.close);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
  await tester.pumpWidget(
    PikoApp(home: CollectionsHome(repository: SqliteCollectionsRepository(db))),
  );
  await tester.runAsync(() => db.select(db.collections).get());
  await tester.pumpAndSettle();
  return db;
}

void expectInvitation(Matcher matcher) {
  expect(find.text(copy.text('home.emptyDescription')), matcher);
  expect(find.text(copy.text('action.firstCollection')), matcher);
}

void main() {
  testWidgets(
    'fresh real database explains empty collections without fabricated data',
    (tester) async {
      final db = await emptyDatabase(tester);
      expect(
        await tester.runAsync(() => db.select(db.collections).get()),
        isEmpty,
      );
      expectInvitation(findsOneWidget);
      expect(find.text(copy.text('action.new')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith('collection-'),
        ),
        findsNothing,
      );
      expect(find.text(copy.text('action.review')), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'first-collection action writes real data and removes invitation reactively',
    (tester) async {
      final db = await emptyDatabase(tester);
      await tester.tap(find.text(copy.text('action.firstCollection')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'My first collection');
      await tester.ensureVisible(find.text(copy.text('action.create')));
      await tester.tap(find.text(copy.text('action.create')));
      await tester.runAsync(() => db.select(db.collections).get());
      await tester.pumpAndSettle();
      final records = await tester.runAsync(
        () => db.select(db.collections).get(),
      );
      expect(records, hasLength(1));
      expect(records!.single.name, 'My first collection');
      expect(find.text('My first collection'), findsOneWidget);
      expectInvitation(findsNothing);
      expect(find.text(copy.text('action.new')), findsOneWidget);
    },
  );

  testWidgets(
    'both invitation and ordinary New dismiss without creating collections',
    (tester) async {
      final db = await emptyDatabase(tester);
      for (final key in ['action.firstCollection', 'action.new']) {
        await tester.tap(find.text(copy.text(key)));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Unsaved name');
        await tester.tap(find.byTooltip(copy.text('common.close')));
        await tester.pumpAndSettle();
        expectInvitation(findsOneWidget);
        expect(
          await tester.runAsync(() => db.select(db.collections).get()),
          isEmpty,
        );
      }
    },
  );

  testWidgets('pending, failed and retrying reads never imply empty success', (
    tester,
  ) async {
    final repository = ControlledEmptyRepository();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      for (final watch in repository.watches) {
        await watch.close();
      }
    });
    await tester.pumpWidget(
      PikoApp(home: CollectionsHome(repository: repository)),
    );
    await tester.pumpAndSettle();
    expectInvitation(findsNothing);
    repository.watches.last.add([]);
    await tester.pumpAndSettle();
    expectInvitation(findsOneWidget);
    repository.watches.last.addError(StateError('Read failed'));
    await tester.pumpAndSettle();
    expectInvitation(findsNothing);
    expect(find.text(copy.text('collection.loadFailed')), findsOneWidget);
    await tester.tap(find.text(copy.text('action.retry')));
    await tester.pumpAndSettle();
    expect(repository.watches, hasLength(2));
    expectInvitation(findsNothing);
    repository.watches.last.add([]);
    await tester.pumpAndSettle();
    expectInvitation(findsOneWidget);
    expect(find.text(copy.text('action.new')), findsOneWidget);
  });
}
