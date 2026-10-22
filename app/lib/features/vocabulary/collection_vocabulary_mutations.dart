import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/clock.dart';
import '../../data/vocabulary_deletion.dart';
import '../../data/vocabulary_repository.dart';

typedef CollectionVocabularyMutationsFactory =
    CollectionVocabularyMutations Function(String collectionId);

final class CollectionUndoOffer {
  CollectionUndoOffer(this.receipt);
  final VocabularyDeletionReceipt receipt;
  Object? error;
  Timer? timer;
  VocabularyRecord get entry => receipt.entry;
}

/// Owns one Collection route's temporary deletion offers, never its row list or
/// editor buffers. Repository streams remain authoritative after delete/Undo.
final class CollectionVocabularyMutations extends ChangeNotifier {
  CollectionVocabularyMutations({
    required this.collectionId,
    required VocabularyDeletionService service,
    required PikoClock clock,
    // Public dependency names remain independent of private implementation fields.
    // ignore: prefer_initializing_formals
  }) : _service = service,
       // ignore: prefer_initializing_formals
       _clock = clock;
  final String collectionId;
  final VocabularyDeletionService _service;
  final PikoClock _clock;
  final _offers = <CollectionUndoOffer>[];
  Future<void>? _pending, _ending;
  bool _ended = false;
  String? deletingId, restoringId;
  Object? deleteError;
  String? errorEntryId;
  bool get isBusy => _pending != null;
  bool get supportsBatch => _service is VocabularyBatchDeletionService;

  Future<void> deleteMany(Set<String> ids) {
    if (_ended || isBusy || !supportsBatch) {
      throw StateError('Collection batch deletion unavailable.');
    }
    final selected = Set<String>.of(ids);
    final done = Completer<void>();
    _pending = done.future;
    deleteError = null;
    errorEntryId = null;
    notifyListeners();
    unawaited(() async {
      try {
        final startedAt = _clock.now().toUtc();
        final receipts = await (_service as VocabularyBatchDeletionService)
            .deleteMany(collectionId: collectionId, ids: selected);
        for (final receipt in receipts) {
          if (_ended) {
            _forgetReceipt(receipt);
          } else {
            final offer = CollectionUndoOffer(receipt);
            _offers.add(offer);
            _schedule(offer, fallback: startedAt);
          }
        }
        done.complete();
      } catch (error, stack) {
        if (!_ended) deleteError = error;
        done.completeError(error, stack);
      } finally {
        _pending = null;
        if (!_ended) notifyListeners();
      }
    }());
    return done.future;
  }

  Future<void> awaitPending() async {
    while (_pending != null) {
      try {
        await _pending;
      } catch (_) {
        /* The initiating action reports errors. */
      }
    }
  }

  CollectionUndoOffer? get latest => _offers.lastOrNull;
  List<CollectionUndoOffer> get offers => List.unmodifiable(_offers);
  bool canUndo(CollectionUndoOffer offer) {
    if (_ended || isBusy || !_offers.contains(offer)) return false;
    try {
      return _service.canUndo(offer.receipt);
    } catch (_) {
      return false;
    }
  }

  Future<void> delete(VocabularyRecord entry, {Future<void>? acceptedWrites}) {
    if (_pending != null && deletingId == entry.id) return _pending!;
    if (_ended || isBusy) throw StateError('Collection mutation unavailable.');
    if (entry.collectionId != collectionId) {
      throw StateError('Foreign Collection entry.');
    }
    final done = Completer<void>();
    deletingId = entry.id;
    errorEntryId = null;
    deleteError = null;
    _pending = done.future;
    notifyListeners();
    unawaited(_delete(entry, acceptedWrites, done));
    return done.future;
  }

