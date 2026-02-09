import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

class CircularTimer extends StatelessWidget {
  final String formattedTime;
  final double progress;

  const CircularTimer({
    super.key,
    required this.formattedTime,
    this.progress = 0.0,
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
        // Progress Ring
        if (progress > 0)
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        // Timer Text
        Text(
          formattedTime,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 64,
                fontWeight: FontWeight.normal,
                fontFamily: GoogleFonts.robotoMono().fontFamily, // Monospace for numbers
                letterSpacing: -2,
                color: Colors.black,
              ),
        ),
      ],
    );
  }
}
