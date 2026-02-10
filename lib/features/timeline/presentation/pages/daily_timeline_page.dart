import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'daily_timeline_content.dart';

class DailyTimelinePage extends ConsumerWidget {
  const DailyTimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DailyTimelineContent();
  }
}
