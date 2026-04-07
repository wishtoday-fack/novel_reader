import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:novel_reader/models/book_format.dart';
import 'package:novel_reader/utils/constants.dart';
import 'package:path/path.dart' as p;

class FileUtils {
  static BookFormat detectFormat(String filePath) {
    final extension = p.extension(filePath).toLowerCase();
    return BookFormat.fromExtension(extension);
  }

  static String generateBookId(String filePath) {
    final bytes = utf8.encode(filePath);
    final hash = md5.convert(bytes);
    return hash.toString();
  }

  static Future<bool> exists(String filePath) async {
    return await File(filePath).exists();
  }

  static Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  static String extractFileName(String filePath) {
    return p.basenameWithoutExtension(filePath);
  }

  static String getExtension(String filePath) {
    return p.extension(filePath).toLowerCase();
  }

  static bool isSupportedFormat(String filePath) {
    final ext = getExtension(filePath);
    return AppConstants.supportedExtensions.contains(ext);
  }
}
