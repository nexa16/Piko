import 'package:flutter/material.dart';
import 'ui/piko_theme.dart';

void main() {
  runApp(const PikoApp());
}

class PikoApp extends StatelessWidget {
  const PikoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: PikoTheme.build(),
      debugShowCheckedModeBanner: false,
      home: const Scaffold(body: SizedBox.expand()),
    );
  }
}
