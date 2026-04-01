import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/productivity_utils.dart';
import '../domain/models/activity_event.dart';
import '../../../core/providers/repository_provider.dart';

final clockProvider = Provider<DateTime>((ref) => DateTime.now());

final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = ref.watch(clockProvider);
  return DateTime(now.year, now.month, 1);
});

class PerformanceStats {
  final int totalTasks;
  final int previousMonthTotal;
  final int currentStreak;
  final Map<int, int> heatmapData;
  final ProductivityBucket peakBucket;
  final double improvementPercentage;

  PerformanceStats({
    required this.totalTasks,
    required this.previousMonthTotal,
    required this.currentStreak,
    required this.heatmapData,
    required this.peakBucket,
    required this.improvementPercentage,
  });
}

final activityHistoryProvider = FutureProvider<List<ActivityEvent>>((ref) async {
  final repository = ref.watch(activityRepositoryProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  
  // We fetch a wide range to ensure streaks are calculated correctly
  // Fetch from 2 months ago to the end of next month
  final start = DateTime(selectedMonth.year, selectedMonth.month - 2, 1);
  final end = DateTime(selectedMonth.year, selectedMonth.month + 2, 0);
  
  return repository.getActivityHistory(start: start, end: end);
});

final performanceProvider = Provider<AsyncValue<PerformanceStats>>((ref) {
  final activityAsync = ref.watch(activityHistoryProvider);
  final selectedMonth = ref.watch(selectedMonthProvider);
  final now = ref.watch(clockProvider);

  return activityAsync.whenData((events) {
    // 1. Resolve latest status per task to handle completions/uncompletions
    final latestTaskStatus = <String, ActivityEvent>{};
    for (final event in events) {
      final existing = latestTaskStatus[event.taskId];
      if (existing == null || event.timestamp.isAfter(existing.timestamp)) {
        latestTaskStatus[event.taskId] = event;
      }
    }

    // 2. Filter for currently "Completed" tasks
    final activeCompletions = latestTaskStatus.values
        .where((e) => e.type == ActivityEventType.completed)
        .toList();

    // 3. Define Ranges
    final currentMonthStart = selectedMonth;
    final currentMonthEnd = DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59);
    final previousMonthStart = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
    final previousMonthEnd = DateTime(selectedMonth.year, selectedMonth.month, 0, 23, 59, 59);

    // 4. Filter by Date Ranges
    final currentMonthEvents = activeCompletions.where((e) {
      final localTime = e.timestamp.toLocal();
      return localTime.isAfter(currentMonthStart.subtract(const Duration(seconds: 1))) &&
             localTime.isBefore(currentMonthEnd.add(const Duration(seconds: 1)));
    }).toList();

    final previousMonthEvents = activeCompletions.where((e) {
      final localTime = e.timestamp.toLocal();
      return localTime.isAfter(previousMonthStart.subtract(const Duration(seconds: 1))) &&
             localTime.isBefore(previousMonthEnd.add(const Duration(seconds: 1)));
    }).toList();

    // 5. Heatmap Data
    final heatmapData = <int, int>{};
    for (final e in currentMonthEvents) {
      final day = e.timestamp.toLocal().day;
      heatmapData[day] = (heatmapData[day] ?? 0) + 1;
    }

    // 6. Streak Logic (All active completions ever)
    final allCompletionDates = activeCompletions.map((e) => e.timestamp).toList();
    final currentStreak = StreakCalculator.calculateCurrentStreak(allCompletionDates, now);

    // 7. Productivity Peak
    final currentMonthDates = currentMonthEvents.map((e) => e.timestamp).toList();
    final peakBucket = ProductivityAnalyzer.getPeakBucket(currentMonthDates);

    // 8. Improvement Logic
    double improvement = 0.0;
    if (previousMonthEvents.isNotEmpty) {
      improvement = ((currentMonthEvents.length - previousMonthEvents.length) / previousMonthEvents.length) * 100;
    } else if (currentMonthEvents.isNotEmpty) {
      improvement = 100.0;
    }

    return PerformanceStats(
      totalTasks: currentMonthEvents.length,
      previousMonthTotal: previousMonthEvents.length,
      currentStreak: currentStreak,
      heatmapData: heatmapData,
      peakBucket: peakBucket,
      improvementPercentage: improvement,
    );
  });
});
