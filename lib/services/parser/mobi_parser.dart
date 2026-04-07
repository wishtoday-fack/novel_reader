import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_mobi/dart_mobi.dart';
import 'package:novel_reader/models/chapter.dart';
import 'package:novel_reader/services/parser/book_parser.dart';
import 'package:novel_reader/utils/file_utils.dart';
import 'package:novel_reader/utils/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:charset_converter/charset_converter.dart';

/// MOBI format parser using dart_mobi package
/// Supports MOBI, AZW, AZW3 formats
class MobiParser implements BookParser {
  /// Cache for parsed MOBI data to avoid re-reading large files
  final Map<String, MobiData> _dataCache = {};
  
  /// Cache for extracted images: filePath -> (resourceId -> localImagePath)
  final Map<String, Map<int, String>> _imageCache = {};
  
  /// Book ID for organizing images
  String? _currentBookId;

  @override
  Future<BookInfo> parseMetadata(String filePath) async {
    final mobiData = await _openBook(filePath);

    String title = FileUtils.extractFileName(filePath);
    String? author;
    String? description;

    // Try to get title from fullname
    if (mobiData.mobiHeader?.fullname != null &&
        mobiData.mobiHeader!.fullname!.isNotEmpty) {
      title = await _decodeText(mobiData.mobiHeader!.fullname!.codeUnits, mobiData);
    }

    // Extract metadata from EXTH header
    var exthHeader = mobiData.mobiExthHeader;
    while (exthHeader != null) {
      if (exthHeader.tag != null && exthHeader.data != null) {
        final tag = MobiExthTag.fromValue(exthHeader.tag!);
        final value = await _decodeText(exthHeader.data!, mobiData);
        switch (tag) {
          case MobiExthTag.title:
            title = value;
            break;
          case MobiExthTag.author:
            author = value;
            break;
          case MobiExthTag.description:
            description = value;
            break;
          default:
            break;
        }
      }
      exthHeader = exthHeader.next;
    }

    // Estimate chapters count
    final chapters = await _extractChapters(mobiData, 'temp');

    return BookInfo(
      title: title,
      author: author,
      description: description,
      totalChapters: chapters.length,
    );
  }

  @override
  Future<List<Chapter>> parseChapters(String filePath, String bookId) async {
    _currentBookId = bookId;
    final mobiData = await _openBook(filePath);
    return _extractChapters(mobiData, bookId);
  }

  @override
  Future<String> parseContent(String filePath, int chapterIndex) async {
    final mobiData = await _openBook(filePath);

    try {
      // Parse the content parts
      final rawml = mobiData.parseOpt(false, false, true);
      
      // Extract and cache images for this book
      await _extractAndSaveImages(filePath, rawml, _currentBookId ?? 'default');

      // Get markup content (HTML/XML)
      if (rawml.markup != null) {
        var part = rawml.markup;
        int currentIndex = 0;
        
        // Navigate to the requested chapter/part
        while (part != null && currentIndex < chapterIndex) {
          part = part.next;
          currentIndex++;
        }
        
        if (part != null && part.data != null) {
          final content = await _decodeText(part.data!, mobiData);
          return _htmlToTextWithImages(content, filePath);
        }
      }

      // Fallback to flow content
      if (rawml.flow != null && rawml.flow!.data != null) {
        final content = await _decodeText(rawml.flow!.data!, mobiData);
        return _htmlToTextWithImages(content, filePath);
      }

      return 'MOBI内容提取失败';
    } catch (e) {
      AppLogger.error('Failed to parse MOBI content: $filePath, chapter: $chapterIndex', e);
      return '内容解析错误';
    }
  }