  Future<void> _delete(
    VocabularyRecord entry,
    Future<void>? drain,
    Completer<void> done,
  ) async {
    try {
      if (drain != null) await drain;
      if (_ended) throw StateError('Collection route ended before deletion.');
      final startedAt = _clock.now().toUtc();
      final receipt = await _service.delete(entry.id);
      if (receipt.entry.id != entry.id ||
          receipt.entry.collectionId != collectionId) {
        _forgetReceipt(receipt);
        throw StateError('Deletion returned a different identity.');
      }
      if (_ended) {
        _forgetReceipt(receipt);
      } else {
        final offer = CollectionUndoOffer(receipt);
        _offers.add(offer);
        _schedule(offer, fallback: startedAt);
      }
      done.complete();
    } catch (error, stack) {
      if (!_ended) {
        deleteError = error;
        errorEntryId = entry.id;
      }
      done.completeError(error, stack);
    } finally {
      _pending = null;
      deletingId = null;
      if (!_ended) notifyListeners();
    }
  }

  Future<void> undo(CollectionUndoOffer offer) {
    if (_pending != null && restoringId == offer.entry.id) return _pending!;
    if (_ended || isBusy) throw StateError('Collection mutation unavailable.');
    if (!_offers.contains(offer)) throw VocabularyUndoFailure.invalidReceipt;
    final done = Completer<void>();
    restoringId = offer.entry.id;
    offer.error = null;
    _pending = done.future;
    notifyListeners();
    unawaited(_undo(offer, done));
    return done.future;
  }

  Future<void> _undo(CollectionUndoOffer offer, Completer<void> done) async {
    try {
      final restored = await _service.restore(offer.receipt);
      if (restored.id != offer.entry.id ||
          restored.collectionId != collectionId) {
        throw StateError('Undo returned a different identity.');
      }
      // A committed restoration succeeds even if route teardown already forgot
      // its offer. No manual row reinsertion or stale editor resurrection.
      if (_offers.contains(offer)) _forget(offer);
      done.complete();
    } catch (error, stack) {
      if (!_ended && _offers.contains(offer)) offer.error = error;
      done.completeError(error, stack);
    } finally {
      _pending = null;
      restoringId = null;
      if (!_ended) _expire();
    }
  }

  void _forgetReceipt(VocabularyDeletionReceipt receipt) {
    try {
      _service.forget(receipt);
    } catch (_) {
      /* Issuer may already be ended. */
    }
  }

  void _forget(CollectionUndoOffer offer) {
    offer.timer?.cancel();
    _offers.remove(offer);
    _forgetReceipt(offer.receipt);
  }

  void _schedule(CollectionUndoOffer offer, {DateTime? fallback}) {
    offer.timer?.cancel();
    DateTime now;
    try {
      now = _clock.now().toUtc();
    } catch (_) {
      if (fallback == null) rethrow;
      now = fallback;
    }
    final duration = offer.receipt.expiresAt.difference(now);
    offer.timer = Timer(
      duration.isNegative ? Duration.zero : duration,
      _expire,
    );
  }

  void _expire() {
    if (_ended) return;
    try {
      _service.expireUndo();
      final now = _clock.now().toUtc();
      for (final offer in _offers.toList()) {
        if (offer.entry.id == restoringId) continue;
        if (!now.isBefore(offer.receipt.expiresAt)) {
          _forget(offer);
        } else {
          _schedule(offer);
        }
      }
    } catch (_) {
      // Expiry fails closed, retaining only a restore already accepted by issuer.
      for (final offer in _offers.toList()) {
        if (offer.entry.id != restoringId) _forget(offer);
      }
    }
    notifyListeners();
  }

  /// End transient UI lifetime synchronously, but release the owned service only
  /// after accepted mutations finish. Register this future before storage closes.
  Future<void> end() {
    if (_ending != null) return _ending!;
    _ended = true;
    VocabularyDeletionReceipt? acceptedRestore;
    for (final offer in _offers.toList()) {
      if (offer.entry.id == restoringId) {
        acceptedRestore = offer.receipt;
        offer.timer?.cancel();
        _offers.remove(offer);
      } else {
        _forget(offer);
      }
    }
    final pending = _pending;
    super.dispose();
    return _ending = (() async {
      try {
        if (pending != null) await pending;
      } catch (_) {
        /* Reported to initiating caller. */
      } finally {
        if (acceptedRestore != null) _forgetReceipt(acceptedRestore);
        _service.dispose();
      }
    })();
  }

  @override
  // end() invokes super.dispose exactly once while also returning the drain.
  // ignore: must_call_super
  void dispose() {
    unawaited(end());
  }
}
