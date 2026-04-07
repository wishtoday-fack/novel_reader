import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novel_reader/providers/settings_provider.dart';
import 'package:novel_reader/utils/themes.dart' show ReaderTheme;

/// Settings screen for the novel reader application
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (_, settings, __) => ListView(
          children: [
            // Reading settings section
            _buildSection(
              title: '阅读设置',
              children: [
                _buildNavigationTile(
                  icon: Icons.text_fields,
                  title: '字体设置',
                  subtitle: '字号: ${settings.fontSize.toInt()}',
                  onTap: () => _showFontSettings(context, settings),
                ),
                _buildNavigationTile(
                  icon: Icons.palette,
                  title: '主题设置',
                  subtitle: '当前: ${settings.theme.name}',
                  onTap: () => _showThemeSettings(context, settings),
                ),
                _buildSwitchTile(
                  icon: Icons.save,
                  title: '自动保存进度',
                  subtitle: '阅读时自动保存阅读进度',
                  value: settings.autoSaveProgress,
                  onChanged: (v) => settings.setAutoSaveProgress(v),
                ),
                _buildSwitchTile(
                  icon: Icons.screen_lock_portrait,
                  title: '保持屏幕常亮',
                  subtitle: '阅读时保持屏幕常亮',
                  value: settings.keepScreenOn,
                  onChanged: (v) => settings.setKeepScreenOn(v),
                ),
              ],
            ),

            const Divider(),

            // Data management section
            _buildSection(
              title: '数据管理',
              children: [
                _buildNavigationTile(
                  icon: Icons.backup,
                  title: '数据备份',
                  subtitle: '备份阅读记录和设置',
                  onTap: () => _showBackupOptions(context),
                ),
                _buildNavigationTile(
                  icon: Icons.restore,
                  title: '数据恢复',
                  subtitle: '从备份恢复数据',
                  onTap: () => _showRestoreOptions(context),
                ),
                _buildNavigationTile(
                  icon: Icons.delete_sweep,
                  title: '清除缓存',
                  subtitle: '清除阅读缓存数据',
                  onTap: () => _showClearCacheDialog(context),
                ),
              ],
            ),

            const Divider(),

            // About section
            _buildSection(
              title: '关于',
              children: [
                _buildNavigationTile(
                  icon: Icons.info_outline,
                  title: '关于我们',
                  subtitle: '版本 1.0.0',
                  onTap: () => _showAboutDialog(context),
                ),
                _buildNavigationTile(
                  icon: Icons.description,
                  title: '隐私政策',
                  subtitle: '查看隐私政策',
                  onTap: () => _showPrivacyPolicy(context),
                ),
                _buildNavigationTile(
                  icon: Icons.star_outline,
                  title: '给我们评分',
                  subtitle: '喜欢就给个好评吧',
                  onTap: () => _showRatingDialog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
      onTap: () => onChanged(!value),
    );
  }

  void _showFontSettings(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setState) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('字体设置', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              // Font size slider
              Row(
                children: [
                  const Text('字号'),
                  Expanded(
                    child: Slider(
                      value: settings.fontSize,
                      min: 12,
                      max: 32,
                      divisions: 20,
                      onChanged: (v) {
                        settings.setFontSize(v);
                        setState(() {});
                      },
                    ),
                  ),
                  Text('${settings.fontSize.toInt()}'),
                ],
              ),
              const SizedBox(height: 16),
              // Line spacing slider
              Row(
                children: [
                  const Text('行距'),
                  Expanded(
                    child: Slider(
                      value: settings.lineSpacing,
                      min: 1.0,
                      max: 3.0,
                      divisions: 20,
                      onChanged: (v) {
                        settings.setLineSpacing(v);
                        setState(() {});
                      },
                    ),
                  ),
                  Text(settings.lineSpacing.toStringAsFixed(1)),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(_),
                child: const Text('确定'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemeSettings(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('主题设置', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: ReaderTheme.presets.length,
                itemBuilder: (_, i) {
                  final theme = ReaderTheme.presets[i];
                  final isSelected = settings.themeIndex == i;
                  return GestureDetector(
                    onTap: () {
                      settings.setThemeIndex(i);
                    },
                    child: Container(
                      width: 60,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: theme.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.withValues(alpha: 0.3),
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          theme.name,
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton(
                onPressed: () => Navigator.pop(_),
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('数据备份'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('将备份以下数据:'),
            SizedBox(height: 8),
            Text('• 阅读进度'),
            Text('• 书签'),
            Text('• 阅读设置'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(_);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('备份成功')),
              );
            },
            child: const Text('备份'),
          ),
        ],
      ),
    );
  }

  void _showRestoreOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('数据恢复'),
        content: const Text('确定要从备份恢复数据吗？当前数据将被覆盖。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(_);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('恢复成功')),
              );
            },
            child: const Text('恢复'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除缓存吗？这不会影响您的书籍和阅读进度。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(_);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清除')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: '小说阅读器',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026 Meituan',
      children: [
        const SizedBox(height: 16),
        const Text('一个跨平台的小说阅读应用'),
        const SizedBox(height: 8),
        const Text('支持 TXT, EPUB, PDF, MOBI 格式'),
      ],
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('隐私政策'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('我们重视您的隐私保护。'),
              SizedBox(height: 16),
              Text('数据收集:'),
              Text('• 我们不收集任何个人身份信息'),
              Text('• 阅读数据仅存储在您的设备上'),
              SizedBox(height: 16),
              Text('数据使用:'),
              Text('• 数据仅用于提供阅读服务'),
              Text('• 我们不会与第三方共享数据'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(_),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('给我们评分'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('如果您喜欢这个应用，请给我们一个好评！'),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 32),
                Icon(Icons.star, color: Colors.amber, size: 32),
                Icon(Icons.star, color: Colors.amber, size: 32),
                Icon(Icons.star, color: Colors.amber, size: 32),
                Icon(Icons.star, color: Colors.amber, size: 32),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(_);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('感谢您的支持！')),
              );
            },
            child: const Text('去评分'),
          ),
        ],
      ),
    );
  }
}
