class AppConstants {
  static const String appName = '小说阅读器';
  static const String appVersion = '1.0.0';

  static const String databaseName = 'novel_reader.db';
  static const int databaseVersion = 1;

  static const int maxChapterCacheSize = 50;
  static const int maxMetadataCacheSize = 100;

  static const double minFontSize = 12.0;
  static const double maxFontSize = 32.0;
  static const double defaultFontSize = 18.0;
  static const double minLineSpacing = 1.0;
  static const double maxLineSpacing = 3.0;
  static const double defaultLineSpacing = 1.5;

  static const List<String> supportedExtensions = [
    '.txt',
    '.epub',
    '.pdf',
    '.mobi',
    '.azw',
    '.azw3',
    '.azw4',
  ];
}
