import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'package:piko/features/ai/ai_entry_session_coordinator.dart';
import 'package:piko/features/ai/ai_page.dart';
import '../data/ai_service_test.dart' show envelope, edit;
import '../data/statistics_test.dart' show stored;

class NeverProvider implements AiProvider {
  @override
  Future<Map<String, Object?>> generate(AiRequest r) =>
      throw StateError('No provider call authorized');
  @override
  void close() {}
}

void main() {
  for (final scenario in [
    (false, false),
    (true, false),
    (false, true),
    (true, true),
  ]) {
    final (done, partial) = scenario;
    test(
      'staged ${partial ? 'partial' : 'complete'} group Hints share ${done ? 'Done' : 'Add-next'} commit; failure retains draft/choices, Source and later edits remain correct',
      () async {
        final db = PikoDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final collection =
            await SqliteCollectionsRepository(
              db,
              interfaceLanguage: () => 'en',
            ).create(
              name: 'Synthetic',
              targetLanguage: VocabularyLanguage.french,
              nativeLanguage: VocabularyLanguage.german,
            );
        final service = SqliteAiService(db, enabled: true),
            v = SqliteVocabularyRepository(db),
            cats = SqliteCategoriesRepository(db);
        final source = (await cats.dimensions(
          collection.id,
        )).singleWhere((g) => g.name == 'Source');
        final manual = (await cats.values(
          source.id,
        )).singleWhere((v) => v.name == 'Manually entered');
        late final EntrySessionController session;
        final coordinator = AiEntrySessionCoordinator(
          support: AiSupport(service, NeverProvider()),
          repository: v,
          session: () => session,
        );
        addTearDown(coordinator.dispose);
        session = EntrySessionController(
          collectionId: collection.id,
          repository: v,
          confirmDraft: coordinator.confirm,
        );
        addTearDown(session.dispose);
        await session.initializeContentDefault();
        session.setTargetText('bank');
        session.setNativeText('Bank');
        final old = await session.confirmAndNext();
        expect(session.savedEntryState(old.id).draft.assignments, {
          source.id: {manual.id},
        });
        session.setTargetText('bank');
        session.setNativeText('Ufer');
        final anchor = coordinator.anchor(session.draft);
        final request = await service.request(
          collectionId: collection.id,
          action: AiAction.hints,
          anchor: anchor,
        );
        final plan = AiPlan.parse(
          request,
          envelope(
            request,
            complete: !partial,
            edits: [
              edit('new', anchor.record.id, 'hint', 'Flussrand'),
              edit('old', old.id, 'hint', 'Geldinstitut'),
            ],
          ),
        );
        final before = await stored(db);
        if (partial) {
          await coordinator.stage(AiStagedHints(plan, {'new', 'old'}));
          await expectLater(
            done ? session.completeSession() : session.confirmAndNext(),
            throwsA(AiFailure.dependency),
          );
          expect(await stored(db), before);
        }
        await coordinator.stage(
          AiStagedHints(plan, {'new', 'old'}, allowPartial: partial),
        );
        expect(await stored(db), before);
        await db.customStatement(
          "CREATE TRIGGER fail_joint BEFORE INSERT ON vocabulary_entries BEGIN SELECT RAISE(ABORT,'synthetic'); END",
        );
        await expectLater(
          done ? session.completeSession() : session.confirmAndNext(),
          throwsA(anything),
        );
        expect(await stored(db), before);
        expect(coordinator.staged, isNotNull);
        expect(session.draft.targetText, 'bank');
        expect(session.draft.nativeText, 'Ufer');
        await db.customStatement('DROP TRIGGER fail_joint');
        if (done) {
          await session.completeSession();
        } else {
          await session.confirmAndNext();
        }
        expect(coordinator.staged, isNull);
        expect(
          session.savedEntryState(old.id).draft.content.hintText,
          'Geldinstitut',
        );
        final words = await v.watchByCollection(collection.id).first;
        expect(words.length, 2);
        expect(words.last.content.hintText, 'Flussrand');
        expect(await v.categorizedAssignments(words.last.id), {
          source.id: {manual.id},
        });
        expect(await v.categorizedAssignments(old.id), {
          source.id: {manual.id},
        });
        if (!done) {
          session.editSavedEntry(old.id, targetText: 'Bank');
          await session.awaitSavedEdits();
          expect(
            (await v.watchById(old.id).first)!.content.hintText,
            'Geldinstitut',
          );
          expect(await v.categorizedAssignments(old.id), {
            source.id: {manual.id},
          });
        }
      },
    );
  }
  test(
    'ordinary Done uses known acquisition label; stale staged draft can be discarded then saved normally',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c =
          await SqliteCollectionsRepository(
            db,
            interfaceLanguage: () => 'en',
          ).create(
            name: 'Synthetic',
            targetLanguage: VocabularyLanguage.french,
            nativeLanguage: VocabularyLanguage.german,
          );
      final v = SqliteVocabularyRepository(db),
          service = SqliteAiService(db, enabled: true);
      final existing = await v.confirmNewEntry(
        collectionId: c.id,
        targetText: 'bank',
        nativeText: 'Bank',
        assignments: {},
        content: const VocabularyContent(),
      );
      late final EntrySessionController session;
      final coordinator = AiEntrySessionCoordinator(
        support: AiSupport(service, NeverProvider()),
        repository: v,
        session: () => session,
      );
      addTearDown(coordinator.dispose);
      session = EntrySessionController(
        collectionId: c.id,
        repository: v,
        confirmDraft: coordinator.confirm,
      );
      addTearDown(session.dispose);
      await session.initializeContentDefault();
      session.setTargetText('bank');
      session.setNativeText('Ufer');
      final anchor = coordinator.anchor(session.draft),
          request = await service.request(
            collectionId: c.id,
            action: AiAction.hints,
            anchor: coordinator.anchor(session.draft),
          );
      final plan = AiPlan.parse(
        request,
        envelope(
          request,
          edits: [
            edit('new', anchor.record.id, 'hint', 'Flussrand'),
            edit('old', existing.entry.id, 'hint', 'Geldinstitut'),
          ],
        ),
      );
      await coordinator.stage(AiStagedHints(plan, {'new', 'old'}));
      session.setNativeText('Böschung');
      final before = await stored(db);
      await expectLater(session.completeSession(), throwsA(AiFailure.stale));
      expect(await stored(db), before);
      coordinator.discard();
      await session.completeSession();
      final words = await v.watchByCollection(c.id).first;
      expect(words.last.nativeText, 'Böschung');
      expect(words.last.content.hintText, isNull);
      expect(
        (await v.watchById(existing.entry.id).first)!.content.hintText,
        isNull,
      );
      expect(
        (await v.categorizedAssignments(words.last.id)).values.single.length,
        1,
      );
    },
  );
}
