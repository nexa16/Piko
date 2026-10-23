import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/features/collections/collection_level_control.dart';
import 'package:piko/features/collections/create_collection.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';

const owner = CollectionRecord(
  id: 'one',
  name: 'Words',
  targetLanguage: VocabularyLanguage.korean,
  nativeLanguage: VocabularyLanguage.german,
);

class Levels implements CollectionsRepository, CollectionLevelRepository {
  final writes = <String>[];
  @override
  Future<CollectionRecord> setLevel({
    required String id,
    required String level,
  }) async {
    writes.add(level);
    return CollectionRecord(
      id: owner.id,
      name: owner.name,
      targetLanguage: owner.targetLanguage,
      nativeLanguage: owner.nativeLanguage,
      level: level,
    );
  }

  @override
  Future<CollectionRecord> createWithLevel({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
    required String level,
  }) async {
    writes.add(level);
    return CollectionRecord(
      id: 'new',
      name: name,
      targetLanguage: targetLanguage,
      nativeLanguage: nativeLanguage,
      level: level,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final locale in ['en', 'de']) {
    testWidgets(
      '$locale create Collection and Settings use selected A1–C2 level',
      (tester) async {
        final repository = Levels(), copy = PikoCopy(locale);
        CollectionRecord? created;
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(locale),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Open'),
                  onPressed: () async {
                    created = await showPikoDialog<CollectionRecord>(
                      context,
                      builder: (_) =>
                          CreateCollectionDialog(repository: repository),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('collection-create-level')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('B2'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(PikoButton, copy.text('action.create')),
        );
        await tester.pumpAndSettle();
        expect(created!.level, 'B2');
        expect(repository.writes, ['B2']);
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(locale),
            home: Scaffold(
              body: CollectionLevelControl(
                collection: owner,
                repository: repository,
                enabled: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('collection-settings-level')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('C1'));
        await tester.pumpAndSettle();
        expect(repository.writes, ['B2', 'C1']);
        expect(find.text('C1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
