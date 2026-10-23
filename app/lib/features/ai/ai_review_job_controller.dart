import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../../data/ai/ai_contract.dart';
import '../../data/ai/ai_review_job.dart';

/// Durable paid work is server-owned. Disposing this screen stops only GETs.
final class AiReviewJobController extends ChangeNotifier {
  AiReviewJobController({
    required this.collectionId,
    required this.installationId,
    required this.store,
    required this.provider,
    this.pollInterval = const Duration(seconds: 3),
  });
  final String collectionId, installationId;
  final AiReviewJobStore store;
  final AiReviewJobProvider provider;
  final Duration pollInterval;
  AiLocalReviewJob? job;
  AiFailure? error;
  AiServiceError? details;
  bool busy = false, _disposed = false;
  Timer? _timer;
  AiPlan? get plan =>
      job?.status.state == AiJobState.completed && job?.result != null
      ? AiPlan.parse(job!.manifest.request, job!.result!)
      : null;
  bool get ownsUnfinished => job != null && !job!.status.terminal;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    details = null;
    _emit();
    try {
      await action();
    } catch (e) {
      details = e is AiServiceError ? e : null;
      error = details?.failure ?? (e is AiFailure ? e : AiFailure.unavailable);
    } finally {
      busy = false;
      _emit();
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (!_disposed &&
        ownsUnfinished &&
        job!.status.state != AiJobState.preparing) {
      _timer = Timer(pollInterval, refresh);
    }
  }

  Future<void> load() => _run(() async {
    job = await store.reviewJobFor(collectionId, installationId);
    if (job != null) await _fetch();
  });
  Future<void> start({
    required int maxCostCents,
    required AiOptions options,
    bool allowGroups = true,
    bool allowValues = true,
  }) => _run(() async {
    if (ownsUnfinished) throw AiFailure.dependency;
    job = await store.prepareReviewJob(
      collectionId: collectionId,
      installationId: installationId,
      maxCostCents: maxCostCents,
      options: options,
      allowGroups: allowGroups,
      allowValues: allowValues,
    );
    await _admit();
  });
  Future<void> _admit() async {
    final current = job!, doc = job!.manifest.document;
    final entries = doc['entries']! as List;
    final prepare = {...doc}..remove('entries');
    final response = await provider.reviewJob('prepare', {
      ...prepare,
      'jobId': current.id,
      'snapshotVersion': 1,
      'snapshotDigest': current.manifest.digest,
      'installationId': installationId,
      'scopeIds': entries.map((e) => (e as Map)['id']).toList(),
      'maxCostCents': current.maxCostCents,
      'idempotencyKey': current.id,
      'expiresAt': current.status.expiresAt.toIso8601String(),
    });
    job = await store.saveReviewStatus(current, AiJobStatus(response));
    if (job!.status.state != AiJobState.preparing) {
      await _fetch();
      return;
    }
    var index = 0, chunk = <Object?>[];
    Future<void> upload() async {
      if (chunk.isEmpty) return;
      await provider.reviewJob('upload', {
        'jobId': current.id,
        'installationId': installationId,
        'index': index++,
        'entries': chunk,
      });
      chunk = [];
    }

    for (final e in entries) {
      if (chunk.isNotEmpty &&
          (chunk.length >= 25 ||
              utf8.encode(jsonEncode([...chunk, e])).length > 150000)) {
        await upload();
      }
      chunk.add(e);
    }
    await upload();
    job = await store.saveReviewStatus(
      job!,
      AiJobStatus(
        await provider.reviewJob('start', {
          'jobId': current.id,
          'installationId': installationId,
          'idempotencyKey': '${current.id}:start',
        }),
      ),
    );
  }

  Future<void> _fetch() async {
    job = await store.reviewJobFor(collectionId, installationId);
    final current = job;
    if (current == null || current.status.state == AiJobState.detached) return;
    if ({
      AiJobState.expired,
      AiJobState.cancelled,
      AiJobState.failed,
    }.contains(current.status.state)) {
      return;
    }
    if (current.cancelPending) {
      job = await store.saveReviewStatus(
        current,
        AiJobStatus(
          await provider.reviewJob('cancel', {
            'jobId': current.id,
            'installationId': installationId,
            'idempotencyKey': '${current.id}:cancel',
          }),
        ),
      );
    } else {
      job = await store.saveReviewStatus(
        current,
        AiJobStatus(
          await provider.reviewJob('status', {
            'jobId': current.id,
            'installationId': installationId,
          }),
        ),
      );
    }
    if (job!.status.state == AiJobState.completed && job!.result == null) {
      final result = await _result(current);
      await store.saveReviewResult(job!, result);
      job = await store.reviewJobFor(collectionId, installationId);
    }
  }

  Future<Map<String, Object?>> _result(AiLocalReviewJob current) async {
    final first = await provider.reviewJob('result', {
      'jobId': current.id,
      'installationId': installationId,
      'part': 0,
    });
    final parts = first['parts'], hash = first['resultHash'];
    if (parts is! int ||
        parts < 1 ||
        parts > 1024 ||
        hash is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw AiFailure.invalidResponse;
    }
    final buffer = StringBuffer();
    for (var index = 0; index < parts; index++) {
      final part = index == 0
          ? first
          : await provider.reviewJob('result', {
              'jobId': current.id,
              'installationId': installationId,
              'part': index,
            });
      if (part['jobId'] != current.id ||
          part['snapshotDigest'] != current.manifest.digest ||
          part['resultHash'] != hash ||
          part['parts'] != parts ||
          part['part'] != index ||
          part['content'] is! String ||
          (part['content']! as String).length > 200000) {
        throw AiFailure.invalidResponse;
      }
      buffer.write(part['content']);
      if (buffer.length > 32000000) throw AiFailure.invalidResponse;
    }
    final text = buffer.toString(), bytes = utf8.encode(buffer.toString());
    if (bytes.length > 64000000 || sha256.convert(bytes).toString() != hash) {
      throw AiFailure.invalidResponse;
    }
    try {
      return aiObject(jsonDecode(text));
    } on FormatException {
      throw AiFailure.invalidResponse;
    }
  }

  Future<void> refresh() => _run(_fetch);
  Future<void> resume() => _run(() async {
    if (job == null || job!.cancelPending || job!.status.terminal) return;
    if (job!.status.state != AiJobState.preparing &&
        job!.status.state != AiJobState.paused) {
      return;
    }
    if (job!.status.state == AiJobState.preparing) {
      // Each upload/prepare/start is idempotent for this same admitted snapshot.
      await _admit();
    } else {
      job = await store.saveReviewStatus(
        job!,
        AiJobStatus(
          await provider.reviewJob('resume', {
            'jobId': job!.id,
            'installationId': installationId,
            'idempotencyKey': '${job!.id}:resume:${job!.status.generation}',
          }),
        ),
      );
    }
  });
  Future<void> cancel() => _run(() async {
    if (job == null || job!.status.terminal) return;
    await store.markReviewCancellation(job!);
    job = await store.reviewJobFor(collectionId, installationId);
    await _fetch();
  });
  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
