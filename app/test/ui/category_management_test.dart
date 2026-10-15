import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/features/categories/category_management.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'category_assignment_picker_test.dart' show PickerFixture;
import 'category_inline_value_test.dart' show press;

Finder field(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextField),
);
Finder get confirmation => find.byType(PikoDialog).last;

Future<void> mount(
  WidgetTester tester,
  PickerFixture f,
  String language, {
  CategoriesRepository? repository,
  ValueChanged<bool>? pending,
  ValueChanged<Future<void>>? writes,
}) async {
  await tester.pumpWidget(
    PikoApp(
      localeController: InterfaceLocaleController(Locale(language)),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPikoDialog<void>(
              context,
              builder: (_) => PikoDialog(
                title: 'Collection menu',
                body: ExpansionTile(
                  title: Text(PikoCopy(language).text('r2.editCategories')),
                  initiallyExpanded: true,
                  children: [
                    CategoryManagement(
                      collectionId: f.dimension.collectionId,
                      repository: repository ?? f.repository,
                      onPendingChanged: pending,
                      onPendingWrites: writes,
                    ),
                  ],
                ),
              ),
            ),
            child: const Text('Open menu'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open menu'));
  await f.flush(tester);
}

Future<void> expand(WidgetTester tester, PickerFixture f) async {
  await press(tester, find.text(f.dimension.name));
  await f.flush(tester);
}

Future<void> acceptDelete(
  WidgetTester tester,
  String key,
  String language,
) async {
  final target = find.descendant(
    of: confirmation,
    matching: find.widgetWithText(PikoButton, PikoCopy(language).text(key)),
  );
  await press(tester, target);
}

class HeldUpdate implements CategoriesRepository {
  HeldUpdate(this.real);
  final CategoriesRepository real;
  final gate = Completer<void>();
  int updates = 0;
  @override
  Stream<List<CategoryDimensionRecord>> watchDimensions(String collectionId) =>
      real.watchDimensions(collectionId);
  @override
  Stream<List<CategoryValueRecord>> watchValues(String dimensionId) =>
      real.watchValues(dimensionId);
  @override
  Future<CategoryDimensionRecord> updateDimension({
    required String id,
    required String name,
    required CategoryMode mode,
  }) async {
    updates++;
    await gate.future;
    return real.updateDimension(id: id, name: name, mode: mode);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unused management fixture method');
}

void main() {
  testWidgets(
    'collapse and reopen retain staged form without sharing Boolean expansion storage with text scrolling',
    (tester) async {
      final f = PickerFixture();
      try {
        await tester.runAsync(f.initialize);
        await mount(tester, f, 'en');
        await expand(tester, f);
        final input = field('category-management-name-${f.dimension.id}');
        await tester.enterText(input, ' Retained unsaved name ');
        final controller = tester.widget<TextField>(input).controller!;
        await press(tester, find.text('Difficulty'));
        expect(input, findsNothing);
        await press(tester, find.text('Difficulty'));
        await f.flush(tester);
        expect(tester.widget<TextField>(input).controller, same(controller));
        expect(controller.text, ' Retained unsaved name ');
        expect(
          (await tester.runAsync(
            () => f.repository.dimensionById(f.dimension.id),
          ))!.name,
          'Difficulty',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await f.cleanup(tester);
      }
    },
  );
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language inline name/mode confirm together and blocked Single conversion preserves both stored fields',
      (tester) async {
        final f = PickerFixture();
        try {
          await tester.runAsync(f.initialize);
          await tester.runAsync(
            () => f.repository.replaceAssignments(
              entryId: f.entryId,
              assignments: {
                f.dimension.id: f.values.map((value) => value.id).toSet(),
              },
            ),
          );
          await mount(tester, f, language);
          await expand(tester, f);
          final copy = PikoCopy(language);
          final name = field('category-management-name-${f.dimension.id}');
          expect(find.text(copy.text('category.saveDimension')), findsNothing);
          await tester.enterText(name, ' Renamed difficulty ');
          await press(tester, find.text(copy.text('r2.single')));
          await press(tester, find.text(copy.text('category.saveDimension')));
          await f.flush(tester);
          expect(find.text(copy.text('r2.categoryInvalid')), findsOneWidget);
          final stored = (await tester.runAsync(
            () => f.repository.dimensionById(f.dimension.id),
          ))!;
          expect(stored.name, 'Difficulty');
          expect(stored.mode, CategoryMode.multiple);
          expect(
            tester.widget<TextField>(name).controller!.text,
            ' Renamed difficulty ',
          );
          await press(tester, find.text(copy.text('r2.multiple')));
          await press(tester, find.text(copy.text('category.saveDimension')));
          await f.flush(tester);
          final saved = (await tester.runAsync(
            () => f.repository.dimensionById(f.dimension.id),
          ))!;
          expect(saved.name, 'Renamed difficulty');
          expect(saved.mode, CategoryMode.multiple);
          expect(saved.position, f.dimension.position);
          expect(find.text(copy.text('category.saveDimension')), findsNothing);
          expect(find.byType(CategoryManagement), findsOneWidget);
        } finally {
          await f.cleanup(tester);
        }
      },
    );

    testWidgets(
      '$language safe value/dimension deletion returns to expanded menu and preserves vocabulary/learning',
      (tester) async {
        final f = PickerFixture();
        try {
          await tester.runAsync(f.initialize);
          final before = (await tester.runAsync(
            () => f.db
                .customSelect('SELECT * FROM learning_items ORDER BY id')
                .get(),
          ))!.map((row) => row.data).toList();
          expect(before, hasLength(2));
          await mount(tester, f, language);
          await expand(tester, f);
          final copy = PikoCopy(language);
          final valueRow = find.byKey(ValueKey(f.values.first.id));
          final removeValue = find.descendant(
            of: valueRow,
            matching: find.byTooltip(copy.text('category.deleteValue')),
          );
          await press(tester, removeValue);
          expect(
            find.descendant(
              of: confirmation,
              matching: find.byTooltip(copy.text('common.close')),
            ),
            findsNothing,
          );
          await press(
            tester,
            find.descendant(
              of: confirmation,
              matching: find.text(copy.text('action.cancel')),
            ),
          );
          expect(
            (await tester.runAsync(() => f.repository.values(f.dimension.id)))!,
            hasLength(2),
          );
          await press(tester, removeValue);
          await acceptDelete(tester, 'category.deleteValue', language);
          await f.flush(tester);
          expect(find.byType(CategoryManagement), findsOneWidget);
          expect(find.byKey(ValueKey(f.values.last.id)), findsOneWidget);
          expect(
            (await tester.runAsync(() => f.repository.assignments(f.entryId)))!,
            isEmpty,
          );
          await press(tester, find.text(copy.text('category.deleteDimension')));
          await acceptDelete(tester, 'category.deleteDimension', language);
          await f.flush(tester);
          expect(find.byType(CategoryManagement), findsOneWidget);
          expect(find.text(copy.text('category.addDimension')), findsOneWidget);
          expect(
            (await tester.runAsync(
              () => f.repository.dimensions(f.dimension.collectionId),
            ))!,
            isEmpty,
          );
          final after = (await tester.runAsync(
            () => f.db
                .customSelect('SELECT * FROM learning_items ORDER BY id')
                .get(),
          ))!.map((row) => row.data).toList();
          expect(after, before);
          expect(
            (await tester.runAsync(
              () => f.db.customSelect('SELECT * FROM vocabulary_entries').get(),
            ))!,
            hasLength(1),
          );
          expect(f.raw.text, ' Retained vocabulary draft ');
        } finally {
          await f.cleanup(tester);
        }
      },
    );
  }

  testWidgets(
    'inline dimension/value creation and value rename retain creation order without assignments',
    (tester) async {
      final f = PickerFixture();
      try {
        await tester.runAsync(f.initialize);
        await mount(tester, f, 'en');
        final copy = PikoCopy('en');
        await press(tester, find.text(copy.text('category.addDimension')));
        await tester.enterText(field('category-management-name-new'), 'Topic');
        await press(tester, find.text(copy.text('category.saveDimension')));
        await f.flush(tester);
        final dimensions = (await tester.runAsync(
          () => f.repository.dimensions(f.dimension.collectionId),
        ))!;
        expect(dimensions.map((dimension) => dimension.name), [
          'Difficulty',
          'Topic',
        ]);
        final topic = dimensions.last;
        final branch = find.byKey(ValueKey(topic.id));
        if (find
            .descendant(
              of: branch,
              matching: find.text(copy.text('r2.addValue')),
            )
            .evaluate()
            .isEmpty) {
          await press(tester, find.text('Topic'));
          await f.flush(tester);
        }
        await press(
          tester,
          find.descendant(
            of: branch,
            matching: find.text(copy.text('r2.addValue')),
          ),
        );
        await tester.enterText(
          field('category-management-value-new-${topic.id}'),
          'Travel',
        );
        await press(tester, find.byTooltip(copy.text('r2.saveValue')));
        await f.flush(tester);
        final values = (await tester.runAsync(
          () => f.repository.values(topic.id),
        ))!;
        expect(values.single.name, 'Travel');
        final row = find.byKey(ValueKey(values.single.id));
        await press(
          tester,
          find.descendant(
            of: row,
            matching: find.byTooltip(copy.text('r2.editValue')),
          ),
        );
        await tester.enterText(
          field('category-management-value-${values.single.id}'),
          'Journey',
        );
        await press(tester, find.byTooltip(copy.text('r2.saveValue')));
        await f.flush(tester);
        final updated = (await tester.runAsync(
          () => f.repository.values(topic.id),
        ))!.single;
        expect(updated.id, values.single.id);
        expect(updated.name, 'Journey');
        expect(updated.position, values.single.position);
        expect(
          (await tester.runAsync(
            () => f.repository.assignments(f.entryId),
          ))!.single.dimensionId,
          f.dimension.id,
        );
      } finally {
        await f.cleanup(tester);
      }
    },
  );

  testWidgets(
    'failed deletion keeps confirmation open for retry and leaves content intact',
    (tester) async {
      final f = PickerFixture();
      try {
        await tester.runAsync(f.initialize);
        await tester.runAsync(
          () => f.db.customStatement(
            "CREATE TRIGGER fail_value_delete BEFORE DELETE ON category_values BEGIN SELECT RAISE(ABORT, 'fixture failure'); END",
          ),
        );
        await mount(tester, f, 'en');
        await expand(tester, f);
        final copy = PikoCopy('en');
        await press(
          tester,
          find.descendant(
            of: find.byKey(ValueKey(f.values.first.id)),
            matching: find.byTooltip(copy.text('category.deleteValue')),
          ),
        );
        await acceptDelete(tester, 'category.deleteValue', 'en');
        await f.flush(tester);
        expect(find.text(copy.text('category.deleteFailed')), findsOneWidget);
        expect(
          (await tester.runAsync(() => f.repository.values(f.dimension.id)))!,
          hasLength(2),
        );
        await tester.runAsync(
          () => f.db.customStatement('DROP TRIGGER fail_value_delete'),
        );
        await acceptDelete(tester, 'category.deleteValue', 'en');
        await f.flush(tester);
        expect(find.text(copy.text('category.deleteFailed')), findsNothing);
        expect(
          (await tester.runAsync(() => f.repository.values(f.dimension.id)))!,
          hasLength(1),
        );
        expect(find.byType(CategoryManagement), findsOneWidget);
      } finally {
        await f.cleanup(tester);
      }
    },
  );

  testWidgets(
    'one pending rename disables controls and reports its drain without duplicate writes',
    (tester) async {
      final f = PickerFixture();
      HeldUpdate? held;
      try {
        await tester.runAsync(f.initialize);
        held = HeldUpdate(f.repository);
        final changes = <bool>[], pending = <Future<void>>[];
        await mount(
          tester,
          f,
          'en',
          repository: held,
          pending: changes.add,
          writes: pending.add,
        );
        await expand(tester, f);
        final name = field('category-management-name-${f.dimension.id}');
        await tester.enterText(name, 'Pending name');
        await tester.pumpAndSettle();
        final invoke = tester
            .widget<PikoButton>(
              find.widgetWithText(
                PikoButton,
                PikoCopy('en').text('category.saveDimension'),
              ),
            )
            .onPressed!;
        invoke();
        invoke();
        await tester.pumpAndSettle();
        expect(held.updates, 1);
        expect(tester.widget<TextField>(name).enabled, isFalse);
        held.gate.complete();
        await f.flush(tester);
        await Future.wait(pending);
        await tester.pumpAndSettle();
        expect(changes, [true, false]);
        expect(
          (await tester.runAsync(
            () => f.repository.dimensionById(f.dimension.id),
          ))!.name,
          'Pending name',
        );
      } finally {
        if (held != null && !held.gate.isCompleted) held.gate.complete();
        await f.cleanup(tester);
      }
    },
  );
}
