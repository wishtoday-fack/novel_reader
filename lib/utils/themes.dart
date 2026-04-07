import 'package:flutter/material.dart';

class AppThemes {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
    );
  }
}

class ReaderTheme {
  final String name;
  final Color backgroundColor;
  final Color textColor;

  const ReaderTheme({
    required this.name,
    required this.backgroundColor,
    required this.textColor,
  });

  static const List<ReaderTheme> presets = [
    ReaderTheme(
      name: '白色',
      backgroundColor: Color(0xFFFFFFFF),
      textColor: Color(0xFF333333),
    ),
    ReaderTheme(
      name: '护眼',
      backgroundColor: Color(0xFFCCE8CF),
      textColor: Color(0xFF2C4A2E),
    ),
    ReaderTheme(
      name: '羊皮纸',
      backgroundColor: Color(0xFFF5E6D3),
      textColor: Color(0xFF5D4E37),
    ),
    ReaderTheme(
      name: '夜间',
      backgroundColor: Color(0xFF1A1A1A),
      textColor: Color(0xFFCCCCCC),
    ),
  ];
}
