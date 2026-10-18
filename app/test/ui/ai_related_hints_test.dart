import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/data/ai/ai_contract.dart';
import 'package:piko/data/local/sqlite_ai_service.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/features/ai/ai_related_hints_control.dart';
import 'package:piko/features/ai/ai_page.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_checkbox.dart';
import '../data/regular_reviews_test.dart' show Fixture, rows;
import '../data/ai_service_test.dart' show envelope, edit;
import '../data/statistics_test.dart' show stored;
import 'ai_page_test.dart' show tapVisible;

class HintProvider implements AiProvider {
  final calls = <AiRequest>[];
  @override
  Future<Map<String, Object?>> generate(AiRequest r) async {
    calls.add(r);
    return envelope(
      r,
      edits: [
        for (final id in r.targets)
          edit('hint-$id', id, 'hint', 'Synthetic distinction'),
      ],
    );
  }

  @override
  void close() {}
}

void main() {
  for (final locale in ['en', 'de']) {
    for (final draft in [false, true]) {
      testWidgets(
        'related Hints $locale ${draft ? 'new stage' : 'saved apply'} local discovery, cancel and exact target subset',
        (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = const Size(320, 800);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.view.resetPhysicalSize);
          final f = Fixture();
          await f.initialize();
          addTearDown(f.db.close);
          final related = await f.vocabulary.createWithContent(
            collectionId: f.owner.id,
            targetText: 'One',
            nativeText: 'Eine',
            assignments: {},
            content: const VocabularyContent(),
            active: false,
          );
          await f.vocabulary.create(
            collectionId: f.owner.id,
            targetText: 'Onex',
            nativeText: 'Einer',
          );
          await f.vocabulary.create(
            collectionId: f.owner.id,
            targetText: 'Noch',
            nativeText: 'Eine',
          );
          final service = SqliteAiService(f.db, enabled: true),
              p = HintProvider(),
              copy = PikoCopy(locale);
          final anchor = AiEntry(
            draft
                ? VocabularyRecord(
                    id: 'draft-synthetic',
                    collectionId: f.owner.id,
                    targetText: 'One',
                    nativeText: 'Erste',
                    content: const VocabularyContent(),
                    active: true,
                  )
                : f.entry,
            {},
          );
          AiStagedHints? staged;
          AiAdoption? adopted;
          var settled = 0;
          await t.pumpWidget(
            PikoApp(
              locale: Locale(locale),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 800),
                  textScaler: TextScaler.linear(2),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: AiRelatedHintsControl(
                      support: AiSupport(service, p),
                      anchor: anchor,
                      collectionName: 'Synthetic',
                      settleAnchor: () async {
                        settled++;
                        return anchor;
                      },
                      onStaged: draft
                          ? (s) async {
                              staged = s;
                            }
                          : null,
                      onApplied: (a) async {
                        adopted = a;
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(p.calls, isEmpty);
          final before = await stored(f.db),
              learning = await rows(f.db, 'learning_items');
          final control = find.byKey(const ValueKey('ai-related-hints'));
          await tapVisible(t, control);
          expect(find.byType(AiPage), findsOneWidget);
          Navigator.of(t.element(find.byType(AiPage))).pop();
          await t.pumpAndSettle();
          expect(control, findsOneWidget);
          expect(p.calls, isEmpty);
          expect(await stored(f.db), before);
          await tapVisible(t, control);
          // Keep one target; all directly related meanings remain comparison context.
          for (final entry in (await service.snapshot(
            f.owner.id,
          )).related(anchor).entries.where((e) => e.record.id != related.id)) {
            final label =
                '${entry.record.targetText} — ${entry.record.nativeText}';
            await tapVisible(
              t,
              find.byWidgetPredicate(
                (w) => w is PikoCheckbox && w.label == label,
              ),
            );
          }
          await tapVisible(
            t,
            find.byWidgetPredicate(
              (w) => w is PikoCheckbox && w.label == copy.text('ai.consent'),
            ),
          );
          await tapVisible(t, find.byKey(const ValueKey('ai-start')));
          expect(p.calls.length, 1);
          final r = p.calls.single;
          expect(r.targets, {related.id});
          expect(r.snapshot.entries.length, draft ? 3 : 2);
          expect(
            r.snapshot.entries.any(
              (e) =>
                  e.record.targetText == 'Onex' ||
                  e.record.targetText == 'Noch',
            ),
            isFalse,
          );
          expect(
            r.snapshot.entries.any(
              (e) => e.record.id == related.id && !e.record.active,
            ),
            isTrue,
          );
          await tapVisible(
            t,
            find.byKey(ValueKey('ai-select-hint-${related.id}')),
          );
          await tapVisible(t, find.byKey(const ValueKey('ai-apply')));
          expect(find.byType(AiPage), findsNothing);
          expect(control, findsOneWidget);
          expect(settled, 2);
          if (draft) {
            expect(staged, isNotNull);
            expect(adopted, isNull);
            expect(await stored(f.db), before);
          } else {
            expect(adopted, isNotNull);
            expect(staged, isNull);
            expect(
              (await f.vocabulary.watchById(related.id).first)!
                  .content
                  .hintText,
              'Synthetic distinction',
            );
          }
          expect(await rows(f.db, 'learning_items'), learning);
          expect(t.takeException(), isNull);
          await t.pump();
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
        },
      );
    }
  }
}
