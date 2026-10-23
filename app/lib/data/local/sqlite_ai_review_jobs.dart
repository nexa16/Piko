import 'dart:convert';
import 'package:drift/drift.dart';
import '../ai/ai_contract.dart';
import '../ai/ai_review_job.dart';
import 'piko_database.dart';

final class SqliteAiReviewJobs implements AiReviewJobStore {
  SqliteAiReviewJobs(this.database, this.service);
  final PikoDatabase database;
  final AiContentService service;
  AiLocalReviewJob _read(QueryRow row) {
    final payload = aiObject(jsonDecode(row.read<String>('payload_json')));
    final manifest = AiReviewManifest.restore(aiObject(payload['saved']));
    if (manifest.digest != row.read<String>('digest')) throw AiFailure.stale;
    return AiLocalReviewJob(
      id: row.read<String>('job_id'),
      installationId: row.read<String>('installation_id'),
      manifest: manifest,
      maxCostCents: payload['maxCostCents']! as int,
      status: AiJobStatus({
        ...aiObject(jsonDecode(row.read<String>('status_json'))),
        'state': row.read<String>('state'),
      }),
      cancelPending: row.read<int>('cancel_pending') != 0,
      result: row.readNullable<String>('result_json') == null
          ? null
          : aiObject(jsonDecode(row.read<String>('result_json'))),
    );
  }

  @override
  Future<AiLocalReviewJob?> reviewJobFor(
    String collectionId,
    String installationId,
  ) => database.transaction(() async {
    // A restored database has no authority to control or lock a new install.
    await database.customStatement(
      "UPDATE ai_review_jobs SET lock_enabled=0, state='detached' "
      'WHERE collection_id=? AND installation_id<>?',
      [collectionId, installationId],
    );
    final row = await database
        .customSelect(
          'SELECT * FROM ai_review_jobs WHERE '
          'collection_id=? AND installation_id=? AND state<>? ORDER BY rowid DESC LIMIT 1',
          variables: [
            Variable(collectionId),
            Variable(installationId),
            const Variable('detached'),
          ],
        )
        .getSingleOrNull();
    if (row == null) return null;
    final job = _read(row);
    if (!job.status.terminal &&
        !database.clock.now().toUtc().isBefore(job.status.expiresAt)) {
      return saveReviewStatus(
        job,
        AiJobStatus({
          ...job.status.data,
          'state': 'expired',
          'generation': job.status.generation + 1,
        }),
      );
    }
    return job;
  });

  @override
  Future<AiLocalReviewJob> prepareReviewJob({
    required String collectionId,
    required String installationId,
    required int maxCostCents,
    required AiOptions options,
    bool allowGroups = true,
    bool allowValues = true,
  }) => database.transaction(() async {
    if (!service.enabled) throw AiFailure.disabled;
    if (maxCostCents <= 0 || maxCostCents > 1000000) throw AiFailure.dependency;
    await database.requireCollectionWritable(collectionId);
    final request = options.bind(
      await service.request(
        collectionId: collectionId,
        action: AiAction.review,
        allowGroups: allowGroups,
        allowValues: allowValues,
      ),
    );
    if (request.snapshot.entries.isEmpty) throw AiFailure.dependency;
    final manifest = AiReviewManifest(request);
    final expiry = database.clock.now().toUtc().add(const Duration(days: 7));
    final status = AiJobStatus({
      'jobId': request.id,
      'state': 'preparing',
      'generation': 0,
      'expiresAt': expiry.toIso8601String(),
      'processed': 0,
      'total': request.snapshot.entries.length,
      'phase': 'upload',
    });
    await database.customStatement(
      'INSERT INTO ai_review_jobs '
      '(job_id, collection_id, installation_id, digest, state, expires_at, payload_json, status_json) '
      'VALUES (?,?,?,?,?,?,?,?)',
      [
        request.id,
        collectionId,
        installationId,
        manifest.digest,
        'preparing',
        expiry.toIso8601String(),
        jsonEncode({'saved': manifest.persisted, 'maxCostCents': maxCostCents}),
        jsonEncode(status.data),
      ],
    );
    await database.watchReviewExpiry();
    return AiLocalReviewJob(
      id: request.id,
      installationId: installationId,
      manifest: manifest,
      maxCostCents: maxCostCents,
      status: status,
    );
  });

  @override
  Future<AiLocalReviewJob> saveReviewStatus(
    AiLocalReviewJob job,
    AiJobStatus status,
  ) => database.transaction(() async {
    if (status.id != job.id ||
        status.expiresAt.isAfter(job.status.expiresAt) ||
        (status.data.containsKey('snapshotDigest') &&
            status.data['snapshotDigest'] != job.manifest.digest)) {
      throw AiFailure.invalidResponse;
    }
    final row = await database
        .customSelect(
          'SELECT * FROM ai_review_jobs WHERE '
          'job_id=? AND installation_id=?',
          variables: [Variable(job.id), Variable(job.installationId)],
        )
        .getSingle();
    final current = _read(row);
    if (status.generation < current.status.generation ||
        (current.status.terminal && status.state != current.status.state)) {
      return current;
    }
    await database.customStatement(
      'UPDATE ai_review_jobs SET state=?, generation=?, '
      'expires_at=?, status_json=?, lock_enabled=?, cancel_pending=? WHERE job_id=? AND installation_id=?',
      [
        status.state.name,
        status.generation,
        status.expiresAt.toIso8601String(),
        jsonEncode(status.data),
        status.terminal ? 0 : 1,
        status.terminal
            ? 0
            : current.cancelPending
            ? 1
            : 0,
        job.id,
        job.installationId,
      ],
    );
    await database.watchReviewExpiry();
    return AiLocalReviewJob(
      id: job.id,
      installationId: job.installationId,
      manifest: job.manifest,
      maxCostCents: job.maxCostCents,
      status: status,
      cancelPending: !status.terminal && current.cancelPending,
      result: current.result,
    );
  });

  @override
  Future<void> markReviewCancellation(
    AiLocalReviewJob job,
  ) => database.customStatement(
    'UPDATE ai_review_jobs SET cancel_pending=1 WHERE job_id=? AND installation_id=? AND lock_enabled=1',
    [job.id, job.installationId],
  );

  @override
  Future<void> saveReviewResult(
    AiLocalReviewJob job,
    Map<String, Object?> result,
  ) => database.transaction(() async {
    final row = await database
        .customSelect(
          'SELECT * FROM ai_review_jobs WHERE job_id=?',
          variables: [Variable(job.id)],
        )
        .getSingle();
    final current = _read(row);
    if (current.installationId != job.installationId ||
        current.status.state != AiJobState.completed ||
        result['jobId'] != job.id ||
        result['snapshotDigest'] != job.manifest.digest) {
      throw AiFailure.stale;
    }
    AiPlan.parse(job.manifest.request, result);
    await database.customStatement(
      'UPDATE ai_review_jobs SET result_json=? WHERE job_id=?',
      [jsonEncode(result), job.id],
    );
  });
}
