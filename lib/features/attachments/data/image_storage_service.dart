import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageStorageException implements Exception {
  final String message;
  ImageStorageException(this.message);
  @override
  String toString() => message;
}

class ImageStorageService {
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int maxAttachmentsPerNote = 10;
  static const _uuid = Uuid();

  static Future<Directory> get _attachmentsDir async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/attachments');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Compresses and saves an image to the local attachments directory.
  /// Returns the generated filename.
  static Future<String> saveImage(File source, int currentAttachmentCount) async {
    if (currentAttachmentCount >= maxAttachmentsPerNote) {
      throw ImageStorageException('Maximum of $maxAttachmentsPerNote attachments allowed per note.');
    }

    final fileSize = await source.length();
    if (fileSize > maxFileSizeBytes) {
      throw ImageStorageException('File size exceeds the 10MB limit.');
    }

    final dir = await _attachmentsDir;
    final extension = '.jpg'; // Compress always outputs JPEG
    final filename = '${_uuid.v4()}$extension';
    final destinationPath = '${dir.path}/$filename';

    final result = await FlutterImageCompress.compressAndGetFile(
      source.absolute.path,
      destinationPath,
      quality: 85,
    );

    if (result == null) {
      throw ImageStorageException('Failed to compress and save image.');
    }

    return filename;
  }

  /// Resolves a filename to its absolute File path for rendering.
  static Future<File> getFile(String filename) async {
    if (filename.startsWith('http://') || filename.startsWith('https://')) {
      throw ImageStorageException('Network URLs are not supported by the local file resolver.');
    }
    // Legacy support for tasks/notes that saved absolute file paths
    if (filename.contains('/') || filename.contains('\\')) {
      return File(filename);
    }
    final dir = await _attachmentsDir;
    return File('${dir.path}/$filename');
  }

  /// Resolves a filename to its absolute path string.
  static Future<String> getFilePath(String filename) async {
    final file = await getFile(filename);
    return file.path;
  }

  /// Deletes a physical file.
  static Future<void> deleteFile(String filename) async {
    final file = await getFile(filename);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Deletes multiple physical files.
  static Future<void> deleteFiles(List<String> filenames) async {
    for (final filename in filenames) {
      await deleteFile(filename);
    }
  }
}
