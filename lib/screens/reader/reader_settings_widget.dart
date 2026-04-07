import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novel_reader/providers/settings_provider.dart';
import 'package:novel_reader/utils/themes.dart' show ReaderTheme;

class ReaderSettingsWidget extends StatelessWidget {
  final SettingsProvider settings;
  const ReaderSettingsWidget({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: settings,
      child: Consumer<SettingsProvider>(
        builder: (_, s, __) => Container(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Font size slider
                Row(
                  children: [
                    const Icon(Icons.text_fields, size: 20),
                    const SizedBox(width: 8),
                    const Text('字号'),
                    Expanded(
                      child: Slider(
                        value: s.fontSize,
                        min: 12,
                        max: 32,
                        divisions: 20,
                        onChanged: (v) => s.setFontSize(v),
                      ),
                    ),
                    Text('${s.fontSize.toInt()}'),
                  ],
                ),
                
                // Line spacing slider
                Row(
                  children: [
                    const Icon(Icons.format_line_spacing, size: 20),
                    const SizedBox(width: 8),
                    const Text('行距'),
                    Expanded(
                      child: Slider(
                        value: s.lineSpacing,
                        min: 1.0,
                        max: 3.0,
                        divisions: 20,
                        onChanged: (v) => s.setLineSpacing(v),
                      ),
                    ),
                    Text(s.lineSpacing.toStringAsFixed(1)),
                  ],
                ),
                
                // Brightness slider
                Row(
                  children: [
                    const Icon(Icons.brightness_6, size: 20),
                    const SizedBox(width: 8),
                    const Text('亮度'),
                    Expanded(
                      child: Slider(
                        value: s.brightness,
                        min: 0.1,
                        max: 1.0,
                        divisions: 18,
                        onChanged: (v) => s.setBrightness(v),
                      ),
                    ),
                    Text('${(s.brightness * 100).toInt()}%'),
                  ],
                ),
                
                const Divider(),
                
                // Theme selection
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('主题'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: ReaderTheme.presets.length,
                    itemBuilder: (_, i) {
                      final theme = ReaderTheme.presets[i];
                      final isSelected = s.themeIndex == i;
                      return GestureDetector(
                        onTap: () => s.setThemeIndex(i),
                        child: Container(
                          width: 50,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: theme.backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected 
                                ? Theme.of(context).colorScheme.primary 
                                : Colors.grey.withValues(alpha: 0.3),
                              width: isSelected ? 2 : 1,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
