import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'services/database_service.dart';
import 'services/parser_service.dart';
import 'services/file_service.dart';
import 'repositories/book_repository.dart';
import 'repositories/settings_repository.dart';
import 'providers/bookshelf_provider.dart';
import 'providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final dbService = DatabaseService();
  await dbService.initialize();
  
  final parserService = BookParserService();
  
  // Initialize repositories
  final prefs = await SharedPreferences.getInstance();
  final settingsRepo = SettingsRepository(prefs);
  final bookRepo = BookRepository(
    databaseService: dbService,
    parserService: parserService,
  );
  
  // Initialize providers
  final settingsProvider = SettingsProvider(settingsRepo);
  
  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: dbService),
        Provider<BookParserService>.value(value: parserService),
        Provider<BookRepository>.value(value: bookRepo),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ChangeNotifierProvider(
          create: (_) => BookshelfProvider(
            bookRepository: bookRepo,
            fileService: FileService(),
          ),
        ),
      ],
      child: const NovelReaderApp(),
    ),
  );
}
