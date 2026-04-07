import 'dart:io';
import 'package:epub_plus/epub_plus.dart';
import 'package:image/image.dart' as img;
import 'package:novel_reader/models/chapter.dart';
import 'package:novel_reader/services/parser/book_parser.dart';
import 'package:novel_reader/utils/file_utils.dart';
import 'package:novel_reader/utils/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;

/// EPUB format parser using epub_plus library
/// Supports EPUB 2.0 and 3.0 formats
class EpubParser implements BookParser {
  /// Cache for opened EPUB books to avoid repeated file operations
  final Map<String, EpubBook> _bookCache = {};

  @override
  Future<BookInfo> parseMetadata(String filePath) async {
    final epubBook = await _openBook(filePath);

    String title;
    String? author;
    String? description;

    // Extract title
    if (epubBook.title != null && epubBook.title!.isNotEmpty) {
      title = epubBook.title!;
    } else {
      title = FileUtils.extractFileName(filePath);
    }

    // Extract author
    if (epubBook.author != null && epubBook.author!.isNotEmpty) {
      author = epubBook.author;
    } else if (epubBook.authors.isNotEmpty) {
      author = epubBook.authors.where((a) => a != null).join(', ');
    }

    // Extract description from schema metadata
    final metadata = epubBook.schema?.package?.metadata;
    if (metadata?.description != null && metadata!.description!.isNotEmpty) {
      description = metadata.description;
    }

    // Count chapters
    final chapters = await _extractChapters(epubBook, 'temp');

    return BookInfo(
      title: title,
      author: author,
      description: description,
      totalChapters: chapters.length,
    );
  }

  @override
  Future<List<Chapter>> parseChapters(String filePath, String bookId) async {
    final epubBook = await _openBook(filePath);
    return _extractChapters(epubBook, bookId);
  }

  @override
  Future<String> parseContent(String filePath, int chapterIndex) async {
    final epubBook = await _openBook(filePath);
    final chapters = await _extractChapters(epubBook, 'temp');

    if (chapterIndex < 0 || chapterIndex >= chapters.length) {
      throw RangeError('Invalid chapter index: $chapterIndex');
    }

    final chapter = chapters[chapterIndex];
    if (chapter.content != null && chapter.content!.isNotEmpty) {
      return chapter.content!;
    }

    // Extract content from chapter HTML
    return await _extractChapterContent(epubBook, chapterIndex);
  }

  @override
  Future<String?> extractCover(String filePath) async {
    try {
      final epubBook = await _openBook(filePath);

      // Try to get cover image
      final coverImage = epubBook.coverImage;
      if (coverImage != null) {
        return await _saveCoverImage(coverImage);
      }

      return null;
    } catch (e) {
      AppLogger.error('Failed to extract EPUB cover', e);
      return null;
    }
  }

  /// Open and cache an EPUB book
  Future<EpubBook> _openBook(String filePath) async {
    if (_bookCache.containsKey(filePath)) {
      return _bookCache[filePath]!;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('EPUB file not found', filePath);
    }

    try {
      final bytes = await file.readAsBytes();
      final epubBook = await EpubReader.readBook(bytes);

      _bookCache[filePath] = epubBook;
      return epubBook;
    } catch (e) {
      AppLogger.error('EPUB parsing error: $e');
      throw Exception('Failed to parse EPUB file. The file may be corrupted or contain invalid references.');
    }
  }

  /// Extract chapters from EPUB book
  Future<List<Chapter>> _extractChapters(EpubBook epubBook, String bookId) async {
    final chapters = <Chapter>[];

    // Use the chapters list from epubBook
    final epubChapters = epubBook.chapters;

    if (epubChapters.isEmpty) {
      // Fallback: extract from HTML content files
      return _extractChaptersFromContent(epubBook, bookId);
    }

    int index = 0;
    for (final epubChapter in epubChapters) {
      final chapter = _convertEpubChapter(epubChapter, bookId, index);
      chapters.add(chapter);

      // Also add sub-chapters
      for (final subChapter in epubChapter.subChapters) {
        index++;
        final subChapterModel = _convertEpubChapter(subChapter, bookId, index);
        chapters.add(subChapterModel);
      }

      index++;
    }

    return chapters;
  }

