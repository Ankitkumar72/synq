import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../notes/domain/models/note.dart';
import '../../../notes/data/notes_provider.dart';

class ViewEventPage extends ConsumerWidget {
  final Note event;

  const ViewEventPage({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the event from the provider to get updates
    final notes = ref.watch(notesProvider).value;
    final currentEvent =
        notes?.firstWhere(
          (n) => n.id == event.id,
          orElse: () => event,
        ) ??
        event;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: _buildCompleteButton(ref, currentEvent),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.black),
            onPressed: () => _showDeleteDialog(context, ref, currentEvent),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title with Color Block
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentEvent.color != null)
                    Container(
                      width: 12,
                      height: 38,
                      margin: const EdgeInsets.only(top: 4, right: 16),
                      decoration: BoxDecoration(
                        color: Color(currentEvent.color!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      currentEvent.title,
                      style: GoogleFonts.roboto(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Date/Time Block
              _buildDateTimeSection(currentEvent),
              const SizedBox(height: 32),

              // Description Label
              Text(
                'DESCRIPTION',
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),

              // Description Box
              _buildDescriptionBox(currentEvent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteButton(WidgetRef ref, Note event) {
    final isCompleted = event.isCompleted;
    return GestureDetector(
      onTap: () {
        ref.read(notesProvider.notifier).toggleCompleted(event.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF5372F6),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (isCompleted ? const Color(0xFF10B981) : const Color(0xFF5372F6))
                  .withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.circle_outlined,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              isCompleted ? 'Completed' : 'Complete Event',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSection(Note event) {
    final dateStr =
        event.scheduledTime != null
            ? DateFormat('MMM d, yyyy').format(event.scheduledTime!)
            : 'No date';
    final startTimeStr =
        event.scheduledTime != null
            ? DateFormat('h:mm a').format(event.scheduledTime!)
            : '';
    final endTimeStr =
        event.endTime != null ? DateFormat('h:mm a').format(event.endTime!) : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 20,
                color: Color(0xFF5372F6),
              ),
              const SizedBox(width: 10),
              Text(
                dateStr,
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 20, color: Color(0xFF5372F6)),
              const SizedBox(width: 10),
              Text(
                event.isAllDay ? 'All Day' : '$startTimeStr - $endTimeStr',
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionBox(Note event) {
    final hasBody = event.body?.isNotEmpty == true;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: Text(
        hasBody ? event.body! : 'Add details or notes...',
        style: GoogleFonts.roboto(
          fontSize: 15,
          color: hasBody ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
          height: 1.5,
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Note event) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Event'),
            content: const Text('Are you sure you want to delete this event?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  ref.read(notesProvider.notifier).deleteNote(event.id);
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // close view page
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}
