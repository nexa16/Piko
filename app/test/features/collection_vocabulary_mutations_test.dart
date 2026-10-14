import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/core/clock.dart';
import 'package:piko/data/vocabulary_deletion.dart';
import 'package:piko/features/vocabulary/collection_vocabulary_mutations.dart';
import 'package:piko/features/vocabulary/inline_vocabulary_edit_controller.dart';
import '../support/collection_deletion_fixture.dart';

class SchedulingFailure implements PikoClock {
  SchedulingFailure(this.instant);
  final DateTime instant;
  var reads = 0;
  @override
  DateTime now() {
    if (reads++ == 0) return instant;
    throw StateError('Clock unavailable');
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
void main() {
  late CollectionDeletionFixture f;
  setUp(() async {
    f = CollectionDeletionFixture();
    await f.initialize();
  });
  tearDown(() => f.dispose());
  test(
    'real deletion and Undo retain exact identity, insertion position, texts and complete direction states',
    () async {
      final entry = f.entries[1];
      final items = await f.db.select(f.db.learningItems).get();
      // Persist distinct valid card states using existing complete JSON shapes.
      for (var i = 0; i < items.length; i++) {
        final json = jsonDecode(items[i].cardJson) as Map<String, dynamic>;
        json['stability'] = 3.5 + i;
        json['difficulty'] = 6.0;
        await f.db.customStatement(
          'UPDATE learning_items SET card_json = ? WHERE id = ?',
          [jsonEncode(json), items[i].id],
        );
      }
      final before =
          (await f.db
                  .customSelect('SELECT * FROM learning_items ORDER BY id')
                  .get())
              .map((r) => r.data)
              .toList();
      await f.mutations.delete(entry);
      final offer = f.mutations.latest!;
      expect(
        (await f.real.watchByCollection(f.owner.id).first).map((r) => r.id),
        [f.entries[0].id, f.entries[2].id],
      );
      await f.mutations.undo(offer);
      expect(
        (await f.real.watchByCollection(f.owner.id).first).map((r) => r.id),
        f.entries.map((r) => r.id),
      );
      expect(
        (await f.db
                .customSelect('SELECT * FROM learning_items ORDER BY id')
                .get())
            .map((r) => r.data)
            .toList(),
        before,
      );
      expect(f.mutations.offers, isEmpty);
      expect(
        () => f.mutations.undo(offer),
        throwsA(VocabularyUndoFailure.invalidReceipt),
      );
    },
  );
  test(
    'target-only queued writes drain before delete; invalid latest buffer never replaces restored stored pair',
    () async {
      final entry = f.entries[0];
      final gate = Completer<void>();
      f.repository.updateGates[entry.id] = gate;
      final edit = await InlineVocabularyEditController.open(
        entryId: entry.id,
        collectionId: entry.collectionId,
        repository: f.repository,
      );
      addTearDown(edit.dispose);
      edit.setTargetText('Accepted A');
      edit.setTargetText('Accepted B');
      edit.setNativeText(' ');
      final deleting = f.mutations.delete(
        entry,
        acceptedWrites: edit.awaitSavedEdits(),
      );
      expect(f.deletion.deletes, 0);
      expect(f.mutations.delete(entry), same(deleting));
      gate.complete();
      await deleting;
      expect(f.mutations.latest!.entry.targetText, 'Accepted B');
      expect(f.mutations.latest!.entry.nativeText, entry.nativeText);
      await f.mutations.undo(f.mutations.latest!);
      expect(
        (await f.real.watchById(entry.id).first)!.targetText,
        'Accepted B',
      );
    },
  );
  test(
    'failure keeps retryable offer and original deadline; conflict never overwrites another pair',
    () async {
      f.deletion.failDelete = true;
      await expectLater(f.mutations.delete(f.entries[0]), throwsStateError);
      expect(f.mutations.offers, isEmpty);
      f.deletion.failDelete = false;
      await f.mutations.delete(f.entries[0]);
      final offer = f.mutations.latest!;
      final deadline = offer.receipt.expiresAt;
      final duplicate = await f.real.create(
        collectionId: f.owner.id,
        targetText: 'One',
        nativeText: 'Eins',
      );
      await expectLater(
        f.mutations.undo(offer),
        throwsA(VocabularyUndoFailure.duplicatePair),
      );
      expect(f.mutations.latest, same(offer));
      expect(offer.receipt.expiresAt, deadline);
      await f.deletion.real.delete(duplicate.id);
      await f.mutations.undo(offer);
      expect(f.mutations.offers, isEmpty);
    },
  );
  test(
    'end during accepted-save drain cancels only not-started deletion and closes service after drain',
    () async {
      final gate = Completer<void>();
      final deleting = f.mutations.delete(
        f.entries[0],
        acceptedWrites: gate.future,
      );
      final failure = expectLater(deleting, throwsStateError);
      final ending = f.mutations.end();
      expect(f.deletion.disposals, 0);
      gate.complete();
      await failure;
      await ending;
      expect(f.deletion.deletes, 0);
      expect(f.deletion.disposals, 1);
    },
  );
  test(
    'accepted Undo survives route ending before transaction starts; no late notifications',
    () async {
      await f.mutations.delete(f.entries[0]);
      final offer = f.mutations.latest!;
      final gate = Completer<void>();
      f.deletion.restoreGate = gate;
      var notifications = 0;
      f.mutations.addListener(() => notifications++);
      final restoring = f.mutations.undo(offer);
      final prior = notifications;
      final ending = f.mutations.end();
      expect(f.deletion.disposals, 0);
      gate.complete();
      await restoring;
      await ending;
      expect(
        (await f.real.watchById(f.entries[0].id).first)!.id,
        f.entries[0].id,
      );
      expect(notifications, prior);
      expect(f.deletion.disposals, 1);
    },
  );
  test(
    'late delete receipt is forgotten; postcommit scheduling clock failure cannot report failed deletion',
    () async {
      final gate = Completer<void>();
      f.deletion.afterDeleteGate = gate;
      final deleting = f.mutations.delete(f.entries[0]);
      while (f.deletion.receipts.isEmpty) {
        await tick();
      }
      final receipt = f.deletion.receipts.single;
      final ending = f.mutations.end();
      gate.complete();
      await deleting;
      await ending;
      expect(f.deletion.real.canUndo(receipt), isFalse);
      expect(f.mutations.latest, isNull);
      // The route-owned service above ended; use a fresh fixture for this boundary.
      final fresh = CollectionDeletionFixture();
      await fresh.initialize();
      addTearDown(fresh.dispose);
      final controller = CollectionVocabularyMutations(
        collectionId: fresh.owner.id,
        service: fresh.deletion,
        clock: SchedulingFailure(fresh.clock.now()),
      );
      await controller.delete(fresh.entries[0]);
      expect(controller.deleteError, isNull);
      expect(controller.latest, isNotNull);
      await controller.end();
    },
  );
  testWidgets(
    'two deadlines never extend; pending restore stays offered and backward clock reschedules expiry',
    (tester) async {
      await tester.runAsync(() => f.mutations.delete(f.entries[0]));
      final older = f.mutations.latest!;
      f.clock.advance(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      await tester.runAsync(() => f.mutations.delete(f.entries[1]));
      final latest = f.mutations.latest!;
      final gate = Completer<void>();
      f.deletion.restoreGate = gate;
      final restoring = f.mutations.undo(latest);
      expect(f.mutations.latest, same(latest));
      expect(f.mutations.canUndo(latest), isFalse);
      gate.complete();
      await tester.runAsync(() => restoring);
      expect(f.mutations.latest, same(older));
      f.clock.set(DateTime.utc(2026, 10, 14));
      await tester.pump(const Duration(seconds: 6));
      expect(f.mutations.latest, same(older));
      expect(older.receipt.expiresAt, DateTime.utc(2026, 10, 14, 0, 0, 8));
      f.clock.advance(const Duration(seconds: 8));
      await tester.pump(const Duration(seconds: 8));
      expect(f.mutations.latest, isNull);
    },
  );
}
