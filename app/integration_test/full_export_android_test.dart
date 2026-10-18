import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart'
    show Selectable, QueryRow, Variable, ResultSetImplementation;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_full_export_service.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/features/settings/settings_route.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import '../test/data/regular_reviews_test.dart' show Fixture;
import 'review_correction_android_test.dart' as review;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;
import 'support/round2_catalogue_fixture.dart';

class _ExportDatabase extends PikoDatabase {
  _ExportDatabase(File file, review.ReviewFixtureClock clock)
    : super(NativeDatabase(file), clock: clock);
  bool failExport = false, closing = false;
  final closed = Completer<void>();
  @override
  Selectable<QueryRow> customSelect(
    String query, {
    List<Variable> variables = const [],
    Set<ResultSetImplementation> readsFrom = const {},
  }) {
    final result = super.customSelect(
      query,
      variables: variables,
      readsFrom: readsFrom,
    );
    if (failExport && query.startsWith('SELECT v.* FROM category_values')) {
      failExport = false;
      return _FailedRead(result);
    }
    return result;
  }

  @override
  Future<void> close() async {
    if (closing) return closed.future;
    closing = true;
    await super.close();
    closed.complete();
  }
}

class _FailedRead extends Selectable<QueryRow> {
  _FailedRead(this.inner);
  final Selectable<QueryRow> inner;
  @override
  Future<List<QueryRow>> get() async =>
      throw StateError('Injected isolated export read failure');
  @override
  Stream<List<QueryRow>> watch() => inner.watch();
}

