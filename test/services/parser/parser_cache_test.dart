import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/services/parser/parser_cache.dart';

void main() {
  group('ParserCache', () {
    late ParserCache cache;

    setUp(() {
      cache = ParserCache(maxSize: 3);
    });

    test('should cache and retrieve content', () async {
      await cache.putChapter('key1', 'Content 1');
      final content = await cache.getChapter('key1');
      expect(content, 'Content 1');
    });

    test('should return null for missing key', () async {
      final content = await cache.getChapter('missing');
      expect(content, isNull);
    });

    test('should evict oldest when full', () async {
      await cache.putChapter('key1', 'Content 1');
      await cache.putChapter('key2', 'Content 2');
      await cache.putChapter('key3', 'Content 3');
      await cache.putChapter('key4', 'Content 4');

      expect(await cache.getChapter('key1'), isNull);
      expect(await cache.getChapter('key4'), 'Content 4');
    });
  });
}
