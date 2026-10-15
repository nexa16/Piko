import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/features/collections/collections_home.dart';

void main() {
  testWidgets('application starts without example content or fabricated data', (
    tester,
  ) async {
    final database = PikoDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(database.close);
    await tester.pumpWidget(
      PikoApp(
        home: CollectionsHome(
          repository: SqliteCollectionsRepository(database),
        ),
      ),
    );
    await tester.runAsync(() => database.customSelect('SELECT 1').get());
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('My collections'), findsOneWidget);
    expect(find.text('Korean Basics'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(database.close);
    await tester.pump();
  });
}
