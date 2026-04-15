// Entry point để DEV / test Code Editor mà không cần Firebase
// Chạy: flutter run -t lib/main_dev.dart
import 'package:flutter/material.dart';
import 'screens/code_editor_screen.dart';

void main() {
  runApp(const DevApp());
}

class DevApp extends StatelessWidget {
  const DevApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Code Editor Dev',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A73E8)),
        useMaterial3: true,
      ),
      home: const CodeEditorScreen(),
    );
  }
}
