import 'package:flutter/material.dart';
import 'package:novel_reader/models/chapter.dart';

class ChapterList extends StatelessWidget {
  final List<Chapter> chapters;
  final int currentIndex;
  final Function(int) onTap;

  const ChapterList({
    super.key, 
    required this.chapters, 
    this.currentIndex = 0, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty) {
      return const Center(child: Text('暂无章节'));
    }

    return ListView.builder(
      itemCount: chapters.length,
      itemBuilder: (_, i) => ListTile(
        leading: i == currentIndex 
          ? Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.primary) 
          : null,
        title: Text(
          chapters[i].title, 
          style: i == currentIndex 
            ? TextStyle(
                color: Theme.of(context).colorScheme.primary, 
                fontWeight: FontWeight.bold
              ) 
            : null
        ),
        onTap: () => onTap(i),
      ),
    );
  }
}
