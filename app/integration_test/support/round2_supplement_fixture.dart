import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import '../review_correction_android_test.dart' show waitUntil;
import 'round2_catalogue_fixture.dart' show CatalogueConfiguration;

const supplementPlan = <String, String>{
  'empty-detail': 'Empty Collection Detail omits the entire learning area',
  'caughtup-detail':
      'Nonempty Collection with no due/pending work shows friendly encouragement',
  'caughtup-home':
      'Overview omits zero-due quick actions without congratulatory text',
  'one-direction-detail':
      'One actual Review direction and one left half-width Speed action',
  'vocabulary-unchanged': 'Collection inline vocabulary editor before changes',
  'vocabulary-changed':
      'Collection inline vocabulary edit saved but still reversible',
  'vocabulary-invalid':
      'Invalid raw vocabulary text retained above last committed pair',
  'vocabulary-discarded': 'Discard restores opening text and closes the editor',
  'collection-delete-revealed':
      'Explicit swipe reveal under a rounded Collection vocabulary row',
  'collection-undo': 'Collection deletion with reachable transactional Undo',
  'entry-saved-card': 'Entry session compact confirmed card with a fresh draft',
  'entry-new-draft': 'Entry session new draft after Confirm and Next',
  'entry-saved-edit':
      'Entry session saved vocabulary editor with an accepted text edit',
  'entry-undo': 'Entry session deletion retains the new draft and offers Undo',
  'review-correction':
      'Immediately previous normal review displayed in correction mode, without regrading',
  'review-no-due':
      'Real authoritative empty review route; test-only navigation, no offered zero-count action',
  'pending-retry-detail':
      'Nonempty Collection waiting for retry eligibility, not caught-up encouragement',
  'filtered-zero-detail':
      'Nonempty filtered subset has no due work and uses neutral feedback',
  'speed-only-detail':
      'Positive Speed eligibility with no normal Review action',
  'category-empty-picker': 'Assignment picker for a dimension with no values',
  'category-overflow-picker':
      'Assignment picker with 24 actual values and overflow-dependent search',
  'category-no-match-picker':
      'Overflow picker retains the search query with no matching values',
  'entry-duplicate':
      'Entry draft retains its duplicate pair with specific validation and no blind Retry',
  'entry-inactive-empty-draft':
      'Inactive empty next-entry card shows New vocabulary, not placeholder vocabulary',
  'entry-inactive-partial-draft':
      'Inactive partial draft previews only actual input while the saved editor stays active',
  'entry-saved-duplicate':
      'Saved-entry duplicate retains raw text and last valid persisted values without Retry',
  'entry-saved-duplicate-reopened':
      'Reopening a saved duplicate retains the specific reason while its conflict remains',
  'entry-saved-duplicate-resolved':
      'Reopening retained saved text after conflict removal clears feedback and autosaves',
  'category-management-empty':
      'Expanded Collection category management with no definitions and Add dimension',
  'filters-empty':
      'Filters popup with no category definitions, safe dismissal and no Apply',
};

Map<String, int> supplementSpecs(String id) {
  if (id.startsWith('entry-')) {
    return {
      'ENTRY-001': 2,
      if (id == 'entry-duplicate') 'ENTRY-002': 1,
      if (id.startsWith('entry-saved-duplicate')) 'ENTRY-005': 2,
      if (id.startsWith('entry-saved-duplicate') || id == 'entry-duplicate')
        'UX-ENTRY-003': 1,
      if (id.startsWith('entry-inactive-')) 'UX-ENTRY-004': 1,
      'ENTRY-004': 1,
      'UX-ENTRY-001': 4,
      'UX-VOCAB-DELETE-001': 3,
    };
  }
  if (id.startsWith('vocabulary-')) {
    return {'VOCAB-EDIT-001': 1, 'UX-COLL-011': 1, 'UX-COLL-012': 1};
  }
  if (id.startsWith('collection-')) {
    return {'UX-VOCAB-DELETE-001': 3, 'UX-COLL-011': 1};
  }
  if (id == 'review-correction') {
    return {'UNDO-001': 1, 'UX-REVIEW-001': 4};
  }
  if (id == 'review-no-due') {
    return {'REVIEW-002': 2, 'UX-REVIEW-001': 4};
  }
  if (id.startsWith('category-')) {
    return {'CAT-001': 1, 'UX-CAT-001': 3};
  }
  if (id == 'filtered-zero-detail' || id == 'filters-empty') {
    return {'FILTER-002': 3, 'UX-COLL-008': 3};
  }
  if (id == 'pending-retry-detail') {
    return {'REVIEW-002': 2, 'UX-COLL-008': 3};
  }
  return {
    'UX-COLL-008': 3,
    'UX-COLL-004': 2,
    'REVIEW-001': 2,
    'UX-SETUP-002': 4,
  };
}

