import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/preferred_direction.dart';
import 'package:piko/features/learning/due_learning_session.dart';
import 'package:piko/features/learning/regular_grading_coordinator.dart';
import '../support/mutable_clock.dart';
import 'regular_reviews_test.dart' show Fixture, instant, rows;
import 'retry_gap_migration_test.dart' show gateway, storedSnapshot;

// Intentional inventory: additions require a stated product/integrity purpose.
const allowedColumns = <String, Set<String>>{
  'app_settings': {'key', 'value'},
  'collections': {'id', 'name', 'target_language', 'native_language'},
  'vocabulary_entries': {
    'id',
    'collection_id',
    'target_text',
    'native_text',
    'target_key',
    'native_key',
  },
  'learning_items': {
    'id',
    'entry_id',
    'direction',
    'format_version',
    'card_json',
    'generation',
    'review_revision',
    'speed_completed',
  },
  'regular_reviews': {'id', 'item_id', 'generation', 'reviewed_at', 'rating'},
  'retry_obligations': {
    'id',
    'item_id',
    'generation',
    'revision',
    'origin_review_id',
    'created_at',
    'expires_at',
    'wait_eligible_at',
    'error_count',
    'due_ordinal',
  },
  'scope_answer_ordinals': {
    'collection_id',
    'direction',
    'ordinal',
    'revision',
  },
  'learning_identity_sequence': {'singleton', 'next_id'},
  'vocabulary_order_sequence': {'singleton', 'next_row_id'},
  // CAT-001: portable Collection-owned definitions and explicit assignments.
  // Positions retain definition creation order; comparison keys enforce names.
  'category_dimensions': {
    'id',
    'collection_id',
    'name',
    'name_key',
    'mode',
    'position',
  },
  'category_values': {'id', 'dimension_id', 'name', 'name_key', 'position'},
  // Collection/dimension columns enforce ownership through composite FKs.
  'vocabulary_category_assignments': {
    'entry_id',
    'collection_id',
    'dimension_id',
    'value_id',
  },
};

Future<void> assertInventory(PikoDatabase db) async {
  final tables = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  expect(
    tables.map((row) => row.read<String>('name')).toSet(),
    allowedColumns.keys.toSet(),
  );
  for (final entry in allowedColumns.entries) {
    final columns = await db
        .customSelect('PRAGMA table_info(${entry.key})')
        .get();
    expect(
      columns.map((row) => row.read<String>('name')).toSet(),
      entry.value,
      reason: entry.key,
    );
  }
}

void main() {
  test(
    'DATA-005 real reinforcement retains only current state and regular history across reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'piko-minimal-data-',
      );
      final file = File('${directory.path}/fixture.sqlite');
      final clock = MutablePikoClock(instant);
      var db = PikoDatabase(NativeDatabase(file), clock: clock);
      DueLearningSession? session;
      try {
        final f = Fixture(database: db);
        await f.initialize();
        await SqliteSettingsRepository(db).write('locale', 'de');
        await assertInventory(db);
        final source = await gateway(db, f.owner.id);
        session = await DueLearningSession.start(
          source: source,
          cutoff: clock.now(),
          clock: clock,
          presentationActive: false,
        );
        await session.submitAnswerNow(session.current!, AnswerGrade.incorrect);
        final firstHistory = await rows(db, 'regular_reviews');
        expect(firstHistory, hasLength(1));
        for (var attempt = 0; attempt < 3; attempt++) {
          final currentRound = (await source.retryState(
            at: clock.now(),
          )).rounds.single;
          expect(await rows(db, 'retry_obligations'), hasLength(1));
          clock.set(currentRound.waitEligibleAt!);
          await session.refreshRetries();
          await session.submitAnswerNow(
            session.current!,
            attempt == 2 ? AnswerGrade.correct : AnswerGrade.incorrect,
          );
          expect(await rows(db, 'regular_reviews'), firstHistory);
        }
        expect(await rows(db, 'retry_obligations'), isEmpty);
        expect(await rows(db, 'scope_answer_ordinals'), hasLength(1));
        expect((await rows(db, 'scope_answer_ordinals')).single['ordinal'], 4);
        expect(await rows(db, 'app_settings'), [
          {'key': PreferredDirection.settingKey, 'value': PreferredDirection.targetToNative.name},
          {'key': 'locale', 'value': 'de'},
        ]);
        for (final item in await rows(db, 'learning_items')) {
          final card = jsonDecode(item['card_json']! as String) as Map;
          expect(card.keys.toSet(), {
            'cardId',
            'state',
            'step',
            'stability',
            'difficulty',
            'due',
            'lastReview',
          });
        }
        await assertInventory(db);
        final expected = await storedSnapshot(db);
        await session.stop();
        session.dispose();
        session = null;
        await db.close();
        db = PikoDatabase(NativeDatabase(file), clock: clock);
        await assertInventory(db);
        expect(await storedSnapshot(db), expected);
      } finally {
        await session?.stop();
        session?.dispose();
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
