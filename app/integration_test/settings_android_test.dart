import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/data/local/sqlite_collections_repository.dart';
import 'package:piko/data/local/sqlite_learning_repository.dart';
import 'package:piko/data/local/sqlite_settings_repository.dart';
import 'package:piko/data/local/sqlite_vocabulary_repository.dart';
import 'package:piko/features/settings/settings_route.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_field.dart';

import 'inline_edit_android_test.dart' as fixture;
import 'support/entry_termination_fixture.dart' show hydratedRuntimeCopy;

Finder _button(String key, String locale) =>
    find.widgetWithText(PikoButton, PikoCopy(locale).text(key));

Map<String, Object?> _withLocale(
  Map<String, Object?> original,
  String locale,
) => {
  ...original,
  'app_settings': [
    for (final row in (original['app_settings']! as List).cast<Map>())
      if (row['key'] == 'locale') {...row, 'value': locale} else row,
  ],
};

Future<void> _chooseLanguage(WidgetTester tester, String option) async {
  await fixture.tapVisible(tester, find.byType(PikoDropdown<Locale>));
  await fixture.tapVisible(tester, find.text(option).last);
}

Future<void> _waitForLocale(
  WidgetTester tester,
  SqliteSettingsRepository settings,
  String locale,
) => fixture.waitUntil(tester, () async {
  if (await settings.read('locale') != locale) return false;
  final apps = find.byType(MaterialApp);
  if (apps.evaluate().isEmpty) return false;
  return tester.widget<MaterialApp>(apps).locale?.languageCode == locale &&
      find
          .text(PikoCopy(locale).text('settings.language'))
          .evaluate()
          .isNotEmpty;
});

Future<void> _expectContainedAtDoubleText(
  WidgetTester tester,
  Finder finder, {
  bool touchTarget = false,
}) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  final element = finder.first.evaluate().single;
  final media = MediaQuery.of(element);
  expect(media.textScaler.scale(10), closeTo(20, .01));
  final rect = tester.getRect(finder.first);
  if (touchTarget) {
    expect(rect.width, greaterThanOrEqualTo(44));
    expect(rect.height, greaterThanOrEqualTo(44));
  }
  expect(rect.left, greaterThanOrEqualTo(media.padding.left));
  expect(rect.right, lessThanOrEqualTo(media.size.width - media.padding.right));
  expect(rect.top, greaterThanOrEqualTo(media.padding.top));
  expect(rect.bottom, lessThanOrEqualTo(media.size.height));
}

/// SETTINGS acceptance on Android. Storage is an exclusively owned fixture
/// file, and the 200% scale is injected into this test process only; it does
/// not change or prove the device's platform font or assistive-reader settings.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android Settings switches EN-DE-EN and preserves the isolated database',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final support = await getApplicationSupportDirectory();
      final directory = await support.createTemp('piko-settings-verification-');
      final file = File('${directory.path}/test.sqlite');
      final db = fixture.InlineFixtureDatabase(file);
      PikoDatabase? reopened;
      var mounted = false;
      try {
        final collections = SqliteCollectionsRepository(db);
        final owner = await collections.create(
          name: 'Retained settings fixture',
          targetLanguage: VocabularyLanguage.french,
          nativeLanguage: VocabularyLanguage.german,
        );
        await collections.create(
          name: 'Unrelated collection',
          targetLanguage: VocabularyLanguage.korean,
          nativeLanguage: VocabularyLanguage.english,
        );
        final entry = await SqliteVocabularyRepository(db).create(
          collectionId: owner.id,
          targetText: 'bonjour',
          nativeText: 'Guten Tag',
        );
        final learning = SqliteLearningRepository(db);
        final items = await learning.forEntry(entry.id);
        expect(items, hasLength(2));
        for (var index = 0; index < items.length; index++) {
          final instant = DateTime.utc(2026, 10, 14, 9);
          await learning.saveCard(
            items[index].id,
            fsrs.Card(
              cardId: items[index].id,
              state: fsrs.State.review,
              stability: 2.75 + index,
              difficulty: 6.25 - index,
              due: instant.add(Duration(days: 3 + index)),
              lastReview: instant.subtract(Duration(days: 2 + index)),
            ),
          );
        }
        final settings = SqliteSettingsRepository(db);
        await settings.write('locale', 'en');
        final before = await fixture.snapshot(db);

        mounted = true;
        await tester.pumpWidget(
          PikoApp(home: PikoRuntime(databaseFactory: () => db)),
        );
        final homeCopy = await hydratedRuntimeCopy(tester);
        expect(homeCopy.locale, 'en');
        await fixture.tapVisible(tester, _button('nav.settings', 'en'));
        expect(find.byType(SettingsRoute), findsOneWidget);
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
          const Locale('en'),
        );
        await _expectContainedAtDoubleText(
          tester,
          _button('common.back', 'en'),
          touchTarget: true,
        );
        await _expectContainedAtDoubleText(
          tester,
          find.byType(DropdownButton<Locale>),
          touchTarget: true,
        );
        await _expectContainedAtDoubleText(
          tester,
          find.text(const PikoCopy('en').text('nav.settings')),
        );

        await _chooseLanguage(tester, 'Deutsch');
        await _waitForLocale(tester, settings, 'de');
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
          const Locale('de'),
        );
        expect(
          find.text(const PikoCopy('de').text('nav.settings')),
          findsOneWidget,
        );
        expect(await fixture.snapshot(db), _withLocale(before, 'de'));
        await _expectContainedAtDoubleText(
          tester,
          _button('common.back', 'de'),
          touchTarget: true,
        );
        await _expectContainedAtDoubleText(
          tester,
          find.byType(DropdownButton<Locale>),
          touchTarget: true,
        );

        await _chooseLanguage(tester, 'English');
        await _waitForLocale(tester, settings, 'en');
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
          const Locale('en'),
        );
        expect(await fixture.snapshot(db), before);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        await db.closed.future.timeout(const Duration(seconds: 10));
        mounted = false;
        reopened = PikoDatabase(NativeDatabase(file));
        expect(await SqliteSettingsRepository(reopened).read('locale'), 'en');
        expect(await fixture.snapshot(reopened), before);
        await reopened.close();
        reopened = null;
      } finally {
        await tester.pumpWidget(const SizedBox());
        if (mounted) {
          await db.closed.future.timeout(const Duration(seconds: 10));
        } else {
          await db.close();
        }
        await reopened?.close();
        if (directory.parent.absolute.path != support.absolute.path ||
            !directory.uri.pathSegments
                .where((part) => part.isNotEmpty)
                .last
                .startsWith('piko-settings-verification-')) {
          throw StateError('Refusing cleanup outside owned Settings fixture');
        }
        await directory.delete(recursive: true);
      }
    },
  );
}
