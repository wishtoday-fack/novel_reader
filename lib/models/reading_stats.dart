class ReadingStats {
  final String id;
  final String bookId;
  final DateTime date;
  final int readDuration; // minutes
  final int pagesRead;

  ReadingStats({
    required this.id,
    required this.bookId,
    required this.date,
    required this.readDuration,
    required this.pagesRead,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'date': date.millisecondsSinceEpoch,
      'read_duration': readDuration,
      'pages_read': pagesRead,
    };
  }

  factory ReadingStats.fromMap(Map<String, dynamic> map) {
    return ReadingStats(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      readDuration: map['read_duration'] as int,
      pagesRead: map['pages_read'] as int,
    );
  }
}
