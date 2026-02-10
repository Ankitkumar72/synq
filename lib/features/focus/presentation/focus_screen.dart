import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../home/presentation/providers/current_focus_provider.dart';
import 'widgets/circular_timer.dart';
import 'widgets/waveform_graph.dart';

class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusAsync = ref.watch(currentFocusProvider);
    final progress = ref.watch(currentFocusProgressProvider);
    final timeRemaining = ref.watch(currentFocusTimeRemainingProvider);
    
    final task = focusAsync.value;
    
    final now = DateTime.now();
    final wallClockTime = DateFormat('HH:mm:ss').format(now);

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
          data: (task) => Padding(
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
                const Spacer(),
                
                // Task Title
                Text(
                  task?.title ?? "Free Time",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                ),
                const Spacer(),
                
                // Timer
                SizedBox(
                  height: 300,
                  width: 300,
                  child: CircularTimer(
                    formattedTime: (task != null && task.endTime != null) 
                        ? timeRemaining 
                        : wallClockTime,
                    progress: (task != null && task.endTime != null) ? progress : 0.0,
                  ),
                ),
                const Spacer(),
                
                // Waveform
                const SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: WaveformGraph(),
                ),
                const Spacer(),
                
                // End Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
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
                const SizedBox(height: 32),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
      ),
      ),
    );
  }
}
