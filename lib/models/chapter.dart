class Chapter {
  final String id;
  final String bookId;
  final int index;
  final String title;
  final String? content;
  final int startPosition;
  final int endPosition;

  Chapter({
    required this.id,
    required this.bookId,
    required this.index,
    required this.title,
    this.content,
    this.startPosition = 0,
    this.endPosition = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'chapter_index': index,
      'title': title,
      'content': content,
      'start_position': startPosition,
      'end_position': endPosition,
    };
  }

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      index: map['chapter_index'] as int,
      title: map['title'] as String,
      content: map['content'] as String?,
      startPosition: map['start_position'] as int? ?? 0,
      endPosition: map['end_position'] as int? ?? 0,
    );
  }
}
