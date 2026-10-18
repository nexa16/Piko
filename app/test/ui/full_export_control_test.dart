import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/data/full_export.dart';
import 'package:piko/features/interchange/full_export_control.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/ui/components/piko_button.dart';
import 'package:piko/ui/components/piko_page.dart';
import 'json_transfer_test.dart' show JsonTestPlatform;

class ReportService implements FullExportService {
  int calls = 0;
  Completer<String>? gate;
  Object? error;
  @override
  Future<String> exportAll() async {
    calls++;
    if (error != null) throw error!;
    return gate?.future ?? '{"format":"piko.full-export","collections":[]}';
  }
}

final exportButton = find.byKey(const ValueKey('settings-full-export'));
void main() {
  Future<void> mount(
    WidgetTester tester,
    ReportService service,
    JsonTestPlatform platform, {
    String locale = 'en',
    double scale = 1,
    List<Future<void>>? drains,
  }) async {
    await tester.pumpWidget(
      PikoApp(
        locale: Locale(locale),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: PikoPage(
                child: Column(
                  children: [
                    const SizedBox(height: 500),
                    FullExportControl(
                      service: service,
                      platform: platform,
                      registerPending: (future) => drains?.add(future),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(exportButton);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'one export drains through platform completion; cancellation is not success',
    (tester) async {
      final service = ReportService()..gate = Completer<String>();
      final platform = JsonTestPlatform()..saveResult = false;
      final drains = <Future<void>>[];
      await mount(tester, service, platform, drains: drains);
      final button = tester.widget<PikoButton>(exportButton);
      button.focusNode!.requestFocus();
      await tester.pump();
      final activate = button.onPressed!;
      await tester.tap(exportButton);
      activate();
      await tester.pumpAndSettle();
      expect(service.calls, 1);
      expect(drains, hasLength(1));
      expect(tester.widget<PikoButton>(exportButton).onPressed, isNull);
      var drained = false;
      unawaited(drains.single.then((_) => drained = true));
      expect(drained, isFalse);
      service.gate!.complete('{"exact":"한글"}');
      await tester.pumpAndSettle();
      await drains.single;
      expect(platform.saved, ['{"exact":"한글"}']);
      expect(
        find.text(PikoCopy('en').text('fullExport.cancelled')),
        findsOneWidget,
      );
      expect(find.text(PikoCopy('en').text('json.fileSaved')), findsNothing);
      expect(button.focusNode!.hasFocus, isTrue);
    },
  );

  for (final locale in ['en', 'de']) {
    testWidgets(
      '$locale 320dp/200% read/write failure can retry with anchored focus',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final service = ReportService()..error = StateError('Read failure');
        final platform = JsonTestPlatform();
        final copy = PikoCopy(locale);
        await mount(tester, service, platform, locale: locale, scale: 2);
        final top = tester.getTopLeft(exportButton).dy;
        await tester.tap(exportButton);
        await tester.pumpAndSettle();
        expect(find.text(copy.text('fullExport.failed')), findsOneWidget);
        expect(
          tester
              .getRect(find.byKey(const ValueKey('full-export-status')))
              .bottom,
          lessThanOrEqualTo(800),
        );
        expect(
          tester.widget<PikoButton>(exportButton).label,
          copy.text('action.retry'),
        );
        expect(tester.getTopLeft(exportButton).dy, closeTo(top, .5));
        expect(platform.saved, isEmpty);
        service.error = null;
        platform.saveFailure = StateError('File permission denied');
        await tester.tap(exportButton);
        await tester.pumpAndSettle();
        expect(find.text(copy.text('fullExport.failed')), findsOneWidget);
        platform.saveFailure = null;
        await tester.tap(exportButton);
        await tester.pumpAndSettle();
        expect(find.text(copy.text('json.fileSaved')), findsOneWidget);
        expect(
          tester
              .getRect(find.byKey(const ValueKey('full-export-status')))
              .bottom,
          lessThanOrEqualTo(800),
        );
        expect(service.calls, 3);
        expect(platform.saved, hasLength(1));
        expect(tester.getTopLeft(exportButton).dy, closeTo(top, .5));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('covered or replaced export cannot open a late native picker', (
    tester,
  ) async {
    final service = ReportService()..gate = Completer<String>();
    final platform = JsonTestPlatform();
    final drains = <Future<void>>[];
    await mount(tester, service, platform, drains: drains);
    await tester.tap(exportButton);
    await tester.pump();
    final navigator = Navigator.of(tester.element(exportButton));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Covered')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    service.gate!.complete('{}');
    await tester.pumpAndSettle();
    await drains.single;
    expect(platform.saved, isEmpty);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(tester.widget<PikoButton>(exportButton).onPressed, isNotNull);

    service.gate = Completer<String>();
    await tester.tap(exportButton);
    await tester.pump();
    await mount(tester, ReportService(), platform, drains: drains);
    service.gate!.complete('{}');
    await tester.pumpAndSettle();
    await Future.wait(drains);
    expect(platform.saved, isEmpty);
    expect(tester.widget<PikoButton>(exportButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
