import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/models/book.dart';
import 'package:novel_reader/models/book_format.dart';

void main() {
  group('Book', () {
    test('should create a book instance', () {
      final book = Book(
        id: 'test-id',
        title: '测试书籍',
        author: '测试作者',
        filePath: '/path/to/book.txt',
        format: BookFormat.txt,
        fileSize: 1024,
        addTime: DateTime(2026, 1, 1),
        updateTime: DateTime(2026, 1, 1),
        totalChapters: 10,
      );

      expect(book.id, 'test-id');
      expect(book.title, '测试书籍');
      expect(book.author, '测试作者');
      expect(book.format, BookFormat.txt);
    });

    test('should convert to and from map', () {
      final book = Book(
        id: 'test-id',
        title: '测试书籍',
        filePath: '/path/to/book.txt',
        format: BookFormat.txt,
        fileSize: 1024,
        addTime: DateTime(2026, 1, 1),
        updateTime: DateTime(2026, 1, 1),
        totalChapters: 10,
      );

      final map = book.toMap();
      final fromMap = Book.fromMap(map);

      expect(fromMap.id, book.id);
      expect(fromMap.title, book.title);
      expect(fromMap.format, book.format);
    });
  });
}
