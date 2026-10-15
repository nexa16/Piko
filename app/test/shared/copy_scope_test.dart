import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/shared/catalogs.dart';
import 'package:piko/shared/copy_scope.dart';

void main() {
  testWidgets('app title and descendant scope consume canonical copy', (
    tester,
  ) async {
    await tester.pumpWidget(const PikoApp(home: Scaffold()));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final context = tester.element(find.byType(Scaffold));
    expect(app.title, PikoCopyScope.of(context).text('app.name'));
  });

  testWidgets('changing scope locale rebuilds the existing catalog consumer', (
    tester,
  ) async {
    var builds = 0;
    final consumer = Builder(
      builder: (context) {
        builds++;
        return Text(PikoCopyScope.of(context).text('nav.settings'));
      },
    );
    Widget host(String locale) => Directionality(
      textDirection: TextDirection.ltr,
      child: PikoCopyScope(copy: PikoCopy(locale), child: consumer),
    );
    await tester.pumpWidget(host('en'));
    expect(
      find.text(const PikoCopy('en').text('nav.settings')),
      findsOneWidget,
    );
    final initialBuilds = builds;
    await tester.pumpWidget(host('de'));
    expect(builds, greaterThan(initialBuilds));
    expect(
      find.text(const PikoCopy('de').text('nav.settings')),
      findsOneWidget,
    );
  });
}
