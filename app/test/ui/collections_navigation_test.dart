import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_card.dart';
import 'package:piko/ui/piko_theme.dart';

const first = CollectionRecord(
  id: 'first',
  name: 'Same name',
  targetLanguage: VocabularyLanguage.korean,
  nativeLanguage: VocabularyLanguage.german,
);
const second = CollectionRecord(
  id: 'second',
  name: 'Same name',
  targetLanguage: VocabularyLanguage.korean,
  nativeLanguage: VocabularyLanguage.german,
);

/// New watch calls return distinct streams, so retry must really resubscribe.
class NavigationRepository implements CollectionsRepository {
  NavigationRepository({this.records = const [], this.seed = true});
  List<CollectionRecord> records;
  final bool seed;
  final allStreams = <StreamController<List<CollectionRecord>>>[];
  final detailStreams = <StreamController<CollectionRecord?>>[];
  final detailIds = <String>[];
  var allSubscriptions = 0;
  var detailSubscriptions = 0;

  @override
  Stream<List<CollectionRecord>> watchAll() {
    late StreamController<List<CollectionRecord>> controller;
    controller = StreamController<List<CollectionRecord>>(
      onListen: () {
        allSubscriptions++;
        if (seed) {
          scheduleMicrotask(() {
            if (!controller.isClosed) controller.add(List.of(records));
          });
        }
      },
    );
    allStreams.add(controller);
    return controller.stream;
  }

  @override
  Stream<CollectionRecord?> watchById(String id) {
    detailIds.add(id);
    late StreamController<CollectionRecord?> controller;
    controller = StreamController<CollectionRecord?>(
      onListen: () {
        detailSubscriptions++;
        if (seed) {
          scheduleMicrotask(() {
            if (!controller.isClosed) {
              controller.add(
                records.where((record) => record.id == id).firstOrNull,
              );
            }
          });
        }
      },
    );
    detailStreams.add(controller);
    return controller.stream;
  }

  @override
  Future<CollectionRecord> create({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
  }) async {
    final record = CollectionRecord(
      id: 'created-${records.length}',
      name: name.trim(),
      targetLanguage: targetLanguage,
      nativeLanguage: nativeLanguage,
    );
    records = [...records, record];
    for (final controller in allStreams) {
      if (!controller.isClosed && controller.hasListener) {
        controller.add(List.of(records));
      }
    }
    return record;
  }

  Future<void> dispose() async {
    for (final controller in [...allStreams, ...detailStreams]) {
      await controller.close();
    }
  }
}

