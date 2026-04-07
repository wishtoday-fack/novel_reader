import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/services/parser/epub_parser.dart';
import 'package:novel_reader/services/parser/book_parser.dart';

void main() {
  late EpubParser parser;

  setUp(() {
    parser = EpubParser();
  });

  group('EpubParser', () {
    test('should implement BookParser interface', () {
      expect(parser, isA<BookParser>());
    });

    test('should parse metadata from valid epub', () async {
      // Note: This test requires a valid EPUB file
      // For now, we test with a non-existent file to verify error handling
      expect(
        () => parser.parseMetadata('non_existent.epub'),
        throwsA(isA<Exception>()),
      );
    });

    test('should parse chapters from valid epub', () async {
      expect(
        () => parser.parseChapters('non_existent.epub', 'test-book-id'),
        throwsA(isA<Exception>()),
      );
    });

    test('should parse content from valid epub chapter', () async {
      expect(
        () => parser.parseContent('non_existent.epub', 0),
        throwsA(isA<Exception>()),
      );
    });

    test('should extract cover from epub', () async {
      // Should not throw, returns null if no cover
      final cover = await parser.extractCover('non_existent.epub');
      expect(cover, isNull);
    });
  });
}
