import 'dart:typed_data';

/// Sealed class to represent all possible image sources in the app.
sealed class ImageSource {
  const ImageSource();

  /// A unique key for this image content (used by the cache manager).
  String get cacheKey;
}

/// Image sourced from a network URL.
class NetworkImageSource extends ImageSource {
  final String url;
  const NetworkImageSource(this.url);

  @override
  String get cacheKey => url;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkImageSource && runtimeType == other.runtimeType && url == other.url;

  @override
  int get hashCode => url.hashCode;
}

/// Image sourced from a local file path.
class FileImageSource extends ImageSource {
  final String filePath;
  const FileImageSource(this.filePath);

  @override
  String get cacheKey => filePath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileImageSource && runtimeType == other.runtimeType && filePath == other.filePath;

  @override
  int get hashCode => filePath.hashCode;
}

/// Image sourced from raw bytes in memory.
class MemoryImageSource extends ImageSource {
  final Uint8List bytes;
  const MemoryImageSource(this.bytes);

  @override
  String get cacheKey => bytes.hashCode.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryImageSource && runtimeType == other.runtimeType && bytes == other.bytes;

  @override
  int get hashCode => bytes.hashCode;
}

/// Utility to generate a stable, value-based Hero tag by combining 
/// image content identity with render context (index).
String imageHeroTag(ImageSource source, int index) =>
    'img_${source.cacheKey.hashCode}_$index';
