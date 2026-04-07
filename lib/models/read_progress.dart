class ReadProgress {
  final String bookId;
  final int currentChapter;
  final int currentPage;
  final double position;
  final DateTime lastReadTime;
  final int totalReadTime; // minutes

  ReadProgress({
    required this.bookId,
    this.currentChapter = 0,
    this.currentPage = 0,
    this.position = 0.0,
    required this.lastReadTime,
    this.totalReadTime = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'book_id': bookId,
      'current_chapter': currentChapter,
      'current_page': currentPage,
      'position': position,
      'last_read_time': lastReadTime.millisecondsSinceEpoch,
      'total_read_time': totalReadTime,
    };
  }

  factory ReadProgress.fromMap(Map<String, dynamic> map) {
    return ReadProgress(
      bookId: map['book_id'] as String,
      currentChapter: map['current_chapter'] as int? ?? 0,
      currentPage: map['current_page'] as int? ?? 0,
      position: (map['position'] as num?)?.toDouble() ?? 0.0,
      lastReadTime: DateTime.fromMillisecondsSinceEpoch(map['last_read_time'] as int),
      totalReadTime: map['total_read_time'] as int? ?? 0,
    );
  }

  ReadProgress copyWith({
    String? bookId,
    int? currentChapter,
    int? currentPage,
    double? position,
    DateTime? lastReadTime,
    int? totalReadTime,
  }) {
    return ReadProgress(
      bookId: bookId ?? this.bookId,
      currentChapter: currentChapter ?? this.currentChapter,
      currentPage: currentPage ?? this.currentPage,
      position: position ?? this.position,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      totalReadTime: totalReadTime ?? this.totalReadTime,
    );
  }
}
