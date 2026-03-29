import 'dart:io';

enum ImageSourceFormat { png, jpeg, webp, unknown }

class ImageFormatStrategy {
  /// Detect format from file extension
  static ImageSourceFormat detect(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png': return ImageSourceFormat.png;
      case 'jpg':
      case 'jpeg': return ImageSourceFormat.jpeg;
      case 'webp': return ImageSourceFormat.webp;
      default: return ImageSourceFormat.unknown;
    }
  }

  /// Should we skip re-encoding entirely?
  /// True when: source is PNG and file is small enough
  static Future<bool> shouldCopyDirect(File file, ImageSourceFormat fmt) async {
    if (fmt != ImageSourceFormat.png) return false;
    final bytes = await file.length();
    return bytes < 1 * 1024 * 1024; // Under 1MB → bit-for-bit copy
  }

  /// Output extension for the stored file
  static String outputExtension(ImageSourceFormat fmt) {
    switch (fmt) {
      case ImageSourceFormat.png: return '.png';
      case ImageSourceFormat.jpeg: return '.webp'; // upgrade JPEGs to WebP
      case ImageSourceFormat.webp: return '.webp';
      case ImageSourceFormat.unknown: return '.webp';
    }
  }
}
