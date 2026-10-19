import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collection_query.dart';
import 'package:piko/features/collections/collection_detail.dart';
import 'package:piko/features/collections/collection_query_binding.dart';
import 'package:piko/features/collections/collection_search_field.dart';
import 'package:piko/features/collections/collection_view_scope.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'package:piko/ui/components/piko_form.dart';
import 'collection_inline_edit_test.dart' show LiveVocabulary, owner, one;
import 'collection_query_detail_test.dart' show projection, ProjectionService;
import 'collection_review_entry_points_test.dart' show Collections;

void main() {
  for (final language in ['en', 'de']) {
    for (final aiEnabled in [false, true]) {
      testWidgets(
        '$language F28/F10 empty chooser preserves gated routes and context at narrow enlarged text, AI=$aiEnabled',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          final copy = PikoCopy(language);
          final vocabulary = LiveVocabulary()..records = [];
          final scope = CollectionViewScope();
          final service = ProjectionService(projection(all: [], visible: []));
          final binding = CollectionQueryBinding(
            collectionId: owner.id,
            service: service,
            scope: scope,
            invalidations: const Stream<void>.empty(),
          );
          var manualStarts = 0, jsonOpens = 0, aiOpens = 0;
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
            binding.dispose();
            scope.dispose();
            await vocabulary.close();
            tester.view.reset();
          });
          await tester.pumpWidget(
            PikoApp(
              locale: Locale(language),
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(language == 'de' ? 2 : 1),
                  ),
                  child: CollectionDetail(
                    repository: Collections([owner]),
                    collectionId: owner.id,
                    queryBinding: binding,
                    vocabularyRepository: vocabulary,
                    entrySessionFactory: (_) {
                      manualStarts++;
                      throw StateError('Manual route was not chosen');
                    },
                    interchangeBuilder: (context, record) {
                      jsonOpens++;
                      return PikoDialog(
                        title: copy.text('json.importTab'),
                        purpose: PikoDialogPurpose.summary,
                        body: Text(
                          record.id,
                          key: const ValueKey('chosen-owner'),
                        ),
                      );
                    },
                    aiBuilder: !aiEnabled
                        ? null
                        : (context, record) {
                            aiOpens++;
                            return Scaffold(
                              body: SafeArea(
                                child: Column(
                                  children: [
                                    Text(
                                      record.id,
                                      key: const ValueKey('chosen-owner'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: Text(copy.text('common.back')),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final add = find.byKey(const ValueKey('collection-empty-add'));
          expect(add, findsOneWidget);
          expect(find.text(copy.text('collection.empty')), findsOneWidget);
          expect(find.byType(CollectionSearchField), findsNothing);
          Future<void> open() async {
            await tester.ensureVisible(add);
            await tester.pumpAndSettle();
            // The collapsing header changes its extent during scrolling; use
            // ordinary gestures until the actual primary target is reachable.
            for (var attempt = 0; attempt < 12; attempt++) {
              final rect = tester.getRect(add);
              if (add.hitTestable().evaluate().isNotEmpty &&
                  rect.center.dy >= 0 &&
                  rect.center.dy < 900) {
                break;
              }
              final viewport = tester.getRect(find.byType(Scrollable).first);
              await tester.dragFrom(
                Offset(viewport.center.dx, viewport.bottom - 48),
                const Offset(0, -160),
              );
              await tester.pumpAndSettle();
            }
            expect(add.hitTestable(), findsOneWidget);
            expect(tester.getRect(add).center.dy, inInclusiveRange(0, 899));
            await tester.tap(add);
            await tester.pumpAndSettle();
          }

          await open();
          final manual = find.widgetWithText(
            PikoNavigationRow,
            copy.text('entry.methodManual'),
          );
          final json = find.widgetWithText(
            PikoNavigationRow,
            copy.text('entry.methodJson'),
          );
          final ai = find.widgetWithText(
            PikoNavigationRow,
            copy.text('entry.methodAi'),
          );
          expect(manual, findsOneWidget);
          expect(json, findsOneWidget);
          expect(ai, aiEnabled ? findsOneWidget : findsNothing);
          expect(
            tester.getTopLeft(manual).dy,
            lessThan(tester.getTopLeft(json).dy),
          );
          if (aiEnabled) {
            expect(
              tester.getTopLeft(json).dy,
              lessThan(tester.getTopLeft(ai).dy),
            );
          }
          expect(manualStarts, 0);
          expect(jsonOpens, 0);
          expect(aiOpens, 0);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(add, findsOneWidget);
          expect(vocabulary.records, isEmpty);
          await open();
          await tester.ensureVisible(json);
          await tester.tap(json);
          await tester.pumpAndSettle();
          expect(jsonOpens, greaterThan(0));
          expect(aiOpens, 0);
          expect(manualStarts, 0);
          expect(find.text(owner.id), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          if (aiEnabled) {
            await open();
            await tester.ensureVisible(ai);
            await tester.tap(ai);
            await tester.pumpAndSettle();
            expect(aiOpens, greaterThan(0));
            expect(find.text(owner.id), findsOneWidget);
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          }
          expect(add, findsOneWidget);
          expect(vocabulary.records, isEmpty);
          expect(manualStarts, 0);
          service.error = StateError('Synthetic read failure');
          binding.refresh();
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('collection-empty-add')),
            findsNothing,
          );
          expect(find.text(copy.text('collection.empty')), findsNothing);
          service.error = null;
          final held = Completer<CollectionQuerySnapshot>();
          service.gate = held;
          binding.refresh();
          await tester.pump();
          expect(
            find.byKey(const ValueKey('collection-empty-add')),
            findsNothing,
          );
          expect(find.text(copy.text('collection.empty')), findsNothing);
          scope.setSearch('no match');
          held.complete(projection(all: [one], visible: []));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('collection-empty-add')),
            findsNothing,
          );
          expect(find.text(copy.text('collection.empty')), findsNothing);
          expect(find.byType(CollectionSearchField), findsOneWidget);
          expect(scope.search, 'no match');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
