import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/utils/file_utils.dart';
import 'package:novel_reader/models/book_format.dart';

void main() {
  group('FileUtils', () {
    test('should detect txt format', () {
      final format = FileUtils.detectFormat('/path/to/book.txt');
      expect(format, BookFormat.txt);
    });

    test('should detect epub format', () {
      final format = FileUtils.detectFormat('/path/to/book.epub');
      expect(format, BookFormat.epub);
    });

    test('should detect mobi variants', () {
      expect(FileUtils.detectFormat('/path/to/book.mobi'), BookFormat.mobi);
      expect(FileUtils.detectFormat('/path/to/book.azw3'), BookFormat.mobi);
    });

    test('should throw for unsupported format', () {
      expect(
        () => FileUtils.detectFormat('/path/to/book.doc'),
        throwsArgumentError,
      );
    });

    test('should generate consistent book id', () {
      final id1 = FileUtils.generateBookId('/path/to/book.txt');
      final id2 = FileUtils.generateBookId('/path/to/book.txt');
      expect(id1, id2);
    });
  });
}
