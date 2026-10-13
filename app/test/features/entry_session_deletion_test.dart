import 'dart:async';
import 'dart:convert';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/vocabulary_deletion.dart';
import 'package:piko/core/clock.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import '../support/entry_deletion_fixture.dart';

class FallibleSchedulingClock implements PikoClock {
  FallibleSchedulingClock(this.instant);
  final DateTime instant;
  int calls = 0;
  @override
  DateTime now() {
    if (calls++ == 0) return instant;
    throw StateError('Clock read failed');
  }
}

void main() {
  late EntryDeletionFixture f;
  setUp(() async {
    f = EntryDeletionFixture();
    await f.initialize();
  });
  tearDown(() => f.dispose());

  test(
    'clock failure after committed deletion cannot misreport failure or leak an unscheduled receipt',
    () async {
      f.session = EntrySessionController(
        collectionId: f.owner.id,
        repository: f.repository,
        deletionService: f.deletion,
        clock: FallibleSchedulingClock(f.clock.now()),
      );
      f.sessions.add(f.session);
      final saved = await f.confirm('One', 'Eins');
      final receipt = await f.session.deleteSavedEntry(saved.id);
      expect(f.session.confirmedEntries, isEmpty);
      expect(f.session.undoEntries.single.entry.id, saved.id);
      expect(f.deletion.canUndo(receipt), isTrue);
      f.session.forgetUndo();
      expect(f.deletion.canUndo(receipt), isFalse);
    },
  );

  test(
    'disposal while draining blocks a new delete but accepted autosave finishes without notifications',
    () async {
      final saved = await f.confirm('One', 'Eins');
      final gate = Completer<void>();
      f.repository.updateGates[saved.id] = gate;
      f.session.editSavedEntry(saved.id, nativeText: 'Saved edit');
      final deleting = f.session.deleteSavedEntry(saved.id);
      final expectation = expectLater(deleting, throwsStateError);
      var notifications = 0;
      f.session.addListener(() => notifications++);
      f.sessions.remove(f.session);
      f.session.dispose();
      gate.complete();
      await expectation;
      await f.session.awaitSavedEdits();
      expect(f.deletion.deletes, 0);
      expect(notifications, 0);
      expect(
        (await f.db.select(f.db.vocabularyEntries).get()).single.nativeText,
        'Saved edit',
      );
    },
  );

  test(
    'disposal after delete commit forgets late receipt without disposing service or notifying',
    () async {
      final saved = await f.confirm('One', 'Eins');
      f.deletion.afterDeleteGate = Completer<void>();
      final deleting = f.session.deleteSavedEntry(saved.id);
      while (f.deletion.receipts.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      var notifications = 0;
      f.session.addListener(() => notifications++);
      f.sessions.remove(f.session);
      f.session.dispose();
      f.deletion.afterDeleteGate!.complete();
      final receipt = await deleting;
      expect(notifications, 0);
      expect(f.deletion.canUndo(receipt), isFalse);
      expect(f.deletion.disposals, 0);
      expect(f.session.confirmedEntries, isEmpty);
    },
  );

  test(
    'forgetting an offer after restore commit cannot lose live session bookkeeping',
    () async {
      final saved = await f.confirm('One', 'Eins');
      await f.session.deleteSavedEntry(saved.id);
      f.deletion.afterRestoreGate = Completer<void>();
      final restoring = f.session.undoDeletion(saved.id);
      while ((await f.db.select(f.db.vocabularyEntries).get()).isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      f.session.forgetUndo();
      f.deletion.afterRestoreGate!.complete();
      await restoring;
      expect(f.session.confirmedEntries.single.id, saved.id);
      expect(f.session.savedEntryState(saved.id).draft.nativeText, 'Eins');
      expect(f.session.undoEntries, isEmpty);
    },
  );

  test(
    'delete/Undo restores vocabulary and complete directional state, not invalid raw buffer',
    () async {
      final saved = await f.confirm('Café', 'Kaffee');
      final items = await f.db.select(f.db.learningItems).get();
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final card = fsrs.Card(
          cardId: item.id,
          state: index == 0 ? fsrs.State.review : fsrs.State.relearning,
          step: index == 0 ? null : 2,
          stability: 4 + index.toDouble(),
          difficulty: 5 - index.toDouble(),
          due: f.clock.now().add(Duration(days: index + 1)),
          lastReview: f.clock.now().subtract(const Duration(days: 1)),
        );
        await f.db.customStatement(
          'UPDATE learning_items SET card_json = ? WHERE id = ?',
          [jsonEncode(card.toMap()), item.id],
        );
      }
      final before =
          (await f.db
                  .customSelect('SELECT * FROM learning_items ORDER BY id')
                  .get())
              .map((r) => r.data)
              .toList();
      f.session.editSavedEntry(saved.id, targetText: ' ');
      f.session.setTargetText(' raw draft ');
      f.session.setNativeText('  ');
      await f.session.deleteSavedEntry(saved.id);
      expect(await f.db.select(f.db.learningItems).get(), isEmpty);
      expect(f.session.draft.targetText, ' raw draft ');
      await f.session.undoDeletion(saved.id);
      expect(
        (await f.db
                .customSelect('SELECT * FROM learning_items ORDER BY id')
                .get())
            .map((r) => r.data)
            .toList(),
        before,
      );
      expect(f.session.savedEntryState(saved.id).draft.targetText, 'Café');
      expect(f.session.savedEntryState(saved.id).error, isNull);
      expect(f.session.activeEntryId, isNull);
    },
  );

  test(
    'target save queue drains independently; busy repeats and competing actions are guarded',
    () async {
      final first = await f.confirm('One', 'Eins'),
          other = await f.confirm('Two', 'Zwei');
      final gate = Completer<void>(), unrelated = Completer<void>();
      f.repository.updateGates[first.id] = gate;
      f.repository.updateGates[other.id] = unrelated;
      f.session.editSavedEntry(first.id, nativeText: 'First');
      f.session.editSavedEntry(first.id, nativeText: 'Latest');
      f.session.editSavedEntry(other.id, nativeText: 'Other');
      final deletion = f.session.deleteSavedEntry(first.id);
      expect(identical(deletion, f.session.deleteSavedEntry(first.id)), isTrue);
      expect(f.session.isBusy, isTrue);
      expect(f.deletion.deletes, 0);
      expect(() => f.session.completeSession(), throwsStateError);
      expect(() => f.session.confirmAndNext(), throwsStateError);
      expect(() => f.session.setTargetText('new'), throwsStateError);
      expect(() => f.session.selectSavedEntry(other.id), throwsStateError);
      gate.complete();
      await deletion;
      expect(f.deletion.receipts.single.entry.nativeText, 'Latest');
      expect(f.session.savedEntryState(other.id).isSaving, isTrue);
      await f.session.undoDeletion(first.id);
      unrelated.complete();
      await f.session.awaitSavedEdits();
      expect(f.session.savedEntryState(other.id).draft.nativeText, 'Other');
    },
  );

  test(
    'first/middle/last and active/inactive removal preserve identities and original ordinals',
    () async {
      final a = await f.confirm('One', 'Eins'),
          b = await f.confirm('Two', 'Zwei'),
          c = await f.confirm('Three', 'Drei');
      f.session.selectSavedEntry(b.id);
      await f.session.deleteSavedEntry(a.id);
      expect(f.session.activeEntryId, b.id);
      await f.session.deleteSavedEntry(b.id);
      expect(f.session.activeEntryId, c.id);
      await f.session.deleteSavedEntry(c.id);
      expect(f.session.activeEntryId, isNull);
      final d = await f.confirm('Four', 'Vier');
      await f.session.undoDeletion(b.id);
      await f.session.undoDeletion(a.id);
      await f.session.undoDeletion(c.id);
      expect(f.session.confirmedEntries.map((e) => e.id), [
        a.id,
        b.id,
        c.id,
        d.id,
      ]);
      expect(f.session.activeEntryId, isNull);
      expect(
        () => f.session.undoDeletion(a.id),
        throwsA(VocabularyUndoFailure.invalidReceipt),
      );
    },
  );

  test(
    'delete failure keeps saved card; restore conflict remains retryable with deadline unchanged',
    () async {
      final saved = await f.confirm('One', 'Eins');
      f.deletion.failDelete = true;
      await expectLater(f.session.deleteSavedEntry(saved.id), throwsStateError);
      expect(f.session.confirmedEntries.single.id, saved.id);
      f.deletion.failDelete = false;
      await f.session.deleteSavedEntry(saved.id);
      final deadline = f.session.undoEntries.single.expiresAt;
      final collision = await f.repository.create(
        collectionId: f.owner.id,
        targetText: 'One',
        nativeText: 'Eins',
      );
      await expectLater(
        f.session.undoDeletion(saved.id),
        throwsA(VocabularyUndoFailure.duplicatePair),
      );
      expect(f.session.undoEntries.single.expiresAt, deadline);
      final temporary = await f.deletion.real.delete(collision.id);
      f.deletion.real.forget(temporary);
      f.deletion.restoreGate = Completer<void>();
      final restoring = f.session.undoDeletion(saved.id);
      expect(identical(restoring, f.session.undoDeletion(saved.id)), isTrue);
      expect(f.session.undoEntries, hasLength(1));
      f.deletion.restoreGate!.complete();
      await restoring;
      expect(f.session.undoEntries, isEmpty);
    },
  );

  test(
    'forgotten lifetime cannot retain a late receipt and does not dispose injected service',
    () async {
      final saved = await f.confirm('One', 'Eins');
      f.deletion.deleteGate = Completer<void>();
      final result = f.session.deleteSavedEntry(saved.id);
      f.session.forgetUndo();
      f.deletion.deleteGate!.complete();
      final receipt = await result;
      expect(f.session.undoEntries, isEmpty);
      expect(f.deletion.canUndo(receipt), isFalse);
      expect(f.deletion.disposals, 0);
    },
  );
}
