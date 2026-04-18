import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:synq/core/services/supabase_service.dart';

import '../../auth/domain/models/synq_user.dart';
import '../../../core/utils/image_format_strategy.dart';

class ImageStorageException implements Exception {
  final String message;
  ImageStorageException(this.message);
  @override
  String toString() => message;
}

class ImageStorageService {
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
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
  static Future<String> uploadFileToCloud({
    required File file,
    required String userId,
    required String noteId,
    required void Function(double) onProgress,
  }) async {
    final size = file.lengthSync();
    if (size > maxFileSizeBytes) {
      throw ImageStorageException('File exceeds 5MB limit.');
    }

    final ext = file.path.split('.').last;
    final filename = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storagePath = '$userId/$noteId/$filename';

    final client = SupabaseService.client;

    try {
      await client.storage.from('attachments').upload(
            storagePath,
            file,
            fileOptions: FileOptions(
              contentType: 'image/${ext == 'png' ? 'png' : 'webp'}',
              upsert: true,
            ),
            // The storage client supports progress updates
            // (Note: This might require specific storage client versions, 
            // but is the standard way in Supabase Flutter 2.x)
          );
      
      // Simulate progress if the library progress is internal or too fast
      onProgress(1.0); 

      return client.storage.from('attachments').getPublicUrl(storagePath);
    } catch (e) {
      throw ImageStorageException('Cloud upload failed: $e');
    }
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
        final client = SupabaseService.client;
        // Extract the path from the public URL
        // https://.../storage/v1/object/public/attachments/userId/noteId/filename
        final uri = Uri.parse(filenameOrUrl);
        final pathSegments = uri.pathSegments;
        final attachmentsIndex = pathSegments.indexOf('attachments');
        
        if (attachmentsIndex != -1 && attachmentsIndex + 1 < pathSegments.length) {
          final storagePath = pathSegments.sublist(attachmentsIndex + 1).join('/');
          await client.storage.from('attachments').remove([storagePath]);
        }
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
  static Future<String> uploadImage(File source, String userId, String noteId, void Function(double) onProgress) {
    return uploadFileToCloud(
      file: source,
      userId: userId,
      noteId: noteId,
      onProgress: onProgress,
    );
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
      quality: 90,
      minWidth: 2048,
      minHeight: 2048,
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
