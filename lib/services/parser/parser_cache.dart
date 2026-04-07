import 'dart:collection';

class ParserCache {
  final int maxSize;
  final LinkedHashMap<String, String> _chapterCache;
  final Map<String, dynamic> _metadataCache = {};

  ParserCache({this.maxSize = 50})
      : _chapterCache = LinkedHashMap<String, String>();

  Future<void> putChapter(String key, String content) async {
    if (_chapterCache.containsKey(key)) {
      _chapterCache.remove(key);
    }
    _chapterCache[key] = content;
    if (_chapterCache.length > maxSize) {
      _chapterCache.remove(_chapterCache.keys.first);
    }
  }

  Future<String?> getChapter(String key) async {
    final content = _chapterCache[key];
    if (content != null) {
      _chapterCache.remove(key);
      _chapterCache[key] = content;
    }
    return content;
  }

  void putMetadata(String key, dynamic metadata) {
    _metadataCache[key] = metadata;
  }

  T? getMetadata<T>(String key) {
    return _metadataCache[key] as T?;
  }

  Future<void> clear() async {
    _chapterCache.clear();
    _metadataCache.clear();
  }

  int get size => _chapterCache.length;
}
