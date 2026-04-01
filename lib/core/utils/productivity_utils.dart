enum ProductivityBucket { morning, afternoon, evening, night, varied }

class ProductivityAnalyzer {
  static ProductivityBucket getPeakBucket(List<DateTime> completionDates) {
    if (completionDates.length < 3) return ProductivityBucket.varied;

    final counts = <ProductivityBucket, int>{
      ProductivityBucket.morning: 0,
      ProductivityBucket.afternoon: 0,
      ProductivityBucket.evening: 0,
      ProductivityBucket.night: 0,
    };

    for (final date in completionDates) {
      final hour = date.toLocal().hour;
      if (hour >= 6 && hour < 12) {
        counts[ProductivityBucket.morning] = (counts[ProductivityBucket.morning] ?? 0) + 1;
      } else if (hour >= 12 && hour < 17) {
        counts[ProductivityBucket.afternoon] = (counts[ProductivityBucket.afternoon] ?? 0) + 1;
      } else if (hour >= 17 && hour < 21) {
        counts[ProductivityBucket.evening] = (counts[ProductivityBucket.evening] ?? 0) + 1;
      } else {
        counts[ProductivityBucket.night] = (counts[ProductivityBucket.night] ?? 0) + 1;
      }
    }

    final maxEntries = counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    
    // Fallback if the peak bucket doesn't represent at least 30% of total
    if (maxEntries.value / completionDates.length < 0.3) {
      return ProductivityBucket.varied;
    }

    return maxEntries.key;
  }

  static String getDescription(ProductivityBucket bucket) {
    switch (bucket) {
      case ProductivityBucket.morning:
        return "mornings";
      case ProductivityBucket.afternoon:
        return "afternoons";
      case ProductivityBucket.evening:
        return "evenings";
      case ProductivityBucket.night:
        return "nights";
      case ProductivityBucket.varied:
        return "varied times";
    }
  }
}

class StreakCalculator {
  static int calculateCurrentStreak(List<DateTime> completionDates, DateTime now) {
    if (completionDates.isEmpty) return 0;

    final localNow = now.toLocal();
    final today = _toDateOnly(localNow);
    final yesterday = today.subtract(const Duration(days: 1));

    final completedDates = completionDates
        .map((d) => _toDateOnly(d.toLocal()))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (completedDates.isEmpty) return 0;

    final latestDate = completedDates.first;

    // A streak is broken if the latest completion is before yesterday
    if (latestDate.isBefore(yesterday)) {
      return 0;
    }

    int streak = 0;
    DateTime currentCheck = latestDate;

    // If latest completion is today or yesterday, we can start counting
    for (final date in completedDates) {
      if (date == currentCheck) {
        streak++;
        currentCheck = currentCheck.subtract(const Duration(days: 1));
      } else if (date.isBefore(currentCheck)) {
        // Found a gap
        break;
      }
    }

    return streak;
  }

  static DateTime _toDateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }
}
