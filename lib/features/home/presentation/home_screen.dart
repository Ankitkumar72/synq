import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import 'widgets/current_focus_card.dart';
import 'widgets/next_up_card.dart';
import 'widgets/stats_card.dart';
import 'widgets/task_list_tile.dart';
import '../../focus/presentation/focus_screen.dart';
import '../../review/presentation/review_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WEDNESDAY, OCT 24',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                      ),
                      Text(
                        'Synq.',
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                    ],
                  ),
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey, // Placeholder for profile image
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Current Focus Section (Full Width)
              SizedBox(
                height: 200,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => const FocusScreen()),
                  ),
                  child: const CurrentFocusCard(
                    title: 'Q3 Marketing Deck',
                    description: 'Finalize the slide sequence and integrate the new revenue projections.',
                    progress: 0.65,
                    timeRemaining: '45m left',
                    timeRange: '10:00 - 12:00',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Grid Row (Next Up + Stats)
              SizedBox(
                height: 160,
                child: Row(
                  children: [
                    const Expanded(
                      child: NextUpCard(
                        title: 'Dentist',
                        subtitle: 'Dr. Smith',
                        time: '14:30',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatsCard(
                        count: 4,
                        label: 'Tasks Completed',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Suggestion List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SUGGESTED TASKS', // Replaced "SUGGESTED BY AI"
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                  ),
                  const Icon(Icons.auto_awesome, size: 16, color: AppColors.accentPurple),
                ],
              ),
              const SizedBox(height: 16),

              // Task List
              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  TaskListTile(
                    title: 'Draft Project Proposal',
                    subtitle: 'High Energy · 1:00 PM',
                    onTap: () {},
                  ),
                  TaskListTile(
                    title: 'Grocery Run',
                    subtitle: 'Personal · 5:00 PM',
                    onTap: () {},
                  ),
                   TaskListTile(
                    title: 'Review Design Assets',
                    subtitle: 'Quick Win · Work',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withOpacity(0.05),
              blurRadius: 20, // Soft shadow
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(icon: const Icon(Icons.grid_view_rounded, color: Colors.black), onPressed: () {}),
            IconButton(
              icon: const Icon(Icons.calendar_today_rounded, color: Colors.grey),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReviewScreen()),
              ),
            ),
            
            // FAB replacement in dock
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Colors.black, // Dark FAB
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
            
            IconButton(icon: const Icon(Icons.search, color: Colors.grey), onPressed: () {}),
            IconButton(icon: const Icon(Icons.settings, color: Colors.grey), onPressed: () {}),
          ],
        ),
      ),
    );
  }
}
