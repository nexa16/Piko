import 'dart:async';
import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import '../../core/clock.dart';
import '../vocabulary_deletion.dart';
import '../vocabulary_repository.dart';
import '../retry_obligation.dart';
import '../categories_repository.dart';
import 'piko_database.dart';
import 'sqlite_categories_repository.dart';

final class _Snapshot {
  const _Snapshot(
    this.rowId,
    this.entry,
    this.learning,
    this.reviews,
    this.retries,
    this.assignments,
  );
  final int rowId;
  final VocabularyEntry entry;
  final List<LearningItem> learning;
  final List<RegularReview> reviews;
  final List<StoredRetryObligation> retries;
  final List<StoredCategoryAssignment> assignments;
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
      final retryRows =
          await (database.select(database.retryObligations)..where(
                (retry) => retry.itemId.isIn(learning.map((item) => item.id)),
              ))
              .get();
      final assignments = await (database.select(
        database.vocabularyCategoryAssignments,
      )..where((row) => row.entryId.equals(id))).get();
      for (final retry in retryRows) {
        final record = _retryRecord(retry);
        final origins = reviewRows.where(
          (row) => row.read<String>('id') == record.originReviewId,
        );
        final owners = learning.where(
          (item) =>
              item.id == record.itemId && item.generation == record.generation,
        );
        if (owners.length != 1 ||
            origins.length != 1 ||
            origins.single.read<int>('item_id') != record.itemId ||
            origins.single.read<int>('generation') != record.generation ||
            origins.single.read<String>('rating') != 'again' ||
            DateTime.tryParse(origins.single.read<String>('reviewed_at')) !=
                record.createdAt) {
          throw const FormatException('Invalid retry snapshot origin');
        }
      }
      await (database.delete(
        database.vocabularyEntries,
      )..where((item) => item.id.equals(id))).go();
      database.notifyUpdates({
        TableUpdate.onTable(database.learningItems, kind: UpdateKind.delete),
        TableUpdate.onTable(database.regularReviews, kind: UpdateKind.delete),
        TableUpdate.onTable(database.retryObligations, kind: UpdateKind.delete),
        TableUpdate.onTable(
          database.vocabularyCategoryAssignments,
          kind: UpdateKind.delete,
        ),
      });
      // Deadline/receipt construction belongs to the transaction: a fallible
      // clock cannot commit a deletion without issuing its Undo capability.
      final deleteAt = clock.now().toUtc();
      final snapshot = _Snapshot(
        row.read<int>('original_rowid'),
        entry,
        List.unmodifiable(learning),
        List.unmodifiable(
          reviewRows.map((row) => database.regularReviews.map(row.data)),
        ),
        List.unmodifiable(
          retryRows.where(
            (retry) => deleteAt.isBefore(_retryRecord(retry).expiresAt),
          ),
        ),
        List.unmodifiable(assignments),
      );
      return _Receipt(
        issuer: _issuer,
        entry: VocabularyRecord(
          id: entry.id,
          collectionId: entry.collectionId,
          targetText: entry.targetText,
          nativeText: entry.nativeText,
        ),
        expiresAt: deleteAt.add(undoDuration),
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
        final now = clock.now().toUtc();
        if (!now.isBefore(receipt.expiresAt)) {
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
        // Undo never resets a retry deadline or recreates an expired obligation.
        final retries = snapshot.retries
            .where((retry) => now.isBefore(_retryRecord(retry).expiresAt))
            .toList(growable: false);
        final retryIds = retries.map((retry) => retry.id).toList();
        if (retryIds.isNotEmpty &&
            (await (database.select(
              database.retryObligations,
            )..where((row) => row.id.isIn(retryIds))).get()).isNotEmpty) {
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
        for (final retry in retries) {
          await database.into(database.retryObligations).insert(retry);
        }
        final assignments = <String, Set<String>>{};
        for (final assignment in snapshot.assignments) {
          // Explicit category deletion remains effective after vocabulary Undo.
          // Restore exact assignments only while both original owners survive.
          final surviving = await database
              .customSelect(
                'SELECT v.id FROM category_values v JOIN category_dimensions d ON d.id = v.dimension_id '
                'WHERE v.id = ? AND d.id = ? AND d.collection_id = ?',
                variables: [
                  Variable(assignment.valueId),
                  Variable(assignment.dimensionId),
                  Variable(entry.collectionId),
                ],
              )
              .getSingleOrNull();
          if (surviving != null) {
            assignments
                .putIfAbsent(assignment.dimensionId, () => <String>{})
                .add(assignment.valueId);
          }
        }
        try {
          await SqliteCategoriesRepository(
            database,
          ).replaceAssignments(entryId: entry.id, assignments: assignments);
        } on CategoryValidation catch (error) {
          if (error == CategoryValidation.cardinalityViolation) {
            throw VocabularyUndoFailure.categoryConflict;
          }
          rethrow;
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

  RetryObligation _retryRecord(StoredRetryObligation row) =>
      RetryObligation.fromStored(
        id: row.id,
        itemId: row.itemId,
        generation: row.generation,
        revision: row.revision,
        originReviewId: row.originReviewId,
        createdAt: row.createdAt,
        expiresAt: row.expiresAt,
        errorCount: row.errorCount,
        dueOrdinal: row.dueOrdinal,
        waitEligibleAt: row.waitEligibleAt,
      );
}
