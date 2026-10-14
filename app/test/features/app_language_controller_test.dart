import 'dart:async';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/settings_repository.dart';
import 'package:piko/data/regular_review.dart';
import 'package:piko/features/learning/learning_scheduler.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/features/settings/app_language_controller.dart';
import 'package:piko/shared/interface_locale.dart';
import '../data/regular_reviews_test.dart' show Fixture, rows;

class HeldSettings implements SettingsRepository {
  HeldSettings(this.real);
  final SettingsRepository real;
  Completer<void>? readGate;
  Completer<void>? writeGate;
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;
  @override
  Future<String?> read(String key) async {
    await readGate?.future;
    if (failRead) throw StateError('read');
    return real.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    await writeGate?.future;
    if (failWrite) throw StateError('write');
    await real.write(key, value);
  }

  @override
  Future<void> remove(String key) => real.remove(key);
}

void main() {
  for (final stored in [null, 'en', 'de', 'fr', 'de-AT']) {
    test(
      'retained $stored hydrates authoritatively over injected German',
      () async {
        final db = PikoDatabase(NativeDatabase.memory());
        final repository = SqliteSettingsRepository(db);
        final locale = InterfaceLocaleController(const Locale('de'));
        final drains = <Future<void>>[];
        final controller = AppLanguageController(
          repository: repository,
          locale: locale,
          registerPending: drains.add,
        );
        try {
          if (stored != null) await repository.write('locale', stored);
          await controller.load();
          expect(controller.ready, isTrue);
          expect(locale.value.languageCode, stored == 'de' ? 'de' : 'en');
          expect(drains, hasLength(1));
          expect(await repository.read('locale'), stored);
        } finally {
          controller.dispose();
          locale.dispose();
          await db.close();
        }
      },
    );
  }
  test(
    'registered read failure is distinct from missing preference and retries',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      final repository = HeldSettings(SqliteSettingsRepository(db))
        ..failRead = true;
      final locale = InterfaceLocaleController();
      final controller = AppLanguageController(
        repository: repository,
        locale: locale,
        registerPending: (_) {},
      );
      try {
        await controller.load();
        expect(controller.ready, isFalse);
        expect(controller.error, isA<StateError>());
        repository.failRead = false;
        await controller.retry();
        expect(controller.ready, isTrue);
        expect(controller.error, isNull);
      } finally {
        controller.dispose();
        locale.dispose();
        await db.close();
      }
    },
  );
  test(
    'single-flight optimistic write rolls back and retry persists without other changes',
    () async {
      final f = Fixture();
      await f.initialize();
      final repo = HeldSettings(SqliteSettingsRepository(f.db));
      final locale = InterfaceLocaleController();
      final controller = AppLanguageController(
        repository: repo,
        locale: locale,
        registerPending: (_) {},
      );
      try {
        await controller.load();
        await repo.real.write('unrelated', 'retained');
        final item = (await f.learning.forEntry(f.entry.id)).first;
        await f.learning.review(
          kind: ReviewKind.regular,
          expectedPrior: item,
          rating: LearningRating.again,
          reviewedAt: f.db.clock.now().toUtc(),
        );
        final tables = [
          'collections',
          'vocabulary_entries',
          'learning_items',
          'regular_reviews',
          'retry_obligations',
          'scope_answer_ordinals',
          'learning_identity_sequence',
          'vocabulary_order_sequence',
        ];
        final before = await Future.wait(
          tables.map((table) => rows(f.db, table)),
        );
        repo.writeGate = Completer<void>();
        repo.failWrite = true;
        final write = controller.select(const Locale('de'));
        expect(locale.value, const Locale('de'));
        expect(controller.pending, isTrue);
        await controller.select(const Locale('en'));
        expect(repo.writes, 1);
        repo.writeGate!.complete();
        await write;
        expect(locale.value, const Locale('en'));
        expect(controller.error, isNotNull);
        repo.failWrite = false;
        await controller.retry();
        expect(locale.value, const Locale('de'));
        expect(await repo.real.read('locale'), 'de');
        expect(await repo.real.read('unrelated'), 'retained');
        expect(
          await Future.wait(tables.map((table) => rows(f.db, table))),
          before,
        );
      } finally {
        repo.writeGate?.completeIfPending();
        controller.dispose();
        locale.dispose();
        await f.db.close();
      }
    },
  );
  for (final fails in [false, true]) {
    test(
      'replacement waits admitted old write ($fails) before hydration',
      () async {
        final db = PikoDatabase(NativeDatabase.memory());
        final repo = HeldSettings(SqliteSettingsRepository(db));
        final oldLocale = InterfaceLocaleController();
        final newLocale = InterfaceLocaleController(const Locale('de'));
        final drains = <Future<void>>[];
        final old = AppLanguageController(
          repository: repo,
          locale: oldLocale,
          registerPending: drains.add,
        );
        final next = AppLanguageController(
          repository: repo,
          locale: newLocale,
          registerPending: drains.add,
        );
        try {
          await old.load();
          repo.writeGate = Completer<void>();
          repo.failWrite = fails;
          final write = old.select(const Locale('de'));
          old.dispose();
          final read = next.load(after: old.awaitPending);
          expect(next.ready, isFalse);
          repo.writeGate!.complete();
          await write;
          await read;
          expect(newLocale.value.languageCode, fails ? 'en' : 'de');
          expect(await repo.real.read('locale'), fails ? null : 'de');
        } finally {
          repo.writeGate?.completeIfPending();
          old.dispose();
          next.dispose();
          oldLocale.dispose();
          newLocale.dispose();
          await db.close();
        }
      },
    );
  }
  test(
    'failed lifetime registration writes nothing and keeps committed locale',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      final repo = HeldSettings(SqliteSettingsRepository(db));
      final locale = InterfaceLocaleController();
      bool reject = false;
      final controller = AppLanguageController(
        repository: repo,
        locale: locale,
        registerPending: (_) {
          if (reject) throw StateError('registration');
        },
      );
      try {
        await controller.load();
        reject = true;
        await controller.select(const Locale('de'));
        expect(repo.writes, 0);
        expect(locale.value, const Locale('en'));
        reject = false;
        await controller.retry();
        expect(await repo.read('locale'), 'de');
      } finally {
        controller.dispose();
        locale.dispose();
        await db.close();
      }
    },
  );
  test('real SQLite file reopen retains selected language', () async {
    final directory = await Directory.systemTemp.createTemp('piko-language-');
    final file = File('${directory.path}/settings.sqlite');
    final locale = InterfaceLocaleController();
    var db = PikoDatabase(NativeDatabase(file));
    var controller = AppLanguageController(
      repository: SqliteSettingsRepository(db),
      locale: locale,
      registerPending: (_) {},
    );
    try {
      await controller.load();
      await controller.select(const Locale('de'));
      controller.dispose();
      await db.close();
      locale.value = const Locale('en');
      db = PikoDatabase(NativeDatabase(file));
      controller = AppLanguageController(
        repository: SqliteSettingsRepository(db),
        locale: locale,
        registerPending: (_) {},
      );
      await controller.load();
      expect(locale.value, const Locale('de'));
    } finally {
      controller.dispose();
      locale.dispose();
      await db.close();
      await directory.delete(recursive: true);
    }
  });
  test(
    'selecting committed choice also updates externally changed visible locale',
    () async {
      final db = PikoDatabase(NativeDatabase.memory());
      final locale = InterfaceLocaleController();
      final repo = SqliteSettingsRepository(db);
      final controller = AppLanguageController(
        repository: repo,
        locale: locale,
        registerPending: (_) {},
      );
      try {
        await controller.load();
        locale.value = const Locale('de');
        await controller.select(const Locale('en'));
        expect(locale.value, const Locale('en'));
        expect(await repo.read('locale'), 'en');
      } finally {
        controller.dispose();
        locale.dispose();
        await db.close();
      }
    },
  );
}

extension on Completer<void> {
  void completeIfPending() {
    if (!isCompleted) complete();
  }
}
