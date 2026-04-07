import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/services/parser_service.dart';
import 'package:novel_reader/models/book_format.dart';

void main() {
  late BookParserService service;

  setUp(() {
    service = BookParserService();
  });

  group('BookParserService', () {
    test('should detect formats correctly', () {
      expect(service.detectFormat('/path/to/book.txt'), BookFormat.txt);
      expect(service.detectFormat('/path/to/book.epub'), BookFormat.epub);
      expect(service.detectFormat('/path/to/book.pdf'), BookFormat.pdf);
      expect(service.detectFormat('/path/to/book.mobi'), BookFormat.mobi);
    });

    test('should get appropriate parser', () {
      expect(service.getParser(BookFormat.txt), isNotNull);
      expect(service.getParser(BookFormat.epub), isNotNull);
      expect(service.getParser(BookFormat.pdf), isNotNull);
      expect(service.getParser(BookFormat.mobi), isNotNull);
    });
  });
}
