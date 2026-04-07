import 'dart:io';
import 'package:novel_reader/models/book.dart';
import 'package:novel_reader/models/chapter.dart';
import 'package:novel_reader/models/read_progress.dart';
import 'package:novel_reader/models/bookmark.dart';
import 'package:novel_reader/services/database_service.dart';
import 'package:novel_reader/services/parser_service.dart';
import 'package:novel_reader/utils/logger.dart';

class BookRepository {
  final DatabaseService _db;
  final BookParserService _parser;

  BookRepository({required DatabaseService databaseService, required BookParserService parserService})
      : _db = databaseService, _parser = parserService;

  Future<List<Book>> getAllBooks() => _db.getAllBooks();
  Future<Book?> getBook(String id) => _db.getBook(id);

  Future<Book?> importBook(String filePath) async {
    try {
      // Validate file path
      if (filePath.isEmpty) {
        AppLogger.error('Empty file path provided');
        return null;
      }
      
      final file = File(filePath);
      if (!await file.exists()) {
        AppLogger.error('File does not exist: $filePath');
        return null;
      }
      
      final book = await _parser.parseBook(filePath);
      final existing = await _db.getBook(book.id);
      if (existing != null) return existing;

      await _db.insertBook(book);
      final chapters = await _parser.parseChapters(filePath, book.id);
      await _db.insertChapters(chapters);

      final updated = book.copyWith(totalChapters: chapters.length);
      await _db.updateBook(updated);
      return updated;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to import book', e, stackTrace);
      return null;
    }
  }

  Future<bool> deleteBook(String id) async {
    try { 
      await _db.deleteBook(id); 
      return true; 
    } catch (e) { 
      AppLogger.error('Failed to delete book', e); 
      return false; 
    }
  }

  Future<List<Chapter>> getChapters(String bookId) => _db.getChapters(bookId);
  Future<ReadProgress?> getReadProgress(String bookId) => _db.getReadProgress(bookId);
  Future<void> saveReadProgress(ReadProgress progress) => _db.saveReadProgress(progress);
  Future<List<Bookmark>> getBookmarks(String bookId) => _db.getBookmarks(bookId);
  Future<void> addBookmark(Bookmark bookmark) => _db.insertBookmark(bookmark);
  Future<void> deleteBookmark(String id) => _db.deleteBookmark(id);
}
