import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/folder_provider.dart';
import '../data/notes_provider.dart';
import 'widgets/folder_card.dart';
import 'widgets/add_folder_sheet.dart';
import 'folder_detail_screen.dart';
import '../../../../core/navigation/fade_page_route.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(foldersProvider);
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: foldersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (folders) {
            final allNotes = notesAsync.value ?? [];
            
            // Favorites
            final favorites = folders.where((f) => f.isFavorite).toList();
            
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.menu),
                            onPressed: () {}, // Drawer or Menu?
                          ),
                          Text(
                            'FOLDERS',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Search Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const TextField(
                          decoration: InputDecoration(
                            icon: Icon(Icons.search, color: Colors.grey),
                            hintText: 'Search Folders...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Favorites Section
                      if (favorites.isNotEmpty) ...[
                        Text(
                          'FAVORITES',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 160, // Fixed height for cards?
                          child: GridView.count(
                             crossAxisCount: 2,
                             mainAxisSpacing: 16,
                             crossAxisSpacing: 16,
                             childAspectRatio: 1.1,
                             shrinkWrap: true,
                             physics: const NeverScrollableScrollPhysics(),
                             children: favorites.map((folder) {
                               final count = allNotes.where((n) => n.folderId == folder.id).length;
                               return FolderCard(
                                 folder: folder,
                                 itemCount: count,
                                 onTap: () => Navigator.push(
                                   context,
                                   FadePageRoute(builder: (_) => FolderDetailScreen(folder: folder)),
                                 ),
                               );
                             }).toList(),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                      
                      // All Folders Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ALL FOLDERS',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                          ),
                          Text(
                            '${folders.length} Total',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ]),
                  ),
                ),
                
                // All Folders Grid
                SliverPadding(
                   padding: const EdgeInsets.symmetric(horizontal: 24),
                   sliver: SliverGrid(
                     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                       crossAxisCount: 2,
                       mainAxisSpacing: 16,
                       crossAxisSpacing: 16,
                       childAspectRatio: 1.0,
                     ),
                     delegate: SliverChildBuilderDelegate(
                       (context, index) {
                         if (index == folders.length) {
                           // Add New Folder Card
                           return _buildAddNewFolderCard(context);
                         }
                         final folder = folders[index];
                         final count = allNotes.where((n) => n.folderId == folder.id).length;
                         return FolderCard(
                           folder: folder,
                           itemCount: count,
                           onTap: () => Navigator.push(
                             context,
                             FadePageRoute(builder: (_) => FolderDetailScreen(folder: folder)),
                           ),
                         );
                       },
                       childCount: folders.length + 1, // +1 for Add New
                     ),
                   ),
                ),
                 const SliverPadding(padding: EdgeInsets.only(bottom: 100)), // Space for FAB/Dock
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddFolderSheet(context),
        label: const Text('Add Folder'),
        icon: const Icon(Icons.create_new_folder),
        backgroundColor: Colors.black, // Dark FAB
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildAddNewFolderCard(BuildContext context) {
    return GestureDetector(
      onTap: () => showAddFolderSheet(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent, // Or slight grey?
          borderRadius: BorderRadius.circular(20),
             border: Border.all(
               color: Colors.grey.withAlpha(80), 
               width: 2,
             ),
          // Using DottedBorder package is better but let's stick to standard
        ),
        // Let's use standard border with Dotted illusion via CustomPainter or just a light solid border
        child: Container(
          decoration: BoxDecoration(
             color: Colors.white,
             borderRadius: BorderRadius.circular(20),
             border: Border.all(color: Colors.grey.shade300, width: 1), // Dashed preferred but solid for now
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 32, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'New',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
