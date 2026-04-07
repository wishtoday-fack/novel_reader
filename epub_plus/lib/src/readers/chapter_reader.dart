import 'dart:convert';

import '../ref_entities/epub_book_ref.dart';
import '../ref_entities/epub_chapter_ref.dart';
import '../ref_entities/epub_text_content_file_ref.dart';
import '../schema/navigation/epub_navigation_point.dart';

class ChapterReader {
  static List<EpubChapterRef> getChapters(EpubBookRef bookRef) {
    if (bookRef.schema!.navigation == null) {
      return <EpubChapterRef>[];
    }
    return getChaptersImpl(bookRef, bookRef.schema!.navigation!.navMap!.points);
  }

  static List<EpubChapterRef> getChaptersImpl(
      EpubBookRef bookRef, List<EpubNavigationPoint> navigationPoints) {
    var result = <EpubChapterRef>[];
    for (var navigationPoint in navigationPoints) {
      String? contentFileName;
      String? anchor;
      if (navigationPoint.content?.source == null) continue;
      var contentSourceAnchorCharIndex =
          navigationPoint.content!.source!.indexOf('#');
      if (contentSourceAnchorCharIndex == -1) {
        contentFileName = navigationPoint.content!.source;
        anchor = null;
      } else {
        contentFileName = navigationPoint.content!.source!
            .substring(0, contentSourceAnchorCharIndex);
        anchor = navigationPoint.content!.source!
            .substring(contentSourceAnchorCharIndex + 1);
      }

      // Skip if contentFileName is null
      if (contentFileName == null) continue;

      // Try to find matching HTML content file with URL encoding variations
      EpubTextContentFileRef? htmlContentFileRef =
          _findHtmlContentFile(bookRef, contentFileName);

      if (htmlContentFileRef == null) {
        // Skip this navigation point instead of throwing
        // This allows the EPUB to be parsed even with broken references
        continue;
      }

      var chapterRef = EpubChapterRef(
        epubTextContentFileRef: htmlContentFileRef,
        title: navigationPoint.navigationLabels.first.text,
        contentFileName: contentFileName,
        anchor: anchor,
        subChapters:
            getChaptersImpl(bookRef, navigationPoint.childNavigationPoints),
      );
      result.add(chapterRef);
    }

    return result;
  }

  /// Find HTML content file with URL encoding variations
  static EpubTextContentFileRef? _findHtmlContentFile(
      EpubBookRef bookRef, String contentFileName) {
    final htmlFiles = bookRef.content!.html;

    // Try exact match first
    if (htmlFiles.containsKey(contentFileName)) {
      return htmlFiles[contentFileName];
    }

    // Try URL decoded version
    final decodedFileName = _safeDecodeUri(contentFileName);
    if (htmlFiles.containsKey(decodedFileName)) {
      return htmlFiles[decodedFileName];
    }

    // Try URL encoded version
    final encodedFileName = _encodeUri(contentFileName);
    if (htmlFiles.containsKey(encodedFileName)) {
      return htmlFiles[encodedFileName];
    }

    // Try case-insensitive match
    for (final entry in htmlFiles.entries) {
      if (entry.key.toLowerCase() == contentFileName.toLowerCase()) {
        return entry.value;
      }
      if (entry.key.toLowerCase() == decodedFileName.toLowerCase()) {
        return entry.value;
      }
    }

    // Try fuzzy matching by comparing decoded filenames
    for (final entry in htmlFiles.entries) {
      final decodedKey = _safeDecodeUri(entry.key);
      if (decodedKey == decodedFileName) {
        return entry.value;
      }
      // Normalize and compare (handle encoding variations)
      if (_normalizeForComparison(entry.key) ==
          _normalizeForComparison(contentFileName)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Safely decode URI, handling invalid percent encoding
  static String _safeDecodeUri(String uri) {
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
  static String _fixInvalidPercentEncoding(String uri) {
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
  static bool _isHexDigit(String char) {
    const hexDigits = '0123456789ABCDEFabcdef';
    return hexDigits.contains(char);
  }

  /// Normalize string for comparison (handle encoding variations)
  static String _normalizeForComparison(String s) {
    return _safeDecodeUri(s).toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Encode special characters in URI
  static String _encodeUri(String uri) {
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
        final bytes = utf8.encode(char);
        for (final byte in bytes) {
          buffer.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
        }
      }
    }
    return buffer.toString();
  }
}