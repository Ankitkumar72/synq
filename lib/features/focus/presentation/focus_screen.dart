import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../home/presentation/providers/current_focus_provider.dart';
import '../../notes/domain/models/note.dart';
import 'widgets/circular_timer.dart';
import 'widgets/waveform_graph.dart';
import 'session_complete_screen.dart';
import '../../notes/data/notes_provider.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  bool _hasCompletedSession = false;
  Note? _cachedTask;

  void _completeSession(Note task) {
    if (_hasCompletedSession) return;
    _hasCompletedSession = true;

    try {
      ref.read(notesProvider.notifier).toggleCompleted(task.id);
    } catch (e) {
      // Ignore error if already completed
    }
    
    String timeStr = '00:00';
    if (task.scheduledTime != null) {
      final elapsed = DateTime.now().difference(task.scheduledTime!);
      // If elapsed is negative, task hasn't started yet
      if (!elapsed.isNegative) {
        final hours = elapsed.inHours;
        final minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
        timeStr = hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SessionCompleteScreen(
          taskName: task.title,
          timeFocused: timeStr,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final focusAsync = ref.watch(currentFocusProvider);
    final progress = ref.watch(currentFocusProgressProvider);
    final timeRemaining = ref.watch(currentFocusTimeRemainingProvider);
    
    // Cache the task so we don't instantly lose it when the timer hits zero
    // (since currentFocusProvider will yield null as soon as now > endTime)
    if (focusAsync.value != null) {
      _cachedTask = focusAsync.value;
    }
    
    final task = _cachedTask;
    
    final now = DateTime.now();
    final wallClockTime = DateFormat('HH:mm:ss').format(now);

    // Check if task time is up and we haven't completed it yet
    if (task != null && task.endTime != null && !_hasCompletedSession) {
      if (now.isAfter(task.endTime!) || now.isAtSameMomentAs(task.endTime!)) {
        // Use addPostFrameCallback to perform navigation after the layout phase
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _completeSession(task);
            }
        });
      }
    }

    return PopScope(
      canPop: task == null || !task.isActive,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && task != null && task.isActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please use the End Session button to exit.'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              width: 280,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
        child: focusAsync.when(
          data: (_) => Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      
                      // Top Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              task != null ? Icons.auto_awesome : Icons.bed, 
                              size: 16, 
                              color: task != null ? AppColors.success : AppColors.textSecondary
                            ),
                            const SizedBox(width: 8),
                            Text(
                              task != null 
                                ? "${task.category.name.toUpperCase()} FOCUS" 
                                : "No Active Task",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Task Title
                      Text(
                        task?.title ?? "Free Time",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                      ),
                      const SizedBox(height: 48),
                      
                      // Timer
                      SizedBox(
                        height: MediaQuery.of(context).size.width * 0.7, // Responsive sizing
                        width: MediaQuery.of(context).size.width * 0.7,
                        child: CircularTimer(
                          formattedTime: (task != null && task.endTime != null) 
                              ? timeRemaining 
                              : wallClockTime,
                          progress: (task != null && task.endTime != null) ? progress : 0.0,
                        ),
                      ),
                      const SizedBox(height: 48),
                      
                      // Waveform
                      const SizedBox(
                        height: 80, // Slightly reduced to fit better
                        width: double.infinity,
                        child: WaveformGraph(),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              
              // End Button (Fixed at bottom)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (task != null) {
                        _completeSession(task);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "End Session",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // We use task instead of focusAsync.value to maintain the cached state
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
      ),
    );
  }
}
