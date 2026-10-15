import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/features/categories/category_assignment_picker.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_checkbox.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'category_assignment_picker_test.dart'
    show PickerFixture, value, checked;

Finder get name => find.descendant(
  of: find.byKey(const ValueKey('category-new-value-name')),
  matching: find.byType(TextField),
);

Future<void> press(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

class HeldValues implements CategoriesRepository {
  HeldValues(this.real);
  final CategoriesRepository real;
  final gate = Completer<void>();
  int writes = 0;
  @override
  Future<CategoryDimensionRecord?> dimensionById(String id) =>
      real.dimensionById(id);
  @override
  Future<List<CategoryValueRecord>> values(String dimensionId) =>
      real.values(dimensionId);
  @override
  Stream<List<CategoryValueRecord>> watchValues(String dimensionId) =>
      real.watchValues(dimensionId);
  @override
  Future<List<CategoryAssignmentRecord>> assignments(String entryId) =>
      real.assignments(entryId);
  @override
  Future<CategoryValueRecord> createValue({
    required String dimensionId,
    required String name,
    String? id,
  }) async {
    writes++;
    await gate.future;
    return real.createValue(dimensionId: dimensionId, name: name, id: id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Unused category fixture method');
}

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language inline value validates, retains staged assignments, and stays unassigned after creation',
      (tester) async {
        final f = PickerFixture();
        try {
          await tester.runAsync(f.initialize);
          await f.mount(tester, language);
          await f.open(tester);
          final copy = PikoCopy(language);
          await tester.tap(value(f.values.last));
          await tester.pumpAndSettle();
          await press(tester, find.text(copy.text('r2.addValue')));
          expect(name, findsOneWidget);
          expect(find.byTooltip(copy.text('r2.saveValue')), findsNothing);
          for (final invalid in ['   ', ' Value 1 ']) {
            await tester.enterText(name, invalid);
            await press(tester, find.byTooltip(copy.text('r2.saveValue')));
            await f.flush(tester);
            expect(find.text(copy.text('r2.valueInvalid')), findsOneWidget);
            expect(tester.widget<TextField>(name).controller!.text, invalid);
            expect(checked(tester, f.values.first), isTrue);
            expect(checked(tester, f.values.last), isTrue);
          }
          await tester.enterText(name, ' Created value ');
          await press(tester, find.byTooltip(copy.text('r2.saveValue')));
          await f.flush(tester);
          expect(find.byType(PikoDialog), findsOneWidget);
          final stored = (await tester.runAsync(
            () => f.repository.values(f.dimension.id),
          ))!;
          expect(stored, hasLength(3));
          expect(stored.last.name, 'Created value');
          expect(stored.last.dimensionId, f.dimension.id);
          expect(checked(tester, stored.last), isFalse);
          expect(checked(tester, f.values.first), isTrue);
          expect(checked(tester, f.values.last), isTrue);
          expect(
            (await tester.runAsync(
              () => f.repository.assignments(f.entryId),
            ))!.single.valueIds,
            {f.values.first.id},
          );
          expect(f.raw.text, ' Retained vocabulary draft ');
          await press(tester, find.text(copy.text('r2.addValue')));
          await tester.enterText(name, 'Canceled value');
          await press(tester, find.text(copy.text('action.cancel')));
          expect(name, findsNothing);
          expect(
            (await tester.runAsync(() => f.repository.values(f.dimension.id)))!,
            hasLength(3),
          );
          expect(checked(tester, stored.last), isFalse);
          expect(checked(tester, f.values.last), isTrue);
        } finally {
          await f.cleanup(tester);
        }
      },
    );
  }

  testWidgets(
    'transient creation failure retains unchanged name for retry and never assigns it',
    (tester) async {
      final f = PickerFixture();
      try {
        await tester.runAsync(f.initialize);
        await tester.runAsync(
          () => f.db.customStatement(
            "CREATE TRIGGER fail_category_value BEFORE INSERT ON category_values BEGIN SELECT RAISE(ABORT, 'fixture write failure'); END",
          ),
        );
        await f.mount(tester, 'en');
        await f.open(tester);
        final copy = PikoCopy('en');
        await press(tester, find.text(copy.text('r2.addValue')));
        await tester.enterText(name, 'Retained name');
        await press(tester, find.byTooltip(copy.text('r2.saveValue')));
        await f.flush(tester);
        expect(
          find.text(copy.text('category.valueSaveFailed')),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(name).controller!.text,
          'Retained name',
        );
        await tester.runAsync(
          () => f.db.customStatement('DROP TRIGGER fail_category_value'),
        );
        await press(tester, find.byTooltip(copy.text('r2.saveValue')));
        await f.flush(tester);
        final stored = (await tester.runAsync(
          () => f.repository.values(f.dimension.id),
        ))!;
        expect(stored.last.name, 'Retained name');
        expect(checked(tester, stored.last), isFalse);
      } finally {
        await f.cleanup(tester);
      }
    },
  );

  testWidgets(
    'accepted value write is single-flight and guards close, cancel and assignment edits until it drains',
    (tester) async {
      final f = PickerFixture();
      HeldValues? held;
      try {
        await tester.runAsync(f.initialize);
        held = HeldValues(f.repository);
        final pending = <Future<void>>[];
        await tester.pumpWidget(
          PikoApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showCategoryAssignmentPicker(
                    context,
                    entryId: f.entryId,
                    dimension: f.dimension,
                    repository: held!,
                    onPendingWrites: pending.add,
                  ),
                  child: const Text('Open picker'),
                ),
              ),
            ),
          ),
        );
        await f.open(tester);
        final copy = PikoCopy('en');
        await press(tester, find.text(copy.text('r2.addValue')));
        await tester.enterText(name, 'Pending value');
        await tester.pumpAndSettle();
        final save = tester.widget<PikoIconButton>(
          find.ancestor(
            of: find.byTooltip(copy.text('r2.saveValue')),
            matching: find.byType(PikoIconButton),
          ),
        );
        final invoke = save.onPressed!;
        invoke();
        invoke();
        await f.flush(tester);
        expect(held.writes, 1);
        expect(tester.widget<TextField>(name).enabled, isFalse);
        expect(
          tester.widget<PikoCheckbox>(value(f.values.first)).onChanged,
          isNull,
        );
        final close = tester.widget<PikoIconButton>(
          find.ancestor(
            of: find.byTooltip(copy.text('common.close')),
            matching: find.byType(PikoIconButton),
          ),
        );
        expect(close.onPressed, isNull);
        held.gate.complete();
        await f.flush(tester);
        await Future.wait(pending);
        await tester.pumpAndSettle();
        final stored = (await tester.runAsync(
          () => f.repository.values(f.dimension.id),
        ))!;
        expect(stored.last.name, 'Pending value');
        expect(checked(tester, stored.last), isFalse);
        expect(find.byType(PikoDialog), findsOneWidget);
      } finally {
        if (held != null && !held.gate.isCompleted) held.gate.complete();
        await f.cleanup(tester);
      }
    },
  );
}
