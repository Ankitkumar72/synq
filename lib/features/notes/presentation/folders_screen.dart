import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/folder_search_engine.dart';
import '../data/folder_provider.dart';
import '../data/notes_provider.dart';
import '../domain/models/folder.dart';
import '../domain/models/note.dart';
import 'widgets/folder_card.dart';
import 'widgets/add_folder_sheet.dart';
import 'folder_detail_screen.dart';
import '../../../../core/navigation/fade_page_route.dart';

final folderSearchEngineProvider = Provider<FolderSearchEngine>((ref) {
  final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
  final notes = ref.watch(notesProvider).value ?? const <Note>[];
  return FolderSearchEngine(
    folders: folders,
    notes: notes,
  );
});

class FoldersScreen extends ConsumerStatefulWidget {
  const FoldersScreen({super.key});

  @override
  ConsumerState<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends ConsumerState<FoldersScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  static const double _gridSpacing = 12;
  static const double _gridAspectRatio = 1.78;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(foldersProvider);
    final notesAsync = ref.watch(notesProvider);
    final searchEngine = ref.watch(folderSearchEngineProvider);
    final isSearching = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: foldersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (folders) {
            final allNotes = notesAsync.value ?? const <Note>[];
            final noteCountByFolderId = <String, int>{};
            for (final note in allNotes) {
              final folderId = note.folderId;
              if (folderId == null || folderId.isEmpty) continue;
              noteCountByFolderId[folderId] =
                  (noteCountByFolderId[folderId] ?? 0) + 1;
            }
            final folderById = {
              for (final folder in folders) folder.id: folder,
            };

            final matchedFolderIds = searchEngine.searchFolderIds(_searchQuery);
            final visibleFolders = matchedFolderIds
                .map((id) => folderById[id])
                .whereType<Folder>()
                .toList(growable: false);
            
            // Favorites (filtered by search when query exists)
            final favorites = visibleFolders.where((f) => f.isFavorite).toList();
            final contentWidth = MediaQuery.sizeOf(context).width - 48;
            final itemWidth = (contentWidth - _gridSpacing) / 2;
            final itemHeight = itemWidth / _gridAspectRatio;
            final favoriteRowCount = (favorites.length / 2).ceil();
            final favoriteGridHeight = favoriteRowCount == 0
                ? 0.0
                : (favoriteRowCount * itemHeight) +
                    ((favoriteRowCount - 1) * _gridSpacing);
            
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'FOLDERS',
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: Colors.black,
                            ),
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
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            _searchDebounce?.cancel();
                            _searchDebounce = Timer(
                              const Duration(milliseconds: 120),
                              () {
                                if (!mounted) return;
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                            );
                          },
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            icon: const Icon(Icons.search, color: Colors.grey),
                            hintText: 'Search folders, notes, tags...',
                            hintStyle: const TextStyle(color: AppColors.textSecondary),
                            filled: false,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            suffixIcon: isSearching
                                ? IconButton(
                                    icon: const Icon(Icons.close, color: Colors.grey),
                                    onPressed: () {
                                      _searchDebounce?.cancel();
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
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
                          height: favoriteGridHeight,
                          child: GridView.count(
                             crossAxisCount: 2,
                             mainAxisSpacing: _gridSpacing,
                             crossAxisSpacing: _gridSpacing,
                             childAspectRatio: _gridAspectRatio,
                             shrinkWrap: true,
                             physics: const NeverScrollableScrollPhysics(),
                             children: favorites.map((folder) {
                               final count = noteCountByFolderId[folder.id] ?? 0;
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
                            isSearching
                                ? '${visibleFolders.length} Results'
                                : '${folders.length} Total',
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

                if (isSearching && visibleFolders.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'No matching folders found',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),
                  ),
                
                // All Folders Grid
                if (!isSearching || visibleFolders.isNotEmpty)
                  SliverPadding(
                     padding: const EdgeInsets.symmetric(horizontal: 24),
                     sliver: SliverGrid(
                       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                         crossAxisCount: 2,
                         mainAxisSpacing: _gridSpacing,
                         crossAxisSpacing: _gridSpacing,
                         childAspectRatio: _gridAspectRatio,
                       ),
                       delegate: SliverChildBuilderDelegate(
                         (context, index) {
                           if (!isSearching && index == visibleFolders.length) {
                             // Add New Folder Card only on default list
                             return _buildAddNewFolderCard(context);
                           }
                           final folder = visibleFolders[index];
                           final count = noteCountByFolderId[folder.id] ?? 0;
                           return FolderCard(
                             folder: folder,
                             itemCount: count,
                             onTap: () => Navigator.push(
                               context,
                               FadePageRoute(builder: (_) => FolderDetailScreen(folder: folder)),
                             ),
                           );
                         },
                         childCount: isSearching
                             ? visibleFolders.length
                             : visibleFolders.length + 1, // +1 for Add New
                       ),
                     ),
                  ),
                 const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAddNewFolderCard(BuildContext context) {
    return GestureDetector(
      onTap: () => showAddFolderSheet(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add, size: 20, color: Colors.grey),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Folder',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Create',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
