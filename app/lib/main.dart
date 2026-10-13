import 'package:flutter/material.dart';

void main() {
  runApp(const PikoApp());
}

class PikoApp extends StatelessWidget {
  const PikoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: SizedBox.expand()),
    );
  }
}
