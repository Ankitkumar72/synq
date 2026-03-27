import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/timeline_provider.dart';
import '../../../tasks/presentation/pages/overdue_tasks_page.dart';

class SynqDrawer extends ConsumerWidget {
  final bool isOverdueTasksPage;

  const SynqDrawer({super.key, this.isOverdueTasksPage = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(timelineViewModeProvider);

    return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text(
                'Synq Calendar',
                style: GoogleFonts.roboto(
                  color: Colors.black87,
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SynqDrawerItem(
              icon: Icons.view_agenda_outlined,
              title: 'Schedule',
              isSelected: !isOverdueTasksPage && currentMode == TimelineViewMode.schedule,
              onTap: () {
                ref.read(timelineViewModeProvider.notifier).state =
                    TimelineViewMode.schedule;
                Navigator.of(context).pop();
                if (isOverdueTasksPage) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
            SynqDrawerItem(
              icon: Icons.calendar_view_day,
              title: 'Day',
              isSelected: !isOverdueTasksPage && currentMode == TimelineViewMode.daily,
              onTap: () {
                ref.read(timelineViewModeProvider.notifier).state =
                    TimelineViewMode.daily;
                Navigator.of(context).pop();
                if (isOverdueTasksPage) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
            SynqDrawerItem(
              icon: Icons.view_week_outlined,
              title: 'Week',
              isSelected:
                  !isOverdueTasksPage && currentMode == TimelineViewMode.weekly, // Currently sharing view
              onTap: () {
                ref.read(timelineViewModeProvider.notifier).state =
                    TimelineViewMode.weekly;
                Navigator.of(context).pop();
                if (isOverdueTasksPage) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
            SynqDrawerItem(
              icon: Icons.calendar_month_outlined,
              title: 'Month',
              isSelected: !isOverdueTasksPage && currentMode == TimelineViewMode.monthly,
              onTap: () {
                ref.read(timelineViewModeProvider.notifier).state =
                    TimelineViewMode.monthly;
                Navigator.of(context).pop();
                if (isOverdueTasksPage) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      'U',
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'User Name',
                    style: GoogleFonts.roboto(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            SynqDrawerItem(
              icon: Icons.assignment_late_outlined,
              title: 'Overdue Tasks',
              isSelected: isOverdueTasksPage,
              onTap: () {
                Navigator.of(context).pop(); // close drawer only
                if (!isOverdueTasksPage) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OverdueTasksPage()),
                  );
                }
              },
            ),
            SynqDrawerItem(
              icon: Icons.settings_outlined,
              title: 'Settings',
              isSelected: false,
              onTap: () {
                _closeDrawer(context);
              },
            ),
            SynqDrawerItem(
              icon: Icons.help_outline,
              title: 'Help and feedback',
              isSelected: false,
              onTap: () {
                _closeDrawer(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _closeDrawer(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isEndDrawerOpen == true || scaffold?.isDrawerOpen == true) {
      Navigator.pop(context);
    }
  }
}

class SynqDrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const SynqDrawerItem({
    super.key,
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
      child: Material(
        color: isSelected ? const Color(0xFFE8EFFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFF1E3A8A) : Colors.black54,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: GoogleFonts.roboto(
                    color: isSelected ? const Color(0xFF1E3A8A) : Colors.black87,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
