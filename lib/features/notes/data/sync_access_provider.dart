import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncAccessState {
  const SyncAccessState({
    required this.cloudSyncEnabled,
    required this.isLoading,
  });

  final bool cloudSyncEnabled;
  final bool isLoading;

  SyncAccessState copyWith({
    bool? cloudSyncEnabled,
    bool? isLoading,
  }) {
    return SyncAccessState(
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final syncAccessProvider =
    StateNotifierProvider<SyncAccessNotifier, SyncAccessState>((ref) {
  return SyncAccessNotifier();
});

class SyncAccessNotifier extends StateNotifier<SyncAccessState> {
  SyncAccessNotifier()
      : super(const SyncAccessState(
          cloudSyncEnabled: true,
          isLoading: true,
        )) {
    _load();
  }

  static const String _cloudSyncKey = 'cloud_sync_enabled';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_cloudSyncKey) ?? true;
    state = state.copyWith(
      cloudSyncEnabled: enabled,
      isLoading: false,
    );
  }

  Future<void> setCloudSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cloudSyncKey, enabled);
    state = state.copyWith(cloudSyncEnabled: enabled);
  }
}
