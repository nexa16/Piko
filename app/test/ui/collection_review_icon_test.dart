import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/learning/review_launch.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_icon.dart';
import 'package:piko/ui/piko_theme.dart';

const collection = CollectionRecord(
  id: 'collection',
  name: 'Words',
  targetLanguage: VocabularyLanguage.french,
  nativeLanguage: VocabularyLanguage.german,
);

class Vocabulary implements VocabularyRepository {
  const Vocabulary();

  @override
  Future<VocabularyOpeningSnapshot> captureOpeningSnapshot({
    required String entryId,
    required String collectionId,
  }) => throw UnimplementedError();
  @override
  Future<VocabularyRecord> create({
    required String collectionId,
    required String targetText,
    required String nativeText,
  }) => throw UnimplementedError();
  @override
  Future<VocabularyRecord> restoreOpeningSnapshot(
    VocabularyOpeningSnapshot snapshot,
  ) => throw UnimplementedError();
  @override
  Future<VocabularyRecord> update({
    required String id,
    required String targetText,
    required String nativeText,
  }) => throw UnimplementedError();
  @override
  Stream<List<VocabularyRecord>> watchByCollection(String collectionId) =>
      const Stream.empty();
  @override
  Stream<VocabularyRecord?> watchById(String id) => const Stream.empty();
}

void main() {
  testWidgets(
    'Collection review actions use the circular Lucide review arrow',
    (tester) async {
      ReviewLaunch launch(ReviewLaunchPresentation presentation) =>
          ReviewLaunch(
            collection: collection,
            factory: (id, direction) async =>
                throw StateError('Review was not launched'),
            vocabularyRepository: const Vocabulary(),
            beforeLaunch: () async {},
            onPendingWrites: null,
            onBusyChanged: (_) {},
            presentation: presentation,
            dueCount: 3,
          );

      await tester.pumpWidget(
        PikoApp(
          home: Scaffold(
            body: Column(
              children: [
                launch(ReviewLaunchPresentation.collectionQuick),
                launch(ReviewLaunchPresentation.collectionCard),
              ],
            ),
          ),
        ),
      );

      final icons = tester.widgetList<PikoIcon>(find.byType(PikoIcon));
      expect(icons, hasLength(2));
      expect(
        icons.every((icon) => icon.name == PikoIconName.rotateCcw),
        isTrue,
      );
      final rendered = tester.widgetList<SvgPicture>(find.byType(SvgPicture));
      expect(
        rendered.every(
          (icon) =>
              icon.colorFilter ==
              ColorFilter.mode(pikoDesign.color('primary'), BlendMode.srcIn),
        ),
        isTrue,
      );
    },
  );
}
