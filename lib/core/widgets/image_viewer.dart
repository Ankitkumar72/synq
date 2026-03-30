import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:synq/core/domain/models/image_source.dart';
import 'package:synq/core/services/cache_manager.dart';
import 'package:synq/core/widgets/image_error_widget.dart';

/// Pure function to determine if the viewer can be dismissed via swipe.
/// We allow dismissal only when the image is not significantly zoomed.
bool getCanDismiss(TransformationController controller) {
  final Matrix4 matrix = controller.value;
  // Get the maximum scale on any axis (usually X/Y are same).
  // If the scale is very close to 1.0 (identity), we allow dismissal.
  final double scale = matrix.getMaxScaleOnAxis();
  return (scale - 1.0).abs() < 0.01;
}

class ImageViewerPage extends StatefulWidget {
  final ImageSource source;
  final String heroTag;

  const ImageViewerPage({
    required this.source,
    required this.heroTag,
    super.key,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });

    // Aggressive System UI hiding for immersive media viewing.
    _enterImmersiveMode();
  }

  void _enterImmersiveMode() {
    // 1. Force the app to draw under the system navigation bar and status bar.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // 2. Hide the bars immediately but allow them to "stick" into view with a swipe.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // 3. Ensure the bar backgrounds are transparent so they don't cover part of the image.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false, // Essential for some Android skins like MIUI
    ));
  }

  @override
  void dispose() {
    // Restore system UI mode to "edge-to-edge" with standard theme colors (dark icons for light notes).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onDoubleTapDown(TapDownDetails details) {
    _animationController.stop();
  }

  void _onDoubleTap() {
    final Matrix4 begin = _transformationController.value;
    final Matrix4 end;

    // Use the same precision threshold for double-tap toggle
    if (!getCanDismiss(_transformationController)) {
      end = Matrix4.identity();
    } else {
      const double zoom = 2.5;
      final double x = MediaQuery.of(context).size.width / 2;
      final double y = MediaQuery.of(context).size.height / 2;
      
      end = Matrix4.identity()
        ..translateByDouble(x, y, 0.0, 0.0)
        ..scaleByDouble(zoom, zoom, 1.0, 1.0)
        ..translateByDouble(-x, -y, 0.0, 0.0);
    }

    _animation = Matrix4Tween(begin: begin, end: end).animate(
      _curveSelection(Curves.easeInOut),
    );
    _animationController.forward(from: 0);
  }

  Animation<double> _curveSelection(Curve curve) => 
      _animationController.drive(CurveTween(curve: curve));

  @override
  Widget build(BuildContext context) {
    final double opacity = (1.0 - (_dragOffset.abs() / 600)).clamp(0.0, 1.0);
    final double scale = (1.0 - (_dragOffset.abs() / 1500)).clamp(0.8, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: opacity),
      resizeToAvoidBottomInset: false,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        // Re-enforce overlay style in build to handle some platform EdgeCases
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarContrastEnforced: false,
        ),
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              // Only allow drag-to-dismiss if the image is not zoomed.
              if (getCanDismiss(_transformationController)) {
                setState(() => _dragOffset += details.primaryDelta!);
              }
            },
            onVerticalDragEnd: (details) {
              if (_dragOffset.abs() > 150 || (details.primaryVelocity?.abs() ?? 0) > 300) {
                Navigator.of(context).pop();
              } else {
                setState(() => _dragOffset = 0);
              }
            },
            child: Stack(
              children: [
                Center(
                  child: Transform.translate(
                    offset: Offset(0, _dragOffset),
                    child: Transform.scale(
                      scale: scale,
                      child: Hero(
                        tag: widget.heroTag,
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: GestureDetector(
                            onDoubleTapDown: _onDoubleTapDown,
                            onDoubleTap: _onDoubleTap,
                            child: _buildImageSource(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Close Button
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSource() {
    final source = widget.source;
    if (source is NetworkImageSource) {
      return CachedNetworkImage(
        imageUrl: source.url,
        cacheManager: synqCacheManager,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        errorWidget: (context, url, error) => ImageErrorWidget(
          message: 'Failed to load network image',
          onRetry: () => setState(() {}),
        ),
      );
    } else if (source is FileImageSource) {
      return Image.file(
        File(source.filePath),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const ImageErrorWidget(
          message: 'Local file is missing or corrupted',
        ),
      );
    } else if (source is MemoryImageSource) {
      return Image.memory(
        source.bytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const ImageErrorWidget(
          message: 'Failed to render memory image',
        ),
      );
    }
    return const ImageErrorWidget(message: 'Unknown image source type');
  }
}

class Matrix4Tween extends Tween<Matrix4> {
  Matrix4Tween({super.begin, super.end});

  @override
  Matrix4 lerp(double t) {
    final Matrix4 beginValue = begin ?? Matrix4.identity();
    final Matrix4 endValue = end ?? Matrix4.identity();
    
    // Simplistic interpolation for components. 
    // Works well for scale/translate combinations in this viewer.
    final List<double> beginList = beginValue.storage;
    final List<double> endList = endValue.storage;
    final List<double> resultList = List<double>.filled(16, 0.0);
    
    for (int i = 0; i < 16; i++) {
      resultList[i] = beginList[i] + (endList[i] - beginList[i]) * t;
    }
    
    return Matrix4.fromList(resultList);
  }
}
