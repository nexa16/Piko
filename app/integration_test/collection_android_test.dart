import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android creates a collection and retains it after database reopen',
    (tester) async {
      final directory = await Directory(
        (await getTemporaryDirectory()).path,
      ).createTemp('piko-collection-verification-');
      final file = File('${directory.path}/test.sqlite');
      var db = PikoDatabase(NativeDatabase(file));
      try {
        await tester.pumpWidget(
          PikoApp(
            home: CollectionsHome(repository: SqliteCollectionsRepository(db)),
          ),
        );
        await tester.tap(find.text('New'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Android verification');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.ensureVisible(find.text('Create collection'));
        await tester.tap(find.text('Create collection'));
        await tester.pumpAndSettle();
        // Await database work before reopening, without arbitrary sleeps.
        await db.customSelect('SELECT 1').get();
        await tester.pumpAndSettle();
        expect(find.text('Created Android verification'), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        final original = await db.select(db.collections).getSingle();
        await tester.pumpWidget(const SizedBox());
        await db.close();
        db = PikoDatabase(NativeDatabase(file));
        final row = await db.select(db.collections).getSingle();
        expect(row.id, original.id);
        expect(row.name, 'Android verification');
        expect(row.targetLanguage, 'ko');
        expect(row.nativeLanguage, 'de');
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
