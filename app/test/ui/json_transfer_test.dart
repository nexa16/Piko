import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/data/vocabulary_json.dart';
import 'package:piko/features/interchange/vocabulary_json_page.dart';
import 'package:piko/main.dart';
import 'package:piko/platform/vocabulary_json_platform.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';

const owner = CollectionRecord(
  id: 'owner',
  name: 'Current collection',
  targetLanguage: VocabularyLanguage.french,
  nativeLanguage: VocabularyLanguage.german,
);

class JsonTestService implements VocabularyJsonService {
  Completer<String>? exportGate;
  String exported = '{"saved":"current collection"}';
  final exports = <String>[];
  @override
  Future<String> exportCollection(String collectionId) async {
    exports.add(collectionId);
    return exportGate == null ? exported : exportGate!.future;
  }

  @override
  String sampleJson() => VocabularyJsonFormat.sample;
  @override
  Future<VocabularyJsonPreview> analyzeImport({
    required String collectionId,
    required String json,
    Set<VocabularyJsonGroup> groups = VocabularyJsonGroup.all,
  }) => throw UnimplementedError('Transfer-only fixture');
  @override
  Future<VocabularyJsonApplyResult> applyImport(
    VocabularyJsonPreview preview,
  ) => throw UnimplementedError('Transfer-only fixture');
}

class JsonTestPlatform implements VocabularyJsonPlatform {
  String? file, clipboard;
  Object? readFailure, copyFailure, saveFailure;
  bool saveResult = true;
  Completer<String?>? readGate;
  final copied = <String>[], saved = <String>[];
  @override
  Future<String?> readFile() async {
    if (readFailure != null) throw readFailure!;
    return readGate == null ? file : readGate!.future;
  }

  @override
  Future<String?> readClipboard() async {
    if (readFailure != null) throw readFailure!;
    return clipboard;
  }

  @override
  Future<void> copyText(String text) async {
    if (copyFailure != null) throw copyFailure!;
    copied.add(text);
  }

  @override
  Future<bool> saveFile(String json) async {
    if (saveFailure != null) throw saveFailure!;
    saved.add(json);
    return saveResult;
  }
}

Finder get input => find.byKey(const ValueKey('json-input'));
String inputText(WidgetTester tester) =>
    tester.widget<TextField>(input).controller!.text;

