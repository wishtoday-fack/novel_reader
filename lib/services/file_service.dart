import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:novel_reader/utils/logger.dart';

class FileService {
  Future<bool> checkStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }
    }
    return true;
  }

  Future<String?> pickSingleFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'epub', 'pdf', 'mobi', 'azw', 'azw3', 'azw4'],
      );
      return result?.files.first.path;
    } catch (e) {
      AppLogger.error('Failed to pick file', e);
      return null;
    }
  }

  Future<List<String>> pickMultipleFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'epub', 'pdf', 'mobi', 'azw', 'azw3', 'azw4'],
        allowMultiple: true,
      );
      return result?.files.where((f) => f.path != null).map((f) => f.path!).toList() ?? [];
    } catch (e) {
      AppLogger.error('Failed to pick files', e);
      return [];
    }
  }

  Future<bool> fileExists(String path) async => await File(path).exists();
}