void main() {
  final integration = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native full export saves a consistent report without changing local data',
    (tester) async {
      final config = CatalogueConfiguration(),
          copy = PikoCopy(CatalogueConfiguration().locale);
      final support = await getApplicationSupportDirectory();
      final directory = Directory(
        '${support.path}/full-export-${config.runId}',
      );
      if (await directory.exists()) throw StateError('Evidence already exists');
      await directory.create();
      final file = File('${directory.path}/fixture.sqlite');
      final clock = review.ReviewFixtureClock(DateTime.utc(2026, 10, 18, 12));
      final db = _ExportDatabase(file, clock);
      final seeded = Fixture(database: db);
      var passed = false, converted = false;
      final manifest = <String, Object?>{
        'sourceCommit': config.commit,
        'locale': config.locale,
        'scale': config.scale,
        'normalProductionDatabaseOpened': false,
        'fileName': 'piko-${config.runId}-full.json',
        'transport':
            'SystemVocabularyJsonPlatform.fullExport, real Android save picker',
        'failureEvidence':
            'isolated database read failure; platform write failure covered separately by host injection',
      };
      Finder key(String name) => find.byKey(ValueKey(name));
      Future<Map<String, Object?>> stored(PikoDatabase store) async => {
        for (final table in store.allTables)
          table.actualTableName: await review.rows(
            store,
            table.actualTableName,
          ),
      };
      Future<void> saveManifest() => File('${directory.path}/manifest.json')
          .writeAsString(
            const JsonEncoder.withIndent('  ').convert(manifest),
            flush: true,
          )
          .then((_) {});
      Future<void> phase(String id) async {
        manifest['phase'] = id;
        await saveManifest();
        debugPrint('PIKO_FULL_EXPORT_PHASE:${config.runId}:$id');
        final ack = File('${directory.path}/ack-$id');
        final deadline = DateTime.now().add(const Duration(minutes: 5));
        while (!await ack.exists()) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError('Missing native phase acknowledgement: $id');
          }
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      Future<void> tap(Finder target) async {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target.hitTestable().first);
        await tester.pumpAndSettle();
      }

      Future<void> idle() => review.waitUntil(
        tester,
        () =>
            tester.widget<PikoButton>(key('settings-full-export')).onPressed !=
            null,
      );
      try {
        await seeded.initialize();
        await seeded.collections.rename(id: seeded.owner.id, name: 'French');
        await seeded.review(at: clock.now());
        await seeded.review(reverse: true, at: clock.now());
        await seeded.review(word: seeded.other, at: clock.now());
        await seeded.collections.delete(seeded.kept.id);
        final korean = await seeded.collections.create(
          name: 'Korean',
          targetLanguage: VocabularyLanguage.korean,
          nativeLanguage: VocabularyLanguage.german,
        );
        await seeded.vocabulary.create(
          collectionId: korean.id,
          targetText: '나무',
          nativeText: 'Baum',
        );
        await SqliteSettingsRepository(db).write('locale', config.locale);
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(config.locale),
            home: PikoRuntime(databaseFactory: () => db),
          ),
        );
        await hydratedRuntimeCopy(tester);
        await review.waitUntil(
          tester,
          () => find.text(copy.text('nav.settings')).evaluate().isNotEmpty,
        );
        await tap(find.widgetWithText(PikoButton, copy.text('nav.settings')));
        final media = MediaQuery.of(tester.element(find.byType(SettingsRoute)));
        manifest['width'] = media.size.width;
        manifest['textScale'] = media.textScaler.scale(14) / 14;
        if (config.scale == '200') {
          expect(media.size.width, closeTo(320, 1));
          expect(media.textScaler.scale(14), closeTo(28, 1));
        }
        final export = key('settings-full-export');
        await tester.ensureVisible(export);
        await tester.pumpAndSettle();
        final baseline = await stored(db);
        final expected = await SqliteFullExportService(db).exportAll();
        await File(
          '${directory.path}/expected.json',
        ).writeAsString(expected, flush: true);
        final report = jsonDecode(expected) as Map;
        expect(report['collections'], hasLength(2));
        expect(report['statistics']['dailyCounts'], hasLength(1));
        expect(report['statistics']['dailyCounts'][0]['longTermReviews'], 3);
        final top = tester.getTopLeft(export).dy;
        tester.widget<PikoButton>(export).focusNode!.requestFocus();
        await tester.pump();
        db.failExport = true;
        await tap(export);
        await idle();
        expect(find.text(copy.text('fullExport.failed')), findsOneWidget);
        expect(tester.getTopLeft(export).dy, closeTo(top, .5));
        expect(await stored(db), baseline);
        await tap(export);
        await phase('save-cancel');
        await idle();
        expect(find.text(copy.text('fullExport.cancelled')), findsOneWidget);
        expect(find.text(copy.text('json.fileSaved')), findsNothing);
        expect(tester.widget<PikoButton>(export).focusNode!.hasFocus, isTrue);
        expect(await stored(db), baseline);
        await tap(export);
        await phase('save-confirm');
        await idle();
        expect(find.text(copy.text('json.fileSaved')), findsOneWidget);
        expect(tester.widget<PikoButton>(export).focusNode!.hasFocus, isTrue);
        expect(await stored(db), baseline);
        if (config.locale == 'en') {
          await settleCatalogueCapture(tester, 'full-export-settings');
          await integration.convertFlutterSurfaceToImage();
          converted = true;
          await tester.pump();
          await File('${directory.path}/settings.png').writeAsBytes(
            await integration.takeScreenshot('full-export-settings'),
          );
        }
        await phase(
          'verify-file',
        ); // Host compares the real saved bytes to expected.json.
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await db.closed.future;
        final reopened = PikoDatabase(NativeDatabase(file), clock: clock);
        try {
          expect(await stored(reopened), baseline);
        } finally {
          await reopened.close();
        }
        manifest['assertions'] = [
          'read failure/retry',
          'real native cancellation is not success',
          'real saved file',
          'focus/anchor retained',
          'two Collections and deleted-Collection statistics',
          'all tables unchanged and reopened',
        ];
        passed = true;
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        if (!db.closed.isCompleted) await db.close();
        manifest['passed'] = passed;
        manifest['captured'] = converted;
        await saveManifest();
        debugPrint('PIKO_FULL_EXPORT_EVIDENCE:${directory.path}');
      }
    },
  );
}
