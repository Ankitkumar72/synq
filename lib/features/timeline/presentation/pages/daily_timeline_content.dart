import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/timeline_provider.dart';
import '../widgets/calendar_selector.dart';
import '../widgets/timeline_connector.dart';
import '../widgets/timeline_task_card.dart';
import '../../../home/presentation/widgets/create_task_sheet.dart';


/// Timeline page content without bottom navigation bar (for use in MainShell)
class DailyTimelineContent extends ConsumerWidget {
  const DailyTimelineContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(timelineEventsProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    
    final isMonthly = ref.watch(calendarViewProvider);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isMonthly 
          ? null 
          : FloatingActionButton(
              onPressed: () => showCreateTaskSheet(context, initialDate: selectedDate),
              backgroundColor: AppColors.primary,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            children: [
              isMonthly ? const Expanded(child: CalendarSelector()) : const CalendarSelector(),
              if (!isMonthly)
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatSelectedDate(selectedDate),
                                    style: GoogleFonts.inter(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${events.length} tasks scheduled • 3.5h focus time', // Mocked focus time for design
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.calendar_today_outlined, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (events.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.beach_access, size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  'No tasks today — enjoy your free time!',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final event = events[index];
                                final isLast = index == events.length - 1;

                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Time Column
                                      SizedBox(
                                        width: 60,
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                event.startTime.split(' ')[0],
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: event.isCurrent ? AppColors.primary : AppColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                event.startTime.split(' ').length > 1 ? event.startTime.split(' ')[1] : '',
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Timeline Connector
                                      TimelineConnector(
                                        isLast: isLast,
                                        isActive: event.isCurrent,
                                      ),

                                      // Task Card
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
                                          child: TimelineTaskCard(
                                            title: event.title,
                                            subtitle: event.subtitle,
                                            timeRange: '${event.startTime} - ${event.endTime}',
                                            type: TaskType.values.byName(event.type.name),
                                            tag: event.tag,
                                            isCompleted: event.isCompleted,
                                            onToggleCompletion: (_) {
                                              ref.read(timelineEventsProvider.notifier).toggleEventCompletion(event.id);
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              childCount: events.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSelectedDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return DateFormat("EEEE, d'th'").format(date); // Simplified suffix logic for design
    }
    return DateFormat("EEEE, d'th'").format(date);
  }
}