/// A separate immutable supplement, never an overwrite of the main catalogue.
final class SupplementArtifacts {
  SupplementArtifacts._(this.configuration, this.directory);
  static const fixture = 'round2-supplement-isolated-key-states-v3';
  final CatalogueConfiguration configuration;
  final Directory directory;
  final captures = <Map<String, Object?>>[];
  String status = 'running';
  String? failure;

  static Future<SupplementArtifacts> create(
    CatalogueConfiguration config,
  ) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}/round2-supplement-${config.runId}-${config.locale}-${config.scale}',
    );
    if (await directory.exists()) {
      throw StateError('Refusing to reuse a supplement directory');
    }
    await directory.create();
    final result = SupplementArtifacts._(config, directory);
    await result.writeManifest();
    return result;
  }

  Future<void> writeManifest() async {
    final target = File('${directory.path}/manifest.json');
    await target.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        'runId': configuration.runId,
        'commit': configuration.commit,
        'locale': configuration.locale,
        'scale': configuration.scale,
        'fixture': fixture,
        'palette': 'accepted Cobalt',
        'status': status,
        if (failure != null) 'failure': failure,
        'database':
            'fixture.sqlite (new synthetic DB retained after registered drain/close)',
        'nativeIo':
            'No native I/O or personal clipboard; native IME uses the separate pass',
        'fixtureClock': '2026-10-16T09:00:00Z, fixed',
        'plan': supplementPlan,
        'captures': captures,
        'notCaptured': supplementPlan.keys
            .where((id) => !captures.any((capture) => capture['id'] == id))
            .toList(),
        'coverageGaps': {
          'visual-review':
              'Captured states require human/model visual inspection; a test pass is not visual acceptance.',
          'native-ime-and-picker':
              'Covered by the separate native-device protocol, not this screenshot supplement.',
          'storage-errors-and-variants':
              'Fault-injection/cardinality/correction transition matrices remain focused-test evidence.',
        },
      }),
      flush: true,
    );
    debugPrint('PIKO_SUPPLEMENT_MANIFEST:${target.path}');
  }

  Future<void> capture(
    IntegrationTestWidgetsFlutterBinding binding,
    WidgetTester tester,
    String id, {
    Finder? at,
    Map<String, Object?> metadata = const {},
  }) async {
    if (!supplementPlan.containsKey(id) ||
        captures.any((capture) => capture['id'] == id)) {
      throw StateError('Unknown or duplicate supplement state: $id');
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    if (at != null) {
      expect(at, findsOneWidget, reason: 'Supplement anchor $id');
      await tester.ensureVisible(at);
    }
    await waitUntil(tester, () {
      final scaffolds = find.byType(Scaffold);
      return scaffolds.evaluate().isNotEmpty &&
          MediaQuery.viewInsetsOf(tester.element(scaffolds.last)).bottom == 0;
    }, description: 'native IME hidden before supplement $id');
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'Before supplement screenshot $id',
    );
    final name =
        '${configuration.runId}-supplement-$id-${configuration.locale}-${configuration.scale}';
    final file = File('${directory.path}/$name.png');
    if (await file.exists()) {
      throw StateError('Refusing screenshot overwrite: $id');
    }
    final bytes = await binding.takeScreenshot(name);
    expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
    await file.writeAsBytes(bytes, flush: true);
    final scrollPositions = <Map<String, Object?>>[];
    final scrollables = find.byType(Scrollable);
    for (var index = 0; index < scrollables.evaluate().length; index++) {
      final position = tester
          .state<ScrollableState>(scrollables.at(index))
          .position;
      if (position.hasContentDimensions &&
          position.maxScrollExtent > position.minScrollExtent) {
        scrollPositions.add({
          'index': index,
          'axis': position.axis.name,
          'pixels': position.pixels,
          'maxScrollExtent': position.maxScrollExtent,
          'viewportDimension': position.viewportDimension,
        });
      }
    }
    captures.add({
      'id': id,
      'file': '$name.png',
      'description': supplementPlan[id],
      'specRevisions': supplementSpecs(id),
      'commit': configuration.commit,
      'fixture': fixture,
      'locale': configuration.locale,
      'scale': configuration.scale,
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
    debugPrint('PIKO_SUPPLEMENT_ARTIFACT:${file.path}');
  }
}
