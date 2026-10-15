import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/platform/vocabulary_json_platform.dart';

import '../review_correction_android_test.dart' show waitUntil;

/// Each invocation is one locale/scale cell, never a mutation of installed data.
/// Required defines: PIKO_CATALOGUE_RUN, PIKO_CATALOGUE_COMMIT.
/// Optional defines: PIKO_CATALOGUE_LOCALE=en|de, PIKO_CATALOGUE_SCALE=normal|200.
final class CatalogueConfiguration {
  CatalogueConfiguration()
    : runId = const String.fromEnvironment('PIKO_CATALOGUE_RUN'),
      commit = const String.fromEnvironment('PIKO_CATALOGUE_COMMIT'),
      locale = const String.fromEnvironment(
        'PIKO_CATALOGUE_LOCALE',
        defaultValue: 'en',
      ),
      scale = const String.fromEnvironment(
        'PIKO_CATALOGUE_SCALE',
        defaultValue: 'normal',
      ) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{3,63}$').hasMatch(runId)) {
      throw ArgumentError(
        'PIKO_CATALOGUE_RUN must be a unique safe run ID (4–64 characters)',
      );
    }
    if (!RegExp(r'^[0-9a-fA-F]{7,40}$').hasMatch(commit)) {
      throw ArgumentError(
        'PIKO_CATALOGUE_COMMIT must identify the tested Git commit',
      );
    }
    if (!['en', 'de'].contains(locale) || !['normal', '200'].contains(scale)) {
      throw ArgumentError(
        'Catalogue locale must be en/de; scale must be normal/200',
      );
    }
  }

  final String runId, commit, locale, scale;
  static const fixture = 'mockup-korean-basics-five-categories-v2';
}