  /// Convert EpubChapter to our Chapter model
  Chapter _convertEpubChapter(EpubChapter epubChapter, String bookId, int index) {
    String? content;

    // Try to get content from htmlContent
    try {
      if (epubChapter.htmlContent != null && epubChapter.htmlContent!.isNotEmpty) {
        content = _htmlToText(epubChapter.htmlContent);
      }
    } catch (e) {
      AppLogger.error('Failed to extract content for chapter: ${epubChapter.title}', e);
      content = null;
    }

    return Chapter(
      id: const Uuid().v4(),
      bookId: bookId,
      index: index,
      title: epubChapter.title ?? '第 ${index + 1} 章',
      content: content,
    );
  }

  /// Extract chapters from content when chapters list is empty
  Future<List<Chapter>> _extractChaptersFromContent(EpubBook epubBook, String bookId) async {
    final chapters = <Chapter>[];

    final htmlFiles = epubBook.content?.html ?? {};

    int index = 0;
    for (final entry in htmlFiles.entries) {
      final fileName = entry.key;
      final htmlFile = entry.value;

      String title = FileUtils.extractFileName(fileName);
      String? content;

      try {
        if (htmlFile.content != null && htmlFile.content!.isNotEmpty) {
          content = _htmlToText(htmlFile.content);
        }
      } catch (e) {
        AppLogger.error('Failed to read content for file: $fileName', e);
        // Skip this file and continue with others
        continue;
      }

      chapters.add(Chapter(
        id: const Uuid().v4(),
        bookId: bookId,
        index: index,
        title: title,
        content: content,
      ));

      index++;
    }

    return chapters;
  }

  /// Extract chapter content by index
  Future<String> _extractChapterContent(EpubBook epubBook, int chapterIndex) async {
    final epubChapters = epubBook.chapters;

    // Flatten chapters including sub-chapters
    final allChapters = <EpubChapter>[];
    for (final chapter in epubChapters) {
      allChapters.add(chapter);
      allChapters.addAll(chapter.subChapters);
    }

    if (chapterIndex < 0 || chapterIndex >= allChapters.length) {
      // Try HTML content files
      final htmlFiles = epubBook.content?.html ?? {};
      final htmlKeys = htmlFiles.keys.toList();

      if (chapterIndex < htmlKeys.length) {
        final htmlFile = htmlFiles[htmlKeys[chapterIndex]];
        if (htmlFile?.content != null) {
          return _htmlToText(htmlFile!.content);
        }
      }

      throw RangeError('Invalid chapter index: $chapterIndex');
    }

    final chapter = allChapters[chapterIndex];
    if (chapter.htmlContent != null && chapter.htmlContent!.isNotEmpty) {
      return _htmlToText(chapter.htmlContent);
    }

    return '';
  }

  /// Convert HTML content to plain text
  String _htmlToText(String? html) {
    if (html == null || html.isEmpty) {
      return '';
    }

    try {
      final document = html_parser.parse(html);
      final body = document.body;
      if (body == null) return '';

      // Remove script and style elements
      for (final script in body.querySelectorAll('script, style')) {
        script.remove();
      }

      // Extract text with proper paragraph handling
      final buffer = StringBuffer();
      _extractTextFromNode(body, buffer);

      return buffer.toString().trim();
    } catch (e) {
      AppLogger.error('Failed to parse HTML', e);
      return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    }
  }

  /// Recursively extract text from HTML nodes
  void _extractTextFromNode(html_dom.Node node, StringBuffer buffer) {
    if (node.nodeType == html_dom.Node.TEXT_NODE) {
      final text = node.text?.trim();
      if (text != null && text.isNotEmpty) {
        if (buffer.isNotEmpty && !buffer.toString().endsWith('\n')) {
          buffer.write('\n');
        }
        buffer.write(text);
      }
    } else if (node.nodeType == html_dom.Node.ELEMENT_NODE) {
      final element = node as html_dom.Element;
      final tagName = element.localName?.toLowerCase();

      // Add newlines for block elements
      if (['p', 'div', 'br', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li'].contains(tagName)) {
        if (buffer.isNotEmpty && !buffer.toString().endsWith('\n')) {
          buffer.write('\n');
        }
      }

      for (final child in element.nodes) {
        _extractTextFromNode(child, buffer);
      }
    }
  }

  /// Save cover image to local storage
  Future<String> _saveCoverImage(Image image) async {
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = p.join(appDir.path, 'covers');
    await Directory(coversDir).create(recursive: true);

    final coverFileName = '${const Uuid().v4()}.jpg';
    final coverPath = p.join(coversDir, coverFileName);

    // Encode image to JPEG bytes using the image package
    final bytes = img.encodeJpg(image);
    await File(coverPath).writeAsBytes(bytes);

    return coverPath;
  }

  /// Clear book cache to free memory
  void clearCache() {
    _bookCache.clear();
  }
}
