import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/services/database_service.dart';
import 'package:novel_reader/models/book.dart';
import 'package:novel_reader/models/book_format.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseService dbService;

  setUpAll(() {
    // Initialize sqflite for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dbService = DatabaseService();
    await dbService.initialize();
  });

  tearDown(() async {
    await dbService.close();
  });

  group('DatabaseService', () {
    test('should initialize database', () {
      expect(dbService.database, isNotNull);
    });

    test('should insert and retrieve book', () async {
      final book = Book(
        id: 'test-id-1',
        title: '测试书籍',
        author: '测试作者',
        filePath: '/path/to/book.txt',
        format: BookFormat.txt,
        fileSize: 1024,
        addTime: DateTime.now(),
        updateTime: DateTime.now(),
        totalChapters: 10,
      );

      await dbService.insertBook(book);
      final retrieved = await dbService.getBook('test-id-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.title, '测试书籍');
    });

    test('should delete book', () async {
      final book = Book(
        id: 'test-id-2',
        title: '待删除书籍',
        filePath: '/path/to/book.txt',
        format: BookFormat.txt,
        fileSize: 1024,
        addTime: DateTime.now(),
        updateTime: DateTime.now(),
      );

      await dbService.insertBook(book);
      await dbService.deleteBook('test-id-2');

      final retrieved = await dbService.getBook('test-id-2');
      expect(retrieved, isNull);
    });
  });
}
