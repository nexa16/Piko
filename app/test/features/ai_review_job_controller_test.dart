import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/ai/ai_review_job.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'package:piko/features/ai/ai_review_job_controller.dart';
import '../data/regular_reviews_test.dart' show Fixture;
import '../data/ai_service_test.dart' show envelope;

class FakeJobProvider implements AiReviewJobProvider {
  final calls = <String>[];
  final entries = <Map<String, Object?>>[];
  Map<String, Object?> status = {}, result = {};
  bool offline = false;
  @override
  Future<Map<String, Object?>> reviewJob(
    String action,
    Map<String, Object?> data,
  ) async {
    calls.add(action);
    if (offline) throw AiFailure.network;
    if (action == 'prepare') {
      status = {
        'jobId': data['jobId'],
        'state': 'preparing',
        'generation': 1,
        'expiresAt': data['expiresAt'],
        'total': (data['scopeIds']! as List).length,
        'processed': 0,
      };
    }
    if (action == 'upload') {
      entries.addAll((data['entries']! as List).cast<Map<String, Object?>>());
    }
    if (action == 'start' || action == 'resume') {
      status = {
        ...status,
        'state': 'running',
        'generation': (status['generation']! as int) + 1,
      };
    }
    if (action == 'cancel') {
      status = {
        ...status,
        'state': 'cancelled',
        'generation': (status['generation']! as int) + 1,
      };
    }
    return action == 'result' ? result : status;
  }
}

void main() {
  test(
    '700-entry upload runs once; restart polls only and completed report survives reopen',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      for (var i = 1; i < 700; i++) {
        await f.vocabulary.create(
          collectionId: f.owner.id,
          targetText: 'Word $i',
          nativeText: 'Wort $i',
        );
      }
      final service = SqliteAiService(f.db, enabled: true),
          provider = FakeJobProvider();
      AiReviewJobController controller() => AiReviewJobController(
        collectionId: f.owner.id,
        installationId: 'install-a',
        store: service.reviewJobs,
        provider: provider,
        pollInterval: const Duration(days: 1),
      );
      final first = controller();
      await first.start(maxCostCents: 100, options: const AiOptions());
      expect(first.error, isNull);
      expect(first.plan, isNull);
      expect(provider.entries.map((e) => e['id']).toSet(), hasLength(700));
      expect(provider.calls.where((e) => e == 'start'), hasLength(1));
      final job = first.job!;
      first.dispose();
      final afterRestart = controller();
      addTearDown(afterRestart.dispose);
      final paidCalls = provider.calls
          .where((e) => e == 'start' || e == 'resume')
          .length;
      await afterRestart.load();
      expect(provider.calls.last, 'status');
      expect(
        provider.calls.where((e) => e == 'start' || e == 'resume'),
        hasLength(paidCalls),
      );
      provider.status = {
        ...provider.status,
        'state': 'completed',
        'generation': 3,
        'processed': 700,
      };
      provider.result = {
        ...envelope(job.manifest.request),
        'jobId': job.id,
        'snapshotDigest': job.manifest.digest,
        'conflicts': [],
      };
      await afterRestart.refresh();
      expect(afterRestart.error, isNull);
      expect(afterRestart.plan!.processedIds, hasLength(700));
      await f.db.requireCollectionWritable(f.owner.id);
      expect(
        (await service.reviewJobs.reviewJobFor(
          f.owner.id,
          'install-a',
        ))!.result,
        isNotNull,
      );
    },
  );
  test(
    'offline cancellation persists lock and retries cancel after restart without paid work',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final service = SqliteAiService(f.db, enabled: true),
          provider = FakeJobProvider();
      AiReviewJobController controller() => AiReviewJobController(
        collectionId: f.owner.id,
        installationId: 'install-a',
        store: service.reviewJobs,
        provider: provider,
        pollInterval: const Duration(days: 1),
      );
      final first = controller();
      await first.start(maxCostCents: 50, options: const AiOptions());
      provider.offline = true;
      await first.cancel();
      expect(first.error, AiFailure.network);
      expect(first.job!.cancelPending, isTrue);
      await expectLater(
        f.db.requireCollectionWritable(f.owner.id),
        throwsA(isA<CollectionReviewLocked>()),
      );
      first.dispose();
      provider.offline = false;
      final next = controller();
      addTearDown(next.dispose);
      await next.load();
      expect(next.job!.status.state, AiJobState.cancelled);
      expect(provider.calls.where((e) => e == 'start'), hasLength(1));
      expect(provider.calls.where((e) => e == 'resume'), isEmpty);
      await f.db.requireCollectionWritable(f.owner.id);
    },
  );
}
