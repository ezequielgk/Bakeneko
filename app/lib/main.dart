import 'package:flutter/material.dart';

void main() {
  runApp(const BakenekoApp());
}

class BakenekoApp extends StatelessWidget {
  const BakenekoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bakeneko',
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE29578))),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE29578), brightness: Brightness.dark),
      ),
      home: const Scaffold(
        body: Center(child: Text('Bakeneko-Reader · scaffold OK')),
      ),
    );
  }
}