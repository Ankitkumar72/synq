import 'package:flutter/material.dart';

class IconUtils {
  static const List<IconData> supportedIcons = [
    Icons.folder,
    Icons.work,
    Icons.person,
    Icons.star,
    Icons.lightbulb,
    Icons.shopping_cart,
    Icons.travel_explore,
    Icons.school,
    Icons.fitness_center,
    Icons.music_note,
  ];

  static IconData getIconFromCodePoint(int codePoint) {
    return supportedIcons.firstWhere(
      (icon) => icon.codePoint == codePoint,
      orElse: () => Icons.folder,
    );
  }
}
