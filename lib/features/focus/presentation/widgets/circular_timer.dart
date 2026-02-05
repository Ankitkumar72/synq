import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

class CircularTimer extends StatelessWidget {
  final Duration duration;
  final Duration remaining;

  const CircularTimer({
    super.key,
    required this.duration,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background Circle (Soft)
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.background,
          ),
        ),
        // Timer Text
        Text(
          "${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}",
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 64,
                fontWeight: FontWeight.normal,
                fontFamily: GoogleFonts.robotoMono().fontFamily, // Monospace for numbers
                letterSpacing: -2,
              ),
        ),
      ],
    );
  }
}
