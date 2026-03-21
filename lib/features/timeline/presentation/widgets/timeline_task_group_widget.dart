import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/models/timeline_event.dart';

typedef TaskTappedCallback = void Function(TimelineEvent task);
typedef TaskToggleCallback = void Function(TimelineEvent task, bool isCompleted);

class TimelineTaskGroupWidget extends StatelessWidget {
  final TimelineEvent taskGroup;
  final double top;
  final double left;
  final double width;
  final double height;
  final TaskTappedCallback? onTapped;
  final TaskToggleCallback? onToggle;

  const TimelineTaskGroupWidget({
    super.key,
    required this.taskGroup,
    required this.top,
    required this.left,
    required this.width,
    required this.height,
    this.onTapped,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (taskGroup.groupedTasks == null || taskGroup.groupedTasks!.isEmpty) {
      return const SizedBox.shrink();
    }

    final tasks = taskGroup.groupedTasks!;

    // Allow tasks to span the full width of the container
    final maxChipWidth = width;

    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(), // Keeps standard scroll behavior without bouncy overstretch
        child: SizedBox(
          width: width, // Guarantees wrap takes exactly the assigned column bounds
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: tasks.map((task) {
              return _InlineTaskChip(
                task: task,
                maxWidth: maxChipWidth,
                onTapped: onTapped,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _InlineTaskChip  — compact chip that matches Google Calendar task style
// ──────────────────────────────────────────────────────────────────────────────

class _InlineTaskChip extends StatelessWidget {
  final TimelineEvent task;
  final double maxWidth;
  final TaskTappedCallback? onTapped;

  const _InlineTaskChip({
    required this.task,
    required this.maxWidth,
    this.onTapped,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.isCompleted;
    final chipColor = task.color != null
        ? Color(task.color!)
        : const Color(0xFF6B8DEB); // blue for tasks

    return GestureDetector(
      onTap: () => onTapped?.call(task),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth, minWidth: maxWidth),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: isCompleted ? 0.45 : 0.92),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: chipColor.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCompleted
                  ? Icons.check_circle
                  : Icons.check_circle_outline,
              size: 15, // Increased icon size slightly to match bigger text
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.roboto(
                  fontSize: 14, // Increased from 12 to 14
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  decoration: isCompleted
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}