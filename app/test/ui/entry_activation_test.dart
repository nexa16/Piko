import 'package:piko/ui/components/piko_interaction_anchor.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'entry_stack_test.dart'
    show ScreenRepository, owner, mount, seed, field, clean, scrollTo;

bool focused(WidgetTester tester, String id, String side) =>
    tester.widget<TextField>(field(id, side)).focusNode!.hasFocus;

void main() {
  testWidgets(
    'opening, Save & Next from native, and deliberate draft reopen focus target',
    (tester) async {
      final session = EntrySessionController(
        collectionId: owner.id,
        repository: ScreenRepository(),
      );
      clean(tester, session);
      await mount(tester, session, reduced: true);
      expect(focused(tester, 'draft', 'target'), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      for (var i = 0; i < 3; i++) {
        await tester.enterText(field('draft', 'target'), 'Word $i');
        await tester.enterText(field('draft', 'native'), 'Wort $i');
        expect(focused(tester, 'draft', 'native'), isTrue);
        final save = find.byTooltip(PikoCopy('en').text('action.saveNext'));
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(session.confirmedEntries, hasLength(i + 1));
        expect(focused(tester, 'draft', 'target'), isTrue);
        expect(focused(tester, 'draft', 'native'), isFalse);
        expect(tester.testTextInput.isVisible, isTrue);
      }
      session.setTargetText(' Retained raw ');
      session.selectSavedEntry('entry-1');
      await tester.pumpAndSettle();
      expect(focused(tester, 'entry-1', 'target'), isFalse);
      expect(focused(tester, 'entry-1', 'native'), isFalse);
      session.selectDraft();
      await tester.pumpAndSettle();
      expect(focused(tester, 'draft', 'target'), isTrue);
      expect(session.draft.targetText, ' Retained raw ');
    },
  );

  testWidgets(
    'held user scroll activates only after settling, reflow and programmatic scroll preserve selection',
    (tester) async {
      final session = EntrySessionController(
        collectionId: owner.id,
        repository: ScreenRepository(),
      );
      final locale = InterfaceLocaleController();
      addTearDown(locale.dispose);
      clean(tester, session);
      await seed(session, 3);
      await mount(tester, session, locale: locale, reduced: true);
      final viewport = find.byKey(const ValueKey('entry-stack'));
      final bounds = tester.getRect(viewport);
      final saved = tester.getRect(
        find.byKey(const ValueKey('entry-card-entry-2')),
      );
      final gesture = await tester.startGesture(
        Offset(bounds.left + 4, bounds.center.dy),
      );
      await gesture.moveBy(Offset(0, bounds.center.dy - saved.center.dy));
      await tester.pump(const Duration(milliseconds: 100));
      expect(session.activeEntryId, isNull);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(session.activeEntryId, 'entry-2');
      expect(focused(tester, 'entry-2', 'target'), isFalse);
      expect(focused(tester, 'entry-2', 'native'), isFalse);
      final scroll = tester
          .widget<PikoAnchoredBoxScrollView>(viewport)
          .controller!;
      scroll.jumpTo(scroll.position.minScrollExtent);
      await tester.pumpAndSettle();
      expect(session.activeEntryId, 'entry-2');
      locale.value = const Locale('de');
      await tester.pumpAndSettle();
      expect(session.activeEntryId, 'entry-2');
      expect(focused(tester, 'entry-2', 'target'), isFalse);
      await scrollTo(tester, 'draft');
      expect(session.activeEntryId, isNull);
      expect(focused(tester, 'draft', 'target'), isTrue);
    },
  );

  testWidgets(
    'failed Save & Next retains draft identity instead of reopening a fresh editor',
    (tester) async {
      final repository = ScreenRepository();
      final session = EntrySessionController(
        collectionId: owner.id,
        repository: repository,
      );
      clean(tester, session);
      await mount(tester, session, reduced: true);
      await tester.enterText(field('draft', 'target'), ' Raw ');
      await tester.enterText(field('draft', 'native'), ' Wert ');
      final raw = session.draft;
      repository.pending = Completer<VocabularyRecord>();
      await tester.tap(find.byTooltip(PikoCopy('en').text('action.saveNext')));
      await tester.pump();
      repository.pending!.completeError(StateError('Unavailable'));
      await tester.pumpAndSettle();
      expect(session.draft, same(raw));
      expect(session.confirmedEntries, isEmpty);
      expect(session.activeEntryId, isNull);
      expect(session.advancementRevision, 0);
    },
  );
}
