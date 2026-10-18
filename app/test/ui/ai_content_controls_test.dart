import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/features/ai/ai_content.dart';
import 'package:piko/features/ai/ai_controls.dart';
import 'package:piko/features/ai/entry_ai_controller.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'package:piko/features/vocabulary/vocabulary_content_editor.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_card.dart';
import 'package:piko/ui/components/piko_interaction_anchor.dart';
import '../features/entry_ai_test.dart' show HeldAiGateway;
import '../data/regular_reviews_test.dart' show Fixture;

void main() {
  for (final locale in ['en', 'de']) {
    testWidgets(
      '$locale consent, preview/use, failure and manual editing at 320dp/200%',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = Fixture();
        await fixture.initialize();
        final session = EntrySessionController(
          collectionId: fixture.owner.id,
          repository: fixture.vocabulary,
        );
        await session.initializeContentDefault();
        session.setTargetText('chat');
        session.setNativeText('Katze');
        final gateway = HeldAiGateway();
        final aiAccess = AiAccess(gateway);
        final ai = EntryAiController(
          session: session,
          access: aiAccess,
          targetLanguage: 'fr',
          nativeLanguage: 'de',
        );
        final scroll = ScrollController();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          ai.dispose();
          aiAccess.dispose();
          session.dispose();
          scroll.dispose();
          await fixture.db.close();
        });
        final copy = PikoCopy(locale);
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(locale),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: Scaffold(
                  body: PikoAnchorRegion(
                    child: SingleChildScrollView(
                      controller: scroll,
                      child: ListenableBuilder(
                        listenable: session,
                        builder: (context, _) => PikoCard(
                          child: VocabularyContentEditor(
                            value: session.draft.content,
                            targetLanguage: 'Français',
                            nativeLanguage: 'Deutsch',
                            makeDefault: false,
                            onChanged: (value, _) => session.setContent(value),
                            exampleSuggestion: AiSuggestionControl(
                              controller: ai,
                              task: AiTask.example,
                            ),
                            hintSuggestion: AiSuggestionControl(
                              controller: ai,
                              task: AiTask.hint,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(gateway.connections, 0);
        final toggle = find.byKey(const ValueKey('content-examples-toggle'));
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        final suggest = find.byKey(const ValueKey('ai-suggest-example'));
        await tester.ensureVisible(suggest);
        await tester.tap(suggest);
        await tester.pumpAndSettle();
        expect(find.text(copy.text('ai.processing')), findsOneWidget);
        expect(gateway.connections, 0);
        await tester.tap(find.text(copy.text('action.cancel')));
        await tester.pumpAndSettle();
        expect(gateway.calls, isEmpty);
        await tester.ensureVisible(suggest);
        await tester.tap(suggest);
        await tester.pumpAndSettle();
        await tester.tap(find.text(copy.text('ai.enable')));
        await tester.pumpAndSettle();
        expect(gateway.connections, 1);
        expect(gateway.calls, hasLength(1));
        final field = find.byKey(const ValueKey('content-example-target'));
        await tester.ensureVisible(field);
        await tester.enterText(field, 'raw');
        await tester.pump();
        // This relevant manual edit invalidates the delayed generation permanently.
        gateway.example();
        await tester.pumpAndSettle();
        expect(ai.suggestion, isNull);
        expect(session.draft.content.examples.first.targetText, 'raw');
        await tester.ensureVisible(suggest);
        final top = tester.getTopLeft(suggest).dy;
        final focus = tester
            .widget<Focus>(
              find.byKey(const ValueKey('ai-suggest-focus-example')),
            )
            .focusNode;
        focus?.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(gateway.calls, hasLength(2));
        expect(focus?.hasFocus, isTrue);
        expect(
          tester
              .getSemantics(suggest)
              .getSemanticsData()
              .flagsCollection
              .isFocused,
          Tristate.isTrue,
        );
        final ring =
            tester
                    .widget<DecoratedBox>(
                      find
                          .ancestor(
                            of: suggest,
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(
          ring.border!.top.color,
          Theme.of(tester.element(suggest)).colorScheme.primary,
        );
        expect(tester.getTopLeft(suggest).dy, closeTo(top, .5));
        gateway.example();
        await tester.pumpAndSettle();
        expect(ai.suggestion, isA<AiExample>());
        final use = find.byKey(const ValueKey('ai-use-example'));
        await tester.ensureVisible(use);
        await tester.tap(use);
        await tester.pumpAndSettle();
        expect(session.draft.content.examples, hasLength(2));
        expect(session.draft.content.examples.first.targetText, 'raw');
        expect(session.draft.targetText, 'chat');
        expect(session.draft.nativeText, 'Katze');
        await tester.ensureVisible(suggest);
        await tester.tap(suggest);
        await tester.pumpAndSettle();
        gateway.response!.completeError(AiFailure.limit);
        await tester.pumpAndSettle();
        expect(find.text(copy.text('ai.limit')), findsOneWidget);
        expect(session.draft.content.examples, hasLength(2));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
