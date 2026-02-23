import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../notes/domain/models/note.dart';

class DailyScheduleCard extends StatelessWidget {
  final DateTime date;
  final List<Note> tasks;
  final VoidCallback onTap;

  const DailyScheduleCard({
    super.key,
    required this.date,
    required this.tasks,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasTasks = tasks.isNotEmpty;
    final dayOfWeek = DateFormat('E').format(date).toUpperCase();
    final dayNum = date.day.toString();
    
    // Determine title and subtitle
    String title = 'Free Day';
    if (hasTasks) {
      if (tasks.length == 1) {
        title = tasks.first.title;
      } else {
        // Find category if possible or just use first task title
        title = tasks.first.title;
      }
    }
    
    final completedTasks = tasks.where((t) => t.isCompleted == true).length;
    final totalTasks = tasks.length;
    
    String subtitle;
    if (!hasTasks) {
      subtitle = 'No tasks scheduled';
    } else if (completedTasks == totalTasks) {
      subtitle = 'All tasks completed';
    } else if (completedTasks > 0) {
      subtitle = '$completedTasks task${completedTasks > 1 ? 's' : ''} completed, $totalTasks scheduled';
    } else {
      subtitle = '$totalTasks task${totalTasks > 1 ? 's' : ''} scheduled';
    }
        
    final dotColor = (hasTasks && completedTasks == totalTasks) 
        ? Colors.green 
        : (hasTasks ? const Color(0xFF6B58F5) : const Color(0xFFD1D5DB));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            // Date Circle
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayOfWeek,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF8A93A4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dayNum,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E1E1E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            
            // Text Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hasTasks ? const Color(0xFF1E1E1E) : const Color(0xFF8A93A4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF8A93A4),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            
            // Action Button
            if (hasTasks)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF6B58F5),
                  size: 20,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEBFF), // Light purple
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Plan',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6B58F5), // Deep purple
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
