import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';

class AmbientSound {
  final String id;
  final String name;
  final String assetPath;
  final String icon;

  const AmbientSound({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.icon,
  });
}

const List<AmbientSound> availableSounds = [
  AmbientSound(
    id: 'rainfall',
    name: 'Rainfall',
    assetPath: 'assets/audio/rainfall.mp3',
    icon: 'cloud_queue',
  ),
  AmbientSound(
    id: 'forest',
    name: 'Forest',
    assetPath: 'assets/audio/forest.mp3',
    icon: 'park_outlined',
  ),
  AmbientSound(
    id: 'ocean',
    name: 'Ocean',
    assetPath: 'assets/audio/ocean.mp3',
    icon: 'waves',
  ),
];

class AmbientSoundState {
  final String? activeSoundId;
  final bool isPlaying;

  AmbientSoundState({
    this.activeSoundId,
    this.isPlaying = false,
  });

  AmbientSoundState copyWith({
    String? activeSoundId,
    bool? isPlaying,
  }) {
    return AmbientSoundState(
      activeSoundId: activeSoundId ?? this.activeSoundId,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

class AmbientSoundNotifier extends StateNotifier<AmbientSoundState> {
  final AudioPlayer _player = AudioPlayer();

  AmbientSoundNotifier() : super(AmbientSoundState()) {
    _player.setLoopMode(LoopMode.one);
  }

  Future<void> toggleSound(String soundId) async {
    final sound = availableSounds.firstWhere((s) => s.id == soundId);

    if (state.activeSoundId == soundId) {
      if (state.isPlaying) {
        await _player.pause();
        state = state.copyWith(isPlaying: false);
      } else {
        await _player.play();
        state = state.copyWith(isPlaying: true);
      }
    } else {
      state = state.copyWith(activeSoundId: soundId, isPlaying: true);
      try {
        await _player.setAsset(sound.assetPath);
        await _player.play();
      } catch (e) {
        // Fallback for missing assets during development
        print('Error playing audio: $e');
        state = state.copyWith(isPlaying: false);
      }
    }
  }

  Future<void> stop() async {
    await _player.stop();
    state = AmbientSoundState();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

final ambientSoundProvider = StateNotifierProvider<AmbientSoundNotifier, AmbientSoundState>((ref) {
  return AmbientSoundNotifier();
});
