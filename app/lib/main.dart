import 'package:flutter/material.dart';
import 'shared/catalogs.dart';
import 'shared/copy_scope.dart';
import 'shared/generated_catalogs.dart';
import 'ui/piko_theme.dart';

void main() {
  runApp(const PikoApp());
}

class PikoApp extends StatelessWidget {
  const PikoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return PikoCopyScope(
      copy: PikoCopy(copyCatalog['defaultLocale']! as String),
      child: Builder(
        builder: (context) => MaterialApp(
          title: PikoCopyScope.of(context).text('app.name'),
          theme: PikoTheme.build(),
          debugShowCheckedModeBanner: false,
          home: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
  }
}
