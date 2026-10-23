import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/ai/ai_review_job.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_deletion.dart';
import 'regular_reviews_test.dart' show Fixture, rows;
import 'ai_service_test.dart' show envelope, edit;

void main() {
  Future<(Fixture, SqliteAiService)> setup({PikoDatabase? database}) async {
    final f = Fixture(database: database);
    await f.initialize();
    addTearDown(f.db.close);
    return (f, SqliteAiService(f.db, enabled: true));
  }

  test(
    'durable collection admission blocks indirect content writes but real grades work',
    () async {
      final (f, service) = await setup();
      final opening = await f.vocabulary.captureOpeningSnapshot(
        entryId: f.entry.id,
        collectionId: f.owner.id,
      );
      final job = await service.reviewJobs.prepareReviewJob(
        collectionId: f.owner.id,
        installationId: 'installation-a',
        maxCostCents: 100,
        options: const AiOptions(),
      );
      expect(job.manifest.request.snapshot.entries.map((e) => e.record.id), [
        f.entry.id,
      ]);
      final locked = isA<sqlite.SqliteException>().having(
        (e) => e.message,
        'message',
        contains('PIKO_COLLECTION_REVIEW_LOCKED'),
      );
      await expectLater(
        f.vocabulary.update(
          id: f.entry.id,
          targetText: 'New',
          nativeText: 'Neu',
        ),
        throwsA(locked),
      );
      await expectLater(
        f.vocabulary.restoreOpeningSnapshot(opening),
        throwsA(locked),
      );
      await expectLater(
        f.collections.setLevel(id: f.owner.id, level: 'B1'),
        throwsA(locked),
      );
      await expectLater(
        f.collections.setLanguages(
          id: f.owner.id,
          targetLanguage: VocabularyLanguage.english,
          nativeLanguage: VocabularyLanguage.german,
        ),
        throwsA(locked),
      );
      await expectLater(f.collections.delete(f.owner.id), throwsA(locked));
      await expectLater(
        SqliteCategoriesRepository(f.db).createDimension(
          collectionId: f.owner.id,
          name: 'blocked',
          mode: CategoryMode.single,
        ),
        throwsA(locked),
      );
      await expectLater(
        f.learning.resetLearning(
          entryId: f.entry.id,
          directions: {LearningDirection.targetToNative},
        ),
        throwsA(isA<CollectionReviewLocked>()),
      );
      await f.review();
      expect(
        (await f.learning.reviewsForItem((await f.current()).id)),
        hasLength(1),
      );
      await f.vocabulary.update(
        id: f.other.id,
        targetText: 'Allowed',
        nativeText: 'Erlaubt',
      );
    },
  );
  test(
    'foreign installation jobs detach without content loss; terminal generation cannot unlock successor',
    () async {
      final (f, service) = await setup();
      final old = await service.reviewJobs.prepareReviewJob(
        collectionId: f.owner.id,
        installationId: 'installation-a',
        maxCostCents: 100,
        options: const AiOptions(),
      );
      final content = await rows(f.db, 'vocabulary_entries');
      await f.db.reconcileAiInstallation('installation-b');
      expect(
        await service.reviewJobs.reviewJobFor(f.owner.id, 'installation-b'),
        isNull,
      );
      final next = await service.reviewJobs.prepareReviewJob(
        collectionId: f.owner.id,
        installationId: 'installation-b',
        maxCostCents: 100,
        options: const AiOptions(),
      );
      await service.reviewJobs.saveReviewStatus(
        old,
        AiJobStatus({
          ...old.status.data,
          'state': 'cancelled',
          'generation': 3,
        }),
      );
      expect(
        (await service.reviewJobs.reviewJobFor(
          f.owner.id,
          'installation-b',
        ))!.id,
        next.id,
      );
      await expectLater(
        f.db.requireCollectionWritable(f.owner.id),
        throwsA(isA<CollectionReviewLocked>()),
      );
      expect(await rows(f.db, 'vocabulary_entries'), content);
    },
  );
  test(
    'manifest survives JSON restore and learning; scoped filters freeze only matching including inactive',
    () async {
      final (f, service) = await setup();
      final request = await service.request(
        collectionId: f.owner.id,
        action: AiAction.review,
      );
      final manifest = AiReviewManifest(const AiOptions().bind(request));
      expect(manifest.digest, matches(RegExp('^[a-f0-9]{64}\$')));
      expect(
        AiReviewManifest.restore(manifest.persisted).digest,
        manifest.digest,
      );
      await f.review();
      expect(
        AiReviewManifest(
          const AiOptions().bind(
            await service.request(
              collectionId: f.owner.id,
              action: AiAction.review,
            ),
          ),
        ).digest,
        manifest.digest,
      );
      await f.db.customStatement(
        'UPDATE vocabulary_entries SET active=0 WHERE id=?',
        [f.entry.id],
      );
      final inactive = AiReviewManifest(
        const AiOptions().bind(
          await service.request(
            collectionId: f.owner.id,
            action: AiAction.review,
          ),
        ),
      );
      expect(inactive.request.snapshot.entries, hasLength(1));
      expect(inactive.digest, isNot(manifest.digest));
    },
  );
  test(
    'adoption receipt rolls back with writes and survives service restart',
    () async {
      final (f, service) = await setup();
      final request = await service.request(
        collectionId: f.owner.id,
        action: AiAction.review,
      );
      final plan = AiPlan.parse(
        request,
        envelope(
          request,
          edits: [edit('change', f.entry.id, 'target', 'Changed')],
        ),
      );
      await expectLater(
        service.apply(plan, {
          'change',
        }, beforeCommit: () => throw StateError('disk unavailable')),
        throwsStateError,
      );
      expect(await rows(f.db, 'ai_adoption_receipts'), isEmpty);
      await service.apply(plan, {'change'});
      expect(await rows(f.db, 'ai_adoption_receipts'), hasLength(1));
      await expectLater(
        SqliteAiService(f.db, enabled: true).apply(plan, {'change'}),
        throwsA(AiFailure.consumed),
      );
      expect(
        (await f.vocabulary.watchById(f.entry.id).first)!.targetText,
        'Changed',
      );
    },
  );
  test(
    'completed-job adoption receipt returns same outcome after crash/reopen and rejects changed selection',
    () async {
      final dir = await Directory.systemTemp.createTemp('piko-job-adoption-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/piko.db');
      final f = Fixture(database: PikoDatabase(NativeDatabase(file)));
      await f.initialize();
      final service = SqliteAiService(f.db, enabled: true);
      final job = await service.reviewJobs.prepareReviewJob(
        collectionId: f.owner.id,
        installationId: 'install-a',
        maxCostCents: 100,
        options: const AiOptions(),
      );
      final result = {
        ...envelope(
          job.manifest.request,
          edits: [edit('change', f.entry.id, 'target', 'Changed')],
        ),
        'jobId': job.id,
        'snapshotDigest': job.manifest.digest,
      };
      final finished = await service.reviewJobs.saveReviewStatus(
        job,
        AiJobStatus({
          ...job.status.data,
          'state': 'completed',
          'generation': 1,
        }),
      );
      await service.reviewJobs.saveReviewResult(finished, result);
      final plan = AiPlan.parse(job.manifest.request, result);
      final first = await service.apply(plan, {'change'});
      expect(first.updatedEntries[f.entry.id]!.targetText, 'Changed');
      await f.vocabulary.update(
        id: f.entry.id,
        targetText: 'Later edit',
        nativeText: 'Eins',
      );
      final before = await rows(f.db, 'vocabulary_entries');
      await f.db.close();
      final reopened = PikoDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      final replay = await SqliteAiService(
        reopened,
        enabled: true,
      ).apply(plan, {'change'});
      expect(replay.updatedEntries[f.entry.id]!.targetText, 'Changed');
      expect(await rows(reopened, 'vocabulary_entries'), before);
      await expectLater(
        SqliteAiService(reopened, enabled: true).apply(plan, {}),
        throwsA(AiFailure.consumed),
      );
      expect(await rows(reopened, 'ai_adoption_receipts'), hasLength(1));
    },
  );
  test(
    'language metadata reversal preserves exact learning/content; stale job result rejected',
    () async {
      final (f, service) = await setup();
      await f.review();
      final before = {
        for (final t in [
          'vocabulary_entries',
          'vocabulary_examples',
          'learning_items',
          'regular_reviews',
          'category_dimensions',
          'category_values',
        ])
          t: await rows(f.db, t),
      };
      final old = AiReviewManifest(
        const AiOptions().bind(
          await service.request(
            collectionId: f.owner.id,
            action: AiAction.review,
          ),
        ),
      );
      await f.collections.setLanguages(
        id: f.owner.id,
        targetLanguage: VocabularyLanguage.german,
        nativeLanguage: VocabularyLanguage.french,
      );
      for (final t in before.keys) {
        expect(await rows(f.db, t), before[t], reason: t);
      }
      expect(await service.applicable(old.request), isFalse);
      await expectLater(
        f.collections.setLanguages(
          id: f.owner.id,
          targetLanguage: VocabularyLanguage.german,
          nativeLanguage: VocabularyLanguage.german,
        ),
        throwsA(CollectionValidation.sameLanguage),
      );
    },
  );
  test(
    'trash restore blocked during job and full learning restored after confirmed cancel',
    () async {
      final (f, service) = await setup();
      await f.review();
      final deletion = SqliteVocabularyDeletionService(f.db);
      addTearDown(deletion.dispose);
      final receipt = await deletion.delete(f.entry.id);
      await f.vocabulary.create(
        collectionId: f.owner.id,
        targetText: 'remaining',
        nativeText: 'bleibt',
      );
      final job = await service.reviewJobs.prepareReviewJob(
        collectionId: f.owner.id,
        installationId: 'installation-a',
        maxCostCents: 100,
        options: const AiOptions(),
      );
      await expectLater(
        deletion.restore(receipt),
        throwsA(isA<sqlite.SqliteException>()),
      );
      await service.reviewJobs.markReviewCancellation(job);
      await expectLater(
        f.db.requireCollectionWritable(f.owner.id),
        throwsA(isA<CollectionReviewLocked>()),
      );
      await service.reviewJobs.saveReviewStatus(
        job,
        AiJobStatus({
          ...job.status.data,
          'state': 'cancelled',
          'generation': 1,
        }),
      );
      await deletion.restore(receipt);
      expect(
        await f.learning.reviewsForItem((await f.current()).id),
        hasLength(1),
      );
    },
  );
  test(
    'populated schema23 upgrade preserves old tables and adds operational state only',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-review-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/piko.db');
      final f = Fixture(database: PikoDatabase(NativeDatabase(file)));
      await f.initialize();
      await f.review();
      final tables = [
        'collections',
        'vocabulary_entries',
        'learning_items',
        'regular_reviews',
        'category_dimensions',
        'category_values',
      ];
      final before = {for (final t in tables) t: await rows(f.db, t)};
      await f.db.close();
      final old = sqlite.sqlite3.open(file.path);
      for (final t in old.select(
        "SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE 'ai_lock_%'",
      )) {
        old.execute('DROP TRIGGER ${t['name']}');
      }
      old.execute('DROP TABLE ai_review_jobs');
      old.execute('DROP TABLE ai_adoption_receipts');
      old.execute('PRAGMA user_version=23');
      old.close();
      final reopened = PikoDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      for (final t in tables) {
        expect(await rows(reopened, t), before[t], reason: t);
      }
      expect(await rows(reopened, 'ai_review_jobs'), isEmpty);
      expect(
        (await reopened.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
    },
  );
}
