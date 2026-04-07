import 'dart:async';
import 'dart:convert' as convert;

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';

import '../entities/epub_content_type.dart';
import '../utils/zip_path_utils.dart';
import 'epub_book_ref.dart';

abstract class EpubContentFileRef {
  final EpubBookRef epubBookRef;
  final String? fileName;
  final EpubContentType? contentType;
  final String? contentMimeType;

  const EpubContentFileRef({
    required this.epubBookRef,
    this.fileName,
    this.contentType,
    this.contentMimeType,
  });

  @override
  int get hashCode {
    return epubBookRef.hashCode ^
        fileName.hashCode ^
        contentType.hashCode ^
        contentMimeType.hashCode;
  }

  @override
  bool operator ==(covariant EpubContentFileRef other) {
    if (identical(this, other)) return true;

    return other.epubBookRef == epubBookRef &&
        other.fileName == fileName &&
        other.contentType == contentType &&
        other.contentMimeType == contentMimeType;
  }

  ArchiveFile getContentFileEntry() {
    final contentFilePath = ZipPathUtils.combine(
        epubBookRef.schema!.contentDirectoryPath, fileName);

    if (contentFilePath == null || contentFilePath.isEmpty) {
      throw Exception('EPUB parsing error: file path is empty.');
    }

    // First try direct lookup with all path variations
    final decodedPath = _safeDecodeUri(contentFilePath);
    final encodedPath = _encodeUri(contentFilePath);
    final fullyEncodedPath = _fullyEncodeUri(decodedPath);

    final directPaths = [
      contentFilePath,
      decodedPath,
      encodedPath,
      fullyEncodedPath,
    ];

    for (final path in directPaths) {
      final file = _findFileInArchive(path);
      if (file != null) return file;
    }

    // Try matching by comparing normalized paths with all archive files
    final normalizedTarget = _normalizeForComparison(contentFilePath);
    final decodedTarget = _safeDecodeUri(contentFilePath);

    for (final file in epubBookRef.epubArchive.files) {
      final archiveName = file.name;
      final decodedArchiveName = _safeDecodeUri(archiveName);

      // Compare normalized versions
      if (_normalizeForComparison(archiveName) == normalizedTarget) {
        return file;
      }

      // Compare decoded versions
      if (decodedArchiveName == decodedTarget) {
        return file;
      }

      // Compare case-insensitive decoded versions
      if (decodedArchiveName.toLowerCase() == decodedTarget.toLowerCase()) {
        return file;
      }
    }

    // Try matching by filename only (more relaxed)
    final targetFileName = _extractFileName(decodedTarget);
    final targetFileNameNormalized = _normalizeForComparison(targetFileName);

    for (final file in epubBookRef.epubArchive.files) {
      final archiveFileName = _extractFileName(_safeDecodeUri(file.name));

      if (_normalizeForComparison(archiveFileName) == targetFileNameNormalized) {
        return file;
      }

      // Also try partial match (for files with similar base names)
      if (archiveFileName.contains(targetFileNameNormalized) ||
          targetFileNameNormalized.contains(archiveFileName)) {
        return file;
      }
    }

    throw Exception(
        'EPUB parsing error: file $contentFilePath not found in archive.');
  }

  /// Extract filename from a path
  String _extractFileName(String path) {
    final lastSlash = path.lastIndexOf('/');
    return lastSlash >= 0 ? path.substring(lastSlash + 1) : path;
  }

  /// Find file in archive with exact match
  ArchiveFile? _findFileInArchive(String path) {
    // Exact match
    var file = epubBookRef.epubArchive.files
        .firstWhereOrNull((ArchiveFile x) => x.name == path);

    // Case-insensitive match
    file ??= epubBookRef.epubArchive.files
        .firstWhereOrNull((ArchiveFile x) =>
            x.name.toLowerCase() == path.toLowerCase());

    return file;
  }

  /// Normalize string for comparison (handle encoding variations)
  String _normalizeForComparison(String s) {
    return _safeDecodeUri(s).toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Safely decode URI, handling invalid percent encoding
  String _safeDecodeUri(String uri) {
    if (uri.isEmpty) return uri;
    try {
      return Uri.decodeFull(uri);
    } catch (e) {
      final fixedUri = _fixInvalidPercentEncoding(uri);
      try {
        return Uri.decodeFull(fixedUri);
      } catch (_) {
        return uri;
      }
    }
  }

  /// Fix invalid percent encoding in a URI string
  String _fixInvalidPercentEncoding(String uri) {
    final buffer = StringBuffer();
    int i = 0;

    while (i < uri.length) {
      if (uri[i] == '%') {
        if (i + 2 < uri.length) {
          final hex1 = uri[i + 1];
          final hex2 = uri[i + 2];

          if (_isHexDigit(hex1) && _isHexDigit(hex2)) {
            buffer.write(uri.substring(i, i + 3));
            i += 3;
          } else {
            buffer.write('%25');
            i += 1;
          }
        } else if (i + 1 < uri.length) {
          buffer.write('%25');
          buffer.write(uri[i + 1]);
          i += 2;
        } else {
          buffer.write('%25');
          i += 1;
        }
      } else {
        buffer.write(uri[i]);
        i += 1;
      }
    }

    return buffer.toString();
  }

  /// Check if a character is a valid hexadecimal digit
  bool _isHexDigit(String char) {
    const hexDigits = '0123456789ABCDEFabcdef';
    return hexDigits.contains(char);
  }

  /// Encode special characters in URI (partial - only encode spaces and special chars)
  String _encodeUri(String uri) {
    final buffer = StringBuffer();
    for (int i = 0; i < uri.length; i++) {
      final char = uri[i];
      final codeUnit = uri.codeUnitAt(i);

      if ((codeUnit >= 0x30 && codeUnit <= 0x39) ||
          (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
          (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
          char == '-' || char == '_' || char == '.' ||
          char == '~' || char == '/') {
        buffer.write(char);
      } else if (codeUnit < 128) {
        buffer.write(
            '%${codeUnit.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      } else {
        // Keep non-ASCII characters as-is (for partial encoding)
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  /// Fully encode URI (encode all non-ASCII as UTF-8 percent encoding)
  String _fullyEncodeUri(String uri) {
    final buffer = StringBuffer();
    for (int i = 0; i < uri.length; i++) {
      final char = uri[i];
      final codeUnit = uri.codeUnitAt(i);

      if ((codeUnit >= 0x30 && codeUnit <= 0x39) ||
          (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
          (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
          char == '-' || char == '_' || char == '.' ||
          char == '~' || char == '/') {
        buffer.write(char);
      } else if (codeUnit < 128) {
        buffer.write(
            '%${codeUnit.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      } else {
        final bytes = convert.utf8.encode(char);
        for (final byte in bytes) {
          buffer.write(
              '%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
        }
      }
    }
    return buffer.toString();
  }

  List<int> getContentStream() {
    return openContentStream(getContentFileEntry());
  }

  List<int> openContentStream(ArchiveFile contentFileEntry) {
    var contentStream = <int>[];
    contentStream.addAll(contentFileEntry.content);
    return contentStream;
  }

  Future<List<int>> readContentAsBytes() async {
    var contentFileEntry = getContentFileEntry();
    var content = openContentStream(contentFileEntry);
    return content;
  }

  Future<String> readContentAsText() async {
    var contentStream = getContentStream();
    var result = convert.utf8.decode(contentStream);
    return result;
  }
}