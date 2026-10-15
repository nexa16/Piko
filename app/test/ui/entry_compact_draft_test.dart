import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'entry_stack_test.dart'
    show ScreenRepository, owner, mount, seed, field, clean, scrollTo;

void main() {
  for (final language in ['en', 'de']) {
    testWidgets(
      '$language inactive draft is compact and previews only actual input',
      (tester) async {
        final repository = ScreenRepository();
        final session = EntrySessionController(
          collectionId: owner.id,
          repository: repository,
        );
        final locale = InterfaceLocaleController(Locale(language));
        addTearDown(locale.dispose);
        clean(tester, session);
        await seed(session, 1);
        session.selectSavedEntry('entry-0');
        final empty = session.draft;
        await mount(tester, session, locale: locale, reduced: true);
        final copy = PikoCopy(language);
        final draft = find.byKey(const ValueKey('entry-card-draft'));
        Finder preview(String text) =>
            find.descendant(of: draft, matching: find.text(text));
        expect(preview(copy.text('entry.newVocabulary')), findsOneWidget);
        expect(preview(copy.text('entry.targetPlaceholder')), findsNothing);
        expect(preview(copy.text('entry.nativePlaceholder')), findsNothing);
        expect(field('draft', 'target'), findsNothing);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(session.draft, same(empty));
        final compactHeight = tester.getSize(draft).height;
        await scrollTo(tester, 'draft');
        expect(session.activeEntryId, isNull);
        expect(
          tester
              .widget<TextField>(field('draft', 'target'))
              .focusNode!
              .hasFocus,
          isTrue,
        );
        expect(tester.testTextInput.isVisible, isTrue);
        expect(tester.getSize(draft).height, greaterThan(compactHeight));
        await tester.enterText(field('draft', 'target'), ' Raw target ');
        final partial = session.draft;
        session.selectSavedEntry('entry-0');
        await tester.pumpAndSettle();
        expect(preview(' Raw target '), findsOneWidget);
        expect(preview(copy.text('entry.newVocabulary')), findsNothing);
        expect(preview(copy.text('entry.nativePlaceholder')), findsNothing);
        expect(session.draft, same(partial));
        await scrollTo(tester, 'draft');
        expect(
          tester.widget<TextField>(field('draft', 'target')).controller!.text,
          ' Raw target ',
        );
        expect(
          tester
              .widget<TextField>(field('draft', 'target'))
              .focusNode!
              .hasFocus,
          isTrue,
        );
        session.setTargetText('');
        session.setNativeText(' Raw native ');
        session.selectSavedEntry('entry-0');
        await tester.pumpAndSettle();
        expect(preview(' Raw native '), findsOneWidget);
        expect(preview(copy.text('entry.targetPlaceholder')), findsNothing);
        expect(session.confirmedEntries, hasLength(1));
        expect(repository.sequence, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
