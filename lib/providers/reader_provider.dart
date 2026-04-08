import 'dart:async';
import 'package:flutter/material.dart';
import 'package:novel_reader/models/book.dart';
import 'package:novel_reader/models/chapter.dart';
import 'package:novel_reader/models/read_progress.dart';
import 'package:novel_reader/repositories/book_repository.dart';
import 'package:novel_reader/services/parser_service.dart';
import 'package:novel_reader/utils/logger.dart';

/// 章节内容缓存项
class ChapterContent {
  final int index;
  final String title;
  final String content;
  final int contentLength; // 内容字符数，用于进度计算
  bool isLoading;
  DateTime lastAccessTime;

  ChapterContent({
    required this.index,
    required this.title,
    required this.content,
    this.isLoading = false,
    DateTime? lastAccessTime,
  })  : contentLength = content.length,
        lastAccessTime = lastAccessTime ?? DateTime.now();
}

/// 章节位置追踪器
class ChapterPositionTracker {
  final int chapterIndex;
  final GlobalKey key;
  
  ChapterPositionTracker({required this.chapterIndex}) : key = GlobalKey();
  
  /// 获取章节的实际渲染高度
  double? get height {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size.height;
  }
  
  /// 获取章节在列表中的起始偏移（相对于列表顶部）
  /// 需要传入 ScrollController 来计算
  double? getTopOffset(ScrollController scrollController) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    
    // 获取相对于视口的位置
    try {
      final offset = renderBox.localToGlobal(Offset.zero);
      // 计算相对于列表顶部的偏移
      return scrollController.offset + offset.dy;
    } catch (e) {
      return null;
    }
  }
}

/// 阅读进度信息
class ReadingProgressInfo {
  final int chapterIndex;
  final double chapterPosition; // 章节内位置 (0-1)
  final double overallProgress; // 总体进度 (0-100)
  final int currentWordCount; // 当前位置已读字数
  final int totalWordCount; // 总字数

  const ReadingProgressInfo({
    required this.chapterIndex,
    required this.chapterPosition,
    required this.overallProgress,
    required this.currentWordCount,
    required this.totalWordCount,
  });
}

class ReaderProvider extends ChangeNotifier {
  final BookRepository _repo;
  final BookParserService _parser;
  final String bookId;

  Book? _book;
  List<Chapter> _chapters = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _menuVisible = false;
  bool _settingsVisible = false;
  String? _error;
  
  // 章节内位置 (0-1)，用于保存和恢复
  double _chapterPosition = 0.0;
  
  // 当前滚动偏移（像素）
  double _scrollOffset = 0.0;

  // 连续滚动模式：缓存已加载的章节
  final Map<int, ChapterContent> _loadedChapters = {};
  
  // 章节位置追踪器
  final Map<int, ChapterPositionTracker> _chapterTrackers = {};
  
  // 章节渲染高度缓存（避免频繁调用 findRenderObject）
  final Map<int, double> _chapterHeights = {};
  
  final int _preloadAhead = 2; // 预加载后面几章
  final int _preloadBehind = 1; // 预加载前面几章

  // 内存管理：最大缓存的章节数
  final int _maxCachedChapters = 10;

  // 阅读模式：true = 连续滚动, false = 单章模式
  bool _continuousMode = true;

  // 阅读配置，用于高度估算
  double _fontSize = 18.0;
  double _lineSpacing = 1.8;
  double? _maxWidth;

  // 精确进度追踪
  int _totalWordCount = 0; // 总字数

  // 等待跳转的章节索引（用于跳转到指定章节）
  int? _pendingJumpChapter;
  
  // 等待恢复的章节位置（用于初始加载和跳转）
  double? _pendingChapterPosition;
  
  // 滚动防抖定时器
  Timer? _scrollDebounceTimer;
  
  // 是否正在加载新章节（用于避免加载时更新章节索引）
  bool _isLoadingNewChapter = false;

  ReaderProvider(
      {required BookRepository bookRepository, required BookParserService parserService, required this.bookId})
      : _repo = bookRepository,
        _parser = parserService;

  // Getters
  Book? get book => _book;

  List<Chapter> get chapters => _chapters;

  int get currentIndex => _currentIndex;

