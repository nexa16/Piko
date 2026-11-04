import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/features/ai/ai_page.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_checkbox.dart';
import '../data/regular_reviews_test.dart' show Fixture;
import '../features/ai_review_job_controller_test.dart' show FakeJobProvider;
import 'ai_page_test.dart' show FakeProvider, tapVisible;

class JobProvider extends FakeJobProvider implements AiProvider {
  int ordinaryCalls = 0;
  @override
  Future<Map<String, Object?>> generate(AiRequest request) async {
    ordinaryCalls++;
    throw AiFailure.unavailable;
  }

  @override
  void close() {}
}

void main() {
  Future<void> consent(WidgetTester t) async {
    final copy = PikoCopy('en');
    await t.pumpAndSettle();
    await tapVisible(t, find.byKey(const ValueKey('ai-consent')));
    await tapVisible(
      t,
      find.byWidgetPredicate(
        (w) =>
            w is PikoIconButton && w.semanticLabel == copy.text('common.close'),
      ),
    );
  }

  testWidgets(
    'learning goals stay staged until Apply and cancel preserves previous choices',
    (t) async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      final p = FakeProvider(), copy = PikoCopy('en');
      await t.pumpWidget(
        PikoApp(
          home: AiPage(
            service: SqliteAiService(f.db, enabled: true),
            provider: p,
            collectionId: f.owner.id,
            collectionName: 'Synthetic',
          ),
        ),
      );
      await consent(t);
      await tapVisible(t, find.byKey(const ValueKey('ai-goals-choose')));
      final travel = find.byWidgetPredicate(
        (w) => w is PikoCheckbox && w.label == copy.text('ai.goal.travel'),
      );
      await tapVisible(t, travel);
      await tapVisible(
        t,
        find.widgetWithText(PikoButton, copy.text('action.cancel')),
      );
      expect(find.text(copy.text('ai.goalsNone')), findsOneWidget);
      await tapVisible(t, find.byKey(const ValueKey('ai-goals-choose')));
      expect(t.widget<PikoCheckbox>(travel).value, isFalse);
      await tapVisible(t, travel);
      await tapVisible(
        t,
        find.widgetWithText(PikoButton, copy.text('r2.apply')),
      );
      expect(find.text(copy.text('ai.goal.travel')), findsOneWidget);
      expect(p.calls, 0);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'full review requires explicit positive cost and includes inactive words with no ordinary POST',
    (t) async {
      final f = Fixture();
      await f.initialize();
      addTearDown(f.db.close);
      await f.vocabulary.createWithContent(
        collectionId: f.owner.id,
        targetText: 'Inactive',
        nativeText: 'Inaktiv',
        assignments: const {},
        content: const VocabularyContent(),
        active: false,
      );
      final p = JobProvider(), copy = PikoCopy('en');
      await t.pumpWidget(
        PikoApp(
          home: AiPage(
            service: SqliteAiService(f.db, enabled: true),
            provider: p,
            collectionId: f.owner.id,
            collectionName: 'Synthetic',
            initialAction: AiAction.review,
            installationIdentity: () async => 'install-synthetic',
          ),
        ),
      );
      await consent(t);
      await tapVisible(t, find.byKey(const ValueKey('ai-start')));
      final field = find.byKey(const ValueKey('ai-review-cost'));
      expect(t.widget<TextField>(field).controller!.text, isEmpty);
      final apply = find.widgetWithText(PikoButton, copy.text('r2.apply'));
      expect(t.widget<PikoButton>(apply).onPressed, isNull);
      await t.enterText(field, '0.10');
      await t.pump();
      await tapVisible(t, apply, settle: false);
      for (var i = 0; i < 20 && !p.calls.contains('start'); i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump();
      }
      expect(p.calls.where((e) => e == 'start'), hasLength(1));
      expect(p.entries, hasLength(2));
      expect(p.entries.where((e) => e['active'] == false), hasLength(1));
      expect(p.ordinaryCalls, 0);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
      await t.runAsync(f.db.close);
    },
  );
}
