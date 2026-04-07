class Bookmark {
  final String id;
  final String bookId;
  final int chapterIndex;
  final double position;
  final String? note;
  final DateTime createTime;

  Bookmark({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.position,
    this.note,
    required this.createTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter_index': chapterIndex,
      'position': position,
      'note': note,
      'create_time': createTime.millisecondsSinceEpoch,
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      chapterIndex: map['chapter_index'] as int,
      position: (map['position'] as num).toDouble(),
      note: map['note'] as String?,
      createTime: DateTime.fromMillisecondsSinceEpoch(map['create_time'] as int),
    );
  }
}
