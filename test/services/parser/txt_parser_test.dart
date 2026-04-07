import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/services/parser/txt_parser.dart';

void main() {
  late TxtParser parser;

  setUp(() {
    parser = TxtParser();
  });

  group('TxtParser', () {
    test('should parse metadata', () async {
      final info = await parser.parseMetadata(
        'test/fixtures/test_book.txt',
      );

      expect(info.title, 'test_book');
      expect(info.totalChapters, greaterThan(0));
    });

    test('should parse chapters', () async {
      final chapters = await parser.parseChapters(
        'test/fixtures/test_book.txt',
        'test-book-id',
      );

      expect(chapters.length, 3);
      expect(chapters[0].title, contains('第一章'));
      expect(chapters[1].title, contains('第二章'));
      expect(chapters[2].title, contains('第三章'));
    });

    test('should parse chapter content', () async {
      final content = await parser.parseContent(
        'test/fixtures/test_book.txt',
        0,
      );

      expect(content, contains('第一章'));
      expect(content, contains('这是第一章的内容'));
    });

    test('should return null for cover', () async {
      final cover = await parser.extractCover(
        'test/fixtures/test_book.txt',
      );

      expect(cover, isNull);
    });
  });
}
