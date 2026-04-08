import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:novel_reader/models/chapter.dart';
import 'package:novel_reader/services/parser/book_parser.dart';
import 'package:novel_reader/utils/file_utils.dart';
import 'package:uuid/uuid.dart';

/// Isolate参数类 - 用于字节解码
class _DecodeParams {
  final Uint8List bytes;
  _DecodeParams(this.bytes);
}

/// Isolate参数类 - 用于章节解析
class _ChapterParseParams {
  final String content;
  final String bookId;
  _ChapterParseParams(this.content, this.bookId);
}

/// Isolate参数类 - 用于获取单个章节内容
class _ContentParseParams {
  final String content;
  final int chapterIndex;
  _ContentParseParams(this.content, this.chapterIndex);
}

/// Isolate函数 - 解码字节（不涉及文件IO）
String _decodeBytesInIsolate(_DecodeParams params) {
  // Try UTF-8 first
  try {
    return utf8.decode(params.bytes);
  } catch (e) {
    // Fallback to latin1 (accepts all byte sequences)
    return latin1.decode(params.bytes);
  }
}

/// Isolate函数 - 解析章节
List<Map<String, dynamic>> _parseChaptersInIsolate(_ChapterParseParams params) {
  // Chapter recognition patterns
  final chapterPatterns = [
    RegExp(r'第[一二三四五六七八九十百千万\d]+章\s+.+'), // Chinese chapters
    RegExp(r'Chapter\s+\d+.*', caseSensitive: false), // English chapters
    RegExp(r'卷[一二三四五六七八九十\d]+.*'), // Volumes
  ];
  
  bool isChapterTitle(String line) {
    for (final pattern in chapterPatterns) {
      if (pattern.hasMatch(line)) {
        return true;
      }
    }
    return false;
  }

  final lines = params.content.split('\n');
  final chapters = <Map<String, dynamic>>[];
  final uuid = Uuid();

  int currentChapterStart = 0;
  String? currentChapterTitle;
  int chapterIndex = 0;

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();

    if (isChapterTitle(line)) {
      // Save previous chapter if exists
      if (currentChapterTitle != null) {
        final chapterContent = lines
            .sublist(currentChapterStart, i)
            .join('\n');

        chapters.add({
          'id': uuid.v4(),
          'bookId': params.bookId,
          'index': chapterIndex,
          'title': currentChapterTitle,
          'content': chapterContent,
          'startPosition': currentChapterStart,
          'endPosition': i - 1,
        });

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

    chapters.add({
      'id': uuid.v4(),
      'bookId': params.bookId,
      'index': chapterIndex,
      'title': currentChapterTitle,
      'content': chapterContent,
      'startPosition': currentChapterStart,
      'endPosition': lines.length - 1,
    });
  }

  // If no chapters found, treat entire file as one chapter
  if (chapters.isEmpty) {
    chapters.add({
      'id': uuid.v4(),
      'bookId': params.bookId,
      'index': 0,
      'title': '正文',
      'content': params.content,
      'startPosition': 0,
      'endPosition': lines.length - 1,
    });
  }

  return chapters;
}

/// Isolate函数 - 获取单个章节内容
String _parseContentInIsolate(_ContentParseParams params) {
  // Chapter recognition patterns
  final chapterPatterns = [
    RegExp(r'第[一二三四五六七八九十百千万\d]+章\s+.+'), // Chinese chapters
    RegExp(r'Chapter\s+\d+.*', caseSensitive: false), // English chapters
    RegExp(r'卷[一二三四五六七八九十\d]+.*'), // Volumes
  ];
  
  bool isChapterTitle(String line) {
    for (final pattern in chapterPatterns) {
      if (pattern.hasMatch(line)) {
        return true;
      }
    }
    return false;
  }

  final lines = params.content.split('\n');
  final chapterStarts = <int>[];

  for (int i = 0; i < lines.length; i++) {
    if (isChapterTitle(lines[i].trim())) {
      chapterStarts.add(i);
    }
  }

  if (params.chapterIndex < 0 || params.chapterIndex >= chapterStarts.length) {
    throw RangeError('Invalid chapter index: ${params.chapterIndex}');
  }

  final start = chapterStarts[params.chapterIndex];
  final end = params.chapterIndex + 1 < chapterStarts.length
      ? chapterStarts[params.chapterIndex + 1]
      : lines.length;

  return lines.sublist(start, end).join('\n');
}

class TxtParser implements BookParser {
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
    // 在主线程异步读取文件字节
    final bytes = await File(filePath).readAsBytes();
    
    // 使用Isolate解码字节
    final content = await compute(_decodeBytesInIsolate, _DecodeParams(bytes));
    
    // 使用Isolate解析章节
    final chapterMaps = await compute(_parseChaptersInIsolate, _ChapterParseParams(content, bookId));
    
    // 将Map转换为Chapter对象
    return chapterMaps.map((map) => Chapter.fromMap(map)).toList();
  }

  @override
  Future<String> parseContent(String filePath, int chapterIndex) async {
    // 在主线程异步读取文件字节
    final bytes = await File(filePath).readAsBytes();
    
    // 使用Isolate解码字节
    final content = await compute(_decodeBytesInIsolate, _DecodeParams(bytes));
    
    // 使用Isolate解析单个章节内容
    return await compute(_parseContentInIsolate, _ContentParseParams(content, chapterIndex));
  }

  @override
  Future<String?> extractCover(String filePath) async {
    // TXT files don't have covers
    return null;
  }
}