const cataloguePlan = <String, String>{
  'home-empty': 'Home / empty fixture',
  'collection-create': 'Collection creation form',
  'home-populated': 'Home / Korean Basics, five new entries',
  'review-choice': 'UX-SETUP-001 / Home direction choice',
  'detail': 'Collection / both directions and five entries',
  'collection-overflow': 'Collection / overflow',
  'collection-delete-confirmation': 'Collection / safe cancellation',
  'collection-rename': 'Collection / inline name editor',
  'category-management':
      'UX-CAT-001 / management expanded inside Collection menu',
  'category-dimension-unchanged': 'Category dimension / opening name, no Save',
  'category-dimension-mode':
      'Category dimension / visible Single and Multiple choices',
  'category-dimension-changed':
      'Category dimension / changed name and mode, explicit Save',
  'category-dimension-saved':
      'Category dimension / stored name and Single mode',
  'category-value-create-empty':
      'Category management / empty inline new-value field, no check',
  'category-value-create-changed':
      'Category management / changed new-value field with check',
  'category-value-rename-unchanged':
      'Category management / opening value name, no check',
  'category-value-rename-changed':
      'Category management / changed value name with check',
  'category-delete-value-confirmation':
      'Category value / destructive confirmation, cancelled',
  'category-delete-dimension-confirmation':
      'Category dimension / destructive confirmation, cancelled',
  'category-dimension-create-empty':
      'Category management / empty inline dimension form',
  'category-dimension-create-invalid':
      'Category management / duplicate dimension name retained',
  'category-dimension-create-changed':
      'Category management / corrected dimension name with Save',
  'category-dimension-created':
      'Category management / new Unit dimension with no values',
  'vocabulary-assigned-chip':
      'CAT-009 / assigned category chip beneath the vocabulary pair',
  'category-assignment-unchanged':
      'Assignment popup / opening selection, no Apply',
  'category-assignment-changed':
      'Assignment popup / changed selection with Apply',
  'category-assignment-create-empty':
      'Assignment popup / empty inline value creation, selection retained',
  'category-assignment-create-changed':
      'Assignment popup / changed inline value with check, selection retained',
  'category-assignment-value-created':
      'Assignment popup / saved definition remains unassigned',
  'category-assignment-cancelled':
      'Assignment popup / safe dismissal preserves opening assignment',
  'category-assignment-applied':
      'Assignment popup / confirmed assignment handed to vocabulary autosave',
  'category-dimension-popup-empty':
      'Vocabulary editor / new dimension popup, no Save',
  'category-dimension-popup-changed':
      'Vocabulary editor / new dimension name and Multiple mode with Save',
  'vocabulary-category-second-row':
      'Vocabulary row / confirmed second-row chip after editor closes',
  'filters-unchanged': 'FILTER-002 / opening filter selection, no Apply',
  'filters-changed': 'FILTER-002 / staged category constraint with Apply',
  'detail-filtered-actions':
      'FILTER-001 / two visible words, four due directional items',
  'detail-filtered-vocabulary':
      'FILTER-001 / actual ordered School subset and chips',
  'filters-active':
      'FILTER-002 / active constraint reopened unchanged, no Apply',
  'filters-clear-staged':
      'FILTER-002 / Clear filters pending until Apply, cancellation tested',
  'search-no-matches':
      'FILTER-003 / retained search combined with category constraint, no matches',
  'search-only-no-matches':
      'FILTER-002 / direct category clear retains unmatched search',
  'detail-filters-cleared':
      'FILTER-002 / independent clearing restores all five learning candidates',
  'entry-empty': 'Entry / blank draft',
  'entry-required': 'Entry / missing required native text',
  'entry-discard': 'Entry / unfinished-draft exit confirmation',
  'json-input': 'JSON / input and selected import groups',
  'json-error': 'JSON / invalid syntax preview',
  'json-preview': 'JSON / valid changed-entry preview, not applied',
  'json-confirmation': 'JSON / replacement confirmation, cancelled',
  'json-export': 'JSON / actual isolated-collection export',
  'json-export-fallback':
      'JSON / injected clipboard failure with selectable export',
  'review-hidden': 'UX-REVIEW-001 / fixed reverse direction, hidden card',
  'review-revealed': 'UX-REVIEW-001 / self-assessed revealed card',
  'review-hard': 'Review / selected Hard modifier',
  'review-previous-available':
      'Review / next hidden card with Previous available',
  'review-countdown': 'RETRY-005 / persisted retry deadline countdown',
  'review-retry':
      'Review / automatically loaded retry after fixture-clock resume',
  'review-summary': 'Review / five completed, four first-try correct',
  'speed-setup': 'UX-SETUP-002 / fixed forward direction, default pool five',
  'speed-setup-invalid': 'UX-SETUP-002 / invalid pool validation',
  'speed-hidden': 'UX-REVIEW-001 / Speed hidden card',
  'speed-revealed': 'UX-REVIEW-001 / Speed revealed card',
  'speed-game': 'SPEED-012 / untimed shuffled 1–10 game',
  'speed-game-progress': 'SPEED-012 / consumed numbers remain in place',
  'speed-completed-detail': 'SPEED-006 / auto-return, no Speed summary',
  'settings': 'Settings / requested locale',
  'settings-language-choice': 'Settings / language menu',
};

/// Deliberate gaps are carried into every manifest; a passing harness does not
/// claim these have been visually reviewed or captured on the device.
const catalogueGaps = <String, String>{
  'category-additional-validation-states':
      'Duplicate dimension naming is captured. Cardinality conversion failures, duplicate/empty value naming, deleted-UUID Apply validation and category storage errors remain focused-test evidence, not screenshots in this catalogue.',
  'native-ime':
      'ADB/device pass: real Korean/German input, IME Next/Done, keyboard-visible entry and no overlap at both text scales.',
  'native-file-picker':
      'Device pass: JSON open/save picker, cancellation, permission/read/write failure; this harness intentionally replaces native I/O.',
  'native-clipboard':
      'Device pass: actual clipboard success/failure; harness never reads or changes personal clipboard.',
  'launcher-and-restoration':
      'ADB/device pass: launcher/background/force-stop and restart against this isolated fixture, without clearing installed personal data.',
  'storage-failure-states':
      'Focused fault-injection tests remain evidence for read/write Retry and pending-write drains; no synthetic storage-error screenshots in this catalogue.',
  'review-correction-and-no-due':
      'Capture correction mode, retry reinforcement/Hard variations and no-due state if final visual acceptance requires these additional states.',
};

