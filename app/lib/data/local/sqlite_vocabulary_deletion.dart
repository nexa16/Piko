import 'dart:async';
import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import '../../core/clock.dart';
import '../vocabulary_deletion.dart';
import '../vocabulary_repository.dart';
import 'piko_database.dart';

final class _Snapshot {
  const _Snapshot(this.rowId, this.entry, this.learning, this.reviews);
  final int rowId;
  final VocabularyEntry entry;
  final List<LearningItem> learning;
  final List<RegularReview> reviews;
}

final class _Receipt implements VocabularyDeletionReceipt {
  _Receipt({
    required this.issuer,
    required this.entry,
    required this.expiresAt,
    required this.snapshot,
  });
  final Object issuer;
  @override
  final VocabularyRecord entry;
  @override
  final DateTime expiresAt;
  _Snapshot? snapshot;
  Future<VocabularyRecord>? pending;
  bool used = false, expired = false, forgotten = false;
}

/// Temporary in-memory snapshots only; it does not own the database. Callers
/// schedule expireUndo at receipt deadlines and forget/dispose on lifecycle end.
final class SqliteVocabularyDeletionService
    implements VocabularyDeletionService {
  SqliteVocabularyDeletionService(this.database, {PikoClock? clock})
    : clock = clock ?? database.clock;
  final PikoDatabase database;
  final PikoClock clock;
  static const undoDuration = Duration(seconds: 8);
  final _issuer = Object();
  final Set<_Receipt> _active = {};
  bool _disposed = false;

  void _ensureActive() {
    if (_disposed) {
      throw StateError('The vocabulary deletion service has ended.');
    }
  }

  _Receipt _issued(VocabularyDeletionReceipt receipt) {
    if (receipt is! _Receipt ||
        !identical(receipt.issuer, _issuer) ||
        receipt.forgotten) {
      throw VocabularyUndoFailure.invalidReceipt;
    }
    return receipt;
  }

  @override
  void expireUndo() {
    final now = clock.now().toUtc();
    for (final receipt in _active.toList(growable: false)) {
      if (receipt.pending == null && !now.isBefore(receipt.expiresAt)) {
        receipt.expired = true;
        receipt.snapshot = null;
        _active.remove(receipt);
      }
    }
  }

  @override
  bool canUndo(VocabularyDeletionReceipt receipt) {
    if (_disposed) return false;
    if (receipt is! _Receipt ||
        !identical(receipt.issuer, _issuer) ||
        receipt.forgotten ||
        receipt.expired ||
        receipt.used) {
      return false;
    }
    expireUndo();
    return identical(receipt.issuer, _issuer) &&
        !receipt.forgotten &&
        !receipt.expired &&
        !receipt.used &&
        receipt.pending == null &&
        receipt.snapshot != null;
  }

  @override
  void forget(VocabularyDeletionReceipt receipt) {
    final issued = _issued(receipt);
    issued.forgotten = true;
    issued.snapshot = null;
    _active.remove(issued);
  }

  @override
  void dispose() {
    _disposed = true;
    for (final receipt in _active) {
      receipt.forgotten = true;
      receipt.snapshot = null;
    }
    _active.clear();
  }

  @override
  Future<VocabularyDeletionReceipt> delete(String id) async {
    _ensureActive();
    expireUndo();
    final receipt = await database.transaction(() async {
      _ensureActive();
      final row = await database
          .customSelect(
            'SELECT rowid AS original_rowid, * FROM vocabulary_entries WHERE id = ?',
            variables: [Variable(id)],
          )
          .getSingleOrNull();
      if (row == null) throw VocabularyValidation.entryNotFound;
      final entry = database.vocabularyEntries.map(row.data);
      final learning = await (database.select(
        database.learningItems,
      )..where((item) => item.entryId.equals(id))).get();
      final reviewRows = await database
          .customSelect(
            'SELECT * FROM regular_reviews WHERE item_id IN '
            '(SELECT id FROM learning_items WHERE entry_id = ?) ORDER BY rowid',
            variables: [Variable(id)],
          )
          .get();
      final snapshot = _Snapshot(
        row.read<int>('original_rowid'),
        entry,
        List.unmodifiable(learning),
        List.unmodifiable(
          reviewRows.map((row) => database.regularReviews.map(row.data)),
        ),
      );
      await (database.delete(
        database.vocabularyEntries,
      )..where((item) => item.id.equals(id))).go();
      database.notifyUpdates({
        TableUpdate.onTable(database.learningItems, kind: UpdateKind.delete),
        TableUpdate.onTable(database.regularReviews, kind: UpdateKind.delete),
      });
      // Deadline/receipt construction belongs to the transaction: a fallible
      // clock cannot commit a deletion without issuing its Undo capability.
      return _Receipt(
        issuer: _issuer,
        entry: VocabularyRecord(
          id: entry.id,
          collectionId: entry.collectionId,
          targetText: entry.targetText,
          nativeText: entry.nativeText,
        ),
        expiresAt: clock.now().toUtc().add(undoDuration),
        snapshot: snapshot,
      );
    });
    if (_disposed) {
      receipt.forgotten = true;
      receipt.snapshot = null;
    } else {
      _active.add(receipt);
    }
    return receipt;
  }

  @override
  Future<VocabularyRecord> restore(VocabularyDeletionReceipt receipt) {
    _ensureActive();
    final issued = _issued(receipt);
    if (issued.pending != null) return issued.pending!;
    if (issued.used) throw VocabularyUndoFailure.alreadyUsed;
    if (issued.expired) throw VocabularyUndoFailure.expired;
    expireUndo();
    if (issued.expired || issued.snapshot == null) {
      throw VocabularyUndoFailure.expired;
    }
    final result = Completer<VocabularyRecord>();
    issued.pending = result.future;
    unawaited(_restore(issued, result));
    return result.future;
  }

  Future<void> _restore(
    _Receipt receipt,
    Completer<VocabularyRecord> result,
  ) async {
    try {
      await database.transaction(() async {
        _ensureActive();
        if (receipt.forgotten) throw VocabularyUndoFailure.invalidReceipt;
        if (!clock.now().toUtc().isBefore(receipt.expiresAt)) {
          throw VocabularyUndoFailure.expired;
        }
        final snapshot = receipt.snapshot!;
        final entry = snapshot.entry;
        if (await (database.select(database.collections)
                  ..where((row) => row.id.equals(entry.collectionId)))
                .getSingleOrNull() ==
            null) {
          throw VocabularyUndoFailure.collectionNotFound;
        }
        final existing = await database
            .customSelect(
              'SELECT id FROM vocabulary_entries WHERE id = ? OR rowid = ?',
              variables: [Variable(entry.id), Variable(snapshot.rowId)],
            )
            .get();
        if (existing.isNotEmpty) throw VocabularyUndoFailure.identityConflict;
        final learningIds = snapshot.learning.map((item) => item.id).toList();
        if (learningIds.isNotEmpty &&
            (await (database.select(
              database.learningItems,
            )..where((row) => row.id.isIn(learningIds))).get()).isNotEmpty) {
          throw VocabularyUndoFailure.identityConflict;
        }
        final reviewIds = snapshot.reviews.map((review) => review.id).toList();
        if (reviewIds.isNotEmpty &&
            (await (database.select(
              database.regularReviews,
            )..where((row) => row.id.isIn(reviewIds))).get()).isNotEmpty) {
          throw VocabularyUndoFailure.identityConflict;
        }
        await database.customInsert(
          'INSERT INTO vocabulary_entries (rowid, id, collection_id, target_text, native_text, target_key, native_key) VALUES (?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable(snapshot.rowId),
            Variable(entry.id),
            Variable(entry.collectionId),
            Variable(entry.targetText),
            Variable(entry.nativeText),
            Variable(entry.targetKey),
            Variable(entry.nativeKey),
          ],
          updates: {database.vocabularyEntries},
        );
        for (final item in snapshot.learning) {
          await database.into(database.learningItems).insert(item);
        }
        // Entire items were deleted; insertion in original order preserves each
        // item's history order without making physical rowid a domain identity.
        for (final review in snapshot.reviews) {
          await database.into(database.regularReviews).insert(review);
        }
      });
      receipt.used = true;
      receipt.snapshot = null;
      _active.remove(receipt);
      result.complete(receipt.entry);
    } catch (error, stack) {
      if (error == VocabularyUndoFailure.expired) {
        receipt.expired = true;
        receipt.snapshot = null;
        _active.remove(receipt);
      }
      final Object failure =
          error is SqliteException &&
              error.extendedResultCode == 2067 &&
              error.message.contains(
                'vocabulary_entries.collection_id, vocabulary_entries.target_key, vocabulary_entries.native_key',
              )
          ? VocabularyUndoFailure.duplicatePair
          : error;
      result.completeError(failure, stack);
    } finally {
      receipt.pending = null;
      if (!receipt.used) {
        try {
          expireUndo();
        } catch (_) {
          // A failed clock cannot retain a capability indefinitely or produce
          // a second unhandled error after the caller's result has resolved.
          receipt.expired = true;
          receipt.snapshot = null;
          _active.remove(receipt);
        }
      }
    }
  }
}
