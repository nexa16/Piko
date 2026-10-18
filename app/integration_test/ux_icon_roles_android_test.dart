import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:piko/features/statistics/statistics_widgets.dart';
import 'package:piko/main.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_form.dart';
import 'package:piko/ui/components/piko_icon.dart';
import 'package:piko/ui/piko_theme.dart';
import 'support/round2_catalogue_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native shared default, contextual, disabled and focused pressed icon roles',
    (tester) async {
      final config = CatalogueConfiguration();
      final support = await getApplicationSupportDirectory();
      final directory = Directory(
        '${support.path}/ux-followups-${config.runId}',
      );
      if (await directory.exists()) {
        throw StateError('Unique icon evidence required');
      }
      await directory.create();
      final focus = FocusNode();
      final oldHighlight = FocusManager.instance.highlightStrategy;
      final states = <Map<String, Object?>>[];
      final manifest = <String, Object?>{
        'sourceCommit': config.commit,
        'locale': config.locale,
        'scale': config.scale,
        'normalProductionDatabaseOpened': false,
        'fixture': 'production component icon matrix',
        'states': states,
      };
      var passed = false;
      Finder key(String id) => find.byKey(ValueKey(id));
      ColorFilter filter(Finder parent) => tester
          .widget<SvgPicture>(
            find.descendant(of: parent, matching: find.byType(SvgPicture)),
          )
          .colorFilter!;
      Future<void> reveal(Finder finder) async {
        await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
        await tester.pumpAndSettle();
        expect(finder.hitTestable(), findsOneWidget);
      }

      Future<void> record(String id) async {
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await tester.pump();
        final media = MediaQuery.of(tester.element(find.byType(Scaffold)));
        final roles = <String, Object?>{};
        for (final role in [
          'ordinary',
          'warning',
          'navigation',
          'primary',
          'danger',
          'disabled',
        ]) {
          final owner = role == 'warning'
              ? find.byType(StatisticsReminder)
              : key('icons-$role');
          final icon = find
              .descendant(
                of: owner,
                matching: find.byType(PikoIcon),
                matchRoot: true,
              )
              .first;
          final r = tester.getRect(icon);
          roles[role] = {
            'rect': [r.left, r.top, r.width, r.height],
            'filter': filter(owner).toString(),
          };
        }
        states.add({
          'id': id,
          'width': media.size.width,
          'height': media.size.height,
          'scale': media.textScaler.scale(14) / 14,
          'roles': roles,
        });
        await File('${directory.path}/phase.json').writeAsString(
          jsonEncode({'phase': 'capture-$id', 'run': config.runId}),
          flush: true,
        );
        final ack = File('${directory.path}/ack-capture-$id');
        final end = DateTime.now().add(const Duration(seconds: 30));
        while (!await ack.exists() && DateTime.now().isBefore(end)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(await ack.exists(), isTrue);
        expect(tester.takeException(), isNull);
      }

      try {
        await tester.pumpWidget(
          PikoApp(
            key: const ValueKey('native-icon-matrix-root'),
            locale: Locale(config.locale),
            home: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PikoIcon(
                        PikoIconName.chevronRight,
                        key: ValueKey('icons-ordinary'),
                      ),
                      const StatisticsReminder(),
                      PikoNavigationRow(
                        key: const ValueKey('icons-navigation'),
                        title: 'Navigation',
                        onTap: () {},
                      ),
                      PikoButton(
                        key: const ValueKey('icons-primary'),
                        label: 'Primary',
                        focusNode: focus,
                        variant: PikoButtonVariant.reviewPrimary,
                        icon: const PikoIcon(PikoIconName.plus),
                        onPressed: () {},
                      ),
                      PikoButton(
                        key: const ValueKey('icons-danger'),
                        label: 'Danger',
                        variant: PikoButtonVariant.dangerFilled,
                        icon: const PikoIcon(PikoIconName.trash),
                        onPressed: () {},
                      ),
                      const PikoButton(
                        key: ValueKey('icons-disabled'),
                        label: 'Disabled',
                        variant: PikoButtonVariant.reviewPrimary,
                        icon: PikoIcon(PikoIconName.plus),
                        onPressed: null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(StatisticsReminder), findsOneWidget);
        for (final f in [
          key('icons-ordinary'),
          find.byType(StatisticsReminder),
        ]) {
          expect(
            filter(f),
            const ColorFilter.mode(Color(0xff34365b), BlendMode.srcIn),
          );
        }
        expect(
          filter(key('icons-navigation')),
          ColorFilter.mode(pikoDesign.color('primary'), BlendMode.srcIn),
        );
        expect(
          filter(key('icons-primary')),
          ColorFilter.mode(pikoDesign.color('onPrimary'), BlendMode.srcIn),
        );
        expect(
          filter(key('icons-danger')),
          ColorFilter.mode(pikoDesign.color('onDanger'), BlendMode.srcIn),
        );
        expect(
          filter(key('icons-disabled')),
          ColorFilter.mode(
            pikoDesign
                .color('onPrimary')
                .withValues(
                  alpha: pikoDesign.dimension('states.disabledOpacity'),
                ),
            BlendMode.srcIn,
          ),
        );
        await record('icon-warning');
        await reveal(key('icons-disabled'));
        expect(
          tester.widget<PikoButton>(key('icons-disabled')).onPressed,
          isNull,
        );
        expect(
          tester.getSize(key('icons-danger')).height,
          greaterThanOrEqualTo(48),
        );
        await record('icon-danger-disabled');
        await reveal(key('icons-primary'));
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        final gesture = await tester.startGesture(
          tester.getCenter(key('icons-primary')),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          filter(key('icons-primary')),
          ColorFilter.mode(pikoDesign.color('onPrimary'), BlendMode.srcIn),
        );
        await record('icon-focused-pressed');
        await gesture.up();
        await tester.pumpAndSettle();
        passed = true;
      } finally {
        FocusManager.instance.highlightStrategy = oldHighlight;
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        focus.dispose();
        manifest['passed'] = passed;
        await File('${directory.path}/manifest.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert(manifest),
          flush: true,
        );
      }
    },
  );
}
