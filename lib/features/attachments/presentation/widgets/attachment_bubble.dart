import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/image_storage_service.dart';

class AttachmentBubble extends StatefulWidget {
  final String filename;
  final String userId; // 👈 userId now required
  final VoidCallback onDelete;
  final Function(String)? onMigrated;

  final double? width;
  final double? height;

  const AttachmentBubble({
    super.key,
    required this.filename,
    required this.userId,
    required this.onDelete,
    this.onMigrated,
    this.width = 120,
    this.height = 120,
  });


  @override
  State<AttachmentBubble> createState() => _AttachmentBubbleState();
}

class _AttachmentBubbleState extends State<AttachmentBubble> {
  bool _isMigrating = false;

  Future<void> _migrateToCloud() async {
    if (_isMigrating) return;
    setState(() => _isMigrating = true);

    try {
      final file = await ImageStorageService.getFile(widget.filename);
      // Generate a migration-specific noteId if none available
      final noteId = 'migrated_${DateTime.now().millisecondsSinceEpoch}';
      final task = ImageStorageService.uploadImage(file, widget.userId, noteId);
      final snapshot = await task;
      final url = await snapshot.ref.getDownloadURL();
      
      if (widget.onMigrated != null) {
        widget.onMigrated!(url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Migration failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isMigrating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUrl = widget.filename.startsWith('http');
    final isLocal = widget.filename.startsWith(ImageStorageService.localScheme);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: widget.width,
          height: widget.height ?? 200, // Default to 200 if null to avoid Infinity
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
          child: Stack(
            fit: StackFit.loose, // Loose is safer in unconstrained parents
            children: [
              Positioned.fill( // Use Positioned.fill to mimic 'expand' but only within the bounded Container
                child: isUrl
                    ? CachedNetworkImage(
                        imageUrl: widget.filename,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      )
                    : FutureBuilder<File>(
                        future: ImageStorageService.getFile(widget.filename, useThumbnail: true),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                          }
                          if (snapshot.hasError || !snapshot.hasData) {
                            return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
                          }
                          return Image.file(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => 
                                const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                          );
                        },
                      ),
              ),
              if (isLocal)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: _isMigrating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : GestureDetector(
                            onTap: _migrateToCloud,
                            child: const Icon(
                              Icons.cloud_off_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
        // Close / Delete button
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: widget.onDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  const BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}


