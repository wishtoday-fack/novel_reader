import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:novel_reader/providers/reader_provider.dart';
import 'package:novel_reader/providers/settings_provider.dart';
import 'package:novel_reader/screens/reader/reader_menu_widget.dart';
import 'package:novel_reader/screens/reader/reader_settings_widget.dart';
import 'package:uuid/uuid.dart';
import 'package:novel_reader/models/bookmark.dart';
import 'package:novel_reader/repositories/book_repository.dart';
import 'package:novel_reader/services/parser_service.dart';
import 'package:novel_reader/utils/logger.dart';

class ReaderScreen extends StatefulWidget {
  final String bookId;
  final int initialChapter;
  
  const ReaderScreen({
    super.key, 
    required this.bookId, 
    this.initialChapter = 0
  });
  
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> with WidgetsBindingObserver {
  late ReaderProvider _readerProvider;
  final ScrollController _scrollController = ScrollController();

  bool _isJumping = false;
  int? _lastJumpChapter;

  // 进度恢复状态控制 - 默认不显示遮罩，除非确认需要恢复
  bool _hasRestoredInitialPosition = false;
  bool _isRestoringPosition = false;
  bool _showRestoringOverlay = false;

  // 章节高度缓存
  final Map<int, double> _chapterHeights = {};
  
  bool _isAdjustingOffset = false;
  
  double? _lastFontSize;
  double? _lastLineSpacing;
  double? _lastMaxWidth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _readerProvider = ReaderProvider(
      bookRepository: context.read<BookRepository>(),
      parserService: context.read<BookParserService>(),
      bookId: widget.bookId,
    );
    
    // 初始化完成后检查是否需要显示恢复遮罩
    _readerProvider.init(widget.initialChapter).then((_) {
      if (mounted) {
        if (_readerProvider.pendingChapterPosition != null && _readerProvider.pendingChapterPosition! > 0) {
          setState(() => _showRestoringOverlay = true);
          
          // 安全保底：3秒后如果还在恢复中，强制关闭遮罩，防止卡死
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && _showRestoringOverlay) {
              AppLogger.warning('恢复进度超时，强制关闭遮罩');
              _finishRestoring();
            }
          });
        }
      }
    });

    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsProvider>();
    final contentWidth = MediaQuery.of(context).size.width - 40; // 左右 padding (20*2 = 40)
    
    // 同步设置到 provider，用于高度计算
    _readerProvider.updateSettings(
      fontSize: settings.fontSize,
      lineSpacing: settings.lineSpacing,
      maxWidth: contentWidth,
    );
    
    bool settingsChanged = _lastFontSize != null && 
        (_lastFontSize != settings.fontSize || 
         _lastLineSpacing != settings.lineSpacing ||
         _lastMaxWidth != contentWidth);

    if (settingsChanged) {
      _handleSettingsChanged();
    }
    
    _lastFontSize = settings.fontSize;
    _lastLineSpacing = settings.lineSpacing;
    _lastMaxWidth = contentWidth;
    _updateSystemUI(settings);
  }

  void _updateSystemUI(SettingsProvider settings) {
    final isDark = settings.theme.backgroundColor.computeLuminance() < 0.5;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: settings.theme.backgroundColor,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));
  }

  void _handleSettingsChanged() {
    final currentPos = _readerProvider.preciseProgress;
    _chapterHeights.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _doRestorePosition(_readerProvider, currentPos.chapterPosition, isSmooth: false);
      }
    });
  }

  @override
  void didChangeMetrics() {
    _chapterHeights.clear();
    super.didChangeMetrics();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isJumping || _isRestoringPosition || _isAdjustingOffset) return;

    final pixelOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;
    final maxScrollExtent = _scrollController.position.maxScrollExtent;

    _readerProvider.updateCurrentChapterByPixelOffset(pixelOffset, viewportHeight);

    if (_readerProvider.continuousMode) {
      _checkAndLoadMoreWithOffsetAdjustment(pixelOffset, viewportHeight, maxScrollExtent);
    }
  }
  
  void _checkAndLoadMoreWithOffsetAdjustment(double pixelOffset, double viewportHeight, double maxScrollExtent) {
    final provider = _readerProvider;
    final loadedList = provider.loadedChaptersList;
    if (loadedList.isEmpty) return;
    
    final firstLoaded = loadedList.first.index;
    final lastLoaded = loadedList.last.index;
    
    if (pixelOffset < viewportHeight * 0.8 && firstLoaded > 0) {
      provider.loadChapterAsync(firstLoaded - 1).then((loaded) {
        if (loaded && mounted) _adjustOffsetAfterPreloadBehind(firstLoaded - 1);
      });
    }
    
    final scrollProgress = maxScrollExtent > 0 ? pixelOffset / maxScrollExtent : 0.0;
    if (scrollProgress > 0.7 && lastLoaded < provider.chapters.length - 1) {
      provider.loadChapterAsync(lastLoaded + 1);
    }
  }
  
  void _adjustOffsetAfterPreloadBehind(int newChapterIndex) {
    if (!mounted || !_scrollController.hasClients) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      
      double newChapterHeight = _chapterHeights[newChapterIndex] ?? 0;
      if (newChapterHeight <= 0) {
        final key = _readerProvider.getChapterKey(newChapterIndex);
        final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          newChapterHeight = renderBox.size.height;
          _chapterHeights[newChapterIndex] = newChapterHeight;
        }
      }
      
      if (newChapterHeight > 0) {
        _isAdjustingOffset = true;
        final newOffset = _scrollController.offset + newChapterHeight;
        _scrollController.jumpTo(newOffset.clamp(0.0, _scrollController.position.maxScrollExtent));
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _isAdjustingOffset = false;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _readerProvider.saveAndExit();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _readerProvider,
      child: Consumer2<ReaderProvider, SettingsProvider>(
        builder: (_, provider, settings, __) {
          // 处理加载完成后的首次进度恢复
          if (!provider.loading && !_hasRestoredInitialPosition) {
            _hasRestoredInitialPosition = true;
            final position = provider.pendingChapterPosition ?? 0.0;
            provider.clearPendingChapterPosition();
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _restoreInitialPosition(provider, position);
            });
          }
          
          // 处理手动跳转
          if (provider.pendingJumpChapter != null && provider.pendingJumpChapter != _lastJumpChapter) {
            _lastJumpChapter = provider.pendingJumpChapter;
            final chapterPos = provider.pendingChapterPosition ?? 0.0;
            provider.clearPendingChapterPosition();
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToChapter(provider.pendingJumpChapter!, chapterPos: chapterPos);
              provider.clearPendingJump();
            });
          }
          
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              await provider.saveAndExit();
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: Scaffold(
              backgroundColor: settings.theme.backgroundColor,
              body: Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) => _handleTapDown(details, settings),
                    onHorizontalDragEnd: _handleSwipe,
                    child: provider.loading && provider.loadedChaptersList.isEmpty
                      ? _buildLoadingState(settings)
                      : (provider.continuousMode 
                          ? _buildContinuousContent(provider, settings)
                          : _buildSingleChapterContent(provider, settings)),
                  ),
                  
                  if (_showRestoringOverlay)
                    _buildRestoringOverlay(settings),

                  if (provider.menuVisible)
                    ReaderMenuWidget(
                      title: provider.book?.title ?? '',
                      currentChapter: provider.currentIndex,
                      totalChapters: provider.chapters.length,
                      progress: provider.preciseProgress.overallProgress,
                      onClose: () => provider.hideMenu(),
                      onPrevious: () => provider.previousChapter(),
                      onNext: () => provider.nextChapter(),
                      onShowChapters: () => _showChapters(provider),
                      onShowSettings: () => _showSettings(provider),
                      onAddBookmark: () => _addBookmark(provider),
                      onGoBack: () => _goBack(provider),
                    ),
                  if (provider.settingsVisible)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ReaderSettingsWidget(settings: settings),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(SettingsProvider settings) {
    return Container(
      color: settings.theme.backgroundColor,
      child: Center(
        child: CircularProgressIndicator(color: settings.theme.textColor.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _buildRestoringOverlay(SettingsProvider settings) {
    return Positioned.fill(
      child: Container(
        color: settings.theme.backgroundColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: settings.theme.textColor.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                '正在恢复阅读进度...',
                style: TextStyle(color: settings.theme.textColor.withValues(alpha: 0.6), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _restoreInitialPosition(ReaderProvider provider, double chapterPosition) {
    _isRestoringPosition = true;
    _isJumping = true;
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      _doRestorePosition(provider, chapterPosition);
    });
  }
  
  void _doRestorePosition(ReaderProvider provider, double chapterPosition, {bool isSmooth = false, int retryCount = 0}) {
    if (!mounted) return;

    if (!_scrollController.hasClients) {
      if (retryCount < 10) {
        Future.delayed(const Duration(milliseconds: 50), () {
          _doRestorePosition(provider, chapterPosition, isSmooth: isSmooth, retryCount: retryCount + 1);
        });
      } else {
        _finishRestoring();
      }
      return;
    }
    
    final loadedList = provider.loadedChaptersList;
    if (loadedList.isEmpty) {
      _finishRestoring();
      return;
    }
    
    final viewportHeight = _scrollController.position.viewportDimension;
    int targetListIndex = loadedList.indexWhere((c) => c.index == provider.currentIndex);
    if (targetListIndex < 0) targetListIndex = 0;
    
    // 1. 初次粗略跳转
    double targetPointInList = 0;
    for (int i = 0; i < targetListIndex; i++) {
      targetPointInList += _getChapterHeight(provider, loadedList[i]);
    }
    
    final chapterHeight = _getChapterHeight(provider, loadedList[targetListIndex]);
    targetPointInList += chapterHeight * chapterPosition;
    
    double finalOffset;
    if (chapterPosition == 0) {
      finalOffset = targetPointInList;
    } else {
      finalOffset = targetPointInList - (viewportHeight / 3); // 恢复进度时，稍微靠上一点
    }
    
    finalOffset = finalOffset.clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(finalOffset);
    
    // 2. 二次精准校准：等待一帧使 Widgets 完成布局和测量
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // 尝试获取目标章节的 context
      final targetKey = provider.getChapterKey(provider.currentIndex);
      final targetContext = targetKey.currentContext;
      
      if (targetContext != null) {
        if (chapterPosition == 0) {
          // 如果是跳到开头，直接使用系统 API 确保可见，最准确
          Scrollable.ensureVisible(
            targetContext, 
            alignment: 0.0, 
            duration: isSmooth ? const Duration(milliseconds: 200) : Duration.zero
          ).then((_) => _finishRestoring());
        } else {
          // 如果是跳到中间，根据实际渲染的 RenderBox 重新计算偏移
          final box = targetContext.findRenderObject() as RenderBox?;
          if (box != null) {
            // 获取章节相对于列表顶部的偏移
            double actualTop = 0;
            for (int i = 0; i < targetListIndex; i++) {
              actualTop += _getChapterHeight(provider, loadedList[i]);
            }
            
            double correctedOffset = actualTop + (box.size.height * chapterPosition) - (viewportHeight / 3);
            correctedOffset = correctedOffset.clamp(0.0, _scrollController.position.maxScrollExtent);
            
            if (isSmooth) {
              _scrollController.animateTo(correctedOffset, duration: const Duration(milliseconds: 200), curve: Curves.easeOut)
                  .then((_) => _finishRestoring());
            } else {
              _scrollController.jumpTo(correctedOffset);
              _finishRestoring();
            }
          } else {
            _finishRestoring();
          }
        }
      } else {
        // 如果还是没获取到 context，可能是列表太长还未滑动到可见区域，强制再跳一次
        _scrollController.jumpTo(finalOffset);
        _finishRestoring();
      }
    });
  }

  double _getChapterHeight(ReaderProvider provider, ChapterContent chapter) {
    // 优先从缓存获取
    double h = _chapterHeights[chapter.index] ?? 0;
    if (h <= 0) {
      final key = provider.getChapterKey(chapter.index);
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        h = box.size.height;
        _chapterHeights[chapter.index] = h;
        provider.updateChapterHeight(chapter.index, h);
      }
    }
    
    if (h > 0) return h;
    
    // 如果没有渲染，尝试使用 provider 的精确高度计算（基于 TextPainter）
    final settings = context.read<SettingsProvider>();
    final contentWidth = MediaQuery.of(context).size.width - 40;
    
    return provider.getChapterHeight(
      chapter.index, 
      fontSize: settings.fontSize, 
      lineSpacing: settings.lineSpacing,
      maxWidth: contentWidth,
    );
  }

  void _finishRestoring() {
    if (!mounted) return;
    setState(() {
      _showRestoringOverlay = false;
      _isJumping = false;
      _isRestoringPosition = false;
    });
    
    if (_scrollController.hasClients) {
      _readerProvider.updateCurrentChapterByPixelOffset(
        _scrollController.offset,
        _scrollController.position.viewportDimension,
        forceUpdate: true,
      );
    }
  }
  
  void _scrollToChapter(int chapterIndex, {double chapterPos = 0.0}) {
    if (!_scrollController.hasClients) return;
    _isJumping = true;
    _isRestoringPosition = true;
    _doRestorePosition(_readerProvider, chapterPos, isSmooth: false);
  }

  Widget _buildContinuousContent(ReaderProvider provider, SettingsProvider settings) {
    final chapters = provider.loadedChaptersList;
    if (chapters.isEmpty) return _buildLoadingState(settings);
    
    return SafeArea(
      top: true,
      bottom: true,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildChapterItem(chapters[index], settings, provider),
              childCount: chapters.length,
            ),
          ),
          if (provider.hasNext)
            SliverToBoxAdapter(child: _buildLoadingIndicator(settings)),
        ],
      ),
    );
  }
  
  Widget _buildChapterItem(ChapterContent chapter, SettingsProvider settings, ReaderProvider provider) {
    return MeasureSize(
      key: provider.getChapterKey(chapter.index),
      onChange: (size) {
        _chapterHeights[chapter.index] = size.height;
        provider.updateChapterHeight(chapter.index, size.height);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chapter.title,
              style: TextStyle(
                fontSize: settings.fontSize + 6,
                fontWeight: FontWeight.bold,
                color: settings.theme.textColor.withValues(alpha: 0.9),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            if (chapter.isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else
              ContentWithImages(
                content: chapter.content,
                fontSize: settings.fontSize,
                textColor: settings.theme.textColor,
                lineSpacing: settings.lineSpacing,
              ),
            const SizedBox(height: 40),
            if (chapter.index < provider.chapters.length - 1)
              _buildChapterDivider(chapter.index + 2, settings),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterDivider(int nextChapter, SettingsProvider settings) {
    return Center(
      child: Row(
        children: [
          Expanded(child: Divider(color: settings.theme.textColor.withValues(alpha: 0.1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '第 $nextChapter 章',
              style: TextStyle(color: settings.theme.textColor.withValues(alpha: 0.4), fontSize: 13),
            ),
          ),
          Expanded(child: Divider(color: settings.theme.textColor.withValues(alpha: 0.1))),
        ],
      ),
    );
  }
  
  Widget _buildLoadingIndicator(SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: settings.theme.textColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildSingleChapterContent(ReaderProvider provider, SettingsProvider settings) {
    return SafeArea(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.currentChapter?.title ?? '',
              style: TextStyle(
                fontSize: settings.fontSize + 6,
                fontWeight: FontWeight.bold,
                color: settings.theme.textColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ContentWithImages(
              content: provider.content,
              fontSize: settings.fontSize,
              textColor: settings.theme.textColor,
              lineSpacing: settings.lineSpacing,
            ),
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (provider.hasPrevious)
                  ElevatedButton(onPressed: provider.previousChapter, child: const Text('上一章')),
                if (provider.hasNext)
                  ElevatedButton(onPressed: provider.nextChapter, child: const Text('下一章')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleTapDown(TapDownDetails details, SettingsProvider settings) {
    if (_readerProvider.menuVisible || _readerProvider.settingsVisible) {
      _readerProvider.hideMenu();
      return;
    }
    
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;
    
    if (_readerProvider.continuousMode) {
      _readerProvider.toggleMenu();
      return;
    }
    
    if (tapX < screenWidth * 0.35) {
      if (_readerProvider.hasPrevious) _readerProvider.previousChapter();
    } else if (tapX > screenWidth * 0.65) {
      if (_readerProvider.hasNext) _readerProvider.nextChapter();
    } else {
      _readerProvider.toggleMenu();
    }
  }

  void _handleSwipe(DragEndDetails details) {
    if (details.primaryVelocity == null || _readerProvider.continuousMode) return;
    if (details.primaryVelocity! > 400 && _readerProvider.hasPrevious) {
      _readerProvider.previousChapter();
    } else if (details.primaryVelocity! < -400 && _readerProvider.hasNext) {
      _readerProvider.nextChapter();
    }
  }

  void _showChapters(ReaderProvider provider) {
    provider.hideMenu();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).canvasColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('目录', style: Theme.of(context).textTheme.headlineSmall),
                    IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: provider.chapters.length,
                  itemBuilder: (itemCtx, i) => ListTile(
                    selected: i == provider.currentIndex,
                    leading: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                    title: Text(provider.chapters[i].title),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      provider.goToChapter(i);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings(ReaderProvider provider) {
    provider.hideMenu();
    provider.toggleSettings();
  }

  Future<void> _addBookmark(ReaderProvider provider) async {
    provider.hideMenu();
    final bookmark = Bookmark(
      id: const Uuid().v4(),
      bookId: widget.bookId,
      chapterIndex: provider.currentIndex,
      position: provider.preciseProgress.chapterPosition,
      createTime: DateTime.now(),
    );
    await context.read<BookRepository>().addBookmark(bookmark);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存书签')));
  }

  void _goBack(ReaderProvider provider) async {
    provider.hideMenu();
    await provider.saveAndExit();
    if (mounted) {
      Navigator.pop(context);
    }
  }
}

class MeasureSize extends StatefulWidget {
  final Widget child;
  final void Function(Size size) onChange;
  const MeasureSize({super.key, required this.child, required this.onChange});
  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  @override
  Widget build(BuildContext context) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) widget.onChange(box.size);
    });
    return widget.child;
  }
}

/// Widget that displays content with embedded images
/// Parses [图片:path] placeholders and renders actual images
class ContentWithImages extends StatelessWidget {
  final String content;
  final double fontSize;
  final Color textColor;
  final double lineSpacing;

  const ContentWithImages({
    super.key,
    required this.content,
    required this.fontSize,
    required this.textColor,
    required this.lineSpacing,
  });

  @override
  Widget build(BuildContext context) {
    final segments = _parseContent(content);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.map((segment) {
        if (segment.isImage) {
          return _buildImageSegment(segment);
        } else {
          return _buildTextSegment(segment);
        }
      }).toList(),
    );
  }
  
  List<ContentSegment> _parseContent(String content) {
    final segments = <ContentSegment>[];
    final imagePattern = RegExp(r'\[图片(?::([^\]]*))?\]');
    
    int lastEnd = 0;
    for (final match in imagePattern.allMatches(content)) {
      // Add text before this image
      if (match.start > lastEnd) {
        final text = content.substring(lastEnd, match.start);
        if (text.isNotEmpty) {
          segments.add(ContentSegment(text: text, isImage: false));
        }
      }
      
      // Add image segment
      final imagePath = match.group(1);
      segments.add(ContentSegment(text: imagePath ?? '', isImage: true));
      
      lastEnd = match.end;
    }
    
    // Add remaining text
    if (lastEnd < content.length) {
      final text = content.substring(lastEnd);
      if (text.isNotEmpty) {
        segments.add(ContentSegment(text: text, isImage: false));
      }
    }
    
    return segments;
  }
  
  Widget _buildTextSegment(ContentSegment segment) {
    return Text(
      segment.text,
      style: TextStyle(
        fontSize: fontSize,
        color: textColor,
        height: lineSpacing,
        letterSpacing: 0.2,
      ),
    );
  }
  
  Widget _buildImageSegment(ContentSegment segment) {
    final imagePath = segment.text;
    
    if (imagePath.isEmpty) {
      return _buildPlaceholderImage();
    }
    
    final file = File(imagePath);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: GestureDetector(
        onTap: () => _showImagePreview(imagePath),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              AppLogger.warning('Failed to load image: $imagePath, error: $error');
              return _buildPlaceholderImage();
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildPlaceholderImage() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(Icons.broken_image, size: 40, color: textColor.withValues(alpha: 0.3)),
      ),
    );
  }
  
  void _showImagePreview(String imagePath) {
    // Could implement full-screen image preview here
  }
}

class ContentSegment {
  final String text;
  final bool isImage;
  
  ContentSegment({required this.text, required this.isImage});
}
