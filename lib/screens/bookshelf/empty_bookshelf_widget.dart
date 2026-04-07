import 'package:flutter/material.dart';

class EmptyBookshelf extends StatelessWidget {
  final VoidCallback onImport;
  const EmptyBookshelf({super.key, required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book, 
            size: 80, 
            color: Theme.of(context).colorScheme.outline
          ),
          const SizedBox(height: 24),
          Text(
            '书架空空如也', 
            style: Theme.of(context).textTheme.titleLarge
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮导入书籍',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onImport, 
            icon: const Icon(Icons.add), 
            label: const Text('导入书籍')
          ),
        ],
      ),
    );
  }
}
