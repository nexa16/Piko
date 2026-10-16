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
import 'entry_keyboard_layout_test.dart' show scrollActionIntoView;

class HeaderRepository implements VocabularyRepository {
  @override
  Future<VocabularyOpeningSnapshot> captureOpeningSnapshot({
    required String entryId,
    required String collectionId,
  }) => throw UnimplementedError(
    'Entry-stack fixture does not open inline editors.',
  );
  @override
  Future<VocabularyRecord> restoreOpeningSnapshot(
    VocabularyOpeningSnapshot snapshot,
  ) => throw UnimplementedError(
    'Entry-stack fixture does not discard inline edits.',
  );
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
      '$locale visible Finish and Save & Next retain semantics, tooltips and focus',
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
            pikoDesign.dimension('typography.control'),
          );
          expect(
            backButton.style!.textStyle!.resolve({})!.fontWeight,
            FontWeight.w700,
          );
          expect(
            backRect.height,
            greaterThanOrEqualTo(
              pikoDesign.dimension('components.buttons.height'),
            ),
          );
          expect(
            tester.widget<Text>(title).style!.letterSpacing,
            0,
          );
          if (titleRect.top >= backRect.bottom) {
            // The longer German title takes its own row before compression.
            expect(titleRect.top, greaterThanOrEqualTo(globalRect.bottom));
            expect(titleRect.left, tester.getRect(header).left);
            expect(titleRect.right, tester.getRect(header).right);
          } else {
            expect(titleRect.left - backRect.right, closeTo(gap, .01));
            expect(globalRect.left - titleRect.right, closeTo(gap, .01));
            expect(titleRect.center.dx,
                closeTo((backRect.right + globalRect.left) / 2, .01));
          }
          expect(backRect.left, tester.getRect(header).left);
          expect(globalRect.right, tester.getRect(header).right);
          final target = pikoDesign.dimension('controls.largeHeight');
          expect(globalRect.height, greaterThanOrEqualTo(target));
          expect(globalRect.width, greaterThanOrEqualTo(target));
          expect(tester.getSize(next).height, greaterThanOrEqualTo(target));
          expect(tester.getSize(next).width, greaterThan(target));
          expect(find.descendant(of: header, matching: next), findsNothing);
          for (final label in ['entry.complete', 'action.saveNext']) {
            expect(find.text(copy.text(label)), findsOneWidget);
            expect(find.bySemanticsLabel(copy.text(label)), findsOneWidget);
          }
          // UX-ENTRY-001 opens the target field immediately. Start the header
          // traversal explicitly at Back rather than assuming no initial focus.
          expect(focusedWithin(tester, find.byType(TextField).first), isTrue);
          Focus.of(
            tester.element(
              find.descendant(of: back, matching: find.byType(Text)).first,
            ),
          ).requestFocus();
          await tester.pump();
          expect(focusedWithin(tester, back), isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(focusedWithin(tester, global), isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
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
          await tester.pump();
          expect(focusedWithin(tester, find.byType(TextField).first), isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(focusedWithin(tester, find.byType(TextField).last), isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
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
      final text = tester.widget<Text>(find.text(const PikoCopy('en').text('entry.title')));
      expect(
        text.style!.fontSize,
        pikoDesign.dimension('typography.title'),
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
      final title = tester.getRect(find.text(const PikoCopy('de').text('entry.title')));
      final back = tester.getRect(
        find.byTooltip(const PikoCopy('de').text('common.back')),
      );
      // Enlarged text uses a full-width title below the navigation row. Assert
      // the reflow's separate tracks instead of the compact single-row bounds.
      expect(title.left, closeTo(header.left, .01));
      expect(title.right, closeTo(header.right, .01));
      final titleMargin = pikoDesign.dimension(
        'components.headings.titleMargin',
      );
      expect(title.top, greaterThanOrEqualTo(global.bottom + titleMargin));
      expect(title.top, greaterThanOrEqualTo(back.bottom + titleMargin));
      expect(title.bottom, lessThanOrEqualTo(header.bottom));
      expect(back.right, lessThanOrEqualTo(global.left));
      expect(global.right, closeTo(header.right, .01));
      expect(global.right, lessThanOrEqualTo(392));
      expect(
        global.height,
        greaterThanOrEqualTo(pikoDesign.dimension('controls.largeHeight')),
      );
      expect(
        find
            .byTooltip(const PikoCopy('de').text('entry.complete'))
            .hitTestable(),
        findsOneWidget,
      );
      final next = find.byTooltip(const PikoCopy('de').text('action.saveNext'));
      await scrollActionIntoView(tester, next);
      expect(tester.getRect(next).bottom, lessThanOrEqualTo(1000));
      expect(next.hitTestable(), findsOneWidget);
      expect(find.byType(AnimatedSize), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