  bool get loading => _loading;

  bool get menuVisible => _menuVisible;

  bool get settingsVisible => _settingsVisible;

  bool get hasPrevious => _currentIndex > 0;

  bool get hasNext => _currentIndex < _chapters.length - 1;

  String? get error => _error;

  double get position => _chapterPosition;
  
  double get scrollOffset => _scrollOffset;

  bool get continuousMode => _continuousMode;

  int? get pendingJumpChapter => _pendingJumpChapter;
  
  double? get pendingChapterPosition => _pendingChapterPosition;

  Chapter? get currentChapter =>
      _chapters.isNotEmpty && _currentIndex < _chapters.length ? _chapters[_currentIndex] : null;

  /// 获取已加载的章节列表（按顺序）
  List<ChapterContent> get loadedChaptersList {
    if (_loadedChapters.isEmpty) return [];
    final indices = _loadedChapters.keys.toList()..sort();
    return indices.map((i) => _loadedChapters[i]!).toList();
  }
  
  /// 获取章节的 GlobalKey
  GlobalKey getChapterKey(int index) {
    return _chapterTrackers.putIfAbsent(
      index,
      () => ChapterPositionTracker(chapterIndex: index),
    ).key;
  }

  /// 获取精确的章节高度（基于 TextPainter）
  double calculatePreciseChapterHeight(
    ChapterContent chapter, 
    double maxWidth, 
    {double? fontSize, 
    double? lineSpacing,
    bool? isLastChapter}
  ) {
    final fs = fontSize ?? _fontSize;
    final ls = lineSpacing ?? _lineSpacing;
    final isLast = isLastChapter ?? (chapter.index >= _chapters.length - 1);
    
    // 1. 标题测量 (左右 padding 20*2 = 40)
    final titlePainter = TextPainter(
      text: TextSpan(
        text: chapter.title,
        style: TextStyle(
          fontSize: fs + 6,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    titlePainter.layout(maxWidth: maxWidth);
    
    // 2. 正文测量
    final contentPainter = TextPainter(
      text: TextSpan(
        text: chapter.content,
        style: TextStyle(
          fontSize: fs,
          height: ls,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    contentPainter.layout(maxWidth: maxWidth);
    
    // 3. 计算各个部分的高度和
    // padding top 16 + title + gap 28 + content + gap 40 + [divider + gap 32] + padding bottom 16
    double totalHeight = 16.0; // Top container padding
    totalHeight += titlePainter.height;
    totalHeight += 28.0; // Gap between title and content
    
    if (chapter.isLoading) {
      totalHeight += 80.0; // Center CircularProgressIndicator padding area (40+40)
    } else {
      totalHeight += contentPainter.height;
    }
    
    totalHeight += 40.0; // Gap after content
    
    if (!isLast) {
      // 分隔线区域测量
      final dividerPainter = TextPainter(
        text: TextSpan(
          text: '第 ${chapter.index + 2} 章',
          style: const TextStyle(fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      );
      dividerPainter.layout(maxWidth: maxWidth);
      totalHeight += dividerPainter.height;
      totalHeight += 32.0; // Gap after divider
    } else {
      totalHeight += 32.0; // Gap even for last chapter
    }
    
    totalHeight += 16.0; // Bottom container padding
    
    return totalHeight;
  }

  /// 获取章节的高度（尝试精确计算，失败则估算）
  double getChapterHeight(int chapterIndex, {double? fontSize, double? lineSpacing, double? maxWidth}) {
    // 优先从缓存获取
    if (_chapterHeights.containsKey(chapterIndex)) {
      return _chapterHeights[chapterIndex]!;
    }

    final fs = fontSize ?? _fontSize;
    final ls = lineSpacing ?? _lineSpacing;
    final mw = maxWidth ?? _maxWidth;
    
    final chapter = _loadedChapters[chapterIndex];
    if (chapter != null && mw != null) {
      final h = calculatePreciseChapterHeight(
        chapter, 
        mw, 
        fontSize: fs, 
        lineSpacing: ls,
      );
      _chapterHeights[chapterIndex] = h;
      return h;
    }
    
    // 无法精确计算时使用估算
    final charCount = chapter?.contentLength ?? 
        (chapterIndex >= 0 && chapterIndex < _chapters.length ? _chapters[chapterIndex].title.length + 800 : 1000);
    return _estimateChapterHeight(charCount, fs, ls);
  }

  /// 获取章节的预估高度（基于字数估算）
  /// 内部方法，使用默认字体参数
  double _estimateChapterHeight(int charCount, double fontSize, double lineSpacing) {
    // 假设可用宽度，减去左右 padding (20*2 = 40)
    final width = _maxWidth ?? 340.0;
    
    // 在给定字号下，一行大约能容纳的字符数
    final avgCharsPerLine = (width / (fontSize * 0.9)).floorToDouble(); 

    // 每行的高度
    final lineHeight = fontSize * lineSpacing;

    // 估算行数 (考虑段落间距和空行，稍微增加 15% 的行数)
    final lines = (charCount / avgCharsPerLine * 1.15).ceil();

    // 加上标题高度 (约 80) 和各种间距 (16+28+40+32+16 = 132)
    return (lines * lineHeight) + 150;
  }

  /// 获取章节的预估高度（公开方法，供 ReaderScreen 使用）
  /// 增加对 fontSize 的支持
  @Deprecated('Use getChapterHeight instead for better precision')
  double getEstimatedChapterHeight(int charCount, {double fontSize = 18.0}) {
    return _estimateChapterHeight(charCount, fontSize, 1.8);
  }


  /// 获取精确阅读进度
  ReadingProgressInfo get preciseProgress {
    final loadedList = loadedChaptersList;
    if (loadedList.isEmpty || _totalWordCount == 0) {
      return const ReadingProgressInfo(
        chapterIndex: 0,
        chapterPosition: 0,
        overallProgress: 0,
        currentWordCount: 0,
        totalWordCount: 0,
      );
    }

    // 计算当前章节的起始偏移
    int chapterStart = 0;
    for (int i = 0; i < _currentIndex; i++) {
      final chapter = _loadedChapters[i];
      if (chapter != null) {
        chapterStart += chapter.contentLength;
      }
    }

    final currentChapterContent = _loadedChapters[_currentIndex];
    final chapterLength = currentChapterContent?.contentLength ?? 0;
    final chapterPosition = chapterLength > 0 ? _chapterPosition : 0.0;
    final currentWordCount = chapterStart + (chapterLength * chapterPosition).toInt();
    final overallProgress = _totalWordCount > 0 ? (currentWordCount / _totalWordCount * 100) : 0.0;

    return ReadingProgressInfo(
      chapterIndex: _currentIndex,
      chapterPosition: chapterPosition,
      overallProgress: overallProgress,
      currentWordCount: currentWordCount,
      totalWordCount: _totalWordCount,
    );
  }

  Future<void> init(int initialChapter) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _book = await _repo.getBook(bookId);
      if (_book == null) {
        _error = '书籍不存在';
        _loading = false;
        notifyListeners();
        return;
      }

      _chapters = await _repo.getChapters(bookId);
      if (_chapters.isEmpty) {
        _error = '暂无章节';
        _loading = false;
        notifyListeners();
        return;
      }

      // 确定起始章节和位置
      int startChapter = initialChapter;
      double startPosition = 0.0; // 章节内位置
      
      // 始终读取保存的进度，以获取章节内位置
      final progress = await _repo.getReadProgress(bookId);
      
      // 如果传入的 initialChapter 无效，使用保存的章节
      if (startChapter < 0 || startChapter >= _chapters.length) {
        startChapter = progress?.currentChapter ?? 0;
      }
      
      // 如果 initialChapter 与保存的章节一致，使用保存的位置
      if (progress != null && startChapter == progress.currentChapter) {
        startPosition = progress.position;
      }

      _currentIndex = startChapter.clamp(0, _chapters.length - 1);
      _chapterPosition = startPosition;

      // 连续滚动模式：预加载章节
      if (_continuousMode) {
        await _preloadAroundChapter(_currentIndex);
        _calculateTotalWordCount();
        
        // 设置等待恢复的位置
        _pendingChapterPosition = startPosition;
      } else {
        await _loadContent(_currentIndex);
      }
    } catch (e) {
      AppLogger.error('Init failed', e);
      _error = '加载失败: $e';
    }

    _loading = false;
    notifyListeners();
  }
  
  /// 清除等待恢复的位置（由 ReaderScreen 调用）
  void clearPendingChapterPosition() {
    _pendingChapterPosition = null;
  }

  /// 计算总字数
  void _calculateTotalWordCount() {
    _totalWordCount = 0;
    for (final chapter in _loadedChapters.values) {
      _totalWordCount += chapter.contentLength;
    }
  }

  /// 预加载指定章节周围的内容
  Future<void> _preloadAroundChapter(int centerIndex) async {
    if (_book == null) return;

    // 计算需要加载的章节范围
    final startIndex = (centerIndex - _preloadBehind).clamp(0, _chapters.length - 1);
    final endIndex = (centerIndex + _preloadAhead).clamp(0, _chapters.length - 1);

    // 加载范围内的所有章节
    for (int i = startIndex; i <= endIndex; i++) {
      if (!_loadedChapters.containsKey(i)) {
        await _loadChapterToCache(i);
      }
    }

    // 内存管理：清理远离当前阅读位置的章节
    _cleanupOldChapters(centerIndex);
  }

  /// 加载单个章节到缓存
  Future<void> _loadChapterToCache(int index) async {
    if (_book == null || index < 0 || index >= _chapters.length) return;
    if (_loadedChapters.containsKey(index)) return;

    _isLoadingNewChapter = true;
    
    // 标记为正在加载
    _loadedChapters[index] = ChapterContent(
      index: index,
      title: _chapters[index].title,
      content: '',
      isLoading: true,
    );
    notifyListeners();

    try {
      // 直接从数据库读取的章节数据中获取内容，避免重新解析文件
      String content = _chapters[index].content ?? '';
      
      // 如果数据库中没有内容（可能导入时未保存），才从文件解析
      if (content.isEmpty) {
        content = await _parser.getChapterContent(_book!.filePath, index, _book!.format);
      }
      
      _loadedChapters[index] = ChapterContent(
        index: index,
        title: _chapters[index].title,
        content: content,
        isLoading: false,
      );
      // 更新总字数
      _totalWordCount += content.length;
    } catch (e) {
      _loadedChapters[index] = ChapterContent(
        index: index,
        title: _chapters[index].title,
        content: '加载失败',
        isLoading: false,
      );
      AppLogger.error('Load chapter $index failed', e);
    }
    
    _isLoadingNewChapter = false;
    notifyListeners();
  }
  
  /// 异步加载章节（供 ReaderScreen 使用）
  /// 返回是否成功加载了新章节（如果已经加载则返回false）
  Future<bool> loadChapterAsync(int index) async {
    if (_book == null || index < 0 || index >= _chapters.length) return false;
    if (_loadedChapters.containsKey(index)) return false;
    
    await _loadChapterToCache(index);
    return true;
  }

  /// 内存管理：清理旧的章节缓存
  void _cleanupOldChapters(int currentIndex) {
    if (_loadedChapters.length <= _maxCachedChapters) return;

    // 按访问时间排序，保留当前章节附近的章节
    final entries = _loadedChapters.entries.toList();
    entries.sort((a, b) => a.value.lastAccessTime.compareTo(b.value.lastAccessTime));

    // 计算保留范围
    final keepRange = _maxCachedChapters ~/ 2;
    final minKeep = (currentIndex - keepRange).clamp(0, _chapters.length - 1);
    final maxKeep = (currentIndex + keepRange).clamp(0, _chapters.length - 1);

    // 删除最旧的章节，但保留当前阅读范围
    for (final entry in entries) {
      if (_loadedChapters.length <= _maxCachedChapters) break;

      final index = entry.key;
      if (index < minKeep || index > maxKeep) {
        final removed = _loadedChapters.remove(index);
        if (removed != null) {
          _totalWordCount -= removed.contentLength;
        }
        // 同时移除追踪器
        _chapterTrackers.remove(index);
        _chapterHeights.remove(index);
      }
    }
  }

  Future<void> _loadContent(int index) async {
    if (_book == null || index < 0 || index >= _chapters.length) return;

    try {
      // 直接从数据库读取的章节数据中获取内容，避免重新解析文件
      String content = _chapters[index].content ?? '';
      
      // 如果数据库中没有内容（可能导入时未保存），才从文件解析
      if (content.isEmpty) {
        content = await _parser.getChapterContent(_book!.filePath, index, _book!.format);
      }
      
      _loadedChapters[index] = ChapterContent(
        index: index,
        title: _chapters[index].title,
        content: content,
      );
    } catch (e) {
      _loadedChapters[index] = ChapterContent(
        index: index,
        title: _chapters[index].title,
        content: '加载失败',
      );
      AppLogger.error('Load content failed', e);
    }
    notifyListeners();
  }

  /// 滚动到指定章节时调用（用于更新当前章节索引和预加载）
  Future<void> onScrollToChapter(int index) async {
    if (index == _currentIndex) return;

    _currentIndex = index;
    // 预加载周围章节
    await _preloadAroundChapter(index);
    // 保存进度
    await _saveProgress();
    notifyListeners();
  }
  
  /// 更新章节渲染高度缓存
  void updateChapterHeight(int index, double height) {
    if (height > 0) {
      _chapterHeights[index] = height;
    }
  }

  /// 基于像素偏移更新当前章节（核心方法 - 修复章节乱跳问题）
  /// 
  /// [pixelOffset] 当前滚动偏移（像素）
  /// [viewportHeight] 视口高度
  /// [forceUpdate] 是否强制更新（跳过防抖）
  void updateCurrentChapterByPixelOffset(
    double pixelOffset, 
    double viewportHeight, {
    bool forceUpdate = false,
  }) {
    if (_loadedChapters.isEmpty || _isLoadingNewChapter) return;
    
    _scrollOffset = pixelOffset;
    
    // 防抖处理（除非强制更新）
    if (!forceUpdate) {
      _scrollDebounceTimer?.cancel();
      _scrollDebounceTimer = Timer(const Duration(milliseconds: 50), () {
        _doUpdateCurrentChapter(pixelOffset, viewportHeight);
      });
    } else {
      _doUpdateCurrentChapter(pixelOffset, viewportHeight);
    }
  }
  
  void _doUpdateCurrentChapter(double pixelOffset, double viewportHeight) {
    final loadedList = loadedChaptersList;
    if (loadedList.isEmpty) return;
    
    // 当前可见区域的中心点（相对于列表顶部）
    final viewportCenter = pixelOffset + viewportHeight / 2;
    
    // 计算每个章节的位置
    double accumulatedHeight = 0;
    
    for (final chapter in loadedList) {
      // 优先使用缓存的高度，其次使用追踪器获取，最后估算
      double chapterHeight = _chapterHeights[chapter.index] ?? 0;
      
      if (chapterHeight <= 0) {
        final tracker = _chapterTrackers[chapter.index];
        chapterHeight = tracker?.height ?? 0;
        if (chapterHeight > 0) {
          _chapterHeights[chapter.index] = chapterHeight;
        }
      }
      
      // 如果还是获取不到高度，使用高度计算（优先尝试精确测量）
      if (chapterHeight <= 0) {
        chapterHeight = getChapterHeight(chapter.index, fontSize: _fontSize, lineSpacing: _lineSpacing);
      }
      
      // 检查视口中心是否在当前章节内
      if (viewportCenter >= accumulatedHeight && 
          viewportCenter < accumulatedHeight + chapterHeight) {
        // 更新当前章节索引
        if (chapter.index != _currentIndex) {
          _currentIndex = chapter.index;
          notifyListeners();
        }
        // 计算章节内位置（基于实际高度）
        _chapterPosition = ((viewportCenter - accumulatedHeight) / chapterHeight).clamp(0.0, 1.0);
        return;
      }
      
      accumulatedHeight += chapterHeight;
    }
  }

  /// 检查是否需要加载更多章节（基于像素偏移）
  Future<void> checkAndLoadMoreByOffset(
    double pixelOffset,
    double viewportHeight,
    double maxScrollExtent,
  ) async {
    if (_book == null || _chapters.isEmpty) return;

    final loadedList = loadedChaptersList;
    if (loadedList.isEmpty) return;
    
    // 计算滚动进度（用于判断是否接近边界）
    final scrollProgress = maxScrollExtent > 0 ? pixelOffset / maxScrollExtent : 0.0;
    
    // 检查是否需要预加载前面的章节（滚动到接近顶部）
    if (pixelOffset < viewportHeight * 0.5) {
      final firstLoaded = loadedList.first.index;
      if (firstLoaded > 0) {
        // 预加载前面章节
        final targetFirst = (firstLoaded - _preloadBehind - 1).clamp(0, _chapters.length - 1);
        for (int i = firstLoaded - 1; i >= targetFirst && i >= 0; i--) {
          if (!_loadedChapters.containsKey(i)) {
            await _loadChapterToCache(i);
          }
        }
      }
    }

    // 检查是否需要预加载后面的章节（滚动到接近底部）
    if (scrollProgress > 0.7 || pixelOffset > maxScrollExtent - viewportHeight * 0.5) {
      final lastLoaded = loadedList.last.index;
      if (lastLoaded < _chapters.length - 1) {
        final targetLast = (lastLoaded + _preloadAhead + 1).clamp(0, _chapters.length - 1);
        for (int i = lastLoaded + 1; i < _chapters.length && i <= targetLast; i++) {
          if (!_loadedChapters.containsKey(i)) {
            await _loadChapterToCache(i);
          }
        }
      }
    }
  }
  
  /// 只检查并预加载后面的章节（不预加载前面章节，避免滚动位置跳变）
  /// 用于滚动监听器中，防止预加载前面章节导致的offset异常
  Future<void> checkAndLoadMoreBehind(
    double pixelOffset,
    double viewportHeight,
    double maxScrollExtent,
  ) async {
    if (_book == null || _chapters.isEmpty) return;

    final loadedList = loadedChaptersList;
    if (loadedList.isEmpty) return;
    
    // 计算滚动进度
    final scrollProgress = maxScrollExtent > 0 ? pixelOffset / maxScrollExtent : 0.0;
    
    // 只检查是否需要预加载后面的章节（滚动到接近底部）
    // 使用更保守的阈值，避免频繁触发
    if (scrollProgress > 0.8 || pixelOffset > maxScrollExtent - viewportHeight * 0.3) {
      final lastLoaded = loadedList.last.index;
      if (lastLoaded < _chapters.length - 1) {
        // 只预加载1章，减少notifyListeners的影响
        final nextChapter = lastLoaded + 1;
        if (nextChapter < _chapters.length && !_loadedChapters.containsKey(nextChapter)) {
          await _loadChapterToCache(nextChapter);
        }
      }
    }
  }

  /// 检查是否需要加载更多章节（滚动时调用 - 兼容旧接口）
  Future<void> checkAndLoadMore(double scrollProgress) async {
    if (_book == null || _chapters.isEmpty) return;

    final loadedList = loadedChaptersList;
    if (loadedList.isEmpty) return;
    
    // 检查是否需要预加载前面的章节（滚动到接近顶部）
    if (scrollProgress < 0.3) {
      final firstLoaded = loadedList.first.index;
      final targetFirst = (_currentIndex - _preloadBehind - 1).clamp(0, _chapters.length - 1);
      
      if (firstLoaded > targetFirst) {
        for (int i = firstLoaded - 1; i >= targetFirst && i >= 0; i--) {
          if (!_loadedChapters.containsKey(i)) {
            await _loadChapterToCache(i);
          }
        }
      }
    }

    // 检查是否需要预加载后面的章节（滚动到接近底部）
    if (scrollProgress > 0.7) {
      final lastLoaded = loadedList.last.index;
      final targetLast = (_currentIndex + _preloadAhead + 1).clamp(0, _chapters.length - 1);
      
      if (lastLoaded < targetLast) {
        for (int i = lastLoaded + 1; i < _chapters.length && i <= targetLast; i++) {
          if (!_loadedChapters.containsKey(i)) {
            await _loadChapterToCache(i);
          }
        }
      }
    }
  }

  /// 更新滚动位置和进度（精确追踪）- 保留兼容性
  void updateScrollPosition(double scrollProgress, double maxScroll) {
    // 这个方法现在不再用于章节索引更新
    // 章节索引由 updateCurrentChapterByPixelOffset 处理
  }

  /// 跳转到指定章节
  Future<void> goToChapter(int index) async {
    if (index < 0 || index >= _chapters.length) return;

    _loading = true;
    _pendingJumpChapter = index;
    _pendingChapterPosition = 0.0; // 跳转到章节开头
    notifyListeners();

    _currentIndex = index;

    if (_continuousMode) {
      await _preloadAroundChapter(index);
      _calculateTotalWordCount();
    } else {
      await _loadContent(index);
      _chapterPosition = 0.0;
    }
    
    await _saveProgress();

    _loading = false;
    notifyListeners();
  }

  /// 清除跳转标记
  void clearPendingJump() {
    _pendingJumpChapter = null;
  }

  Future<void> previousChapter() async {
    if (hasPrevious) await goToChapter(_currentIndex - 1);
  }

  Future<void> nextChapter() async {
    if (hasNext) await goToChapter(_currentIndex + 1);
  }

  void toggleMenu() {
    _menuVisible = !_menuVisible;
    if (_menuVisible) _settingsVisible = false;
    notifyListeners();
  }

  void hideMenu() {
    if (_menuVisible || _settingsVisible) {
      _menuVisible = false;
      _settingsVisible = false;
      notifyListeners();
    }
  }

  void toggleSettings() {
    _settingsVisible = !_settingsVisible;
    if (_settingsVisible) _menuVisible = false;
    notifyListeners();
  }

  void hideSettings() {
    if (_settingsVisible) {
      _settingsVisible = false;
      notifyListeners();
    }
  }

  /// 更新阅读配置（由 ReaderScreen 调用，同步最新的字体设置）
  void updateSettings({double? fontSize, double? lineSpacing, double? maxWidth}) {
    bool changed = false;
    if (fontSize != null && _fontSize != fontSize) {
      _fontSize = fontSize;
      changed = true;
    }
    if (lineSpacing != null && _lineSpacing != lineSpacing) {
      _lineSpacing = lineSpacing;
      changed = true;
    }
    if (maxWidth != null && _maxWidth != maxWidth) {
      _maxWidth = maxWidth;
      changed = true;
    }
    
    if (changed) {
      // 如果配置改变，旧的高度缓存失效
      _chapterHeights.clear();
      notifyListeners();
    }
  }

  void setPosition(double pos) {
    _chapterPosition = pos.clamp(0.0, 1.0);
  }

  /// 切换阅读模式
  Future<void> toggleContinuousMode() async {
    _continuousMode = !_continuousMode;
    _loadedChapters.clear();
    _chapterTrackers.clear();
    _chapterHeights.clear();
    _totalWordCount = 0;

    if (_continuousMode) {
      await _preloadAroundChapter(_currentIndex);
      _calculateTotalWordCount();
    } else {
      await _loadContent(_currentIndex);
    }

    notifyListeners();
  }

  Future<void> _saveProgress() async {
    if (_book == null) return;

    await _repo.saveReadProgress(
        ReadProgress(
          bookId: bookId, 
          currentChapter: _currentIndex, 
          position: _chapterPosition, // 保存章节内位置
          lastReadTime: DateTime.now()
        )
    );
  }

  Future<void> saveAndExit() async {
    await _saveProgress();
  }

  // 计算总体阅读进度
  double get overallProgress {
    if (_chapters.isEmpty) return 0.0;
    return (_currentIndex + _chapterPosition) / _chapters.length * 100;
  }

  /// 获取章节内容（兼容旧接口）
  String get content {
    final chapterContent = _loadedChapters[_currentIndex];
    return chapterContent?.content ?? '';
  }

  /// 手动释放内存
  void releaseMemory() {
    // 只保留当前章节
    final current = _loadedChapters[_currentIndex];
    _loadedChapters.clear();
    _chapterTrackers.clear();
    _chapterHeights.clear();
    if (current != null) {
      _loadedChapters[_currentIndex] = current;
    }
    notifyListeners();
  }
  
  @override
  void dispose() {
    _scrollDebounceTimer?.cancel();
    super.dispose();
  }
}
