import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/ai/ai_review_job.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/features/ai/ai_review_job_controller.dart';
import '../data/regular_reviews_test.dart' show Fixture;
import '../data/ai_service_test.dart' show envelope;

class FakeJobProvider implements AiReviewJobProvider {
  final calls = <String>[];
  final entries = <Map<String, Object?>>[];
  final payloads = <(String, Map<String, Object?>)>[];
  Map<String, Object?> status = {}, result = {};
  bool offline = false;
  bool available = true;
  final resultParts = <int>[];
  @override
  Future<Map<String, Object?>> reviewJob(
    String action,
    Map<String, Object?> data,
  ) async {
    calls.add(action);
    payloads.add((action, aiObject(jsonDecode(jsonEncode(data)))));
    if (offline) throw AiFailure.network;
    if (action == 'capabilities') {
      return {
        'reviewJobProtocol': 1,
        'snapshotVersion': 1,
        'resultPartsVersion': 1,
        'reviewJobsAvailable': available,
      };
    }
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
    if (action == 'result') {
      final text = jsonEncode(result), part = data['part'] as int? ?? 0;
      resultParts.add(part);
      final count = (text.length / 200000).ceil(), start = part * 200000;
      return {
        'jobId': result['jobId'],
        'snapshotDigest': result['snapshotDigest'],
        'resultHash': sha256.convert(utf8.encode(text)).toString(),
        'part': part,
        'parts': count,
        'content': text.substring(
          start,
          (start + 200000).clamp(0, text.length),
        ),
      };
    }
    return status;
  }
}

