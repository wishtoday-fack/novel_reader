import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:novel_reader/models/book.dart';
import 'package:novel_reader/models/chapter.dart';
import 'package:novel_reader/models/read_progress.dart';
import 'package:novel_reader/models/bookmark.dart';
import 'package:novel_reader/models/reading_stats.dart';
import 'package:novel_reader/utils/constants.dart';

class DatabaseService {
  Database? _database;

  Database get database {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _database!;
  }

  Future<void> initialize() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, AppConstants.databaseName);

    _database = await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT,
        cover_path TEXT,
        file_path TEXT NOT NULL,
        format TEXT NOT NULL,
        file_size INTEGER,
        add_time INTEGER,
        update_time INTEGER,
        description TEXT,
        total_chapters INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE read_progress (
        book_id TEXT PRIMARY KEY,
        current_chapter INTEGER,
        current_page INTEGER,
        position REAL,
        last_read_time INTEGER,
        total_read_time INTEGER,
        FOREIGN KEY (book_id) REFERENCES books(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE chapters (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        chapter_index INTEGER NOT NULL,
        title TEXT,
        content TEXT,
        start_position INTEGER,
        end_position INTEGER,
        FOREIGN KEY (book_id) REFERENCES books(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE bookmarks (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        chapter_index INTEGER,
        position REAL,
        note TEXT,
        create_time INTEGER,
        FOREIGN KEY (book_id) REFERENCES books(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE reading_stats (
        id TEXT PRIMARY KEY,
        book_id TEXT,
        date INTEGER,
        read_duration INTEGER,
        pages_read INTEGER,
        FOREIGN KEY (book_id) REFERENCES books(id)
      )
    ''');

    await db.execute('CREATE INDEX idx_books_add_time ON books(add_time)');
    await db.execute('CREATE INDEX idx_read_progress_last_read ON read_progress(last_read_time)');
    await db.execute('CREATE INDEX idx_chapters_book_id ON chapters(book_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle migrations
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  // Book operations
  Future<void> insertBook(Book book) async {
    await database.insert('books', book.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Book?> getBook(String id) async {
    final maps = await database.query('books', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Book.fromMap(maps.first);
  }

  Future<List<Book>> getAllBooks() async {
    final maps = await database.query('books', orderBy: 'add_time DESC');
    return maps.map((map) => Book.fromMap(map)).toList();
  }

  Future<void> updateBook(Book book) async {
    await database.update('books', book.toMap(),
        where: 'id = ?', whereArgs: [book.id]);
  }

  Future<void> deleteBook(String id) async {
    await database.transaction((txn) async {
      await txn.delete('read_progress', where: 'book_id = ?', whereArgs: [id]);
      await txn.delete('chapters', where: 'book_id = ?', whereArgs: [id]);
      await txn.delete('bookmarks', where: 'book_id = ?', whereArgs: [id]);
      await txn.delete('reading_stats', where: 'book_id = ?', whereArgs: [id]);
      await txn.delete('books', where: 'id = ?', whereArgs: [id]);
    });
  }

  // Read progress operations
  Future<void> saveReadProgress(ReadProgress progress) async {
    await database.insert('read_progress', progress.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ReadProgress?> getReadProgress(String bookId) async {
    final maps = await database.query('read_progress',
        where: 'book_id = ?', whereArgs: [bookId]);
    if (maps.isEmpty) return null;
    return ReadProgress.fromMap(maps.first);
  }

  // Chapter operations
  Future<void> insertChapters(List<Chapter> chapters) async {
    final batch = database.batch();
    for (final chapter in chapters) {
      batch.insert('chapters', chapter.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Chapter>> getChapters(String bookId) async {
    final maps = await database.query('chapters',
        where: 'book_id = ?', whereArgs: [bookId], orderBy: 'chapter_index ASC');
    return maps.map((map) => Chapter.fromMap(map)).toList();
  }

  // Bookmark operations
  Future<void> insertBookmark(Bookmark bookmark) async {
    await database.insert('bookmarks', bookmark.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Bookmark>> getBookmarks(String bookId) async {
    final maps = await database.query('bookmarks',
        where: 'book_id = ?', whereArgs: [bookId], orderBy: 'create_time DESC');
    return maps.map((map) => Bookmark.fromMap(map)).toList();
  }

  Future<void> deleteBookmark(String id) async {
    await database.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  // Reading stats operations
  Future<void> insertReadingStats(ReadingStats stats) async {
    await database.insert('reading_stats', stats.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ReadingStats>> getReadingStats(String bookId) async {
    final maps = await database.query('reading_stats',
        where: 'book_id = ?', whereArgs: [bookId], orderBy: 'date DESC');
    return maps.map((map) => ReadingStats.fromMap(map)).toList();
  }
}
