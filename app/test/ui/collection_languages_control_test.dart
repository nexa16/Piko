import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/features/collections/collection_languages_control.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'package:piko/ui/components/piko_form.dart';

class _ControlledLanguages implements CollectionLanguageRepository {
  final writes = <(VocabularyLanguage, VocabularyLanguage)>[];
  Completer<void>? gate;
  bool failSync = false, failAsync = false;
  CollectionRecord? saved;
  @override
  Future<CollectionRecord> setLanguages({
    required String id,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
  }) {
    writes.add((targetLanguage, nativeLanguage));
    if (failSync) throw StateError('Synchronous admission rejection');
    return (() async {
      await gate?.future;
      if (failAsync) throw StateError('Deferred storage failure');
      return saved = CollectionRecord(
        id: id,
        name: 'Words',
        targetLanguage: targetLanguage,
        nativeLanguage: nativeLanguage,
      );
    })();
  }
}

const _opening = CollectionRecord(
  id: 'one',
  name: 'Words',
  targetLanguage: VocabularyLanguage.korean,
  nativeLanguage: VocabularyLanguage.german,
);

Future<void> _mount(
  WidgetTester tester,
  CollectionLanguageRepository repository, {
  CollectionRecord opening = _opening,
  ValueChanged<bool>? onBusy,
  ValueChanged<Future<void>>? onPending,
}) async {
  await tester.pumpWidget(
    PikoApp(
      home: Scaffold(
        body: CollectionLanguagesControl(
          collection: opening,
          repository: repository,
          enabled: true,
          onBusyChanged: onBusy,
          onPendingWrites: onPending,
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('collection-change-languages')));
  await tester.pumpAndSettle();
}

Finder _apply() =>
    find.byWidgetPredicate((w) => w is PikoButton && w.label == 'Apply');
Finder _close() => find.byWidgetPredicate(
  (w) => w is PikoIconButton && w.semanticLabel == 'Close',
);

Future<void> _chooseEnglish(WidgetTester tester) async {
  await tester.tap(find.text(PikoCopy('en').text('collection.targetLanguage')));
  await tester.pumpAndSettle();
  final choice = find.byKey(const ValueKey('language-en'));
  await tester.ensureVisible(choice);
  await tester.pumpAndSettle();
  await tester.tap(choice);
  await tester.pumpAndSettle();
}

class _Languages implements CollectionLanguageRepository {
  final writes = <(VocabularyLanguage, VocabularyLanguage)>[];
  @override
  Future<CollectionRecord> setLanguages({
    required String id,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
  }) async {
    writes.add((targetLanguage, nativeLanguage));
    return CollectionRecord(
      id: id,
      name: 'Words',
      targetLanguage: targetLanguage,
      nativeLanguage: nativeLanguage,
    );
  }
}

void main() {
  for (final locale in ['en', 'de']) {
    testWidgets(
      '$locale language edits stage until Apply and reject equal pair',
      (tester) async {
        final repository = _Languages(), copy = PikoCopy(locale);
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(locale),
            home: Scaffold(
              body: CollectionLanguagesControl(
                collection: const CollectionRecord(
                  id: 'one',
                  name: 'Words',
                  targetLanguage: VocabularyLanguage.korean,
                  nativeLanguage: VocabularyLanguage.german,
                ),
                repository: repository,
                enabled: true,
              ),
            ),
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey('collection-change-languages')),
        );
        await tester.pumpAndSettle();
        Finder apply() => find.byWidgetPredicate(
          (w) => w is PikoButton && w.label == copy.text('r2.apply'),
        );
        expect(tester.widget<PikoButton>(apply()).onPressed, isNull);
        await tester.tap(find.text(copy.text('collection.targetLanguage')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('language-de')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('language-de')));
        await tester.pumpAndSettle();
        expect(find.text(copy.text('collection.sameLanguage')), findsOneWidget);
        expect(tester.widget<PikoButton>(apply()).onPressed, isNull);
        expect(repository.writes, isEmpty);
        await tester.tap(find.text(copy.text('collection.targetLanguage')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('language-en')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('language-en')));
        await tester.pumpAndSettle();
        expect(repository.writes, isEmpty);
        await tester.tap(apply());
        await tester.pumpAndSettle();
        expect(repository.writes, [
          (VocabularyLanguage.english, VocabularyLanguage.german),
        ]);
        expect(find.byType(PikoDialog), findsNothing);
      },
    );
  }

  testWidgets(
    'Back cancels staged pair and reopening retains original metadata',
    (tester) async {
      final repository = _ControlledLanguages();
      await _mount(tester, repository);
      await _chooseEnglish(tester);
      expect(find.text('English'), findsOneWidget);
      expect(repository.writes, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(PikoDialog), findsNothing);
      expect(repository.saved, isNull);
      await tester.tap(
        find.byKey(const ValueKey('collection-change-languages')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Korean'), findsOneWidget);
      expect(tester.widget<PikoButton>(_apply()).onPressed, isNull);
      expect(repository.writes, isEmpty);
    },
  );

  testWidgets(
    'pending Apply blocks duplicate saves and Back; failure retains pair then retry succeeds',
    (tester) async {
      final repository = _ControlledLanguages()
        ..gate = Completer<void>()
        ..failAsync = true;
      final busy = <bool>[];
      final pending = <Future<void>>[];
      await _mount(
        tester,
        repository,
        onBusy: busy.add,
        onPending: pending.add,
      );
      await _chooseEnglish(tester);
      final staleApply = tester.widget<PikoButton>(_apply()).onPressed!;
      await tester.tap(_apply());
      await tester.pumpAndSettle();
      staleApply();
      await tester.pump();
      expect(repository.writes, [
        (VocabularyLanguage.english, VocabularyLanguage.german),
      ]);
      expect(tester.widget<PikoButton>(_apply()).onPressed, isNull);
      expect(tester.widget<PikoIconButton>(_close()).onPressed, isNull);
      expect(
        find
            .descendant(of: find.byType(PikoDialog), matching: find.byType(PikoNavigationRow))
            .evaluate()
            .map((e) => (e.widget as PikoNavigationRow).onTap),
        everyElement(isNull),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(find.byType(PikoDialog), findsOneWidget);
      expect(repository.saved, isNull);
      expect(busy, [true]);
      repository.gate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text(PikoCopy('en').text('collection.saveFailed')),
        findsOneWidget,
      );
      expect(find.text('English'), findsOneWidget);
      expect(find.text('German'), findsOneWidget);
      expect(repository.saved, isNull);
      expect(_opening.targetLanguage, VocabularyLanguage.korean);
      expect(busy, [true, false]);
      expect(tester.widget<PikoButton>(_apply()).onPressed, isNotNull);
      repository
        ..gate = null
        ..failAsync = false;
      final retry = tester.widget<PikoButton>(_apply()).onPressed!;
      retry();
      retry();
      await tester.pumpAndSettle();
      await Future.wait(pending);
      expect(repository.writes, hasLength(2));
      expect(repository.saved!.targetLanguage, VocabularyLanguage.english);
      expect(repository.saved!.nativeLanguage, VocabularyLanguage.german);
      expect(busy, [true, false, true, false]);
      expect(pending, hasLength(2));
      expect(find.byType(PikoDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'synchronous admission failure releases busy state and keeps staged values retryable',
    (tester) async {
      final repository = _ControlledLanguages()..failSync = true;
      final busy = <bool>[];
      await _mount(tester, repository, onBusy: busy.add);
      await _chooseEnglish(tester);
      await tester.tap(_apply());
      await tester.pumpAndSettle();
      expect(
        find.text(PikoCopy('en').text('collection.saveFailed')),
        findsOneWidget,
      );
      expect(find.text('English'), findsOneWidget);
      expect(busy, [true, false]);
      expect(repository.saved, isNull);
      expect(tester.widget<PikoButton>(_apply()).onPressed, isNotNull);
      repository.failSync = false;
      await tester.tap(_apply());
      await tester.pumpAndSettle();
      expect(repository.writes, hasLength(2));
      expect(repository.saved!.targetLanguage, VocabularyLanguage.english);
      expect(find.byType(PikoDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom names with equal normalized spelling cannot form the language pair',
    (tester) async {
      final repository = _ControlledLanguages();
      final opening = CollectionRecord(
        id: 'one',
        name: 'Words',
        targetLanguage: VocabularyLanguage.korean,
        nativeLanguage: VocabularyLanguage.stored(
          'custom:11111111-1111-4111-8111-111111111111',
          'Élfisch',
        ),
      );
      await _mount(tester, repository, opening: opening);
      await tester.tap(
        find.text(PikoCopy('en').text('collection.targetLanguage')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(PikoCopy('en').text('language.custom')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'E\u0301LFISCH');
      final saveCustom = find.byWidgetPredicate(
        (w) =>
            w is PikoButton &&
            w.label == PikoCopy('en').text('language.customSave'),
      );
      await tester.tap(saveCustom);
      await tester.pumpAndSettle();
      expect(
        find.text(PikoCopy('en').text('collection.sameLanguage')),
        findsOneWidget,
      );
      expect(tester.widget<PikoButton>(_apply()).onPressed, isNull);
      expect(repository.writes, isEmpty);
      expect(opening.nativeLanguage.customName, 'Élfisch');
      expect(tester.takeException(), isNull);
    },
  );
}