Future<void> home(
  WidgetTester tester,
  NavigationRepository repository, {
  InterfaceLocaleController? locale,
}) async {
  await tester.pumpWidget(
    PikoApp(
      localeController: locale,
      home: CollectionsHome(repository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

void disposeAfterUnmount(WidgetTester tester, NavigationRepository repository) {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await repository.dispose();
  });
}

void main() {
  testWidgets(
    'duplicate names open by stable ID, including whole-card padding',
    (tester) async {
      final repository = NavigationRepository(records: [first, second]);
      disposeAfterUnmount(tester, repository);
      await home(tester, repository);
      expect(find.text('Same name'), findsNWidgets(2));
      final card = find.byKey(const ValueKey('collection-second'));
      final box = tester.getRect(card);
      await tester.tapAt(box.topLeft + const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(repository.detailIds, ['second']);
      expect(
        tester
            .widget<CollectionDetail>(find.byType(CollectionDetail))
            .collectionId,
        'second',
      );
      expect(find.text('Same name'), findsOneWidget);
    },
  );

  testWidgets('creation appears through the existing list subscription', (
    tester,
  ) async {
    final repository = NavigationRepository();
    disposeAfterUnmount(tester, repository);
    await home(tester, repository);
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'My new collection');
    await tester.ensureVisible(find.text('Create collection'));
    await tester.tap(find.text('Create collection'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('collection-created-0')), findsOneWidget);
    expect(find.text('My new collection'), findsOneWidget);
    expect(repository.allSubscriptions, 1);
    await tester.tap(find.byKey(const ValueKey('collection-created-0')));
    await tester.pumpAndSettle();
    expect(repository.detailIds, ['created-0']);
  });

  testWidgets(
    'collection action has semantic activation and keyboard activation',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = NavigationRepository(records: [first]);
      disposeAfterUnmount(tester, repository);
      await home(tester, repository);
      final card = find.byKey(const ValueKey('collection-first'));
      final node = tester.getSemantics(card);
      expect(node.getSemanticsData().label, contains('Open Same name'));
      expect(node.getSemanticsData().label, contains('Korean · German'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(repository.detailIds, ['first']);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      var reachedCard = false;
      for (var i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.context?.visitAncestorElements((
          element,
        ) {
          if (element.widget.key == const ValueKey('collection-first')) {
            reachedCard = true;
            return false;
          }
          return true;
        });
        if (reachedCard) break;
      }
      expect(reachedCard, isTrue);
      final focusedCard = find.descendant(
        of: card,
        matching: find.byType(PikoCard),
      );
      expect(tester.widget<PikoCard>(focusedCard).focused, isTrue);
      final container = tester.widget<Container>(
        find.descendant(of: focusedCard, matching: find.byType(Container)).first,
      );
      final border = (container.decoration! as BoxDecoration).border! as Border;
      expect(border.top.color, pikoDesign.color('primary'));
      expect(border.top.width, pikoDesign.dimension('states.focusWidth'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(repository.detailIds, ['first', 'first']);
      semantics.dispose();
    },
  );

  testWidgets('home loading and failure retry use a fresh real subscription', (
    tester,
  ) async {
    final repository = NavigationRepository(seed: false);
    disposeAfterUnmount(tester, repository);
    await home(tester, repository);
    final copy = const PikoCopy('en');
    expect(find.text(copy.text('collection.loading')), findsOneWidget);
    expect(find.text(copy.text('home.emptyDescription')), findsNothing);
    repository.allStreams.last.addError(StateError('Read failed'));
    await tester.pumpAndSettle();
    expect(find.text(copy.text('collection.loadFailed')), findsOneWidget);
    expect(find.text(copy.text('home.emptyDescription')), findsNothing);
    await tester.tap(find.text(copy.text('action.retry')));
    await tester.pumpAndSettle();
    expect(repository.allSubscriptions, 2);
    repository.allStreams.last.add([first]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('collection-first')), findsOneWidget);
    expect(find.text(copy.text('collection.loadFailed')), findsNothing);
  });

  testWidgets(
    'detail loading, failed retry and missing result stay distinguishable',
    (tester) async {
      final repository = NavigationRepository(seed: false);
      disposeAfterUnmount(tester, repository);
      await tester.pumpWidget(
        PikoApp(
          home: CollectionDetail(
            repository: repository,
            collectionId: 'missing',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final copy = const PikoCopy('en');
      expect(find.text(copy.text('collection.loading')), findsOneWidget);
      expect(find.text(copy.text('collection.notFound')), findsNothing);
      repository.detailStreams.last.addError(StateError('Read failed'));
      await tester.pumpAndSettle();
      expect(find.text(copy.text('collection.loadFailed')), findsOneWidget);
      expect(find.text(copy.text('collection.notFound')), findsNothing);
      await tester.tap(find.text(copy.text('action.retry')));
      await tester.pumpAndSettle();
      expect(repository.detailSubscriptions, 2);
      repository.detailStreams.last.add(null);
      await tester.pumpAndSettle();
      expect(find.text(copy.text('collection.notFound')), findsOneWidget);
      expect(find.text(copy.text('collection.loadFailed')), findsNothing);
    },
  );

  testWidgets(
    'German large-text list/detail wrap and locale changes retain subscriptions',
    (tester) async {
      tester.view.physicalSize = const Size(392, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final locale = InterfaceLocaleController(const Locale('de'));
      addTearDown(locale.dispose);
      final record = CollectionRecord(
        id: 'long',
        name: 'Meine Vokabelsammlung für Alltag und Reisen',
        targetLanguage: VocabularyLanguage.korean,
        nativeLanguage: VocabularyLanguage.german,
      );
      final repository = NavigationRepository(records: [record]);
      disposeAfterUnmount(tester, repository);
      await home(tester, repository, locale: locale);
      expect(find.text('Koreanisch · Deutsch'), findsOneWidget);
      expect(tester.takeException(), isNull);
      locale.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(repository.allSubscriptions, 1);
      expect(find.text(record.name), findsOneWidget);
      expect(find.text('Korean · German'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('collection-long')));
      await tester.tap(find.byKey(const ValueKey('collection-long')));
      await tester.pumpAndSettle();
      locale.value = const Locale('de');
      await tester.pumpAndSettle();
      expect(repository.detailSubscriptions, 1);
      expect(repository.allSubscriptions, 1);
      expect(find.text(record.name), findsOneWidget);
      expect(find.text('Koreanisch · Deutsch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
