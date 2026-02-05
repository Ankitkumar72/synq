import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/presentation/home_screen_content.dart';
import '../../timeline/presentation/pages/daily_timeline_content.dart';
import '../../home/presentation/widgets/create_new_sheet.dart';

/// Provider to track the current navigation index
final currentNavIndexProvider = StateProvider<int>((ref) => 0);

/// Main shell that provides persistent bottom navigation across all screens
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentNavIndexProvider);

    // Define the screens for each tab
    final screens = [
      const HomeScreenContent(),       // Index 0: Home/Dashboard
      const DailyTimelineContent(),    // Index 1: Calendar/Timeline
      const PlaceholderScreen(title: 'Search'),   // Index 2: Placeholder for search
      const PlaceholderScreen(title: 'Settings'), // Index 3: Placeholder for settings
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withAlpha(13), // 0.05 opacity = 13/255
              blurRadius: 20,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Home/Dashboard
            IconButton(
              icon: Icon(
                Icons.grid_view_rounded,
                color: currentIndex == 0 ? Colors.black : Colors.grey,
              ),
              onPressed: () => ref.read(currentNavIndexProvider.notifier).state = 0,
            ),
            
            // Calendar/Timeline
            IconButton(
              icon: Icon(
                Icons.calendar_month,
                color: currentIndex == 1 ? Colors.black : Colors.grey,
              ),
              onPressed: () => ref.read(currentNavIndexProvider.notifier).state = 1,
            ),
            
            // FAB - Create New
            GestureDetector(
              onTap: () => showCreateNewSheet(context),
              child: Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
            
            // Search
            IconButton(
              icon: Icon(
                Icons.search,
                color: currentIndex == 2 ? Colors.black : Colors.grey,
              ),
              onPressed: () => ref.read(currentNavIndexProvider.notifier).state = 2,
            ),
            
            // Settings
            IconButton(
              icon: Icon(
                Icons.settings,
                color: currentIndex == 3 ? Colors.black : Colors.grey,
              ),
              onPressed: () => ref.read(currentNavIndexProvider.notifier).state = 3,
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder screen for tabs not yet implemented
class PlaceholderScreen extends StatelessWidget {
  final String title;
  
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              title == 'Search' ? Icons.search : Icons.settings,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
