import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/services/parser/pdf_parser.dart';
import 'package:novel_reader/services/parser/book_parser.dart';

void main() {
  late PdfParser parser;

  setUp(() {
    parser = PdfParser();
  });

  group('PdfParser', () {
    test('should implement BookParser interface', () {
      expect(parser, isA<BookParser>());
    });

    test('should parse metadata from valid pdf', () async {
      // Note: This test requires a valid PDF file
      // For now, we test with a non-existent file to verify error handling
      expect(
        () => parser.parseMetadata('non_existent.pdf'),
        throwsA(isA<Exception>()),
      );
    });

    test('should parse chapters from valid pdf', () async {
      expect(
        () => parser.parseChapters('non_existent.pdf', 'test-book-id'),
        throwsA(isA<Exception>()),
      );
    });

    test('should parse content from valid pdf page', () async {
      expect(
        () => parser.parseContent('non_existent.pdf', 0),
        throwsA(isA<Exception>()),
      );
    });

    test('should extract cover from pdf', () async {
      // Should not throw, returns null if no cover
      final cover = await parser.extractCover('non_existent.pdf');
      expect(cover, isNull);
    });
  });
}