Future<void> mountJson(
  WidgetTester tester,
  VocabularyJsonService service,
  JsonTestPlatform platform, {
  String language = 'en',
  CollectionRecord collection = owner,
  ValueChanged<Future<void>>? pending,
}) async {
  await tester.pumpWidget(
    PikoApp(
      localeController: InterfaceLocaleController(Locale(language)),
      home: VocabularyJsonPage(
        collection: collection,
        service: service,
        platform: platform,
        onPendingWrites: pending,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pressJson(
  WidgetTester tester,
  String key, {
  String language = 'en',
}) async {
  final button = find.text(PikoCopy(language).text(key));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language editable file/paste and exact sample/current exports preserve input',
      (tester) async {
        final service = JsonTestService();
        final platform = JsonTestPlatform()
          ..file = 'file JSON'
          ..clipboard = 'clipboard JSON';
        final pending = <Future<void>>[];
        await mountJson(
          tester,
          service,
          platform,
          language: language,
          pending: pending.add,
        );
        await pressJson(tester, 'json.file', language: language);
        expect(inputText(tester), 'file JSON');
        await pressJson(tester, 'json.paste', language: language);
        expect(inputText(tester), 'clipboard JSON');
        await tester.enterText(input, 'my raw JSON');
        await pressJson(tester, 'json.example', language: language);
        expect(platform.copied.single, VocabularyJsonFormat.sample);
        expect(inputText(tester), 'my raw JSON');
        await pressJson(tester, 'json.copy', language: language);
        await pressJson(tester, 'json.download', language: language);
        expect(platform.copied.last, service.exported);
        expect(platform.saved.single, service.exported);
        expect(service.exports, ['owner', 'owner']);
        expect(inputText(tester), 'my raw JSON');
        await Future.wait(pending);
        expect(pending, hasLength(5));
        expect(find.text(PikoCopy(language).text('json.notice')), findsNothing);
      },
    );

    testWidgets(
      '$language clipboard failure keeps editable input and separate selectable output; cancellations are quiet',
      (tester) async {
        final service = JsonTestService();
        final platform = JsonTestPlatform()
          ..copyFailure = JsonPlatformFailure.clipboardFailed;
        await mountJson(tester, service, platform, language: language);
        await tester.enterText(input, 'preserved');
        await pressJson(tester, 'json.copy', language: language);
        final output = tester.widget<TextField>(
          find.byKey(const ValueKey('json-fallback')),
        );
        expect(output.readOnly, isTrue);
        expect(output.controller!.text, service.exported);
        expect(inputText(tester), 'preserved');
        expect(
          find.text(PikoCopy(language).text('json.clipboardFailed')),
          findsOneWidget,
        );
        await pressJson(tester, 'json.file', language: language);
        await pressJson(tester, 'json.paste', language: language);
        platform.saveResult = false;
        await pressJson(tester, 'json.download', language: language);
        expect(inputText(tester), 'preserved');
        expect(
          find.text(PikoCopy(language).text('json.fileSaved')),
          findsNothing,
        );
        expect(
          find.text(PikoCopy(language).text('json.clipboardFailed')),
          findsNothing,
        );
        platform.readFailure = JsonPlatformFailure.tooLarge;
        await pressJson(tester, 'json.file', language: language);
        expect(
          find.text(PikoCopy(language).text('json.tooLarge')),
          findsOneWidget,
        );
        expect(inputText(tester), 'preserved');
      },
    );
  }

  testWidgets(
    'late reads preserve newer typing and stale export cannot copy after owner replacement',
    (tester) async {
      final service = JsonTestService();
      final platform = JsonTestPlatform()..readGate = Completer<String?>();
      await mountJson(tester, service, platform);
      await pressJson(tester, 'json.file');
      await tester.enterText(input, 'newer raw input');
      platform.readGate!.complete('old file result');
      await tester.pumpAndSettle();
      expect(inputText(tester), 'newer raw input');
      service.exportGate = Completer<String>();
      await pressJson(tester, 'json.copy');
      final replacement = JsonTestService();
      await mountJson(tester, replacement, platform);
      service.exportGate!.complete('stale export');
      await tester.pumpAndSettle();
      expect(platform.copied, isEmpty);
      expect(inputText(tester), 'newer raw input');
      expect(find.text(PikoCopy('en').text('json.copied')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Copy JSON uses the real opened-Collection snapshot including persisted learning',
    (tester) async {
      final db = PikoDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await db.close();
      });
      final collection = await SqliteCollectionsRepository(db).create(
        name: 'Stored words',
        targetLanguage: VocabularyLanguage.french,
        nativeLanguage: VocabularyLanguage.german,
      );
      final row = await SqliteVocabularyRepository(db).create(
        collectionId: collection.id,
        targetText: 'pomme',
        nativeText: 'Apfel',
      );
      final platform = JsonTestPlatform();
      await mountJson(
        tester,
        SqliteVocabularyJsonService(db),
        platform,
        collection: collection,
      );
      await pressJson(tester, 'json.copy');
      final document = jsonDecode(platform.copied.single) as Map;
      final exported = (document['collections'] as List).single as Map;
      expect(exported['id'], collection.id);
      final entry = (exported['entries'] as List).single as Map;
      expect(entry['id'], row.id);
      expect(entry['targetText'], 'pomme');
      expect(
        (entry['learning'] as Map).keys,
        containsAll(['targetToNative', 'nativeToTarget']),
      );
      expect(inputText(tester), isEmpty);
    },
  );
}
