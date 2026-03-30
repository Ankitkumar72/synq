import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:synq/core/domain/models/image_source.dart';
import 'package:synq/core/services/cache_manager.dart';
import 'package:synq/core/navigation/fade_page_route.dart';
import 'package:synq/core/widgets/image_viewer.dart';
import 'package:synq/core/widgets/image_error_widget.dart';
import '../../../attachments/data/image_storage_service.dart';

class ResizableInlineImage extends StatefulWidget {
  final String path;
  final int index; // Stable index for Hero tags (offset in document)
  final double initialWidth;
  final Function(double)? onWidthChanged;

  const ResizableInlineImage({
    required this.path,
    required this.index,
    this.initialWidth = 300,
    this.onWidthChanged,
    super.key,
  });

  @override
  State<ResizableInlineImage> createState() => _ResizableInlineImageState();
}

class _ResizableInlineImageState extends State<ResizableInlineImage> {
  File? _thumbnail;
  File? _fullRes;
  bool _fullResLoaded = false;
  String? _lastPath;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void didUpdateWidget(ResizableInlineImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _loadImages();
    }
  }

  Future<void> _loadImages() async {
    final currentPath = widget.path;
    if (_lastPath == currentPath) return;
    _lastPath = currentPath;

    if (currentPath.startsWith('http')) return;

    // Stage 1: Load thumbnail immediately
    try {
      final thumb = await ImageStorageService.getFile(currentPath, useThumbnail: true);
      if (mounted && currentPath == widget.path) {
        setState(() => _thumbnail = thumb);
      }
    } catch (e) {
      debugPrint('Error loading thumbnail: $e');
    }

    // Stage 2: Load full-res in background
    try {
      final full = await ImageStorageService.getFile(currentPath, useThumbnail: false);
      if (mounted && currentPath == widget.path) {
        setState(() {
          _fullRes = full;
          _fullResLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading full-res: $e');
    }
  }

  ImageSource _resolveSource() {
    if (widget.path.startsWith('http')) {
      return NetworkImageSource(widget.path);
    }
    final displayFile = _fullResLoaded ? _fullRes : _thumbnail;
    return FileImageSource(displayFile?.path ?? widget.path);
  }

  @override
  Widget build(BuildContext context) {
    final isUrl = widget.path.startsWith('http');
    final source = _resolveSource();
    final heroTag = imageHeroTag(source, widget.index);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      width: double.infinity,
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: () => _openFullscreen(context, source, heroTag),
          child: Hero(
            tag: heroTag,
            child: isUrl ? _buildNetworkImage() : _buildLocalImage(),
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context, ImageSource source, String heroTag) {
    // Aggressively dismiss keyboard before pushing.
    FocusManager.instance.primaryFocus?.unfocus();
    
    Navigator.of(context, rootNavigator: true).push(
      FadePageRoute(
        builder: (context) => ImageViewerPage(
          source: source,
          heroTag: heroTag,
        ),
      ),
    );
  }

  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: widget.path,
      cacheManager: synqCacheManager,
      fit: BoxFit.contain,
      placeholder: (context, url) => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => const SizedBox(
        height: 200,
        child: ImageErrorWidget(iconSize: 32),
      ),
    );
  }

  Widget _buildLocalImage() {
    final displayFile = _fullResLoaded ? _fullRes : _thumbnail;

    if (displayFile == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Image.file(
        displayFile,
        key: ValueKey(_fullResLoaded ? 'full_${widget.path}' : 'thumb_${widget.path}'),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox(
          height: 200,
          child: ImageErrorWidget(iconSize: 32),
        ),
      ),
    );
  }
}

class InlineImageEmbedBuilder extends EmbedBuilder {
  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(
    BuildContext context,
    EmbedContext embedContext,
  ) {
    final path = embedContext.node.value.data as String;
    final widthAttr = embedContext.node.style.attributes['width'];
    final initialWidth = widthAttr?.value?.toDouble() ?? 300.0;
    
    // Use document offset as a stable index for this specific image instance.
    final index = embedContext.node.offset;

    return ResizableInlineImage(
      path: path,
      index: index,
      initialWidth: initialWidth,
      onWidthChanged: (newWidth) {
        final controller = embedContext.controller;
        final node = embedContext.node;
        final offset = node.offset;
        
        controller.formatText(
          offset,
          1,
          Attribute('width', AttributeScope.inline, newWidth.toInt()),
        );
      },
    );
  }
}
