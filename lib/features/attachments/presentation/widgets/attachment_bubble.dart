import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/image_storage_service.dart';

class AttachmentBubble extends StatelessWidget {
  final String filename;
  final VoidCallback onDelete;

  final double? width;
  final double? height;

  const AttachmentBubble({
    super.key,
    required this.filename,
    required this.onDelete,
    this.width = 120,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: width,
          height: height,
          constraints: height == null ? const BoxConstraints(minHeight: 120) : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: FutureBuilder<File>(
            future: ImageStorageService.getFile(filename),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
              }
              return Image.file(
                snapshot.data!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => 
                    const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
              );
            },
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }
}
