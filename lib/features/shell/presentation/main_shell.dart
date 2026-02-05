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
  MainShell({super.key});

  // Keys for each tab's navigator
  final _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentNavIndexProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      // Use IndexedStack with independent Navigators for each tab
      body: IndexedStack(
        index: currentIndex,
        children: [
          _buildTabNavigator(0, const HomeScreenContent()),
          _buildTabNavigator(1, const DailyTimelineContent()),
          _buildTabNavigator(2, const PlaceholderScreen(title: 'Search')),
          _buildTabNavigator(3, const PlaceholderScreen(title: 'Settings')),
        ],
      ),
      bottomNavigationBar: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withAlpha(13),
              blurRadius: 20,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavButton(ref, currentIndex, 0, Icons.grid_view_rounded),
            _buildNavButton(ref, currentIndex, 1, Icons.calendar_month),
            
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
            
            _buildNavButton(ref, currentIndex, 2, Icons.search),
            _buildNavButton(ref, currentIndex, 3, Icons.settings),
          ],
        ),
      ),
    );
  }

  Widget _buildTabNavigator(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(
          builder: (context) => child,
        );
      },
    );
  }

  Widget _buildNavButton(WidgetRef ref, int currentIndex, int index, IconData icon) {
    return IconButton(
      icon: Icon(
        icon,
        color: currentIndex == index ? Colors.black : Colors.grey,
      ),
      onPressed: () {
        if (currentIndex == index) {
          // If tapping active tab, pop to root
          _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
        } else {
          ref.read(currentNavIndexProvider.notifier).state = index;
        }
      },
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
