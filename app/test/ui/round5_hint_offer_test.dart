import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/vocabulary_content.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/vocabulary/vocabulary_content_editor.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_card.dart';

class Preferences implements CollectionHintPreferences {
  final handled = <String>{};
  final automatic = <String>{};
  bool fail = false;
  @override
  Future<bool> hintDefaultOfferHandled(String id) async => handled.contains(id);
  @override
  Future<void> setCollectionHintDefault(String id, bool value) async {
    value ? automatic.add(id) : automatic.remove(id);
  }

  @override
  Future<void> completeHintDefaultOffer(
    String id, {
    required bool accept,
  }) async {
    if (fail) throw StateError('synthetic failure');
    if (handled.add(id) && accept) automatic.add(id);
  }
}

void main() {
  for (final accept in [false, true]) {
    testWidgets(
      'first ON offer: ${accept ? 'failed acceptance and retry' : 'safe dismissal'} retains word and is consumed',
      (tester) async {
        final preferences = Preferences();
        var value = const VocabularyContent(
          hintText: 'Keep this',
          hintVisibility: HintVisibility.hidden,
        );
        await tester.pumpWidget(
          PikoApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PikoCard(
                  child: StatefulBuilder(
                    builder: (context, update) => VocabularyContentEditor(
                      value: value,
                      targetLanguage: 'French',
                      nativeLanguage: 'German',
                      makeDefault: false,
                      collectionId: 'collection',
                      preferences: preferences,
                      onChanged: (next, _) => update(() => value = next),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final toggle = find.byKey(const ValueKey('content-hint-automatic'));
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('Show hints for new words?'), findsOneWidget);
        expect(value.hintVisibility, HintVisibility.always);
        expect(value.hintText, 'Keep this');
        if (accept) {
          preferences.fail = true;
          await tester.tap(find.text('Use for new words'));
          await tester.pumpAndSettle();
          expect(
            find.text('Could not save the Hint default. Please retry.'),
            findsOneWidget,
          );
          expect(preferences.handled, isEmpty);
          preferences.fail = false;
          await tester.tap(find.text('Try again'));
          await tester.pumpAndSettle();
        } else {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }
        expect(preferences.handled, {'collection'});
        expect(preferences.automatic.contains('collection'), accept);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('Show hints for new words?'), findsNothing);
        expect(value.hintText, 'Keep this');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