  @override
  Future<String?> extractCover(String filePath) async {
    try {
      final mobiData = await _openBook(filePath);

      // Parse resources to find cover image
      final rawml = mobiData.parseOpt(false, false, false);

      // Look for images in resources
      var resource = rawml.resources;
      while (resource != null) {
        if (resource.fileType == MobiFileType.jpg ||
            resource.fileType == MobiFileType.png ||
            resource.fileType == MobiFileType.gif ||
            resource.fileType == MobiFileType.bmp) {
          // Typically the first image found is the cover
          if (resource.data != null) {
            return await _saveCoverImage(resource.data!, resource.fileType);
          }
        }
        resource = resource.next;
      }

      return null;
    } catch (e) {
      AppLogger.error('Failed to extract MOBI cover: $filePath', e);
      return null;
    }
  }
  
  /// Extract and save all images from MOBI resources
  Future<void> _extractAndSaveImages(String filePath, MobiRawml rawml, String bookId) async {
    if (_imageCache.containsKey(filePath)) return;
    
    final imageMap = <int, String>{};
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = p.join(appDir.path, 'mobi_images', bookId);
      await Directory(imagesDir).create(recursive: true);
      
      var resource = rawml.resources;
      while (resource != null) {
        if (_isImageType(resource.fileType) && resource.data != null) {
          final imagePath = await _saveImageResource(
            resource.data!, 
            resource.fileType, 
            resource.uid, 
            imagesDir
          );
          if (imagePath != null) {
            imageMap[resource.uid] = imagePath;
          }
        }
        resource = resource.next;
      }
      
      _imageCache[filePath] = imageMap;
      AppLogger.info('Extracted ${imageMap.length} images from MOBI: $filePath');
    } catch (e) {
      AppLogger.error('Failed to extract MOBI images: $filePath', e);
    }
  }
  
  /// Check if file type is an image
  bool _isImageType(MobiFileType? fileType) {
    return fileType == MobiFileType.jpg ||
           fileType == MobiFileType.png ||
           fileType == MobiFileType.gif ||
           fileType == MobiFileType.bmp;
  }
  
  /// Save image resource to local storage
  Future<String?> _saveImageResource(Uint8List bytes, MobiFileType fileType, int uid, String imagesDir) async {
    try {
      String extension;
      switch (fileType) {
        case MobiFileType.png:
          extension = 'png';
          break;
        case MobiFileType.gif:
          extension = 'gif';
          break;
        case MobiFileType.bmp:
          extension = 'bmp';
          break;
        default:
          extension = 'jpg';
      }
      
      final fileName = 'img_${uid.toString().padLeft(5, '0')}.$extension';
      final imagePath = p.join(imagesDir, fileName);
      
      final file = File(imagePath);
      if (!await file.exists()) {
        await file.writeAsBytes(bytes);
      }
      
      return imagePath;
    } catch (e) {
      AppLogger.error('Failed to save image resource: $uid', e);
      return null;
    }
  }

  /// Open and parse a MOBI file using dart_mobi
  Future<MobiData> _openBook(String filePath) async {
    if (_dataCache.containsKey(filePath)) {
      return _dataCache[filePath]!;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('MOBI file not found', filePath);
    }

    try {
      final bytes = await file.readAsBytes();
      final mobiData = await DartMobiReader.read(bytes);

      _dataCache[filePath] = mobiData;
      return mobiData;
    } catch (e) {
      AppLogger.error('Failed to read MOBI file: $filePath', e);
      rethrow;
    }
  }

  /// Extract chapter structure from MOBI data
  Future<List<Chapter>> _extractChapters(MobiData mobiData, String bookId) async {
    final chapters = <Chapter>[];

    try {
      // Parse table of contents and structure
      final rawml = mobiData.parseOpt(true, false, true);

      // 1. Try NCX table of contents
      if (rawml.ncx != null && rawml.ncx!.entries.isNotEmpty) {
        for (int i = 0; i < rawml.ncx!.entriesCount; i++) {
          final entry = rawml.ncx!.entries[i];
          final title = await _decodeText(entry.label.codeUnits, mobiData);
          chapters.add(Chapter(
            id: const Uuid().v4(),
            bookId: bookId,
            index: i,
            title: title.isNotEmpty ? title : '第 ${i + 1} 章',
          ));
        }
        return chapters;
      }

      // 2. Try Guide entries
      if (rawml.guide != null && rawml.guide!.entries.isNotEmpty) {
        for (int i = 0; i < rawml.guide!.entriesCount; i++) {
          final entry = rawml.guide!.entries[i];
          final title = await _decodeText(entry.label.codeUnits, mobiData);
          chapters.add(Chapter(
            id: const Uuid().v4(),
            bookId: bookId,
            index: i,
            title: title.isNotEmpty ? title : '第 ${i + 1} 章',
          ));
        }
        return chapters;
      }

      // 3. Fallback: Treat each markup part as a chapter
      if (rawml.markup != null) {
        var part = rawml.markup;
        int index = 0;
        while (part != null) {
          chapters.add(Chapter(
            id: const Uuid().v4(),
            bookId: bookId,
            index: index,
            title: '第 ${index + 1} 部分',
          ));
          part = part.next;
          index++;
        }
      }

      // 4. Ultimate Fallback: Single chapter for entire book
      if (chapters.isEmpty) {
        chapters.add(Chapter(
          id: const Uuid().v4(),
          bookId: bookId,
          index: 0,
          title: '正文',
        ));
      }

      return chapters;
    } catch (e) {
      AppLogger.error('Failed to extract MOBI chapters structure', e);
      return [
        Chapter(
          id: const Uuid().v4(),
          bookId: bookId,
          index: 0,
          title: '正文',
        ),
      ];
    }
  }

  /// Decodes byte data based on MOBI encoding
  Future<String> _decodeText(List<int> data, MobiData mobiData) async {
    if (data.isEmpty) return '';

    final encoding = mobiData.mobiHeader?.encoding;
    
    try {
      // MobiEncoding.UTF8 is UTF-8
      if (encoding == MobiEncoding.UTF8) {
        return utf8.decode(data, allowMalformed: true);
      } 
      
      // If not UTF-8 or if it fails, try UTF-8 first as a fallback, then GBK
      try {
        return utf8.decode(data);
      } catch (_) {
        // If UTF-8 fails, fallback to GBK which is common for Chinese MOBIs
        try {
          return await CharsetConverter.decode('GBK', Uint8List.fromList(data));
        } catch (e) {
          // Last resort: Latin1
          return String.fromCharCodes(data);
        }
      }
    } catch (e) {
      AppLogger.error('Text decoding failed', e);
      return String.fromCharCodes(data);
    }
  }

  /// Convert HTML content to text, preserving image placeholders
  String _htmlToTextWithImages(String? html, String filePath) {
    if (html == null || html.isEmpty) {
      return '';
    }
    
    final imageCache = _imageCache[filePath] ?? {};
    
    // Process img tags first - replace with image placeholders
    // Match img tags with src attribute (using non-raw string for proper quote handling)
    String processed = html.replaceAllMapped(
      RegExp('<img[^>]+src=["\']([^"\']+)["\'][^>]*>', caseSensitive: false),
      (match) {
        final src = match.group(1) ?? '';
        return _processImageSrc(src, imageCache);
      },
    );
    
    // Also handle img tags with different attribute order
    processed = processed.replaceAllMapped(
      RegExp(r'<img[^>]*>', caseSensitive: false),
      (match) {
        final imgTag = match.group(0) ?? '';
        final srcMatch = RegExp('src=["\']([^"\']+)["\']', caseSensitive: false).firstMatch(imgTag);
        if (srcMatch != null) {
          final src = srcMatch.group(1) ?? '';
          return _processImageSrc(src, imageCache);
        }
        return '';
      },
    );

    return processed
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li>', caseSensitive: false), '\n- ')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&#39;'), "'")
        .trim();
  }
  
  /// Process image source URL and return appropriate placeholder
  String _processImageSrc(String src, Map<int, String> imageCache) {
    AppLogger.info('Processing image src: $src, available keys: ${imageCache.keys.toList()}');
    
    // Handle resource00000.jpg style references (from dart_mobi)
    final resourceMatch = RegExp(r'resource(\d+)').firstMatch(src);
    if (resourceMatch != null) {
      final resourceId = int.parse(resourceMatch.group(1)!);
      final localPath = imageCache[resourceId];
      if (localPath != null) {
        AppLogger.info('Found image for resource ID $resourceId: $localPath');
        return '\n[图片:$localPath]\n';
      } else {
        AppLogger.warning('Resource ID $resourceId not found in cache');
      }
    }
    
    // Handle kindle:embed:XXXX style references (raw MOBI format)
    // dart_mobi should have already converted these, but handle as fallback
    final embedMatch = RegExp(r'kindle:embed:([A-Za-z0-9]+)', caseSensitive: false).firstMatch(src);
    if (embedMatch != null) {
      final encoded = embedMatch.group(1)!;
      AppLogger.info('Found kindle:embed reference: $encoded');
      // The embed ID is base32 encoded, decode it to get the resource ID
      try {
        final resourceId = _base32Decode(encoded);
        final localPath = imageCache[resourceId];
        if (localPath != null) {
          AppLogger.info('Found image for embed ID $encoded -> resource $resourceId: $localPath');
          return '\n[图片:$localPath]\n';
        } else {
          AppLogger.warning('Embed decoded to resource ID $resourceId not found in cache');
        }
      } catch (e) {
        AppLogger.warning('Failed to decode embed reference: $src, error: $e');
      }
    }
    
    // Return placeholder for unrecognized image references
    AppLogger.warning('Unrecognized image src: $src');
    return '\n[图片]\n';
  }
  
  /// Simple base32 decoder for MOBI image references
  /// MOBI uses: 0-9 -> 0-9, A-V -> 10-31
  int _base32Decode(String encoded) {
    const base = 32;
    int decoded = 0;
    int len = encoded.length;
    
    for (int j = 0; j < encoded.length; j++) {
      int c = encoded.codeUnitAt(j);
      int value;
      if (c >= 0x30 && c <= 0x39) {
        // '0'-'9' -> 0-9
        value = c - 0x30;
      } else if (c >= 0x41 && c <= 0x56) {
        // 'A'-'V' -> 10-31
        value = c - 0x41 + 10;
      } else if (c >= 0x61 && c <= 0x76) {
        // 'a'-'v' -> 10-31 (lowercase variant)
        value = c - 0x61 + 10;
      } else {
        throw FormatException('Invalid character in base32: ${String.fromCharCode(c)}');
      }
      decoded += (value * _pow(base, --len)).toInt();
    }
    // MOBI resource IDs in embed references are 1-indexed, so subtract 1
    return decoded - 1;
  }
  
  /// Simple power function for integers
  int _pow(int base, int exponent) {
    int result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }

  // Strip HTML tags and normalize text (legacy method for non-image content)
  // ignore: unused_element
  String _htmlToText(String? html) {
    if (html == null || html.isEmpty) {
      return '';
    }

    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li>', caseSensitive: false), '\n- ')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&#39;'), "'")
        .trim();
  }

  /// Save cover image to app documents directory
  Future<String> _saveCoverImage(Uint8List bytes, MobiFileType fileType) async {
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = p.join(appDir.path, 'covers');
    await Directory(coversDir).create(recursive: true);

    String extension;
    switch (fileType) {
      case MobiFileType.png:
        extension = 'png';
        break;
      case MobiFileType.gif:
        extension = 'gif';
        break;
      case MobiFileType.bmp:
        extension = 'bmp';
        break;
      default:
        extension = 'jpg';
    }

    final coverFileName = 'mobi_cover_${const Uuid().v4()}.$extension';
    final coverPath = p.join(coversDir, coverFileName);

    await File(coverPath).writeAsBytes(bytes);
    return coverPath;
  }

  /// Clear memory cache
  void clearCache() {
    _dataCache.clear();
  }
}
