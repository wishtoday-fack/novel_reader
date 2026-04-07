import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_reader/app.dart';
import 'package:novel_reader/services/database_service.dart';
import 'package:novel_reader/services/parser_service.dart';
import 'package:novel_reader/services/file_service.dart';
import 'package:novel_reader/repositories/book_repository.dart';
import 'package:novel_reader/repositories/settings_repository.dart';
import 'package:novel_reader/providers/bookshelf_provider.dart';
import 'package:novel_reader/providers/settings_provider.dart';

void main() {
  setUpAll(() {
    // Initialize sqflite for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App should load bookshelf screen', (WidgetTester tester) async {
    // Initialize SharedPreferences with mock
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    
    // Create services and repositories
    final dbService = DatabaseService();
    await dbService.initialize();
    
    final parserService = BookParserService();
    final settingsRepo = SettingsRepository(prefs);
    final bookRepo = BookRepository(
      databaseService: dbService,
      parserService: parserService,
    );
    
    final settingsProvider = SettingsProvider(settingsRepo);

    await tester.pumpWidget(
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

    // Wait for the widget to build
    await tester.pumpAndSettle();

    // Verify that bookshelf screen loads with correct title
    expect(find.text('我的书架'), findsOneWidget);
    
    // Clean up
    await dbService.close();
  });
}
