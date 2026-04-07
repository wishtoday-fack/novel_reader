import 'package:flutter/foundation.dart';
import 'package:novel_reader/models/book.dart';
import 'package:novel_reader/models/read_progress.dart';
import 'package:novel_reader/repositories/book_repository.dart';
import 'package:novel_reader/services/file_service.dart';
import 'package:novel_reader/utils/logger.dart';

enum SortBy { lastRead, title, addTime, author }
enum ViewMode { grid, list }

class BookshelfProvider extends ChangeNotifier {
  final BookRepository _repo;
  final FileService _fileService;

  List<Book> _books = [];
  bool _isLoading = false;
  String? _error;
  SortBy _sortBy = SortBy.lastRead;
  ViewMode _viewMode = ViewMode.grid;
  String _searchQuery = '';

  BookshelfProvider({required BookRepository bookRepository, required FileService fileService})
      : _repo = bookRepository, _fileService = fileService;

  List<Book> get books => _filterAndSort();
  bool get isLoading => _isLoading;
  String? get error => _error;
  SortBy get sortBy => _sortBy;
  ViewMode get viewMode => _viewMode;

  Future<void> loadBooks() async {
    _isLoading = true; 
    notifyListeners();
    try {
      _books = await _repo.getAllBooks();
      _error = null;
    } catch (e) {
      _error = '加载书籍失败: $e';
      AppLogger.error('Load books failed', e);
    }
    _isLoading = false; 
    notifyListeners();
  }

  Future<Book?> importBook() async {
    final path = await _fileService.pickSingleFile();
    if (path == null) return null;
    _isLoading = true; 
    notifyListeners();
    final book = await _repo.importBook(path);
    if (book != null) {
      _books.insert(0, book);
    }
    _isLoading = false; 
    notifyListeners();
    return book;
  }

  Future<List<Book>> importBooks() async {
    final paths = await _fileService.pickMultipleFiles();
    if (paths.isEmpty) return [];
    _isLoading = true; 
    notifyListeners();
    for (final p in paths) { 
      await _repo.importBook(p); 
    }
    await loadBooks();
    return books;
  }

  Future<bool> deleteBook(String id) async {
    final ok = await _repo.deleteBook(id);
    if (ok) { 
      _books.removeWhere((b) => b.id == id); 
      notifyListeners(); 
    }
    return ok;
  }

  void setSortBy(SortBy s) { 
    _sortBy = s; 
    notifyListeners(); 
  }
  
  void setViewMode(ViewMode m) { 
    _viewMode = m; 
    notifyListeners(); 
  }
  
  void setSearchQuery(String q) { 
    _searchQuery = q; 
    notifyListeners(); 
  }
  
  Future<ReadProgress?> getReadProgress(String id) => _repo.getReadProgress(id);

  List<Book> _filterAndSort() {
    var list = _searchQuery.isEmpty 
        ? _books 
        : _books.where((b) =>
            b.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            b.author.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    switch (_sortBy) {
      case SortBy.lastRead: 
        list.sort((a, b) => b.updateTime.compareTo(a.updateTime)); 
        break;
      case SortBy.title: 
        list.sort((a, b) => a.title.compareTo(b.title)); 
        break;
      case SortBy.addTime: 
        list.sort((a, b) => b.addTime.compareTo(a.addTime)); 
        break;
      case SortBy.author: 
        list.sort((a, b) => a.author.compareTo(b.author)); 
        break;
    }
    return list;
  }
}
