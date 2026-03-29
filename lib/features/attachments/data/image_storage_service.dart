import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
  static const localScheme = 'app_folder://';

  static Future<Directory> get _attachmentsDir async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/attachments');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> get _thumbnailsDir async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/attachments/thumbnails');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// High-level method to upload an image to cloud storage with progress.
  /// Handles both File (mobile) and Uint8List (web).
  static UploadTask uploadImage(
    dynamic source, 
    String userId,
    String noteId, {
    bool compress = true,
  }) {
    if (kIsWeb) {
      if (source is! Uint8List) {
        throw ImageStorageException('Web upload requires Uint8List');
      }
      return uploadBytesToCloud(source, userId, noteId);
    } else {
      if (source is! File) {
        throw ImageStorageException('Mobile upload requires File');
      }
      return uploadFileToCloud(source, userId, noteId, compress: compress);
    }
  }

  /// Uploads a File to Firebase Storage and returns the UploadTask.
  static UploadTask uploadFileToCloud(File file, String userId, String noteId, {bool compress = true}) {
    final size = file.lengthSync();
    if (size > maxFileSizeBytes) {
      throw ImageStorageException('File exceeds 10MB limit. Please choose a smaller file.');
    }

    final ext = file.path.split('.').last;
    final filename = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    
    final ref = FirebaseStorage.instance
        .ref()
        .child('attachments')
        .child(userId)
        .child(noteId)
        .child(filename);

    return ref.putFile(
      file, 
      SettableMetadata(contentType: 'image/${ext == 'png' ? 'png' : 'jpeg'}'),
    );
  }

  /// Uploads Uint8List bytes to Firebase Storage and returns the UploadTask.
  static UploadTask uploadBytesToCloud(Uint8List bytes, String userId, String noteId) {
    if (bytes.length > maxFileSizeBytes) {
      throw ImageStorageException('Data exceeds 10MB limit.');
    }

    final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    final ref = FirebaseStorage.instance
        .ref()
        .child('attachments')
        .child(userId)
        .child(noteId)
        .child(filename);

    return ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
  }

  /// Compresses and saves an image to the local attachments directory.
  /// Returns a Smart URI (app_folder://filename).
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

    // 1. Clone and Compress Original
    final result = await FlutterImageCompress.compressAndGetFile(
      source.absolute.path,
      destinationPath,
      quality: 85,
    );

    if (result == null) {
      throw ImageStorageException('Failed to compress and save image.');
    }

    // 2. Generate and Cache Thumbnail for performance
    try {
      await generateThumbnail(File(result.path), filename);
    } catch (e) {
      debugPrint('Warning: Could not generate thumbnail: $e');
    }

    return '$localScheme$filename';
  }

  /// Generates a small 200x200 thumbnail for UI speed.
  static Future<File?> generateThumbnail(File source, String originalFilename) async {
    final thumbDir = await _thumbnailsDir;
    final thumbPath = '${thumbDir.path}/$originalFilename';
    
    final result = await FlutterImageCompress.compressAndGetFile(
      source.absolute.path,
      thumbPath,
      minWidth: 200,
      minHeight: 200,
      quality: 70,
    );
    
    return result != null ? File(result.path) : null;
  }

  /// Resolves a Smart URI or Filename to its absolute File path for rendering.
  static Future<File> getFile(String path, {bool useThumbnail = false}) async {
    if (path.startsWith('http')) {
      throw ImageStorageException('Network URLs are not supported by the local file resolver.');
    }

    final cleanPath = path.startsWith(localScheme)
        ? path.substring(localScheme.length)
        : path;

    // Support for thumbnails
    if (useThumbnail) {
      final thumbDir = await _thumbnailsDir;
      final thumbFile = File('${thumbDir.path}/$cleanPath');
      if (await thumbFile.exists()) {
        return thumbFile;
      }
    }

    // Legacy support for tasks/notes that saved absolute file paths
    if (cleanPath.contains('/') || cleanPath.contains('\\')) {
      return File(cleanPath);
    }
    
    final dir = await _attachmentsDir;
    return File('${dir.path}/$cleanPath');
  }

  /// Deletes a file. Now handles both local and cloud cleanup.
  static Future<void> deleteFile(String filenameOrUrl) async {
    if (filenameOrUrl.startsWith('http')) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(filenameOrUrl);
        await ref.delete();
      } catch (e) {
        debugPrint('Error deleting from cloud storage: $e');
      }
    } else {
      final file = await getFile(filenameOrUrl);
      if (await file.exists()) {
        await file.delete();
      }
      // Also delete thumbnail
      final thumbDir = await _thumbnailsDir;
      final cleanPath = filenameOrUrl.startsWith(localScheme)
          ? filenameOrUrl.substring(localScheme.length)
          : filenameOrUrl;
      final thumbFile = File('${thumbDir.path}/$cleanPath');
      if (await thumbFile.exists()) {
        await thumbFile.delete();
      }
    }
  }


  /// Deletes multiple files.
  static Future<void> deleteFiles(List<String> filenames) async {
    for (final filename in filenames) {
      await deleteFile(filename);
    }
  }
}

