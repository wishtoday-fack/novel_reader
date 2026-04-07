import 'package:flutter/material.dart';
import 'screens/bookshelf/bookshelf_screen.dart';
import 'utils/themes.dart';

class NovelReaderApp extends StatelessWidget {
  const NovelReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '小说阅读器',
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      home: const BookshelfScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
