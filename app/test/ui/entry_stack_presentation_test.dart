import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/vocabulary_repository.dart';
import 'package:piko/features/entry/entry_session_controller.dart';
import 'package:piko/features/entry/entry_session_screen.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_card.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/piko_theme.dart';

const collection = CollectionRecord(
  id: 'owner',
  name: 'Stack',
  targetLanguage: VocabularyLanguage.korean,
  nativeLanguage: VocabularyLanguage.german,
);

class PresentationRepository implements VocabularyRepository {
  var next = 0;
  @override
  Future<VocabularyRecord> create({
    required String collectionId,
    required String targetText,
    required String nativeText,
  }) async => VocabularyRecord(
    id: 'saved-${next++}',
    collectionId: collectionId,
    targetText: targetText,
    nativeText: nativeText,
  );
  @override
  Future<VocabularyRecord> update({
    required String id,
    required String targetText,
    required String nativeText,
  }) async => VocabularyRecord(
    id: id,
    collectionId: collection.id,
    targetText: targetText,
    nativeText: nativeText,
  );
  @override
  Stream<List<VocabularyRecord>> watchByCollection(String collectionId) =>
      Stream.value([]);
  @override
  Stream<VocabularyRecord?> watchById(String id) => Stream.value(null);
}

Future<EntrySessionController> screen(
  WidgetTester tester, {
  bool reduced = false,
  String locale = 'en',
}) async {
  final session = EntrySessionController(
    collectionId: collection.id,
    repository: PresentationRepository(),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    session.dispose();
  });
  session.setTargetText('학교');
  session.setNativeText('Schule');
  await session.confirmAndNext();
  await tester.pumpWidget(
    PikoApp(
      locale: Locale(locale),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: EntrySessionScreen(collection: collection, session: session),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

void main() {
  testWidgets(
    'binding previews, metadata and card states consume canonical geometry',
    (tester) async {
      final session = await screen(tester);
      final id = session.confirmedEntries.single.id;
      final card = find.byKey(ValueKey('entry-card-$id'));
      final widget = tester.widget<PikoCard>(card);
      expect(widget.padding, EdgeInsets.all(pikoDesign.dimension('spacing.4')));
      expect(
        widget.constraints!.minHeight,
        pikoDesign.dimension('components.entryStack.compactMinHeight'),
      );
      expect(
        widget.animationDuration!.inMilliseconds,
        pikoDesign.dimension('components.entryStack.stateMotionMs'),
      );
      expect(
        tester.getSize(card).height,
        greaterThanOrEqualTo(
          pikoDesign.dimension('components.entryStack.compactMinHeight'),
        ),
      );
      final number = tester.widget<Text>(
        find.descendant(of: card, matching: find.text('Entry 1')),
      );
      final status = tester.widget<Text>(
        find.descendant(of: card, matching: find.text('Saved')),
      );
      final targetFinder = find.descendant(of: card, matching: find.text('학교'));
      final nativeFinder = find.descendant(
        of: card,
        matching: find.text('Schule'),
      );
      final target = tester.widget<Text>(targetFinder);
      final native = tester.widget<Text>(nativeFinder);
      expect(
        number.style!.fontSize,
        pikoDesign.dimension('components.entryStack.numberSize'),
      );
      expect(number.style!.color, pikoDesign.color('muted'));
      expect(
        status.style!.fontSize,
        pikoDesign.dimension('components.entryStack.statusSize'),
      );
      expect(
        status.style!.height,
        pikoDesign.dimension('components.entryStack.metaLineHeight'),
      );
      expect(
        target.style!.fontWeight,
        pikoDesign.weight('typography.titleWeight'),
      );
      expect(native.style!.color, pikoDesign.color('muted'));
      expect(
        tester.getRect(nativeFinder).top - tester.getRect(targetFinder).bottom,
        pikoDesign.dimension('components.entryStack.previewGap'),
      );
      final headerBottom = tester
          .getRect(find.descendant(of: card, matching: find.byType(Wrap)))
          .bottom;
      expect(
        tester.getRect(targetFinder).top - headerBottom,
        pikoDesign.dimension('components.entryStack.previewTop'),
      );
      final current = tester.widget<PikoCard>(
        find.byKey(const ValueKey('entry-card-draft')),
      );
      expect(current.selected, isTrue);
      expect(widget.selected, isFalse);
      final confirm = find.descendant(
        of: find.byKey(const ValueKey('entry-card-draft')),
        matching: find.byType(PikoIconButton),
      );
      final confirmWidget = tester.widget<PikoIconButton>(confirm);
      expect(confirmWidget.variant, PikoButtonVariant.primary);
      expect(confirmWidget.large, isTrue);
      final button = find.descendant(
        of: confirm,
        matching: find.byType(TextButton),
      );
      final minimum = pikoDesign.dimension('controls.largeHeight');
      expect(tester.getSize(button).width, greaterThanOrEqualTo(minimum));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(minimum));
      final style = tester.widget<TextButton>(button).style!;
      expect(style.minimumSize!.resolve({}), Size.square(minimum));
      expect(style.backgroundColor!.resolve({}), pikoDesign.color('tint'));
      expect(
        find.text(const PikoCopy('en').text('entry.prototype')),
        findsNothing,
      );
      expect(find.text('Delete vocabulary'), findsNothing);
    },
  );

  testWidgets('reduced motion suppresses card size and state transitions', (
    tester,
  ) async {
    await screen(tester, reduced: true, locale: 'de');
    expect(find.byType(AnimatedSize), findsNothing);
    for (final card in tester.widgetList<PikoCard>(find.byType(PikoCard))) {
      expect(card.animationDuration, Duration.zero);
    }
    expect(find.text('Gespeichert'), findsOneWidget);
    expect(find.text('Noch nicht bestätigt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
