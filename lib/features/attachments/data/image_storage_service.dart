import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../auth/domain/models/synq_user.dart';
import '../../../core/utils/image_format_strategy.dart';

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
  static const int _thumbnailShortEdge = 1024;

  // ─── PUBLIC API ────────────────────────────────────────────────

  /// Called when user picks an image from gallery/camera.
  /// Always stores a lossless original locally.
  /// [userTier] controls whether a server-ready compressed copy is also produced.
  static Future<ImageStorageResult> storeImage({
    required File sourceFile,
    required PlanTier planTier,
  }) async {
    final fmt = ImageFormatStrategy.detect(sourceFile.path);
    final storageDir = await _getStorageDir();
    final id = _uuid.v4();

    // 1. Always write a lossless local original
    final localOriginal = await _writeLosslessLocal(
      source: sourceFile,
      fmt: fmt,
      dir: storageDir,
      id: id,
    );

    // 2. Always write a thumbnail (for fast preview)
    final thumbnail = await _writeThumbnail(
      source: sourceFile,
      dir: storageDir,
      id: id,
    );

    // 3. Pro users: produce a server-optimised compressed copy
    File? serverCopy;
    if (planTier.isPro) {
      serverCopy = await _writeServerCopy(
        source: sourceFile,
        fmt: fmt,
        dir: storageDir,
        id: id,
      );
    }

    return ImageStorageResult(
      localOriginalPath: localOriginal.path,
      thumbnailPath: thumbnail.path,
      serverCopyPath: serverCopy?.path, // null for free users
      planTier: planTier,
    );
  }

  /// High-level method to upload an image to cloud storage with progress.
  static UploadTask uploadFileToCloud(File file, String userId, String noteId) {
    final size = file.lengthSync();
    if (size > maxFileSizeBytes) {
      throw ImageStorageException('File exceeds 10MB limit.');
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
      SettableMetadata(contentType: 'image/${ext == 'png' ? 'png' : 'webp'}'),
    );
  }

  /// Resolves a path to its File. Safely handles thumbnails.
  static Future<File> getFile(String path, {bool useThumbnail = false}) async {
    if (path.startsWith('http')) {
      throw ImageStorageException('Network URLs are not supported by the local file resolver.');
    }

    // Handle local scheme
    final cleanPath = path.startsWith(localScheme)
        ? path.substring(localScheme.length)
        : path;

    // Resolve base directory
    final storageDir = await _getStorageDir();
    
    // Check if it's already an absolute path
    File file;
    if (cleanPath.contains('/') || cleanPath.contains('\\')) {
      file = File(cleanPath);
    } else {
      file = File(p.join(storageDir.path, cleanPath));
    }

    if (useThumbnail) {
      final thumbPath = _thumbnailPathFor(file.path);
      final thumb = File(thumbPath);
      if (await thumb.exists()) return thumb;
    }
    
    return file;
  }

  /// Deletes a file. Handles both local and cloud cleanup.
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
      final thumbPath = _thumbnailPathFor(file.path);
      final thumbFile = File(thumbPath);
      if (await thumbFile.exists()) {
        await thumbFile.delete();
      }
      // Delete server copy if exists
      final serverPath = _serverPathFor(file.path);
      final serverFile = File(serverPath);
      if (await serverFile.exists()) {
        await serverFile.delete();
      }
    }
  }

  /// Deletes multiple files.
  static Future<void> deleteFiles(List<String> paths) async {
    for (final path in paths) {
      await deleteFile(path);
    }
  }

  // ─── COMPATIBILITY WRAPPERS (LEGACY) ───────────────────────────

  /// Legacy wrapper for uploadImage.
  static UploadTask uploadImage(dynamic source, String userId, String noteId) {
    if (source is File) {
      return uploadFileToCloud(source, userId, noteId);
    }
    throw ImageStorageException('Unsupported source type for uploadImage');
  }

  /// Legacy wrapper for saveImage.
  static Future<String> saveImage(File source, [int? count]) async {
    final result = await storeImage(
      sourceFile: source,
      planTier: PlanTier.free,
    );
    return result.localOriginalPath;
  }

  // ─── PRIVATE HELPERS ───────────────────────────────────────────

  static Future<File> _writeLosslessLocal({
    required File source,
    required ImageSourceFormat fmt,
    required Directory dir,
    required String id,
  }) async {
    final ext = ImageFormatStrategy.outputExtension(fmt);
    final destPath = p.join(dir.path, 'orig_$id$ext');

    if (await ImageFormatStrategy.shouldCopyDirect(source, fmt)) {
      return source.copy(destPath);
    }

    if (fmt == ImageSourceFormat.png) {
      final compressed = await FlutterImageCompress.compressWithFile(
        source.absolute.path,
        format: CompressFormat.png,
        quality: 100,
      );
      return _writeBytes(compressed!, destPath);
    }

    final compressed = await FlutterImageCompress.compressWithFile(
      source.absolute.path,
      format: CompressFormat.webp,
      quality: 95,
    );
    return _writeBytes(compressed!, destPath);
  }

  static Future<File> _writeThumbnail({
    required File source,
    required Directory dir,
    required String id,
  }) async {
    final destPath = p.join(dir.path, 'thumb_$id.webp');
    final compressed = await FlutterImageCompress.compressWithFile(
      source.absolute.path,
      format: CompressFormat.webp,
      quality: 85,
      minWidth: _thumbnailShortEdge,
      minHeight: _thumbnailShortEdge,
    );
    return _writeBytes(compressed!, destPath);
  }

  static Future<File> _writeServerCopy({
    required File source,
    required ImageSourceFormat fmt,
    required Directory dir,
    required String id,
  }) async {
    final ext = ImageFormatStrategy.outputExtension(fmt);
    final destPath = p.join(dir.path, 'server_$id$ext');

    if (fmt == ImageSourceFormat.png) {
      final compressed = await FlutterImageCompress.compressWithFile(
        source.absolute.path,
        format: CompressFormat.png,
        quality: 100,
      );
      return _writeBytes(compressed!, destPath);
    }

    final compressed = await FlutterImageCompress.compressWithFile(
      source.absolute.path,
      format: CompressFormat.webp,
      quality: 88,
    );
    return _writeBytes(compressed!, destPath);
  }

  static Future<File> _writeBytes(Uint8List bytes, String path) async {
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static String _thumbnailPathFor(String originalPath) {
    final dir = p.dirname(originalPath);
    final name = p.basenameWithoutExtension(originalPath);
    // orig_<uuid>... → thumb_<uuid>.webp
    final id = name.replaceFirst('orig_', '').replaceFirst('server_', '');
    return p.join(dir, 'thumb_$id.webp');
  }

  static String _serverPathFor(String originalPath) {
    final dir = p.dirname(originalPath);
    final name = p.basenameWithoutExtension(originalPath);
    final ext = p.extension(originalPath);
    final id = name.replaceFirst('orig_', '');
    return p.join(dir, 'server_$id$ext');
  }

  static Future<Directory> _getStorageDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'note_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}

// ─── RESULT MODEL ──────────────────────────────────────────────────────────

class ImageStorageResult {
  final String localOriginalPath;
  final String thumbnailPath;
  final String? serverCopyPath; 
  final PlanTier planTier;

  const ImageStorageResult({
    required this.localOriginalPath,
    required this.thumbnailPath,
    this.serverCopyPath,
    required this.planTier,
  });

  bool get hasServerCopy => serverCopyPath != null;
}
