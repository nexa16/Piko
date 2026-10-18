import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piko/main.dart';
import 'package:piko/piko_runtime.dart';
import 'package:piko/data/settings_repository.dart';
import 'package:piko/data/local/piko_database.dart';
import 'package:piko/shared/catalogs.dart';

class CollisionSettings implements SettingsRepository {
  int reads = 0;
  @override
  Future<String?> read(String key) async {
    reads++;
    throw const VocabularyMigrationCollision();
  }

  @override
  Future<void> write(String key, String value) =>
      throw StateError('No writes permitted');
  @override
  Future<void> remove(String key) => throw StateError('No writes permitted');
}

void main() {
  for (final locale in ['en', 'de']) {
    testWidgets(
      '$locale migration collision explains preserved data and retry without an empty home',
      (tester) async {
        final settings = CollisionSettings();
        await tester.pumpWidget(
          PikoApp(
            locale: Locale(locale),
            home: PikoRuntime(settingsRepositoryFactory: (_) => settings),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(PikoCopy(locale).text('storage.migrationCollision')),
          findsOneWidget,
        );
        expect(
          find.text(PikoCopy(locale).text('action.retry')),
          findsOneWidget,
        );
        final reads = settings.reads;
        await tester.tap(find.text(PikoCopy(locale).text('action.retry')));
        await tester.pumpAndSettle();
        expect(settings.reads, greaterThan(reads));
        expect(
          find.text(PikoCopy(locale).text('storage.migrationCollision')),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
