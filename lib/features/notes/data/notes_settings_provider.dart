import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotesSettingsState {
  final bool skipFolderDeleteConfirmation;
  final bool isLoading;

  const NotesSettingsState({
    this.skipFolderDeleteConfirmation = false,
    this.isLoading = true,
  });

  NotesSettingsState copyWith({
    bool? skipFolderDeleteConfirmation,
    bool? isLoading,
  }) {
    return NotesSettingsState(
      skipFolderDeleteConfirmation: skipFolderDeleteConfirmation ?? this.skipFolderDeleteConfirmation,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotesSettingsNotifier extends StateNotifier<NotesSettingsState> {
  NotesSettingsNotifier() : super(const NotesSettingsState()) {
    _load();
  }

  static const String _skipConfirmKey = 'skip_folder_delete_confirmation';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final skip = prefs.getBool(_skipConfirmKey) ?? false;
    state = state.copyWith(
      skipFolderDeleteConfirmation: skip,
      isLoading: false,
    );
  }

  Future<void> setSkipFolderDeleteConfirmation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_skipConfirmKey, value);
    state = state.copyWith(skipFolderDeleteConfirmation: value);
  }
}

final notesSettingsProvider = StateNotifierProvider<NotesSettingsNotifier, NotesSettingsState>((ref) {
  return NotesSettingsNotifier();
});
