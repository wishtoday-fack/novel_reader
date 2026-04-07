import 'book_format.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String? coverPath;
  final String filePath;
  final BookFormat format;
  final int fileSize;
  final DateTime addTime;
  final DateTime updateTime;
  final String? description;
  final int totalChapters;

  Book({
    required this.id,
    required this.title,
    this.author = '未知作者',
    this.coverPath,
    required this.filePath,
    required this.format,
    required this.fileSize,
    required this.addTime,
    required this.updateTime,
    this.description,
    this.totalChapters = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'cover_path': coverPath,
      'file_path': filePath,
      'format': format.name,
      'file_size': fileSize,
      'add_time': addTime.millisecondsSinceEpoch,
      'update_time': updateTime.millisecondsSinceEpoch,
      'description': description,
      'total_chapters': totalChapters,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String? ?? '未知作者',
      coverPath: map['cover_path'] as String?,
      filePath: map['file_path'] as String,
      format: BookFormat.values.firstWhere((e) => e.name == map['format']),
      fileSize: map['file_size'] as int,
      addTime: DateTime.fromMillisecondsSinceEpoch(map['add_time'] as int),
      updateTime: DateTime.fromMillisecondsSinceEpoch(map['update_time'] as int),
      description: map['description'] as String?,
      totalChapters: map['total_chapters'] as int? ?? 0,
    );
  }

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? coverPath,
    String? filePath,
    BookFormat? format,
    int? fileSize,
    DateTime? addTime,
    DateTime? updateTime,
    String? description,
    int? totalChapters,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverPath: coverPath ?? this.coverPath,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      fileSize: fileSize ?? this.fileSize,
      addTime: addTime ?? this.addTime,
      updateTime: updateTime ?? this.updateTime,
      description: description ?? this.description,
      totalChapters: totalChapters ?? this.totalChapters,
    );
  }
}
