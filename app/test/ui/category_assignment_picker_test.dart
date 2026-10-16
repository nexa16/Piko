import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/categories/category_assignment_picker.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_checkbox.dart';

class PickerFixture {
  final db = PikoDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  late final repository = SqliteCategoriesRepository(db);
  late CategoryDimensionRecord dimension;
  late String entryId;
  final values = <CategoryValueRecord>[];
  final results = <CategoryAssignmentRecord?>[];
  final raw = TextEditingController(text: ' Retained vocabulary draft ');

  Future<void> initialize({
    CategoryMode mode = CategoryMode.multiple,
    int count = 2,
  }) async {
    final owner = await SqliteCollectionsRepository(db).create(
      name: 'Words',
      targetLanguage: VocabularyLanguage.french,
      nativeLanguage: VocabularyLanguage.german,
    );
    entryId = (await SqliteVocabularyRepository(db).create(
      collectionId: owner.id,
      targetText: 'pomme',
      nativeText: 'Apfel',
    )).id;
    dimension = await repository.createDimension(
      collectionId: owner.id,
      name: 'Difficulty',
      mode: mode,
    );
    for (var i = 0; i < count; i++) {
      values.add(
        await repository.createValue(
          dimensionId: dimension.id,
          name: 'Value ${i + 1}',
        ),
      );
    }
    if (values.isNotEmpty) {
      await repository.replaceAssignments(
        entryId: entryId,
        assignments: {
          dimension.id: {values.first.id},
        },
      );
    }
  }

  Future<void> flush(WidgetTester tester) async {
    await tester.runAsync(() => db.customSelect('SELECT 1').get());
    await tester.pumpAndSettle();
  }

  Future<void> mount(
    WidgetTester tester,
    String language, {
    Set<String>? initial,
  }) async {
    await tester.pumpWidget(
      PikoApp(
        localeController: InterfaceLocaleController(Locale(language)),
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextField(controller: raw),
                TextButton(
                  onPressed: () async {
                    results.add(
                      await showCategoryAssignmentPicker(
                        context,
                        entryId: entryId,
                        dimension: dimension,
                        repository: repository,
                        initialValueIds: initial,
                      ),
                    );
                  },
                  child: const Text('Open picker'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Open picker'));
    await flush(tester);
  }

  Future<void> cleanup(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(db.close);
    raw.dispose();
  }
}

Finder value(CategoryValueRecord value) =>
    find.byKey(ValueKey('category-value-${value.id}'));
bool checked(WidgetTester tester, CategoryValueRecord record) =>
    tester.widget<PikoCheckbox>(value(record)).value;

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language changed-only Apply stages a set, reverting hides it, X cancels, Apply returns without assignment writes',
      (tester) async {
        final f = PickerFixture();
        try {
          await tester.runAsync(f.initialize);
          await f.mount(tester, language);
          await f.open(tester);
          final copy = PikoCopy(language);
          expect(find.text('Difficulty'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('category-value-search')),
            findsNothing,
          );
          expect(checked(tester, f.values.first), isTrue);
          expect(find.text(copy.text('r2.apply')), findsNothing);
          final titleBefore = tester.getRect(find.text('Difficulty'));
          final rowBefore = tester.getRect(value(f.values.last));
          await tester.tap(value(f.values.last));
          await tester.pumpAndSettle();
          expect(find.text(copy.text('r2.apply')), findsOneWidget);
          expect(tester.getRect(find.text('Difficulty')), titleBefore);
          expect(tester.getRect(value(f.values.last)), rowBefore);
          await tester.tap(value(f.values.last));
          await tester.pumpAndSettle();
          expect(find.text(copy.text('r2.apply')), findsNothing);
          expect(tester.getRect(find.text('Difficulty')), titleBefore);
          expect(tester.getRect(value(f.values.last)), rowBefore);
          await tester.tap(value(f.values.last));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip(copy.text('common.close')));
          await tester.pumpAndSettle();
          expect(f.results, [null]);
          await f.open(tester);
          expect(checked(tester, f.values.last), isFalse);
          await tester.tap(value(f.values.last));
          await tester.pumpAndSettle();
          await tester.tap(find.text(copy.text('r2.apply')));
          await f.flush(tester);
          expect(f.results.last!.valueIds, {
            f.values.first.id,
            f.values.last.id,
          });
          final stored = (await tester.runAsync(
            () => f.repository.assignments(f.entryId),
          ))!;
          expect(stored.single.valueIds, {f.values.first.id});
          expect(f.raw.text, ' Retained vocabulary draft ');
        } finally {
          await f.cleanup(tester);
        }
      },
    );
  }

  testWidgets(
    'Single selection replaces its staged predecessor and can be explicitly cleared',
    (tester) async {
      final f = PickerFixture();
      try {
        await tester.runAsync(() => f.initialize(mode: CategoryMode.single));
        await f.mount(tester, 'en');
        await f.open(tester);
        await tester.tap(value(f.values.last));
        await tester.pumpAndSettle();
        expect(checked(tester, f.values.first), isFalse);
        expect(checked(tester, f.values.last), isTrue);
        await tester.tap(value(f.values.last));
        await tester.pumpAndSettle();
        await tester.tap(find.text(PikoCopy('en').text('r2.apply')));
        await f.flush(tester);
        expect(f.results.single!.valueIds, isEmpty);
        expect(
          (await tester.runAsync(
            () => f.repository.assignments(f.entryId),
          ))!.single.valueIds,
          {f.values.first.id},
        );
      } finally {
        await f.cleanup(tester);
      }
    },
  );

  testWidgets(
    'overflow alone introduces search; filtering retains query and uses one visible value scroll region',
    (tester) async {
      final f = PickerFixture();
      try {
        await tester.runAsync(() => f.initialize(count: 12));
        await f.mount(tester, 'en', initial: {f.values.last.id});
        await f.open(tester);
        final search = find.byKey(const ValueKey('category-value-search'));
        expect(search, findsOneWidget);
        final input = find.descendant(
          of: search,
          matching: find.byType(TextField),
        );
        await tester.enterText(input, 'Value 12');
        await tester.pumpAndSettle();
        expect(search, findsOneWidget);
        expect(value(f.values.last), findsOneWidget);
        expect(value(f.values.first), findsNothing);
        expect(checked(tester, f.values.last), isTrue);
        expect(
          find.byKey(const ValueKey('category-value-list')),
          findsOneWidget,
        );
        tester.view.physicalSize = const Size(392, 480);
        tester.view.devicePixelRatio = 1;
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(input).controller!.text, 'Value 12');
        expect(checked(tester, f.values.last), isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        tester.view.reset();
        await f.cleanup(tester);
      }
    },
  );

  testWidgets(
    'empty lists offer no search or Apply and preserve an unsaved parent selection draft',
    (tester) async {
      final f = PickerFixture();
      try {
        await tester.runAsync(() => f.initialize(count: 0));
        await f.mount(tester, 'de', initial: {});
        await f.open(tester);
        expect(
          find.text(PikoCopy('de').text('category.emptyValues')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('category-value-search')),
          findsNothing,
        );
        expect(find.text(PikoCopy('de').text('r2.apply')), findsNothing);
        expect(f.raw.text, ' Retained vocabulary draft ');
      } finally {
        await f.cleanup(tester);
      }
    },
  );
}
