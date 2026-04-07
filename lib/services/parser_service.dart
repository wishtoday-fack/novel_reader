import 'package:novel_reader/models/book.dart';
import 'package:novel_reader/models/book_format.dart';
import 'package:novel_reader/models/chapter.dart';
import 'package:novel_reader/services/parser/book_parser.dart';
import 'package:novel_reader/services/parser/txt_parser.dart';
import 'package:novel_reader/services/parser/epub_parser.dart';
import 'package:novel_reader/services/parser/pdf_parser.dart';
import 'package:novel_reader/services/parser/mobi_parser.dart';
import 'package:novel_reader/services/parser/parser_cache.dart';
import 'package:novel_reader/utils/file_utils.dart';

class BookParserService {
  final Map<BookFormat, BookParser> _parsers;
  final ParserCache _cache;

  BookParserService({ParserCache? cache})
      : _cache = cache ?? ParserCache(),
        _parsers = {
          BookFormat.txt: TxtParser(),
          BookFormat.epub: EpubParser(),
          BookFormat.pdf: PdfParser(),
          BookFormat.mobi: MobiParser(),
        };

  BookParser getParser(BookFormat format) {
    final parser = _parsers[format];
    if (parser == null) {
      throw UnsupportedError('Unsupported format: $format');
    }
    return parser;
  }

  BookFormat detectFormat(String filePath) {
    return FileUtils.detectFormat(filePath);
  }

  Future<Book> parseBook(String filePath) async {
    final format = detectFormat(filePath);
    final parser = getParser(format);
    final bookId = FileUtils.generateBookId(filePath);

    final metadata = await parser.parseMetadata(filePath);
    final chapters = await parser.parseChapters(filePath, bookId);
    final coverPath = await parser.extractCover(filePath);
    final fileSize = await FileUtils.getFileSize(filePath);

    return Book(
      id: bookId,
      title: metadata.title,
      author: metadata.author ?? '未知作者',
      coverPath: coverPath,
      filePath: filePath,
      format: format,
      fileSize: fileSize,
      addTime: DateTime.now(),
      updateTime: DateTime.now(),
      description: metadata.description,
      totalChapters: chapters.length,
    );
  }

  Future<List<Chapter>> parseChapters(String filePath, String bookId) async {
    final format = detectFormat(filePath);
    final parser = getParser(format);
    return await parser.parseChapters(filePath, bookId);
  }

  Future<String> getChapterContent(
    String filePath,
    int chapterIndex,
    BookFormat format,
  ) async {
    final cacheKey = '$filePath-$chapterIndex';
    final cached = await _cache.getChapter(cacheKey);
    if (cached != null) return cached;

    final parser = getParser(format);
    final content = await parser.parseContent(filePath, chapterIndex);
    await _cache.putChapter(cacheKey, content);
    return content;
  }

  Future<void> clearCache() async {
    await _cache.clear();
  }
}
