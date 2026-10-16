import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/features/collections/collection_entry_count.dart';
import 'package:piko/main.dart';

void main() {
  const collection = CollectionRecord(
    id: 'metadata-fixture',
    name: 'Korean Basics',
    targetLanguage: VocabularyLanguage.korean,
    nativeLanguage: VocabularyLanguage.german,
  );
  for (final locale in ['en', 'de']) {
    testWidgets(
      '$locale Collection metadata has singular and plural entry counts',
      (tester) async {
        final pair = locale == 'en'
            ? 'Korean · German'
            : 'Koreanisch · Deutsch';
        final singular = locale == 'en' ? 'entry' : 'Eintrag';
        final plural = locale == 'en' ? 'entries' : 'Einträge';
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(locale),
            home: Builder(
              builder: (context) => Column(
                children: [
                  for (final count in <int?>[null, 0, 1, 2])
                    Text(collectionEntryMetadata(context, collection, count)),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(pair), findsOneWidget);
        expect(find.text('$pair · 0 $plural'), findsOneWidget);
        expect(find.text('$pair · 1 $singular'), findsOneWidget);
        expect(find.text('$pair · 2 $plural'), findsOneWidget);
      },
    );
  }
}
