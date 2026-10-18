import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/categories_repository.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/data/settings_repository.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_categories_repository.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_json_service.dart';
import 'package:piko/features/categories/category_management.dart';
import 'package:piko/features/interchange/vocabulary_json_page.dart';
import 'package:piko/features/learning/learning_prompt_card.dart';
import 'package:piko/features/settings/app_language_controller.dart';
import 'package:piko/features/settings/settings_route.dart';
import 'package:piko/main.dart';
import 'package:piko/platform/vocabulary_json_platform.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/interface_locale.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'package:piko/ui/components/piko_page.dart';
import 'support/round2_catalogue_fixture.dart';

// Delayed failure exercises the real Settings control without damaging storage.
class _FailedSettings implements SettingsRepository {
  _FailedSettings(this.real);
  final SettingsRepository real;
  Completer<void>? gate;
  @override
  Future<String?> read(String key) => real.read(key);
  @override
  Future<void> remove(String key) => real.remove(key);
  @override
  Future<void> write(String key, String value) async {
    await gate!.future;
    throw StateError('Synthetic write failure');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'existing editors, transfer and Settings retain Android anchors',
    (tester) async {
      final config = CatalogueConfiguration();
      final support = await getApplicationSupportDirectory();
      final directory = Directory(
        '${support.path}/anchor-surfaces-${config.runId}',
      );
      if (await directory.exists()) throw StateError('Evidence already exists');
      await directory.create();
      final db = PikoDatabase(
        NativeDatabase(File('${directory.path}/fixture.sqlite')),
      );
      final records = <Object?>[];
      var passed = false;
      try {
        final owner = await SqliteCollectionsRepository(db).create(
          name: 'Surface verification',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        );
        final vocabulary = SqliteVocabularyRepository(db);
        final categories = SqliteCategoriesRepository(db);
        final dimension = await categories.createDimension(
          collectionId: owner.id,
          name: 'Topics',
          mode: CategoryMode.multiple,
        );
        await categories.createValue(dimensionId: dimension.id, name: 'Food');
        final entry = await vocabulary.createWithContent(
          collectionId: owner.id,
          targetText: 'café',
          nativeText: 'Kaffee',
          assignments: {},
          content: const VocabularyContent(
            hintText: 'A warm drink.',
            hintVisibility: HintVisibility.hidden,
          ),
        );
        final json = SqliteVocabularyJsonService(db);
        Future<Object?> snapshot() async {
          final result =
              jsonDecode(await json.exportCollection(owner.id)) as Map;
          result.remove('exportedAt');
          return result;
        }

        final before = await snapshot();
        for (final enlarged in [false, true]) {
          final language = enlarged ? 'de' : 'en';
          final copy = PikoCopy(language);
          Future<void> mount(Widget child) async {
            await tester.pumpWidget(
              PikoApp(
                key: UniqueKey(),
                locale: Locale(language),
                home: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(enlarged ? 2 : 1),
                      disableAnimations: enlarged,
                    ),
                    child: Center(child: SizedBox(width: 320, child: child)),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
          }

          Future<void> measure(
            String name,
            Finder origin,
            Finder action, {
            VoidCallback? afterTap,
            Finder? replacement,
          }) async {
            await tester.ensureVisible(action);
            await tester.pumpAndSettle();
            final top = tester.getTopLeft(origin).dy;
            await tester.tap(action);
            afterTap?.call();
            final deltas = <double>[];
            for (var frame = 0; frame < 24; frame++) {
              await tester.pump(const Duration(milliseconds: 20));
              final target = replacement ?? origin;
              final delta = tester.getTopLeft(target).dy - top;
              deltas.add(delta);
              expect(
                delta.abs(),
                lessThanOrEqualTo(.5),
                reason: '$name frame $frame',
              );
            }
            await tester.pumpAndSettle();
            expect(
              tester.getTopLeft(replacement ?? origin).dy,
              closeTo(top, .5),
            );
            expect(tester.takeException(), isNull);
            records.add({
              'surface': name,
              'language': language,
              'scale': enlarged ? 2 : 1,
              'reducedMotion': enlarged,
              'frameDeltas': deltas,
            });
          }

          await mount(
            Scaffold(
              body: PikoPage(
                child: Column(
                  children: [
                    const SizedBox(height: 700),
                    LearningPromptCard(
                      presentation: 1,
                      entryId: entry.id,
                      repository: vocabulary,
                      collectionId: owner.id,
                      collection: owner,
                      categoriesRepository: categories,
                      direction: LearningDirection.targetToNative,
                      canReveal: () => true,
                    ),
                    const SizedBox(height: 1500),
                  ],
                ),
              ),
            ),
          );
          final card = find.byKey(const ValueKey('review-prompt'));
          await measure(
            'learning-hint',
            card,
            find.byKey(const ValueKey('learning-reveal-hint')),
          );
          await measure(
            'learning-reveal',
            card,
            find.byKey(const ValueKey('review-prompt-text')),
          );
          await measure(
            'learning-editor-open',
            card,
            find.byKey(const ValueKey('learning-edit-answer')),
            replacement: find.byKey(const ValueKey('learning-answer-editor')),
          );
          await measure(
            'learning-editor-close',
            find.byKey(const ValueKey('learning-answer-editor')),
            find.byKey(ValueKey('inline-complete-${entry.id}')),
            replacement: card,
          );

          await mount(
            Scaffold(
              body: PikoDialog(
                title: 'Categories',
                body: Column(
                  children: [
                    const SizedBox(height: 700),
                    CategoryManagement(
                      collectionId: owner.id,
                      repository: categories,
                    ),
                    const SizedBox(height: 1500),
                  ],
                ),
              ),
            ),
          );
          final title = find.byWidgetPredicate(
            (widget) => widget is Text && widget.data == 'Topics',
          );
          await measure('category-expand', title, title);
          final name = find.descendant(
            of: find.byKey(
              ValueKey('category-management-name-${dimension.id}'),
            ),
            matching: find.byType(TextField),
          );
          final input = tester.widget<TextField>(name);
          input.controller!.text = ' retained draft ';
          input.onChanged?.call(' retained draft ');
          await measure('category-collapse', title, title);
          await measure('category-reopen', title, title);
          expect(
            tester.widget<TextField>(name).controller!.text,
            ' retained draft ',
          );

          final draft = VocabularyJsonDraft()
            ..input = const TextEditingValue(text: '{ invalid');
          await mount(
            VocabularyJsonPage(
              collection: owner,
              service: json,
              platform: const SystemVocabularyJsonPlatform(),
              draft: draft,
              asDialog: true,
            ),
          );
          final analyze = find.widgetWithText(
            PikoButton,
            copy.text('json.analyze'),
          );
          await measure('json-analysis-error', analyze, analyze);
          expect(
            tester
                .widget<TextField>(find.byKey(const ValueKey('json-input')))
                .controller!
                .text,
            '{ invalid',
          );
          await tester.pumpWidget(const SizedBox());

          final settings = _FailedSettings(SqliteSettingsRepository(db));
          final locale = InterfaceLocaleController(Locale(language));
          final controller = AppLanguageController(
            repository: settings,
            locale: locale,
            registerPending: (_) {},
          );
          await controller.load();
          final binding = ValueNotifier<AppLanguageController?>(controller);
          try {
            await mount(
              SettingsRoute(binding: binding, settingsRepository: settings),
            );
            final checkbox = find.byKey(
              const ValueKey('settings-question-examples'),
            );
            settings.gate = Completer<void>();
            await measure('settings-pending', checkbox, checkbox);
            final top = tester.getTopLeft(checkbox).dy;
            settings.gate!.complete();
            await tester.pumpAndSettle();
            expect(find.text(copy.text('settings.saveFailed')), findsOneWidget);
            expect(tester.getTopLeft(checkbox).dy, closeTo(top, .5));
            expect(await settings.read('questionExamples'), isNull);
            records.add({
              'surface': 'settings-delayed-error',
              'language': language,
              'delta': tester.getTopLeft(checkbox).dy - top,
            });
          } finally {
            if (settings.gate?.isCompleted == false) settings.gate!.complete();
            await tester.pumpWidget(const SizedBox());
            binding.dispose();
            controller.dispose();
            locale.dispose();
          }
        }
        expect(
          await snapshot(),
          before,
          reason: 'No learning/content writes from layout checks',
        );
        passed = true;
      } finally {
        await tester.pumpWidget(const SizedBox());
        await db.close();
        await File('${directory.path}/manifest.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'sourceCommit': config.commit,
            'classification': 'instrumented-android',
            'passed': passed,
            'measurements': records,
          }),
          flush: true,
        );
        debugPrint('PIKO_ANCHOR_SURFACES_EVIDENCE:${directory.path}');
      }
    },
  );
}