void main() {
  test(
    'unsupported deployed service cannot create local job or lock',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final service = SqliteAiService(f.db, enabled: true),
          provider = FakeJobProvider()..available = false;
      final controller = AiReviewJobController(
        collectionId: f.owner.id,
        installationId: 'install-a',
        store: service.reviewJobs,
        provider: provider,
      );
      addTearDown(controller.dispose);
      await controller.start(maxCostCents: 100, options: const AiOptions());
      expect(controller.error, AiFailure.unavailable);
      expect(
        await service.reviewJobs.reviewJobFor(f.owner.id, 'install-a'),
        isNull,
      );
      await f.db.requireCollectionWritable(f.owner.id);
      expect(provider.calls, ['capabilities']);
    },
  );
  test(
    'completed result above 2 MB is retrieved through verified GET parts',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final service = SqliteAiService(f.db, enabled: true),
          provider = FakeJobProvider();
      final controller = AiReviewJobController(
        collectionId: f.owner.id,
        installationId: 'install-a',
        store: service.reviewJobs,
        provider: provider,
        pollInterval: const Duration(days: 1),
      );
      addTearDown(controller.dispose);
      await controller.start(maxCostCents: 100, options: const AiOptions());
      final job = controller.job!;
      provider.status = {
        ...provider.status,
        'state': 'completed',
        'generation': 3,
        'processed': 1,
      };
      provider.result = {
        ...envelope(job.manifest.request),
        'jobId': job.id,
        'snapshotDigest': job.manifest.digest,
        'limitations': List.filled(1200, 'Synthetic ${'x' * 1980}'),
      };
      expect(
        utf8.encode(jsonEncode(provider.result)).length,
        greaterThan(2000000),
      );
      await controller.refresh();
      expect(controller.error, isNull);
      expect(controller.plan!.limitations, hasLength(1200));
      expect(provider.resultParts.length, greaterThan(10));
      expect(
        provider.resultParts,
        orderedEquals(List.generate(provider.resultParts.length, (i) => i)),
      );
    },
  );
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
    'filtered 700-entry inventory freezes 600 matching active/inactive entries and excludes other content from every upload',
    () async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final categories = SqliteCategoriesRepository(f.db);
      final group = await categories.createDimension(
        collectionId: f.owner.id,
        name: 'Review scope',
        mode: CategoryMode.single,
      );
      final included = await categories.createValue(
        dimensionId: group.id,
        name: 'Included',
      );
      final excluded = await categories.createValue(
        dimensionId: group.id,
        name: 'Excluded',
      );
      await categories.replaceAssignments(
        entryId: f.entry.id,
        assignments: {
          group.id: {excluded.id},
        },
      );
      final matchingIds = <String>{}, inactiveIds = <String>{};
      final excludedIds = <String>{f.entry.id, f.other.id};
      for (var i = 1; i < 700; i++) {
        final matches = i % 7 != 0, active = i % 3 != 0;
        final entry = await f.vocabulary.createWithContent(
          collectionId: f.owner.id,
          targetText: '${matches ? 'Included' : 'Excluded owner'} word $i',
          nativeText: 'Wort $i',
          assignments: {
            group.id: {matches ? included.id : excluded.id},
          },
          content: const VocabularyContent(),
          active: active,
        );
        if (matches) {
          matchingIds.add(entry.id);
          if (!active) inactiveIds.add(entry.id);
        } else {
          excludedIds.add(entry.id);
        }
      }
      expect(matchingIds, hasLength(600));
      expect(inactiveIds, hasLength(200));
      // Preserve a relationship between the opposite ends of the UUID-sorted
      // frozen scope. Backend tests separately exercise actual cross-shard
      // comparisons; this test proves the client supplies both distant inputs.
      final orderedIds = matchingIds.toList()..sort();
      for (final id in [orderedIds.first, orderedIds.last]) {
        final entry = (await f.vocabulary.watchById(id).first)!;
        await f.vocabulary.update(
          id: id,
          targetText: entry.targetText,
          nativeText: 'Shared cross-batch meaning',
        );
      }
      final filters = <String, Set<String>>{
        group.id: {included.id},
      };
      final checks = <String>{'translations', 'categories'};
      final goals = <String>{'travel'};
      final service = SqliteAiService(f.db, enabled: true);
      final provider = FakeJobProvider();
      AiReviewJobController controller() => AiReviewJobController(
        collectionId: f.owner.id,
        installationId: 'install-filtered-700',
        store: service.reviewJobs,
        provider: provider,
        pollInterval: const Duration(days: 1),
      );
      final first = controller();
      addTearDown(first.dispose);
      await first.start(
        maxCostCents: 125,
        options: AiOptions(
          level: 'B1',
          filters: filters,
          checks: checks,
          goals: goals,
          categoryMode: 'missing',
        ),
        allowGroups: false,
        allowValues: false,
      );
      expect(first.error, isNull);
      expect(first.job!.status.total, 600);
      expect(first.plan, isNull);
      final prepare = provider.payloads
          .singleWhere((p) => p.$1 == 'prepare')
          .$2;
      expect((prepare['scopeIds']! as List).toSet(), matchingIds);
      expect(prepare['options'], {
        'level': 'B1',
        'goals': ['travel'],
        'checks': ['categories', 'translations'],
        'categoryMode': 'missing',
        'filters': {
          group.id: [included.id],
        },
      });
      expect(prepare['allowNewGroups'], isFalse);
      expect(prepare['allowNewValues'], isFalse);
      expect(prepare['maxCostCents'], 125);
      final uploads = provider.payloads.where((p) => p.$1 == 'upload').toList();
      expect(uploads, hasLength(24));
      expect(uploads.map((p) => p.$2['index']), List.generate(24, (i) => i));
      expect(provider.entries, hasLength(600));
      expect(provider.entries.map((e) => e['id']).toSet(), matchingIds);
      expect(
        provider.entries
            .where((e) => e['active'] == false)
            .map((e) => e['id'])
            .toSet(),
        inactiveIds,
      );
      expect(
        provider.entries.map((e) => e['id']).toSet().intersection(excludedIds),
        isEmpty,
      );
      final wire = jsonEncode(provider.payloads.map((p) => p.$2).toList());
      expect(wire, isNot(contains('Excluded owner word')));
      expect(wire, isNot(contains('"target":"One"')));
      expect(wire, isNot(contains('"target":"Two"')));
      expect(provider.entries.first['id'], orderedIds.first);
      expect(provider.entries.last['id'], orderedIds.last);
      expect(provider.entries.first['native'], 'Shared cross-batch meaning');
      expect(provider.entries.last['native'], 'Shared cross-batch meaning');
      final frozenDigest = prepare['snapshotDigest'];
      // Later form edits cannot change the saved scope/options or enqueue work.
      filters[group.id] = {excluded.id};
      checks.clear();
      goals.add('later form edit');
      final restarted = controller();
      addTearDown(restarted.dispose);
      await restarted.load();
      expect(restarted.error, isNull);
      expect(restarted.job!.manifest.digest, frozenDigest);
      expect(restarted.job!.manifest.document['options'], prepare['options']);
      expect(
        restarted.job!.manifest.request.snapshot.entries
            .map((e) => e.record.id)
            .toSet(),
        matchingIds,
      );
      expect(provider.calls.where((c) => c == 'start'), hasLength(1));
      expect(provider.calls.where((c) => c == 'resume'), isEmpty);
      expect(provider.calls.last, 'status');
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
