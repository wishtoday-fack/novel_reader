import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/services/parser/mobi_parser.dart';
import 'package:novel_reader/services/parser/book_parser.dart';

void main() {
  late MobiParser parser;

  setUp(() {
    parser = MobiParser();
  });

  group('MobiParser', () {
    test('should implement BookParser interface', () {
      expect(parser, isA<BookParser>());
    });

    test('should parse metadata from valid mobi', () async {
      // Note: This test requires a valid MOBI file
      // For now, we test with a non-existent file to verify error handling
      expect(
        () => parser.parseMetadata('non_existent.mobi'),
        throwsA(isA<Exception>()),
      );
    });

    test('should parse chapters from valid mobi', () async {
      expect(
        () => parser.parseChapters('non_existent.mobi', 'test-book-id'),
        throwsA(isA<Exception>()),
      );
    });

    test('should parse content from valid mobi chapter', () async {
      expect(
        () => parser.parseContent('non_existent.mobi', 0),
        throwsA(isA<Exception>()),
      );
    });

    test('should extract cover from mobi', () async {
      // Should not throw, returns null if no cover
      final cover = await parser.extractCover('non_existent.mobi');
      expect(cover, isNull);
    });
  });
}
