import 'dart:io';
import 'package:flutter/material.dart';
import 'package:novel_reader/models/book.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final double? readingProgress;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const BookCard({
    super.key, 
    required this.book, 
    this.readingProgress, 
    required this.onTap, 
    required this.onLongPress
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildCover(context)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title, 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (readingProgress != null && readingProgress! > 0) ...[
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: readingProgress! / 100,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    if (book.coverPath != null && File(book.coverPath!).existsSync()) {
      return Image.file(File(book.coverPath!), fit: BoxFit.cover);
    }
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.book, 
          size: 48, 
          color: Theme.of(context).colorScheme.primary
        )
      ),
    );
  }
}
