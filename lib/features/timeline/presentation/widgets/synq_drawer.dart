import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/timeline_provider.dart';

class SynqDrawer extends ConsumerWidget {
  const SynqDrawer({super.key});

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
            _buildDrawerItem(
              context,
              icon: Icons.view_agenda_outlined,
              title: 'Schedule',
              isSelected: currentMode == TimelineViewMode.schedule,
              onTap: () {
                ref.read(timelineViewModeProvider.notifier).state = TimelineViewMode.schedule;
                _closeDrawer(context);
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.calendar_view_day,
              title: 'Day',
              isSelected: currentMode == TimelineViewMode.daily,
              onTap: () {
                ref.read(timelineViewModeProvider.notifier).state = TimelineViewMode.daily;
                _closeDrawer(context);
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.view_week_outlined,
              title: 'Week',
              isSelected: currentMode == TimelineViewMode.weekly, // Currently sharing view
              onTap: () {
                ref.read(timelineViewModeProvider.notifier).state = TimelineViewMode.weekly;
                _closeDrawer(context);
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.calendar_month_outlined,
              title: 'Month',
              isSelected: currentMode == TimelineViewMode.monthly,
              onTap: () {
                ref.read(timelineViewModeProvider.notifier).state = TimelineViewMode.monthly;
                _closeDrawer(context);
              },
            ),
            _buildDrawerItem(
              context,
              icon: Icons.refresh,
              title: 'Refresh',
              isSelected: false,
              onTap: () {
                _closeDrawer(context);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary,
                    child: Text('U', style: GoogleFonts.roboto(color: Colors.white, fontSize: 14)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'User Name',
                    style: GoogleFonts.roboto(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                ],
              ),
            ),
            _buildCheckboxItem(
              context,
              color: Colors.blue,
              title: 'Tasks',
              isChecked: true,
              onTap: () {},
            ),
            _buildCheckboxItem(
              context,
              color: Colors.purple,
              title: 'Todo',
              isChecked: true,
              onTap: () {},
            ),
            _buildDrawerItem(
              context,
              icon: Icons.settings_outlined,
              title: 'Settings',
              isSelected: false,
              onTap: () {
                _closeDrawer(context);
              },
            ),
            _buildDrawerItem(
              context,
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
    if (Scaffold.maybeOf(context)?.isEndDrawerOpen ?? false) {
      Navigator.pop(context);
    } else if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    } else {
      Navigator.pop(context); // Fallback
    }
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
      child: Material(
        color: isSelected ? const Color(0xFFE8EFFF) : Colors.transparent, // Highlight color
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? const Color(0xFF1E3A8A) : Colors.black54, // Icon color
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: GoogleFonts.roboto(
                    color: isSelected ? const Color(0xFF1E3A8A) : Colors.black87, // Text color
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

  Widget _buildCheckboxItem(
    BuildContext context, {
    required Color color,
    required String title,
    required bool isChecked,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Row(
              children: [
                Icon(
                  isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: GoogleFonts.roboto(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
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
