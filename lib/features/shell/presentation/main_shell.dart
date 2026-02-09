import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/presentation/home_screen_content.dart';
import '../../timeline/presentation/pages/daily_timeline_content.dart';
import '../../notes/presentation/folders_screen.dart';
import '../../notes/presentation/note_detail_screen.dart';
import '../../../../core/navigation/fade_page_route.dart';


final currentNavIndexProvider = StateProvider<int>((ref) => 0);


class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  // Keys for each tab's navigator
  final _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  DateTime? _lastPressedAt;

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentNavIndexProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Check if the current tab's nested navigator can pop
        final isFirstRouteInCurrentTab = !await _navigatorKeys[currentIndex].currentState!.maybePop();

        if (isFirstRouteInCurrentTab) {
          // If we are at the root of the tab
          if (currentIndex != 0) {
            // If on any other tab (Calendar, Search, Settings), go back to Home first
            ref.read(currentNavIndexProvider.notifier).state = 0;
          } else {
            // On Home Tab root -> Double back to exit
            _handleDoubleBackToExit();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: true,
        // Use IndexedStack with independent Navigators for each tab
        body: IndexedStack(
          index: currentIndex,
          children: [
            _buildTabNavigator(0, const HomeScreenContent()),
            _buildTabNavigator(1, const DailyTimelineContent()),
            _buildTabNavigator(2, const FoldersScreen()),
            _buildTabNavigator(3, const PlaceholderScreen(title: 'Settings')),
          ],
        ),
        bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0 
          ? null 
          : Container(
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
              
              // Add Task Button Removed

              // Add Note Button
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  FadePageRoute(builder: (_) => const NoteDetailScreen()),
                ),
                icon: Container(
                   padding: const EdgeInsets.all(8),
                   decoration: BoxDecoration(
                     color: Colors.purple.withValues(alpha: 0.1),
                     shape: BoxShape.circle,
                   ),
                   child: const Icon(Icons.note_add_outlined, color: Colors.purple),
                ),
                tooltip: 'Add Note',
              ),
              
              _buildNavButton(ref, currentIndex, 2, Icons.folder_open_rounded),
              _buildNavButton(ref, currentIndex, 3, Icons.settings),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDoubleBackToExit() async {
    final now = DateTime.now();
    const maxDuration = Duration(seconds: 2);
    final isWarningStillActive = _lastPressedAt != null && 
                                 now.difference(_lastPressedAt!) < maxDuration;

    if (isWarningStillActive) {
      await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    } else {
      _lastPressedAt = now;
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Press back again to exit',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: const Color(0xFF323232),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            width: 220,
          ),
        );
      }
    }
  }

  Widget _buildTabNavigator(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (routeSettings) {
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 150),
          reverseTransitionDuration: const Duration(milliseconds: 150),
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
