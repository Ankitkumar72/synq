import 'package:flutter/material.dart';
import '../widgets/timeline_header.dart';
import '../widgets/timeline_hour_blocks.dart';
import '../../../../core/theme/app_theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/timeline_provider.dart';
import '../../../home/presentation/widgets/create_new_sheet.dart';

class DailyTimelinePage extends ConsumerStatefulWidget {
  const DailyTimelinePage({super.key});

  @override
  ConsumerState<DailyTimelinePage> createState() => _DailyTimelinePageState();
}

class _DailyTimelinePageState extends ConsumerState<DailyTimelinePage> {
  @override
  Widget build(BuildContext context) {
    final events = ref.watch(timelineEventsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            TimelineHeader(
              remainingTasks: events.where((e) => !e.isCompleted).length,
              date: DateTime.now(),
            ),
            const Expanded(
              child: TimelineHourBlocks(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateNewSheet(context),
        backgroundColor: AppColors.accentPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
