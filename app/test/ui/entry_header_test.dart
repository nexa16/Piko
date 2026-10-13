import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_entry_header.dart';
import 'package:piko/ui/piko_theme.dart';

class HeaderRepository implements VocabularyRepository {
  int writes = 0;
  @override
  Future<VocabularyRecord> create({
    required String collectionId,
    required String targetText,
    required String nativeText,
  }) async => VocabularyRecord(
    id: '${writes++}',
    collectionId: collectionId,
    targetText: targetText,
    nativeText: nativeText,
  );
  @override
  Future<VocabularyRecord> update({
    required String id,
    required String targetText,
    required String nativeText,
  }) => throw UnimplementedError();
  @override
  Stream<List<VocabularyRecord>> watchByCollection(String id) =>
      Stream.value([]);
  @override
  Stream<VocabularyRecord?> watchById(String id) => Stream.value(null);
}

const owner = CollectionRecord(
  id: 'owner',
  name: 'Words',
  targetLanguage: VocabularyLanguage.korean,
  nativeLanguage: VocabularyLanguage.german,
);

Future<EntrySessionController> mount(
  WidgetTester tester, {
  String locale = 'en',
  double width = 760,
  double scale = 1,
  bool reduced = false,
}) async {
  tester.view.reset();
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final session = EntrySessionController(
    collectionId: owner.id,
    repository: HeaderRepository(),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  await tester.pumpWidget(
    PikoApp(
      locale: Locale(locale),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
          ),
          child: EntrySessionScreen(collection: owner, session: session),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

bool focusedWithin(WidgetTester tester, Finder finder) {
  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (focusContext == null) return false;
  final root = tester.element(finder);
  var found = identical(root, focusContext);
  focusContext.visitAncestorElements((element) {
    if (identical(element, root)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

void main() {
  for (final locale in ['en', 'de']) {
    testWidgets(
      '$locale binding header tracks and distinct checkmarks own semantics/tooltips/focus',
      (tester) async {
        await mount(tester, locale: locale);
        final handle = tester.ensureSemantics();
        try {
          final copy = PikoCopy(locale);
          final header = find.byType(PikoEntryHeader);
          final back = find.byTooltip(copy.text('common.back'));
          final global = find.byTooltip(copy.text('entry.complete'));
          final next = find.byTooltip(copy.text('action.saveNext'));
          final title = find.text(copy.text('entry.title'));
          final backRect = tester.getRect(back),
              globalRect = tester.getRect(global),
              titleRect = tester.getRect(title);
          final gap = pikoDesign.dimension('components.entryHeader.gap');
          expect(
            tester.getRect(header).top,
            pikoDesign.dimension('layout.pageTop'),
          );
          final backButton = tester.widget<TextButton>(
            find.descendant(of: back, matching: find.byType(TextButton)),
          );
          expect(backButton.style!.padding!.resolve({}), EdgeInsets.zero);
          expect(
            backButton.style!.textStyle!.resolve({})!.fontSize,
            pikoDesign.dimension('typography.body'),
          );
          expect(
            backButton.style!.textStyle!.resolve({})!.fontWeight,
            pikoDesign.weight('components.entryHeader.backWeight'),
          );
          expect(
            backRect.height,
            greaterThanOrEqualTo(
              pikoDesign.dimension('components.buttons.height'),
            ),
          );
          expect(
            tester.widget<Text>(title).style!.letterSpacing,
            pikoDesign.dimension('components.entryHeader.titleLetterSpacing'),
          );
          expect(titleRect.left - backRect.right, closeTo(gap, .01));
          expect(globalRect.left - titleRect.right, closeTo(gap, .01));
          expect(
            titleRect.center.dx,
            closeTo((backRect.right + globalRect.left) / 2, .01),
          );
          expect(backRect.left, tester.getRect(header).left);
          expect(globalRect.right, tester.getRect(header).right);
          final target = pikoDesign.dimension('controls.largeHeight');
          expect(globalRect.size, Size.square(target));
          expect(tester.getSize(next), Size.square(target));
          expect(find.descendant(of: header, matching: next), findsNothing);
          for (final label in ['entry.complete', 'action.saveNext']) {
            final icon = find.ancestor(
              of: find.byTooltip(copy.text(label)),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.label == copy.text(label),
              ),
            );
            expect(tester.getSemantics(icon).label, copy.text(label));
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          expect(focusedWithin(tester, back), isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          expect(focusedWithin(tester, global), isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          expect(
            FocusManager.instance.primaryFocus?.context?.widget,
            isA<Focus>(),
          );
          expect(
            (FocusManager.instance.primaryFocus!.context!.widget as Focus)
                .onKeyEvent,
            isNotNull,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          expect(focusedWithin(tester, find.byType(TextField).first), isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          expect(focusedWithin(tester, find.byType(TextField).last), isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          expect(focusedWithin(tester, next), isTrue);
          expect(tester.takeException(), isNull);
        } finally {
          handle.dispose();
        }
      },
    );
  }

  for (final width in [400.0, 401.0]) {
    testWidgets('viewport $width uses canonical responsive title boundary', (
      tester,
    ) async {
      await mount(tester, width: width);
      final text = tester.widget<Text>(find.text('Add Entries'));
      expect(
        text.style!.fontSize,
        pikoDesign.dimension(
          width <=
                  pikoDesign.dimension(
                    'components.entryHeader.compactBreakpoint',
                  )
              ? 'components.entryHeader.compactTitleSize'
              : 'components.entryHeader.titleSize',
        ),
      );
    });
  }

  testWidgets(
    '392px German 200% wraps within header and keeps both checks reachable under reduced motion',
    (tester) async {
      await mount(tester, width: 392, locale: 'de', scale: 2, reduced: true);
      final header = tester.getRect(find.byType(PikoEntryHeader));
      final global = tester.getRect(
        find.byTooltip(const PikoCopy('de').text('entry.complete')),
      );
      final title = tester.getRect(find.text('Einträge hinzufügen'));
      expect(title.left, greaterThanOrEqualTo(header.left));
      expect(title.right, lessThanOrEqualTo(global.left));
      expect(global.right, lessThanOrEqualTo(392));
      expect(
        global.size,
        Size.square(pikoDesign.dimension('controls.largeHeight')),
      );
      final next = find.byTooltip(const PikoCopy('de').text('action.saveNext'));
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      expect(tester.getRect(next).bottom, lessThanOrEqualTo(1000));
      expect(find.byType(AnimatedSize), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
