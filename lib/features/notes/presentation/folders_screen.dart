import 'dart:async';
import 'dart:ui' as ui; // Added for PathMetrics

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../data/folder_search_engine.dart';
import '../data/folder_provider.dart';
import '../data/notes_provider.dart';
import '../data/notes_settings_provider.dart'; // Added
import '../domain/models/folder.dart';
import '../domain/models/note.dart';
import 'widgets/folder_card.dart';
import 'widgets/add_folder_sheet.dart';
import 'widgets/folder_options_sheet.dart';
import 'widgets/delete_confirmation_sheet.dart'; // Added
import 'folder_detail_screen.dart';
import 'note_detail_screen.dart';
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
  static const double _gridAspectRatio = 2.5; // Changed from 1.78 to 2.5 for horizontal pills

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
    final notesSettings = ref.watch(notesSettingsProvider);
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
                            'Folders', // Capitalized normally as per design
                            style: GoogleFonts.playfairDisplay( // Changed to Serif
                              fontSize: 32, // Increased size
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32), // Increased spacing
                      
                      // Search Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(100), // Pill shape
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
                      const SizedBox(height: 32), // Increased spacing
                      
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
                                 onLongPress: () => _showFolderOptionsMenu(context, folder, count, notesSettings),
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
                                : '${folders.length} Total', // Dynamic count text
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
                             onLongPress: () => _showFolderOptionsMenu(context, folder, count, notesSettings),
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
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: Colors.grey.withValues(alpha: 0.5),
          strokeWidth: 1.0, 
          radius: 100,
        ),
        child: Container(
          // No decoration border, handled by painter
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Same padding as FolderCard
          child: Row(
            children: [
              Container(
                width: 32, // Match FolderCard icon size
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2), // Grey circle
                  shape: BoxShape.circle, // Circular
                ),
                child: const Icon(Icons.add, size: 18, color: Colors.grey),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Align( // Vertical center alignment
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'New Folder',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary, // Grey text
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _showFolderOptionsMenu(BuildContext context, Folder folder, int itemCount, NotesSettingsState settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FolderOptionsSheet(
        folder: folder,
        noteCount: itemCount,
        folderCount: 0, // Flat structure assumed
        onNewNote: () {
          Navigator.push(
            context,
            FadePageRoute(builder: (_) => NoteDetailScreen(initialFolderId: folder.id)),
          );
        },
        onNewFolder: () => showAddFolderSheet(context),
        onMakeCopy: () {},
        onMove: () {},
        onBookmark: () {},
        onCopyPath: () {},
        onRename: () => showAddFolderSheet(context, folderToEdit: folder),
        onDelete: () {
          if (settings.skipFolderDeleteConfirmation) {
            ref.read(foldersProvider.notifier).deleteFolder(folder.id);
            return;
          }
          
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => DeleteConfirmationSheet(
              itemName: folder.name,
              onDelete: () {
                ref.read(foldersProvider.notifier).deleteFolder(folder.id);
              },
              onDeleteAndDontAsk: () {
                ref.read(notesSettingsProvider.notifier).setSkipFolderDeleteConfirmation(true);
                ref.read(foldersProvider.notifier).deleteFolder(folder.id);
              },
            ),
          );
        },
        onSearch: () {
          setState(() {
            _searchQuery = folder.name;
            _searchController.text = folder.name;
          });
        },
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashWidth = 6.0;
  final double dashSpace = 4.0;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.radius = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final Path path = Path()..addRRect(rrect);

    final Path dashedPath = Path();
    for (final ui.PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        dashedPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
