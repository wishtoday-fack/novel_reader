import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novel_reader/models/book.dart';
import 'package:novel_reader/providers/bookshelf_provider.dart';
import 'package:novel_reader/screens/bookshelf/book_card_widget.dart';
import 'package:novel_reader/screens/bookshelf/empty_bookshelf_widget.dart';
import 'package:novel_reader/screens/book_detail/book_detail_screen.dart';
import 'package:novel_reader/screens/settings/settings_screen.dart';

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});
  
  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookshelfProvider>().loadBooks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架'),
        actions: [
          IconButton(
            onPressed: _showSearch, 
            icon: const Icon(Icons.search)
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings),
          ),
          PopupMenuButton<SortBy>(
            icon: const Icon(Icons.sort),
            onSelected: (v) => context.read<BookshelfProvider>().setSortBy(v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: SortBy.lastRead, child: Text('最近阅读')),
              PopupMenuItem(value: SortBy.title, child: Text('书名')),
              PopupMenuItem(value: SortBy.addTime, child: Text('添加时间')),
              PopupMenuItem(value: SortBy.author, child: Text('作者')),
            ],
          ),
        ],
      ),
      body: Consumer<BookshelfProvider>(
        builder: (_, provider, __) {
          if (provider.isLoading && provider.books.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.books.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(provider.error!),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => provider.loadBooks(),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }
          if (provider.books.isEmpty) {
            return EmptyBookshelf(onImport: () => provider.importBooks());
          }
          
          return Stack(
            children: [
              GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, 
                  childAspectRatio: 0.65, 
                  crossAxisSpacing: 12, 
                  mainAxisSpacing: 12
                ),
                itemCount: provider.books.length,
                itemBuilder: (_, i) {
                  final book = provider.books[i];
                  return FutureBuilder<double?>(
                    future: _getProgress(book.id, provider),
                    builder: (_, snap) => BookCard(
                      book: book,
                      readingProgress: snap.data,
                      onTap: () => _openBookDetail(book),
                      onLongPress: () => _showOptions(book, provider),
                    ),
                  );
                },
              ),
              if (provider.isLoading)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('处理中...'),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<BookshelfProvider>().importBooks(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<double?> _getProgress(String bookId, BookshelfProvider provider) async {
    final progress = await provider.getReadProgress(bookId);
    return progress?.position;
  }

  void _openBookDetail(Book book) {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => BookDetailScreen(bookId: book.id)
      )
    );
  }

  void _showSearch() {
    showSearch(
      context: context, 
      delegate: _BookSearchDelegate(context.read<BookshelfProvider>())
    );
  }
  
  void _showOptions(Book book, BookshelfProvider provider) {
    showModalBottomSheet(
      context: context, 
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('书籍详情'), 
              onTap: () {
                Navigator.pop(_);
                _openBookDetail(book);
              }
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error)), 
              onTap: () {
                Navigator.pop(_);
                _confirmDelete(book, provider);
              }
            ),
          ]
        ),
      )
    );
  }

  void _confirmDelete(Book book, BookshelfProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除《${book.title}》吗？\n这将删除阅读进度和书签。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(_);
              provider.deleteBook(book.id);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _BookSearchDelegate extends SearchDelegate {
  final BookshelfProvider provider;
  
  _BookSearchDelegate(this.provider);
  
  @override
  List<Widget> buildActions(BuildContext _) => [
    IconButton(
      onPressed: () { 
        query = ''; 
        provider.setSearchQuery(''); 
      }, 
      icon: const Icon(Icons.clear)
    )
  ];
  
  @override
  Widget buildLeading(BuildContext _) => IconButton(
    onPressed: () { 
      provider.setSearchQuery(''); 
      close(_, null); 
    }, 
    icon: const Icon(Icons.arrow_back)
  );
  
  @override
  Widget buildResults(BuildContext _) {
    provider.setSearchQuery(query); 
    return _buildList();
  }
  
  @override
  Widget buildSuggestions(BuildContext _) => query.isEmpty 
    ? const Center(child: Text('输入书名或作者搜索')) 
    : buildResults(_);
  
  Widget _buildList() => Consumer<BookshelfProvider>(
    builder: (_, p, __) => p.books.isEmpty
      ? const Center(child: Text('未找到匹配的书籍'))
      : ListView.builder(
        itemCount: p.books.length,
        itemBuilder: (_, i) {
          final book = p.books[i];
          return ListTile(
            title: Text(book.title),
            subtitle: Text(book.author),
            onTap: () { 
              close(_, null); 
              Navigator.push(
                _, 
                MaterialPageRoute(
                  builder: (_) => BookDetailScreen(bookId: book.id)
                )
              ); 
            },
          );
        },
      ),
  );
}
