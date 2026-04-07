enum BookFormat {
  txt,
  epub,
  pdf,
  mobi;

  String get extension {
    switch (this) {
      case BookFormat.txt:
        return '.txt';
      case BookFormat.epub:
        return '.epub';
      case BookFormat.pdf:
        return '.pdf';
      case BookFormat.mobi:
        return '.mobi';
    }
  }

  static BookFormat fromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case '.txt':
        return BookFormat.txt;
      case '.epub':
        return BookFormat.epub;
      case '.pdf':
        return BookFormat.pdf;
      case '.mobi':
      case '.azw':
      case '.azw3':
      case '.azw4':
        return BookFormat.mobi;
      default:
        throw ArgumentError('Unsupported format: $ext');
    }
  }
}
