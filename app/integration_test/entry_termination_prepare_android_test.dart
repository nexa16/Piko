import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:piko/main.dart';
import 'package:piko/data/vocabulary_normalization.dart';
import 'package:piko/data/collections_repository.dart';
import 'support/entry_termination_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'prepare live production confirmation for external force-stop',
    (tester) async {
      final file = await checkpointFile();
      if (await file.exists()) {
        throw StateError('Refusing to overwrite checkpoint.');
      }
      final db = productionObserver();
      final baseline = await snapshot(db);
      await writeCheckpoint(file, {
        'phase': 'baseline',
        'run': runId,
        'baseline': baseline,
      });
      await tester.pumpWidget(const PikoApp());
      final copy = await hydratedRuntimeCopy(tester);
      await tapVisible(tester, find.text(copy.text('action.new')));
      await tester.enterText(find.byType(TextField), collectionName);
      await tapVisible(tester, find.text(copy.text('action.create')));
      await tapVisible(tester, find.text(collectionName));
      await tapVisible(tester, find.byTooltip(copy.text('action.addEntry')));
      await tester.enterText(entryField('target'), '학교-$runId');
      await tester.enterText(entryField('native'), 'Schule-$runId');
      await tapVisible(tester, find.byTooltip(copy.text('action.saveNext')));
      await waitFor(
        tester,
        () => tester
            .widget<TextField>(entryField('target'))
            .controller!
            .text
            .isEmpty,
      );
      await tester.enterText(entryField('target'), draftTarget);
      await tester.enterText(entryField('native'), 'Raw unfinished $runId');
      expect(
        tester.widget<TextField>(entryField('target')).controller!.text,
        draftTarget,
      );
      final state = await snapshot(db);
      final owner = (state['collections'] as List).cast<Map>().singleWhere(
        (row) => row['name'] == collectionName,
      );
      final entry = (state['vocabulary_entries'] as List)
          .cast<Map>()
          .singleWhere((row) => row['collection_id'] == owner['id']);
      final learning = (state['learning_items'] as List)
          .cast<Map>()
          .where((row) => row['entry_id'] == entry['id'])
          .toList();
      expect(learning, hasLength(2));
      expect(owner['target_language'], VocabularyLanguage.korean.code);
      expect(owner['native_language'], VocabularyLanguage.german.code);
      expect(entry['target_text'], '학교-$runId');
      expect(entry['native_text'], 'Schule-$runId');
      expect(entry['target_key'], vocabularyComparisonKey('학교-$runId'));
      expect(entry['native_key'], vocabularyComparisonKey('Schule-$runId'));
      expectBaseline(
        baseline,
        state,
        ownedCollection: owner['id'] as String,
        ownedEntry: entry['id'] as String,
      );
      final checkpoint = <String, dynamic>{
        'phase': 'ready',
        'run': runId,
        'baseline': baseline,
        'owner': owner,
        'entry': entry,
        'learning': learning,
        'ungraded': {for (final table in ungradedTables) table: <Object?>[]},
        'draft': draftTarget,
      };
      expectOwned(checkpoint, state);
      await writeCheckpoint(file, checkpoint);
      // External coordinator kills the still-live process; deliberately no close,
      // route pop, completed test or finally cleanup before that abrupt boundary.
      // ignore: avoid_print
      print('ENTRY008_READY:$runId');
      await Completer<void>().future;
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
