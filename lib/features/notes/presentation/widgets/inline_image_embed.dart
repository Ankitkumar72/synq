import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../attachments/data/image_storage_service.dart';

class ResizableInlineImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isUrl = path.startsWith('http');
    final isLocal = path.startsWith(ImageStorageService.localScheme);
    final isRawFile = path.startsWith('/') || path.contains(':\\'); // Simple path check

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16), // Zen vertical spacing
      width: double.infinity,
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12), // Subtle premium roundness
        child: isUrl
            ? CachedNetworkImage(
                imageUrl: path,
                fit: BoxFit.contain,
                placeholder: (context, url) => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) => const SizedBox(
                  height: 200,
                  child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
                ),
              )
            : (isLocal || isRawFile) 
                ? FutureBuilder<File>(
                    future: isLocal 
                        ? ImageStorageService.getFile(path, useThumbnail: false)
                        : Future.value(File(path)),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData || (snapshot.data != null && !snapshot.data!.existsSync())) {
                        return const SizedBox(
                          height: 200,
                          child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
                        );
                      }
                      return Image.file(
                        snapshot.data!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          height: 200,
                          child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
                        ),
                      );
                    },
                  )
                : const SizedBox(
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
        
        // Update the width attribute in the Quill Delta
        controller.formatText(
          offset,
          1,
          Attribute('width', AttributeScope.inline, newWidth.toInt()),
        );
      },
    );
  }
}
