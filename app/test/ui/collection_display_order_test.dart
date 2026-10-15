import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/vocabulary/collection_vocabulary.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_field.dart';

Finder field(String id, String side) => find.descendant(
  of: find.byKey(ValueKey('inline-$id-$side')),
  matching: find.byType(TextField),
);

void main() {
  for (final initialLocale in ['en', 'de']) {
    testWidgets(
      '$initialLocale target-first display follows Collection roles, not locale or directional state',
      (tester) async {
        tester.view.physicalSize = const Size(760, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final db = PikoDatabase(
          DatabaseConnection(
            NativeDatabase.memory(),
            closeStreamsSynchronously: true,
          ),
        );
        final collections = SqliteCollectionsRepository(db);
        final vocabulary = SqliteVocabularyRepository(db);
        final learning = SqliteLearningRepository(db);
        final owners = await tester.runAsync(
          () async => [
            await collections.create(
              name: 'Same name',
              targetLanguage: VocabularyLanguage.german,
              nativeLanguage: VocabularyLanguage.english,
            ),
            await collections.create(
              name: 'Same name',
              targetLanguage: VocabularyLanguage.english,
              nativeLanguage: VocabularyLanguage.german,
            ),
          ],
        );
        final entries = await tester.runAsync(
          () async => [
            await vocabulary.create(
              collectionId: owners![0].id,
              targetText: 'Apfel',
              nativeText: 'apple',
            ),
            await vocabulary.create(
              collectionId: owners[1].id,
              targetText: 'pear',
              nativeText: 'Birne',
            ),
          ],
        );
        final instant = DateTime.utc(2026, 10, 14);
        final before = <int, String>{};
        await tester.runAsync(() async {
          for (final entry in entries!) {
            for (final item in await learning.forEntry(entry.id)) {
              final reverse =
                  item.direction == LearningDirection.nativeToTarget;
              await learning.saveCard(
                item.id,
                fsrs.Card(
                  cardId: item.id,
                  state: fsrs.State.review,
                  stability: reverse ? 9.25 : 3.75,
                  difficulty: reverse ? 4.5 : 7.5,
                  lastReview: instant.subtract(const Duration(days: 1)),
                  due: instant.add(Duration(days: reverse ? 1 : 9)),
                ),
              );
            }
            for (final item in await learning.forEntry(entry.id)) {
              before[item.id] = item.cardJson;
            }
          }
        });
        final current = ValueNotifier(owners!.first);
        final locale = InterfaceLocaleController(Locale(initialLocale));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          current.dispose();
          locale.dispose();
          await tester.runAsync(db.close);
        });
        await tester.pumpWidget(
          PikoApp(
            localeController: locale,
            home: ValueListenableBuilder<CollectionRecord>(
              valueListenable: current,
              builder: (_, owner, _) => Scaffold(
                body: SingleChildScrollView(
                  child: CollectionVocabulary(
                    collection: owner,
                    repository: vocabulary,
                  ),
                ),
              ),
            ),
          ),
        );
        final semantics = tester.ensureSemantics();
        try {
          for (var index = 0; index < owners.length; index++) {
            current.value = owners[index];
            tester.view.physicalSize = const Size(760, 1000);
            await tester.runAsync(() => db.customSelect('SELECT 1').get());
            await tester.pumpAndSettle();
            final entry = entries![index];
            final row = find.byKey(ValueKey('vocabulary-${entry.id}'));
            expect(
              tester.getRect(find.text(entry.targetText)).center.dx,
              lessThan(tester.getRect(find.text(entry.nativeText)).center.dx),
            );
            expect(
              find.bySemanticsLabel(
                PikoCopy(locale.value.languageCode).text('vocab.editPair', {
                  'target': entry.targetText,
                  'native': entry.nativeText,
                }),
              ),
              findsOneWidget,
            );
            await tester.tap(row);
            await tester.pumpAndSettle();
            final target = field(entry.id, 'target');
            final native = field(entry.id, 'native');
            expect(
              tester.widget<TextField>(target).controller!.text,
              entry.targetText,
            );
            expect(
              tester.widget<TextField>(native).controller!.text,
              entry.nativeText,
            );
            expect(
              tester.getRect(target).center.dx,
              lessThan(tester.getRect(native).center.dx),
            );
            expect(
              tester.getRect(target).top,
              closeTo(tester.getRect(native).top, 0.1),
            );
            for (final language in ['en', 'de']) {
              locale.value = Locale(language);
              tester.view.physicalSize = const Size(392, 1000);
              await tester.pumpAndSettle();
              final copy = PikoCopy(language);
              expect(
                tester
                    .widget<PikoTextField>(
                      find.byKey(ValueKey('inline-${entry.id}-target')),
                    )
                    .label,
                copy.text(owners[index].targetLanguage.copyKey),
              );
              expect(
                tester
                    .widget<PikoTextField>(
                      find.byKey(ValueKey('inline-${entry.id}-native')),
                    )
                    .label,
                copy.text(owners[index].nativeLanguage.copyKey),
              );
              expect(
                tester.getRect(target).bottom,
                lessThan(tester.getRect(native).top),
              );
              expect(
                tester.getRect(target).left,
                closeTo(tester.getRect(native).left, 0.1),
              );
              expect(
                tester.widget<TextField>(target).controller!.text,
                entry.targetText,
              );
              expect(
                tester.widget<TextField>(native).controller!.text,
                entry.nativeText,
              );
            }
            await tester.tap(
              find.byWidgetPredicate(
                (w) =>
                    w is PikoIconButton &&
                    w.semanticLabel ==
                        PikoCopy(
                          locale.value.languageCode,
                        ).text('vocab.inlineCollapse'),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.getRect(find.text(entry.targetText)).center.dx,
              lessThan(tester.getRect(find.text(entry.nativeText)).center.dx),
            );
          }
          final retained = await tester.runAsync(() async {
            final states = <int, String>{};
            for (final entry in entries!) {
              for (final item in await learning.forEntry(entry.id)) {
                states[item.id] = item.cardJson;
              }
              final stored = await vocabulary.watchById(entry.id).first;
              expect(stored!.collectionId, entry.collectionId);
              expect(stored.targetText, entry.targetText);
              expect(stored.nativeText, entry.nativeText);
            }
            return states;
          });
          expect(retained, before);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
