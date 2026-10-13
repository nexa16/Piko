import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/main.dart';

class PendingRepository implements CollectionsRepository {
  var pending = Completer<CollectionRecord>();
  var calls = 0;
  String? name;
  @override
  Future<CollectionRecord> create({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
  }) {
    calls++;
    this.name = name;
    return pending.future;
  }
}

void main() {
  testWidgets(
    'blank name and same languages show localized errors without saving',
    (tester) async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(
        PikoApp(
          home: CollectionsHome(repository: SqliteCollectionsRepository(db)),
        ),
      );
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create collection'));
      await tester.tap(find.text('Create collection'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a collection name.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Name');
      await tester.tap(find.byType(DropdownButton<VocabularyLanguage>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Korean').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create collection'));
      await tester.tap(find.text('Create collection'));
      await tester.pumpAndSettle();
      expect(find.text('Choose two different languages.'), findsOneWidget);
      expect(
        await tester.runAsync(() => db.select(db.collections).get()),
        isEmpty,
      );
    },
  );
  testWidgets(
    'German UI creates trimmed collection with selected languages in SQLite',
    (tester) async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(
        PikoApp(
          locale: const Locale('de'),
          home: CollectionsHome(repository: SqliteCollectionsRepository(db)),
        ),
      );
      await tester.tap(find.text('Neu'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '  Meine Sammlung  ');
      await tester.tap(find.byType(DropdownButton<VocabularyLanguage>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Französisch').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sammlung erstellen'));
      await tester.tap(find.text('Sammlung erstellen'));
      await tester.runAsync(() => db.customSelect('SELECT 1').get());
      await tester.pumpAndSettle();
      final rows = await tester.runAsync(() => db.select(db.collections).get());
      expect(rows, hasLength(1));
      expect(rows!.single.name, 'Meine Sammlung');
      expect(rows.single.targetLanguage, 'fr');
      expect(rows.single.nativeLanguage, 'de');
      expect(find.text('Meine Sammlung erstellt'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
    },
  );
  testWidgets('closing unsubmitted form does not write', (tester) async {
    final repository = PendingRepository();
    await tester.pumpWidget(
      PikoApp(home: CollectionsHome(repository: repository)),
    );
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Unsaved');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
  });
  testWidgets('failed persistence preserves input and enables retry', (
    tester,
  ) async {
    final repository = PendingRepository();
    await tester.pumpWidget(
      PikoApp(home: CollectionsHome(repository: repository)),
    );
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'My collection');
    await tester.ensureVisible(find.text('Create collection'));
    await tester.tap(find.text('Create collection'));
    await tester.pump();
    repository.pending.completeError(StateError('Disk full'));
    await tester.pumpAndSettle();
    expect(find.text('My collection'), findsOneWidget);
    expect(
      find.text("Couldn't save the collection. Please try again."),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    repository.pending = Completer<CollectionRecord>();
    await tester.tap(find.text('Create collection'));
    repository.pending.complete(
      const CollectionRecord(
        id: 'retry',
        name: 'My collection',
        targetLanguage: VocabularyLanguage.korean,
        nativeLanguage: VocabularyLanguage.german,
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.text('Created My collection'), findsOneWidget);
  });
  testWidgets(
    'double submit writes once and dismissal does not pop home later',
    (tester) async {
      final repository = PendingRepository();
      await tester.pumpWidget(
        PikoApp(home: CollectionsHome(repository: repository)),
      );
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'My collection');
      await tester.ensureVisible(find.text('Create collection'));
      await tester.tap(find.text('Create collection'));
      await tester.tap(find.text('Create collection'));
      expect(repository.calls, 1);
      await tester.pump();
      final pendingField = tester.widget<TextField>(find.byType(TextField));
      expect(pendingField.enabled, isFalse);
      expect(pendingField.decoration!.disabledBorder, isA<OutlineInputBorder>());
      await tester.tap(find.byTooltip('Close'));
      repository.pending.complete(
        const CollectionRecord(
          id: 'test',
          name: 'My collection',
          targetLanguage: VocabularyLanguage.korean,
          nativeLanguage: VocabularyLanguage.german,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('My collections'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
