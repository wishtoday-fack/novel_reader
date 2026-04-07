import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novel_reader/models/book.dart';
import 'package:novel_reader/models/chapter.dart';
import 'package:novel_reader/repositories/book_repository.dart';
import 'package:novel_reader/screens/reader/reader_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final String bookId;
  const BookDetailScreen({super.key, required this.bookId});
  
  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  Book? _book;
  List<Chapter> _chapters = [];
  int _currentChapter = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() { 
    super.initState(); 
    _load(); 
  }

  Future<void> _load() async {
    try {
      final repo = context.read<BookRepository>();
      final book = await repo.getBook(widget.bookId);
      if (book == null) {
        setState(() {
          _loading = false;
          _error = '书籍不存在';
        });
        return;
      }
      
      final chapters = await repo.getChapters(widget.bookId);
      final progress = await repo.getReadProgress(widget.bookId);
      
      setState(() {
        _book = book;
        _chapters = chapters;
        _currentChapter = progress?.currentChapter ?? 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '加载失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator())
      );
    }
    
    if (_error != null || _book == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('错误')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? '找不到该书籍'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
            ],
          ),
        )
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280, 
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader()
            )
          ),
          SliverToBoxAdapter(child: _buildInfo()),
          SliverToBoxAdapter(child: _buildActions()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('目录', style: Theme.of(context).textTheme.titleMedium),
                  Text('共 ${_chapters.length} 章', 
                    style: Theme.of(context).textTheme.bodySmall
                  ),
                ],
              ),
            )
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => ListTile(
                leading: i == _currentChapter 
                  ? Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.primary)
                  : null,
                title: Text(
                  _chapters[i].title,
                  style: i == _currentChapter 
                    ? TextStyle(color: Theme.of(context).colorScheme.primary)
                    : null,
                ),
                onTap: () => _openReader(initialChapter: i),
              ), 
              childCount: _chapters.length
            )
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.surface
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        )
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 100, 
              height: 140, 
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest, 
                borderRadius: BorderRadius.circular(8)
              ),
              child: _book!.coverPath != null && File(_book!.coverPath!).existsSync() 
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(_book!.coverPath!), fit: BoxFit.cover)
                  )
                : Icon(Icons.book, size: 48, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    _book!.title, 
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8), 
                  Text(
                    _book!.author,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_book!.format.name.toUpperCase()} · ${(_book!.fileSize / 1024).toStringAsFixed(0)} KB',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              )
            ),
          ],
        )
      ),
    );
  }

  Widget _buildInfo() {
    if (_book!.description == null || _book!.description!.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('简介', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            _book!.description!,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final hasProgress = _currentChapter > 0;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _openReader(),
              icon: const Icon(Icons.play_arrow),
              label: Text(hasProgress ? '继续阅读' : '开始阅读'),
            ),
          ),
          if (hasProgress) ...[
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openReader(initialChapter: 0),
                icon: const Icon(Icons.refresh),
                label: const Text('从头开始'),
              ),
            ),
          ],
        ],
      )
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showChapterList,
                icon: const Icon(Icons.list),
                label: const Text('章节列表'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _openReader(),
                icon: const Icon(Icons.menu_book),
                label: Text(_currentChapter > 0 ? '第${_currentChapter + 1}章' : '开始'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openReader({int? initialChapter}) async {
    await Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          bookId: widget.bookId, 
          initialChapter: initialChapter ?? _currentChapter
        )
      )
    );
    
    // 从阅读器返回后，重新加载数据以同步最新进度
    if (mounted) {
      _load();
    }
  }

  void _showChapterList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('目录', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(
                    onPressed: () => Navigator.pop(_),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _chapters.length,
                itemBuilder: (_, i) => ListTile(
                  leading: i == _currentChapter 
                    ? Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.primary)
                    : Text('${i + 1}'),
                  title: Text(
                    _chapters[i].title,
                    style: i == _currentChapter 
                      ? TextStyle(color: Theme.of(context).colorScheme.primary)
                      : null,
                  ),
                  onTap: () {
                    Navigator.pop(_);
                    _openReader(initialChapter: i);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
