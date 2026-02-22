import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../pages/weekly_focus_screen.dart';
import '../../data/weekly_focus_provider.dart';

class WeeklyFocusCard extends ConsumerWidget {
  const WeeklyFocusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusState = ref.watch(weeklyFocusProvider);
    final completedCount = focusState.criteriaStatus.where((c) => c).length;
    final totalCount = focusState.criteriaStatus.length;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WeeklyFocusScreen()),
        );
      },
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA), // Light grey matching design
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFEEEBFF), // Light purple
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Color(0xFF6B58F5), // Deep purple flag
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Weekly Focus',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            focusState.objective.isEmpty ? 'Tap to set your weekly focus' : focusState.objective,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: focusState.objective.isEmpty ? const Color(0xFFC4B5FD) : const Color(0xFF8A93A4), // Lighter color if empty
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (focusState.priority.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    focusState.priority,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF8A93A4),
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              Text(
                '$completedCount/$totalCount completed',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF8A93A4),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}
