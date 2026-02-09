import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class WaveformGraph extends StatefulWidget {
  const WaveformGraph({super.key});

  @override
  State<WaveformGraph> createState() => _WaveformGraphState();
}

class _WaveformGraphState extends State<WaveformGraph> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "FOCUS QUALITY",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Live",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ],
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: WavePainter(animationValue: _controller.value),
                  child: Container(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;
  WavePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF66C2A5) // Soft Green/Teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final paintOverlay = Paint()
      ..color = const Color(0xFF66C2A5).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    _drawWave(canvas, size, paint, 1.0, 0.0);
    _drawWave(canvas, size, paintOverlay, 0.8, 0.5); // Second slightly offset wave
  }

  void _drawWave(Canvas canvas, Size size, Paint paint, double amplitudeFactor, double phaseShift) {
    final path = Path();
    final midY = size.height * 0.7;
    
    path.moveTo(0, midY);

    for (double x = 0; x <= size.width; x += 2) {
      // Multiple sine waves combined for "random" look
      final wave1 = math.sin((x / size.width * 2 * math.pi) + (animationValue * 2 * math.pi) + phaseShift);
      final wave2 = math.sin((x / size.width * 4 * math.pi) - (animationValue * 3 * math.pi));
      
      final y = midY + (wave1 * 15 * amplitudeFactor) + (wave2 * 10 * amplitudeFactor);
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) => 
      oldDelegate.animationValue != animationValue;
}