Map<String, int> catalogueSpecs(String id) {
  if (id.startsWith('category-dimension-popup-')) {
    return {'CAT-005': 1, 'CAT-009': 3, 'UX-CAT-001': 3, 'UX-DIALOG-001': 3};
  }
  if (id.startsWith('category-assignment-create-') ||
      id == 'category-assignment-value-created') {
    return {'CAT-004': 1, 'CAT-009': 3, 'UX-CAT-001': 3, 'UX-DIALOG-001': 3};
  }
  if (id.startsWith('category-assignment-') || id.startsWith('vocabulary-')) {
    return {'CAT-009': 3, 'UX-CAT-001': 3, 'UX-DIALOG-001': 3};
  }
  if (id.startsWith('category-')) {
    return {
      'CAT-001': 1,
      'CAT-002': 1,
      'CAT-009': 3,
      'UX-CAT-001': 3,
      'UX-DIALOG-001': 3,
    };
  }
  if (id.startsWith('filters-') || id.startsWith('detail-filter')) {
    return {'FILTER-001': 2, 'FILTER-002': 3, 'COLL-007': 2, 'UX-COLL-008': 3};
  }
  if (id.startsWith('search-')) {
    return {'FILTER-002': 3, 'FILTER-003': 1, 'COLL-007': 2};
  }
  if (id.startsWith('json-')) {
    return {
      'IMPORT-JSON-001': 1,
      'IMPORT-JSON-002': 1,
      'UX-IMPORT-JSON-001': 1,
      'UX-IMPORT-JSON-002': 1,
    };
  }
  if (id.startsWith('speed-game')) return {'SPEED-007': 2, 'SPEED-012': 2};
  if (id.startsWith('speed-setup')) return {'UX-SETUP-002': 4, 'PARAM-005': 1};
  if (id.startsWith('speed-')) return {'SPEED-006': 1, 'UX-REVIEW-001': 4};
  if (id == 'review-choice') return {'REVIEW-001': 2, 'UX-SETUP-001': 2};
  if (id == 'review-countdown') return {'RETRY-005': 2, 'UX-CARD-012': 1};
  if (id.startsWith('review-')) return {'UX-REVIEW-001': 4, 'CARD-UI-026': 1};
  if (id.startsWith('entry-')) return {'UX-ENTRY-001': 4, 'ENTRY-005': 2};
  if (id.startsWith('collection-')) {
    return {'UX-COLL-007': 3, 'UX-DIALOG-001': 3};
  }
  if (id.startsWith('home-')) return {'UX-COLL-004': 2};
  if (id == 'detail') return {'UX-COLL-008': 3, 'UX-SETUP-002': 4};
  return {'UX-SYSTEM-001': 5};
}

/// The test invokes the real JSON service; only the OS transport is isolated.
final class CatalogueJsonPlatform implements VocabularyJsonPlatform {
  String? clipboard;
  String? exported;
  bool failCopy = false;

  @override
  Future<String?> readFile() async => null;
  @override
  Future<String?> readClipboard() async => clipboard;
  @override
  Future<void> copyText(String text) async {
    exported = text;
    if (failCopy) throw JsonPlatformFailure.clipboardFailed;
  }

  @override
  Future<bool> saveFile(String json) async {
    exported = json;
    return true;
  }
}

final class CatalogueArtifacts {
  CatalogueArtifacts._(this.configuration, this.directory);
  final CatalogueConfiguration configuration;
  final Directory directory;
  final List<Map<String, Object?>> captures = [];
  String status = 'running';
  String? failure;

