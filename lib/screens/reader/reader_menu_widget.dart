import 'package:flutter/material.dart';

class ReaderMenuWidget extends StatelessWidget {
  final String title;
  final int currentChapter;
  final int totalChapters;
  final double progress;
  final VoidCallback onClose;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onShowChapters;
  final VoidCallback onShowSettings;
  final VoidCallback onAddBookmark;
  final VoidCallback onGoBack;

  const ReaderMenuWidget({
    super.key,
    required this.title,
    required this.currentChapter,
    required this.totalChapters,
    required this.progress,
    required this.onClose,
    required this.onPrevious,
    required this.onNext,
    required this.onShowChapters,
    required this.onShowSettings,
    required this.onAddBookmark,
    required this.onGoBack,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Column(
          children: [
            // Top menu bar
            _buildTopBar(context),
            
            const Spacer(),
            
            // Bottom menu bar
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              onPressed: onGoBack,
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '第 ${currentChapter + 1} / $totalChapters 章',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onAddBookmark,
              icon: const Icon(Icons.bookmark_outline),
              tooltip: '添加书签',
            ),
            IconButton(
              onPressed: onShowChapters,
              icon: const Icon(Icons.list),
              tooltip: '目录',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            Row(
              children: [
                const Text('进度'),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${progress.toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 16),
            
            // Navigation buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: currentChapter > 0 ? onPrevious : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('上一章'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: currentChapter < totalChapters - 1 ? onNext : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('下一章'),
                    style: OutlinedButton.styleFrom(
                      iconAlignment: IconAlignment.end,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionButton(
                  icon: Icons.list,
                  label: '目录',
                  onPressed: onShowChapters,
                ),
                _ActionButton(
                  icon: Icons.tune,
                  label: '设置',
                  onPressed: onShowSettings,
                ),
                _ActionButton(
                  icon: Icons.bookmark_add,
                  label: '书签',
                  onPressed: onAddBookmark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
