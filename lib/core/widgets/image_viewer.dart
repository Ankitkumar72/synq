import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vector_math/vector_math_64.dart' show Vector4;

class ImageViewerPage extends StatefulWidget {
  final String imageUrl;
  final String heroTag;

  const ImageViewerPage({
    required this.imageUrl,
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

    // Enter immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    // Restore system UI mode
    if (mounted) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
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

    if (_transformationController.value != Matrix4.identity()) {
      end = Matrix4.identity();
    } else {
      // Zoom 2.5x
      final double zoom = 2.5;
      
      // We want to zoom into the center of the screen
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

  // Helper for better curve selection syntax
  Animation<double> _curveSelection(Curve curve) => 
      _animationController.drive(CurveTween(curve: curve));

  @override
  Widget build(BuildContext context) {
    final bool isNetwork = widget.imageUrl.startsWith('http');
    final double opacity = (1.0 - (_dragOffset.abs() / 600)).clamp(0.0, 1.0);
    final double scale = (1.0 - (_dragOffset.abs() / 1500)).clamp(0.8, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: opacity),
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() => _dragOffset += details.primaryDelta!);
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset.abs() > 150 || details.primaryVelocity!.abs() > 300) {
            Navigator.of(context).pop();
          } else {
            setState(() {
              _dragOffset = 0;
            });
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
                        child: isNetwork
                            ? CachedNetworkImage(
                                imageUrl: widget.imageUrl,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                                errorWidget: (context, url, error) => const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.broken_image, color: Colors.white, size: 64),
                                    SizedBox(height: 16),
                                    Text('Media load failed', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              )
                            : Image.file(
                                File(widget.imageUrl),
                                fit: BoxFit.contain,
                              ),
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
    );
  }
}

// Custom Tween for Matrix4 integration
class Matrix4Tween extends Tween<Matrix4> {
  Matrix4Tween({super.begin, super.end});

  @override
  Matrix4 lerp(double t) {
    // Custom Matrix4 interpolation logic could go here for rotations etc.
    // For simple scale/translate, a basic lerp is often enough if well-constructed.
    // However, Matrix4.identity() vs scale is tricky if not component-wise.
    // For now, we use a basic lerp which works well for these simple transforms.
    final Matrix4 beginValue = begin ?? Matrix4.identity();
    final Matrix4 endValue = end ?? Matrix4.identity();

    final Vector4 beginCol0 = beginValue.getRow(0);
    final Vector4 endCol0 = endValue.getRow(0);
    final Vector4 beginCol1 = beginValue.getRow(1);
    final Vector4 endCol1 = endValue.getRow(1);
    final Vector4 beginCol2 = beginValue.getRow(2);
    final Vector4 endCol2 = endValue.getRow(2);
    final Vector4 beginCol3 = beginValue.getRow(3);
    final Vector4 endCol3 = endValue.getRow(3);

    final Vector4 v0 = _lerpVector(beginCol0, endCol0, t);
    final Vector4 v1 = _lerpVector(beginCol1, endCol1, t);
    final Vector4 v2 = _lerpVector(beginCol2, endCol2, t);
    final Vector4 v3 = _lerpVector(beginCol3, endCol3, t);

    return Matrix4.fromList([
      v0.x, v0.y, v0.z, v0.w,
      v1.x, v1.y, v1.z, v1.w,
      v2.x, v2.y, v2.z, v2.w,
      v3.x, v3.y, v3.z, v3.w,
    ]);
  }

  Vector4 _lerpVector(Vector4 b, Vector4 e, double t) {
    return Vector4(
      b.x + (e.x - b.x) * t,
      b.y + (e.y - b.y) * t,
      b.z + (e.z - b.z) * t,
      b.w + (e.w - b.w) * t,
    );
  }
}