  static Future<CatalogueArtifacts> create(
    CatalogueConfiguration config,
  ) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}/round2-catalogue-${config.runId}-${config.locale}-${config.scale}',
    );
    if (await directory.exists()) {
      throw StateError(
        'Refusing to overwrite an existing catalogue: ${directory.path}',
      );
    }
    await directory.create();
    final artifacts = CatalogueArtifacts._(config, directory);
    await artifacts.writeManifest();
    return artifacts;
  }

  Future<void> writeManifest() async {
    final file = File('${directory.path}/manifest.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        'runId': configuration.runId,
        'commit': configuration.commit,
        'locale': configuration.locale,
        'scale': configuration.scale,
        'fixture': CatalogueConfiguration.fixture,
        'palette': 'accepted Cobalt',
        'status': status,
        if (failure != null) 'failure': failure,
        'database':
            'fixture.sqlite (synthetic; retained after registered drain/close)',
        'fixtureClock':
            '2026-10-16T09:00:00Z; advanced only to the stored retry deadline',
        'nativeIo': 'fixture transport, no personal clipboard/files',
        'numberShuffle':
            'production shuffle; positions recorded in capture metadata',
        'categoryFixture':
            'Synthetic Topic (Multiple)/Food/School assignments; UI saves Topics (Single), adds Unit/Source/Travel/Practice, then restores empty search and filters before learning. Original vocabulary text and both directional learning states are asserted unchanged.',
        'plan': cataloguePlan,
        'captures': captures,
        'notCaptured': cataloguePlan.keys
            .where((id) => !captures.any((c) => c['id'] == id))
            .toList(),
        'coverageGaps': catalogueGaps,
      }),
      flush: true,
    );
    debugPrint('PIKO_CATALOGUE_MANIFEST:${file.path}');
  }

  Future<void> capture(
    IntegrationTestWidgetsFlutterBinding binding,
    WidgetTester tester,
    String id, {
    Finder? at,
    Map<String, Object?> metadata = const {},
  }) async {
    if (!cataloguePlan.containsKey(id) || captures.any((c) => c['id'] == id)) {
      throw StateError('Unknown or duplicate catalogue state: $id');
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    if (at != null) {
      expect(at, findsOneWidget, reason: 'Missing screenshot anchor for $id');
      await tester.ensureVisible(at);
    }
    await waitUntil(
      tester,
      () {
        final scaffolds = find.byType(Scaffold);
        return scaffolds.evaluate().isNotEmpty &&
            MediaQuery.viewInsetsOf(tester.element(scaffolds.last)).bottom == 0;
      },
      description:
          'keyboard hidden before $id (native IME has a separate pass)',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Before screenshot $id');
    final name =
        '${configuration.runId}-$id-${configuration.locale}-${configuration.scale}';
    final file = File('${directory.path}/$name.png');
    if (await file.exists()) {
      throw StateError('Refusing screenshot overwrite: $name');
    }
    final bytes = await binding.takeScreenshot(name);
    expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
    await file.writeAsBytes(bytes, flush: true);
    final scrollPositions = <Map<String, Object?>>[];
    final scrollables = find.byType(Scrollable);
    for (var index = 0; index < scrollables.evaluate().length; index++) {
      final state = tester.state<ScrollableState>(scrollables.at(index));
      final position = state.position;
      if (!position.hasContentDimensions ||
          position.maxScrollExtent <= position.minScrollExtent) {
        continue;
      }
      scrollPositions.add({
        'index': index,
        'axis': position.axis.name,
        'pixels': position.pixels,
        'minScrollExtent': position.minScrollExtent,
        'maxScrollExtent': position.maxScrollExtent,
        'viewportDimension': position.viewportDimension,
      });
    }
    captures.add({
      'id': id,
      'file': '$name.png',
      'locale': configuration.locale,
      'scale': configuration.scale,
      'fixture': CatalogueConfiguration.fixture,
      'commit': configuration.commit,
      'description': cataloguePlan[id],
      'specRevisions': catalogueSpecs(id),
      'capturedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'physicalViewport': {
        'width': tester.view.physicalSize.width,
        'height': tester.view.physicalSize.height,
      },
      'devicePixelRatio': tester.view.devicePixelRatio,
      'logicalViewport': {
        'width': tester.view.physicalSize.width / tester.view.devicePixelRatio,
        'height':
            tester.view.physicalSize.height / tester.view.devicePixelRatio,
      },
      if (at != null) 'anchor': at.toString(),
      'scrollPositions': scrollPositions,
      ...metadata,
    });
    await writeManifest();
    debugPrint('PIKO_CATALOGUE_ARTIFACT:${file.path}');
  }
}
