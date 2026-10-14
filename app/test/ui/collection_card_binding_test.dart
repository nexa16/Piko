import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/review_due_membership.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/collections/collection_review_count.dart';
import 'package:piko/features/collections/collections_home.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_icon.dart';
import 'package:piko/ui/piko_theme.dart';

const collection = CollectionRecord(
  id: 'words',
  name: 'Android Sichtprüfung',
  targetLanguage: VocabularyLanguage.french,
  nativeLanguage: VocabularyLanguage.german,
);

class OneCollection implements CollectionsRepository {
  const OneCollection();
  @override
  Future<CollectionRecord> create({
    required String name,
    required VocabularyLanguage targetLanguage,
    required VocabularyLanguage nativeLanguage,
  }) => throw UnimplementedError();
  @override
  Future<void> delete(String id) => throw UnimplementedError();
  @override
  Future<CollectionRecord> rename({required String id, required String name}) =>
      throw UnimplementedError();
  @override
  Stream<List<CollectionRecord>> watchAll() => Stream.value([collection]);
  @override
  Stream<CollectionRecord?> watchById(String id) => Stream.value(collection);
}

class EmptyVocabulary implements VocabularyRepository {
  const EmptyVocabulary();
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
      Stream.value(const []);
  @override
  Stream<VocabularyRecord?> watchById(String id) => const Stream.empty();
}

void main() {
  testWidgets(
    'COLL-013 binding card uses compact hierarchy and decorative muted chevron',
    (tester) async {
      Future<List<ReviewDueMembership>> load({
        required String collectionId,
        required DateTime at,
      }) async => const [];
      await tester.pumpWidget(
        PikoApp(
          home: CollectionsHome(
            repository: const OneCollection(),
            vocabularyRepository: const EmptyVocabulary(),
            reviewMembershipLoader: load,
            reviewCountPolicy: CollectionReviewCountPolicy.distinctVocabulary,
            reviewSessionFactory: (_, _) async =>
                throw StateError('Review was not launched'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(find.text(collection.name));
      final metadata = tester.widget<Text>(
        find.text('French · German · 0 entries'),
      );
      expect(
        title.style!.fontSize,
        pikoDesign.dimension('components.collectionCard.titleSize'),
      );
      expect(
        title.style!.fontWeight,
        pikoDesign.weight('components.collectionCard.titleWeight'),
      );
      expect(
        metadata.style!.fontSize,
        pikoDesign.dimension('components.collectionCard.metadataSize'),
      );
      final chevrons = tester
          .widgetList<PikoIcon>(find.byType(PikoIcon))
          .where((icon) => icon.name == PikoIconName.chevronRight);
      expect(chevrons, hasLength(1));
      expect(chevrons.single.semanticLabel, isNull);
    },
  );
}
