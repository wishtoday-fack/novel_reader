import 'dart:io';
import 'dart:typed_data';
import 'package:pdfx/pdfx.dart';
import 'package:novel_reader/models/chapter.dart';
import 'package:novel_reader/services/parser/book_parser.dart';
import 'package:novel_reader/utils/file_utils.dart';
import 'package:novel_reader/utils/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// PDF format parser using pdfx library
/// PDF files are treated as page-based documents where each page is a chapter
class PdfParser implements BookParser {
  /// Cache for opened PDF documents
  final Map<String, PdfDocument> _documentCache = {};

  @override
  Future<BookInfo> parseMetadata(String filePath) async {
    final document = await _openDocument(filePath);

    return BookInfo(
      title: FileUtils.extractFileName(filePath),
      totalChapters: document.pagesCount,
    );
  }

  @override
  Future<List<Chapter>> parseChapters(String filePath, String bookId) async {
    final document = await _openDocument(filePath);
    final chapters = <Chapter>[];

    for (int i = 0; i < document.pagesCount; i++) {
      chapters.add(Chapter(
        id: const Uuid().v4(),
        bookId: bookId,
        index: i,
        title: '第 ${i + 1} 页',
      ));
    }

    return chapters;
  }

  @override
  Future<String> parseContent(String filePath, int chapterIndex) async {
    final document = await _openDocument(filePath);

    if (chapterIndex < 0 || chapterIndex >= document.pagesCount) {
      throw RangeError('Invalid page index: $chapterIndex');
    }

    // PDF text extraction is limited in pdfx
    // We return a placeholder indicating this is a page-based document
    // Real content extraction would require additional libraries or OCR
    return '第 ${chapterIndex + 1} 页内容\n\n'
        'PDF文档按页显示，请在阅读器中查看实际页面内容。\n'
        '提示：PDF文件以图片形式渲染，文本提取功能有限。';
  }

  @override
  Future<String?> extractCover(String filePath) async {
    try {
      final document = await _openDocument(filePath);

      // Get first page as cover
      final page = await document.getPage(1);

      // Render page to image
      final pageImage = await page.render(
        width: page.width * 2, // 2x resolution for better quality
        height: page.height * 2,
        format: PdfPageImageFormat.jpeg,
        quality: 90,
      );

      await page.close();

      if (pageImage != null) {
        return await _saveCoverImage(pageImage.bytes);
      }

      return null;
    } catch (e) {
      AppLogger.error('Failed to extract PDF cover', e);
      return null;
    }
  }

  /// Open and cache a PDF document
  Future<PdfDocument> _openDocument(String filePath) async {
    if (_documentCache.containsKey(filePath)) {
      return _documentCache[filePath]!;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('PDF file not found', filePath);
    }

    final document = await PdfDocument.openFile(filePath);
    _documentCache[filePath] = document;
    return document;
  }

  /// Save cover image to local storage
  Future<String> _saveCoverImage(Uint8List bytes) async {
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = p.join(appDir.path, 'covers');
    await Directory(coversDir).create(recursive: true);

    final coverFileName = '${const Uuid().v4()}.jpg';
    final coverPath = p.join(coversDir, coverFileName);

    await File(coverPath).writeAsBytes(bytes);
    return coverPath;
  }

  /// Clear document cache to free memory
  void clearCache() async {
    for (final doc in _documentCache.values) {
      await doc.close();
    }
    _documentCache.clear();
  }
}
