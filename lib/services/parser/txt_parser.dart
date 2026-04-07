import 'dart:io';
import 'dart:convert';
import 'package:novel_reader/models/chapter.dart';
import 'package:novel_reader/services/parser/book_parser.dart';
import 'package:novel_reader/utils/file_utils.dart';
import 'package:uuid/uuid.dart';

class TxtParser implements BookParser {
  // Chapter recognition patterns
  static final List<RegExp> _chapterPatterns = [
    RegExp(r'第[一二三四五六七八九十百千万\d]+章\s+.+'), // Chinese chapters
    RegExp(r'Chapter\s+\d+.*', caseSensitive: false), // English chapters
    RegExp(r'卷[一二三四五六七八九十\d]+.*'), // Volumes
  ];

  @override
  Future<BookInfo> parseMetadata(String filePath) async {
    final fileName = FileUtils.extractFileName(filePath);
    final chapters = await parseChapters(filePath, 'temp');

    return BookInfo(
      title: fileName,
      totalChapters: chapters.length,
    );
  }

  @override
  Future<List<Chapter>> parseChapters(String filePath, String bookId) async {
    final content = await _readFileWithEncoding(filePath);

    final chapters = <Chapter>[];
    final lines = content.split('\n');

    int currentChapterStart = 0;
    String? currentChapterTitle;
    int chapterIndex = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (_isChapterTitle(line)) {
        // Save previous chapter if exists
        if (currentChapterTitle != null) {
          final chapterContent = lines
              .sublist(currentChapterStart, i)
              .join('\n');

          chapters.add(Chapter(
            id: const Uuid().v4(),
            bookId: bookId,
            index: chapterIndex,
            title: currentChapterTitle,
            content: chapterContent,
            startPosition: currentChapterStart,
            endPosition: i - 1,
          ));

          chapterIndex++;
        }

        currentChapterTitle = line;
        currentChapterStart = i;
      }
    }

    // Add last chapter
    if (currentChapterTitle != null) {
      final chapterContent = lines
          .sublist(currentChapterStart)
          .join('\n');

      chapters.add(Chapter(
        id: const Uuid().v4(),
        bookId: bookId,
        index: chapterIndex,
        title: currentChapterTitle,
        content: chapterContent,
        startPosition: currentChapterStart,
        endPosition: lines.length - 1,
      ));
    }

    // If no chapters found, treat entire file as one chapter
    if (chapters.isEmpty) {
      chapters.add(Chapter(
        id: const Uuid().v4(),
        bookId: bookId,
        index: 0,
        title: '正文',
        content: content,
      ));
    }

    return chapters;
  }

  @override
  Future<String> parseContent(String filePath, int chapterIndex) async {
    final content = await _readFileWithEncoding(filePath);

    final lines = content.split('\n');
    final chapterStarts = <int>[];
    final chapterTitles = <String>[];

    for (int i = 0; i < lines.length; i++) {
      if (_isChapterTitle(lines[i].trim())) {
        chapterStarts.add(i);
        chapterTitles.add(lines[i].trim());
      }
    }

    if (chapterIndex < 0 || chapterIndex >= chapterStarts.length) {
      throw RangeError('Invalid chapter index: $chapterIndex');
    }

    final start = chapterStarts[chapterIndex];
    final end = chapterIndex + 1 < chapterStarts.length
        ? chapterStarts[chapterIndex + 1]
        : lines.length;

    return lines.sublist(start, end).join('\n');
  }

  @override
  Future<String?> extractCover(String filePath) async {
    // TXT files don't have covers
    return null;
  }

  /// Read file with automatic encoding detection
  Future<String> _readFileWithEncoding(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    
    // Try UTF-8 first
    try {
      return utf8.decode(bytes);
    } catch (e) {
      // Fallback to latin1 (accepts all byte sequences)
      return latin1.decode(bytes);
    }
  }

  /// Check if line is a chapter title
  bool _isChapterTitle(String line) {
    for (final pattern in _chapterPatterns) {
      if (pattern.hasMatch(line)) {
        return true;
      }
    }
    return false;
  }
}
