import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../attachments/data/image_storage_service.dart';
import '../../../../core/widgets/image_viewer.dart';

class ResizableInlineImage extends StatefulWidget {
  final String path;
  final double initialWidth;
  final Function(double)? onWidthChanged;

  const ResizableInlineImage({
    required this.path,
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

    final isUrl = currentPath.startsWith('http');
    if (isUrl) return;

    // Stage 1: Load thumbnail immediately (fast & sharp at 1024px)
    try {
      final thumb = await ImageStorageService.getFile(
        currentPath,
        useThumbnail: true,
      );
      if (mounted && currentPath == widget.path) {
        setState(() {
          _thumbnail = thumb;
          // Don't reset _fullResLoaded yet if we are just updating
        });
      }
    } catch (e) {
      debugPrint('Error loading thumbnail: $e');
    }

    // Stage 2: Load full-res in background, swap when ready
    try {
      final full = await ImageStorageService.getFile(
        currentPath,
        useThumbnail: false,
      );
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

  @override
  Widget build(BuildContext context) {
    final isUrl = widget.path.startsWith('http');
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      width: double.infinity,
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: isUrl
            ? GestureDetector(
                onTap: () => _openFullscreen(context),
                child: Hero(
                  tag: 'image_viewer_${widget.path.hashCode}_${widget.key}',
                  child: CachedNetworkImage(
                    imageUrl: widget.path,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => const SizedBox(
                      height: 200,
                      child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
                    ),
                  ),
                ),
              )
            : GestureDetector(
                onTap: () => _openFullscreen(context),
                child: Hero(
                  tag: 'image_viewer_${widget.path.hashCode}_${widget.key}',
                  child: _buildLocalImage(),
                ),
              ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageViewerPage(
          imageUrl: widget.path,
          heroTag: 'image_viewer_${widget.path.hashCode}_${widget.key}',
        ),
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

    if (!displayFile.existsSync()) {
      return const SizedBox(
        height: 200,
        child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
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
          child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
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

    return ResizableInlineImage(
      path: path,
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
