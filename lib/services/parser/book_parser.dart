import 'package:novel_reader/models/chapter.dart';

class BookInfo {
  final String title;
  final String? author;
  final String? description;
  final int totalChapters;

  BookInfo({
    required this.title,
    this.author,
    this.description,
    this.totalChapters = 0,
  });
}

abstract class BookParser {
  Future<BookInfo> parseMetadata(String filePath);
  Future<List<Chapter>> parseChapters(String filePath, String bookId);
  Future<String> parseContent(String filePath, int chapterIndex);
  Future<String?> extractCover(String filePath);
}
