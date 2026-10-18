import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/features/categories/category_dimension_form.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'category_assignment_picker_test.dart' show PickerFixture;
import 'category_inline_value_test.dart' show press;

Finder get name => find.descendant(
  of: find.byKey(const ValueKey('category-dimension-name')),
  matching: find.byType(TextField),
);

Future<void> mount(
  WidgetTester tester,
  PickerFixture f,
  String language,
  List<CategoryDimensionRecord?> results, {
  CategoriesRepository? repository,
  ValueChanged<Future<void>>? pending,
}) async {
  await tester.pumpWidget(
    PikoApp(
      localeController: InterfaceLocaleController(Locale(language)),
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              TextField(controller: f.raw),
              TextButton(
                onPressed: () async {
                  results.add(
                    await showCreateCategoryDimension(
                      context,
                      collectionId: f.dimension.collectionId,
                      repository: repository ?? f.repository,
                      onPendingWrites: pending,
                    ),
                  );
                },
                child: const Text('Create dimension'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Create dimension'));
  await tester.pumpAndSettle();
}

class HeldDimension implements CategoriesRepository {
  HeldDimension(this.real);
  final CategoriesRepository real;
  final gate = Completer<void>();
  int writes = 0;
  @override
  Future<CategoryDimensionRecord> createDimension({
    required String collectionId,
    required String name,
    required CategoryMode mode,
    bool carryOver = false,
    String? id,
  }) async {
    writes++;
    await gate.future;
    return real.createDimension(
      collectionId: collectionId,
      name: name,
      mode: mode,
      carryOver: carryOver,
      id: id,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unused category fixture method');
}

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language create stages name and mode; reverting hides bottom Save; confirmed dimension starts empty',
      (tester) async {
        final f = PickerFixture();
        try {
          await tester.runAsync(f.initialize);
          final results = <CategoryDimensionRecord?>[];
          await mount(tester, f, language, results);
          final copy = PikoCopy(language);
          expect(find.byType(RadioListTile<CategoryMode>), findsNWidgets(2));
          expect(find.byType(DropdownButton<CategoryMode>), findsNothing);
          expect(find.text(copy.text('category.saveDimension')), findsNothing);
          await tester.tap(
            find.byKey(const ValueKey('category-dimension-mode-multiple')),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(copy.text('category.saveDimension')),
            findsOneWidget,
          );
          await tester.tap(
            find.byKey(const ValueKey('category-dimension-mode-single')),
          );
          await tester.pumpAndSettle();
          expect(find.text(copy.text('category.saveDimension')), findsNothing);
          await tester.enterText(name, ' Topic ');
          await tester.tap(
            find.byKey(const ValueKey('category-dimension-mode-multiple')),
          );
          await tester.pumpAndSettle();
          final save = find.text(copy.text('category.saveDimension'));
          await tester.ensureVisible(save);
          await tester.pumpAndSettle();
          expect(
            tester.getRect(save).top,
            greaterThanOrEqualTo(
              tester
                  .getRect(
                    find.byKey(
                      const ValueKey('category-dimension-mode-multiple'),
                    ),
                  )
                  .bottom,
            ),
          );
          await press(tester, save);
          await f.flush(tester);
          expect(results, hasLength(1));
          final created = results.single!;
          expect(created.name, 'Topic');
          expect(created.mode, CategoryMode.multiple);
          expect(created.collectionId, f.dimension.collectionId);
          expect(
            (await tester.runAsync(() => f.repository.values(created.id)))!,
            isEmpty,
          );
          expect(
            (await tester.runAsync(
              () => f.repository.assignments(f.entryId),
            ))!.any((assignment) => assignment.dimensionId == created.id),
            isFalse,
          );
          expect(f.raw.text, ' Retained vocabulary draft ');
        } finally {
          await f.cleanup(tester);
        }
      },
    );

    testWidgets(
      '$language invalid name retains both fields; X discards unconfirmed dimension',
      (tester) async {
        final f = PickerFixture();
        try {
          await tester.runAsync(f.initialize);
          final results = <CategoryDimensionRecord?>[];
          await mount(tester, f, language, results);
          final copy = PikoCopy(language);
          await tester.tap(
            find.byKey(const ValueKey('category-dimension-mode-multiple')),
          );
          await tester.pumpAndSettle();
          for (final raw in ['   ', ' Difficulty ']) {
            await tester.enterText(name, raw);
            await press(tester, find.text(copy.text('category.saveDimension')));
            await f.flush(tester);
            expect(
              find.text(copy.text('category.dimensionNameInvalid')),
              findsOneWidget,
            );
            expect(tester.widget<TextField>(name).controller!.text, raw);
            final radios = tester.widget<RadioGroup<CategoryMode>>(
              find.byType(RadioGroup<CategoryMode>),
            );
            expect(radios.groupValue, CategoryMode.multiple);
          }
          await press(tester, find.byTooltip(copy.text('common.close')));
          expect(results, [null]);
          expect(
            (await tester.runAsync(
              () => f.repository.dimensions(f.dimension.collectionId),
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
    'transient dimension failure retries same name/mode without partial creation',
    (tester) async {
      final f = PickerFixture();
      try {
        await tester.runAsync(f.initialize);
        await tester.runAsync(
          () => f.db.customStatement(
            "CREATE TRIGGER fail_dimension BEFORE INSERT ON category_dimensions BEGIN SELECT RAISE(ABORT, 'fixture failure'); END",
          ),
        );
        final results = <CategoryDimensionRecord?>[];
        await mount(tester, f, 'en', results);
        await tester.enterText(name, 'Retained dimension');
        await tester.tap(
          find.byKey(const ValueKey('category-dimension-mode-multiple')),
        );
        final copy = PikoCopy('en');
        await press(tester, find.text(copy.text('category.saveDimension')));
        await f.flush(tester);
        expect(
          find.text(copy.text('category.dimensionSaveFailed')),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(name).controller!.text,
          'Retained dimension',
        );
        expect(
          (await tester.runAsync(
            () => f.repository.dimensions(f.dimension.collectionId),
          ))!,
          hasLength(1),
        );
        await tester.runAsync(
          () => f.db.customStatement('DROP TRIGGER fail_dimension'),
        );
        await press(tester, find.text(copy.text('category.saveDimension')));
        await f.flush(tester);
        expect(results.single!.mode, CategoryMode.multiple);
        expect(
          (await tester.runAsync(
            () => f.repository.dimensions(f.dimension.collectionId),
          ))!,
          hasLength(2),
        );
      } finally {
        await f.cleanup(tester);
      }
    },
  );

  testWidgets(
    'pending dimension creation is single-flight and disables name, mode and dismissal',
    (tester) async {
      final f = PickerFixture();
      HeldDimension? held;
      try {
        await tester.runAsync(f.initialize);
        held = HeldDimension(f.repository);
        final results = <CategoryDimensionRecord?>[],
            pending = <Future<void>>[];
        await mount(
          tester,
          f,
          'en',
          results,
          repository: held,
          pending: pending.add,
        );
        await tester.enterText(name, 'Pending dimension');
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
        expect(held.writes, 1);
        expect(tester.widget<TextField>(name).enabled, isFalse);
        expect(
          tester
              .widgetList<RadioListTile<CategoryMode>>(
                find.byType(RadioListTile<CategoryMode>),
              )
              .every((radio) => radio.enabled == false),
          isTrue,
        );
        final close = tester.widget<PikoIconButton>(
          find.ancestor(
            of: find.byTooltip(PikoCopy('en').text('common.close')),
            matching: find.byType(PikoIconButton),
          ),
        );
        expect(close.onPressed, isNull);
        held.gate.complete();
        await f.flush(tester);
        await Future.wait(pending);
        await tester.pumpAndSettle();
        expect(results, hasLength(1));
      } finally {
        if (held != null && !held.gate.isCompleted) held.gate.complete();
        await f.cleanup(tester);
      }
    },
  );
}
