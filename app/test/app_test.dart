import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';

void main() {
  testWidgets('application starts without example content or fabricated data', (
    tester,
  ) async {
    await tester.pumpWidget(const PikoApp());
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('My collections'), findsOneWidget);
    expect(find.text('Korean Basics'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
