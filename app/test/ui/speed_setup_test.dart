import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/collections_repository.dart';
import 'package:piko/data/learning_item.dart';
import 'package:piko/features/speed/speed_session.dart';
import 'package:piko/features/speed/speed_setup_dialog.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/copy_scope.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_dialog.dart';
import 'package:piko/ui/piko_theme.dart';

const collection = CollectionRecord(
  id: 'collection',
  name: 'Words',
  targetLanguage: VocabularyLanguage.french,
  nativeLanguage: VocabularyLanguage.german,
);

class SetupHarness {
  SetupHarness({
    this.language = 'en',
    this.direction = LearningDirection.targetToNative,
    this.count = 3,
  });
  final String language;
  final LearningDirection direction;
  final int count;
  final opener = FocusNode();
  int? result;
  bool closed = false;

  Future<void> mount(WidgetTester tester, {double scale = 1}) async {
    addTearDown(opener.dispose);
    await tester.pumpWidget(
      PikoCopyScope(
        copy: PikoCopy(language),
        child: MaterialApp(
          theme: PikoTheme.build(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => PikoButton(
                label: 'Open',
                focusNode: opener,
                onPressed: () async {
                  result = await showSpeedSetup(
                    context,
                    collection: collection,
                    direction: direction,
                    eligibleCount: count,
                  );
                  closed = true;
                },
              ),
            ),
          ),
        ),
      ),
    );
    opener.requestFocus();
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }
}

Finder startButton(String language) => find.widgetWithText(
  PikoButton,
  PikoCopy(language).text('learn.startSpeed'),
);

void main() {
  for (final language in ['en', 'de']) {
    for (final direction in LearningDirection.values) {
      testWidgets(
        'UX-SETUP-002 $language $direction fixed context and warning at320px/200%',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(320, 900);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final h = SetupHarness(language: language, direction: direction);
          await h.mount(tester, scale: 2);
          final copy = PikoCopy(language);
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('speed-fixed-direction')),
                )
                .data,
            direction == LearningDirection.targetToNative
                ? 'FR → DE'
                : 'DE → FR',
          );
          expect(
            find.text(copy.text('r2.speedNewCount', {'count': 3})),
            findsOneWidget,
          );
          expect(find.byType(DropdownButton<LearningDirection>), findsNothing);
          expect(find.byType(Checkbox), findsNothing);
          expect(find.byType(ExpansionTile), findsNothing);
          final field = find.byKey(const ValueKey('speed-pool-size'));
          await tester.ensureVisible(field);
          expect(tester.widget<TextField>(field).controller!.text, '5');
          expect(
            tester.widget<TextField>(field).keyboardType,
            TextInputType.number,
          );
          final warning = tester.widget<Container>(
            find.byKey(const ValueKey('speed-reset-warning')),
          );
          final decoration = warning.decoration! as BoxDecoration;
          expect(decoration.color, pikoDesign.color('warningSurface'));
          expect(
            (decoration.border! as Border).top.color,
            pikoDesign.color('warningBorder'),
          );
          expect(find.text(copy.text('r2.speedResetWarning')), findsOneWidget);
          expect(find.text(copy.text('r2.poolHint')), findsOneWidget);
          expect(
            tester.widget<PikoDialog>(find.byType(PikoDialog)).purpose,
            PikoDialogPurpose.form,
          );
          expect(find.byTooltip(copy.text('common.close')), findsOneWidget);
          await tester.ensureVisible(startButton(language));
          expect(
            tester.widget<PikoButton>(startButton(language)).onPressed,
            isNotNull,
          );
          await tester.tap(startButton(language));
          await tester.pumpAndSettle();
          expect(h.result, SpeedSession.defaultPoolSize);
          expect(h.closed, isTrue);
          expect(find.byType(SpeedSetupDialog), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'pool accepts1 and safe maximum; invalid decimal, zero, exponent and overflow cannot start',
    (tester) async {
      final h = SetupHarness(count: 1);
      await h.mount(tester);
      final copy = PikoCopy('en');
      expect(find.text(copy.text('r2.speedNewOne')), findsOneWidget);
      final field = find.byKey(const ValueKey('speed-pool-size'));
      for (final invalid in [
        '',
        '0',
        '-1',
        '1.5',
        '1e2',
        '9007199254740992',
        '99999999999999999999',
      ]) {
        await tester.enterText(field, invalid);
        await tester.pumpAndSettle();
        expect(tester.widget<PikoButton>(startButton('en')).onPressed, isNull);
        expect(find.text(copy.text('r2.poolInvalid')), findsOneWidget);
        expect(h.closed, isFalse);
      }
      for (final valid in ['1', '${SpeedSession.maxPoolSize}', '17']) {
        await tester.enterText(field, valid);
        await tester.pumpAndSettle();
        expect(
          tester.widget<PikoButton>(startButton('en')).onPressed,
          isNotNull,
        );
        expect(find.text(copy.text('r2.poolInvalid')), findsNothing);
      }
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(h.result, 17);
      expect(h.closed, isTrue);
    },
  );

  for (final dismissal in ['close', 'escape', 'backdrop']) {
    testWidgets(
      '$dismissal cancels setup without launch and restores opener focus',
      (tester) async {
        final h = SetupHarness();
        await h.mount(tester);
        if (dismissal == 'close') {
          await tester.tap(find.byTooltip(PikoCopy('en').text('common.close')));
        } else if (dismissal == 'escape') {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.tapAt(const Offset(2, 2));
        }
        await tester.pumpAndSettle();
        expect(h.closed, isTrue);
        expect(h.result, isNull);
        expect(h.opener.hasFocus, isTrue);
        expect(find.byType(SpeedSetupDialog), findsNothing);
      },
    );
  }

  testWidgets(
    'an empty eligible set never opens setup or returns a pool size',
    (tester) async {
      final h = SetupHarness(count: 0);
      await h.mount(tester);
      expect(h.closed, isTrue);
      expect(h.result, isNull);
      expect(find.byType(SpeedSetupDialog), findsNothing);
    },
  );
}
