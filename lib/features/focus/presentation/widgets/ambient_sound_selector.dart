import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ambient_sound_provider.dart';
import '../../../../core/theme/app_theme.dart';

class AmbientSoundSelector extends ConsumerWidget {
  const AmbientSoundSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: availableSounds.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final sound = availableSounds[index];
          return AmbientSoundButton(sound: sound);
        },
      ),
    );
  }
}

class AmbientSoundButton extends ConsumerWidget {
  final AmbientSound sound;

  const AmbientSoundButton({
    super.key,
    required this.sound,
  });

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'cloud_queue':
        return Icons.cloud_queue;
      case 'park_outlined':
        return Icons.park_outlined;
      case 'waves':
        return Icons.waves;
      default:
        return Icons.music_note;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ambientSoundProvider);
    final isActive = state.activeSoundId == sound.id;
    final isPlaying = isActive && state.isPlaying;

    return GestureDetector(
      onTap: () => ref.read(ambientSoundProvider.notifier).toggleSound(sound.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.transparent : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.pause : _getIconData(sound.icon),
              size: 18,
              color: isActive ? AppColors.primary : Colors.black,
            ),
            const SizedBox(width: 8),
            Text(
              sound.name,
              style: TextStyle(
                color: Colors.black,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
