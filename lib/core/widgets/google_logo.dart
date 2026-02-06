import 'package:flutter/material.dart';

class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Official Google Colors
    const blue = Color(0xFF4285F4);
    const red = Color(0xFFEA4335);
    const yellow = Color(0xFFFBBC05);
    const green = Color(0xFF34A853);

    // Scale context to 48x48 coordinate system (standard icon size)
    final scale = size.width / 48.0;
    canvas.scale(scale, scale);

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Path Data (Approximated from standard SVG)
    
    // 1. Blue (Right + Center Bar)
    // M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z
    final Path bluePath = Path();
    bluePath.moveTo(46.98, 24.55);
    bluePath.cubicTo(46.98, 22.98, 46.83, 21.46, 46.6, 20.0);
    bluePath.lineTo(24.0, 20.0);
    bluePath.lineTo(24.0, 29.02);
    bluePath.lineTo(36.94, 29.02);
    bluePath.cubicTo(36.36, 31.98, 34.68, 34.5, 32.16, 36.2);
    bluePath.lineTo(39.89, 42.2);
    bluePath.cubicTo(44.4, 38.02, 46.98, 31.84, 46.98, 24.55);
    bluePath.close();
    paint.color = blue;
    canvas.drawPath(bluePath, paint);

    // 2. Green (Bottom)
    // M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z
    final Path greenPath = Path();
    greenPath.moveTo(24.0, 48.0);
    greenPath.cubicTo(30.48, 48.0, 35.93, 45.87, 39.89, 42.19);
    greenPath.lineTo(32.16, 36.19);
    greenPath.cubicTo(30.01, 37.64, 27.24, 38.49, 24.0, 38.49);
    greenPath.cubicTo(17.74, 38.49, 12.43, 34.27, 10.53, 28.58);
    greenPath.lineTo(2.55, 34.77);
    greenPath.cubicTo(6.51, 42.62, 14.62, 48.0, 24.0, 48.0);
    greenPath.close();
    paint.color = green;
    canvas.drawPath(greenPath, paint);

    // 3. Yellow (Bottom Left to Top Left) (Actually just the left bit normally? No, Yellow is usually bottom left)
    // Actually standard breakdown:
    // Blue: Right
    // Green: Bottom
    // Yellow: Left (bottom)
    // Red: Top (and Left top)
    
    // M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z
    final Path yellowPath = Path();
    yellowPath.moveTo(10.53, 28.59);
    yellowPath.cubicTo(10.05, 27.14, 9.77, 25.6, 9.77, 24.0);
    yellowPath.cubicTo(9.77, 22.41, 10.05, 20.86, 10.53, 19.41);
    yellowPath.lineTo(2.55, 13.22);
    yellowPath.cubicTo(0.92, 16.46, 0.0, 20.12, 0.0, 24.0);
    yellowPath.cubicTo(0.0, 27.88, 0.92, 31.54, 2.56, 34.78);
    yellowPath.lineTo(10.53, 28.59);
    yellowPath.close();
    paint.color = yellow;
    canvas.drawPath(yellowPath, paint);

    // 4. Red (Top)
    // M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z
    final Path redPath = Path();
    redPath.moveTo(24.0, 9.5);
    redPath.cubicTo(27.54, 9.5, 30.71, 10.72, 33.21, 13.1);
    redPath.lineTo(40.06, 6.25);
    redPath.cubicTo(35.9, 2.38, 30.47, 0.0, 24.0, 0.0);
    redPath.cubicTo(14.62, 0.0, 6.51, 5.38, 2.56, 13.22);
    redPath.lineTo(10.54, 19.41);
    redPath.cubicTo(12.43, 13.72, 17.74, 9.5, 24.0, 9.5);
    redPath.close();
    paint.color = red;
    canvas.drawPath(redPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
