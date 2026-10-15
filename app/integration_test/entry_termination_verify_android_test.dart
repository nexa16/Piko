import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:piko/main.dart';
import 'support/entry_termination_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'confirmed production vocabulary survives external process termination',
    (tester) async {
      final file = await checkpointFile();
      final checkpoint =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      expect(checkpoint['phase'], 'ready');
      expect(checkpoint['run'], runId);
      final owner = checkpoint['owner'] as Map;
      final entry = checkpoint['entry'] as Map;
      final db = productionObserver();
      final state = await snapshot(db);
      expectBaseline(
        checkpoint['baseline'] as Map<String, dynamic>,
        state,
        ownedCollection: owner['id'] as String,
        ownedEntry: entry['id'] as String,
      );
      expectOwned(checkpoint, state);
      expect(
        (state['collections'] as List)
            .where((row) => (row as Map)['id'] == owner['id'])
            .single,
        owner,
      );
      expect(
        (state['vocabulary_entries'] as List)
            .where((row) => (row as Map)['collection_id'] == owner['id'])
            .toList(),
        [entry],
      );
      expect(
        (state['learning_items'] as List)
            .where((row) => (row as Map)['entry_id'] == entry['id'])
            .toList(),
        checkpoint['learning'],
      );
      await tester.pumpWidget(const PikoApp());
      final copy = await hydratedRuntimeCopy(tester);
      await tapVisible(tester, find.text(collectionName));
      await tapVisible(tester, find.byTooltip(copy.text('action.addEntry')));
      expect(
        tester.widget<TextField>(entryField('target')).controller!.text,
        isEmpty,
      );
      expect(
        tester.widget<TextField>(entryField('native')).controller!.text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      // Delete only exact checkpoint-owned synthetic records after all assertions.
      await cleanupOwned(db, checkpoint);
      await db.close();
      await file.delete();
    },
  );
}
