import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A premium, standardized card component for the Synq design system.
/// Uses [ContinuousRectangleBorder] for smooth "squircle" corners.
class SynqCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final double elevation;
  final List<BoxShadow>? extraShadows;

  const SynqCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.elevation = 0,
    this.extraShadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: extraShadows,
      ),
      child: Material(
        color: color ?? Theme.of(context).cardTheme.color,
        elevation: elevation,
        shape: Theme.of(context).cardTheme.shape,
        clipBehavior: Clip.none, // High performance by default
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24), // Approx match for ripple
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A premium circular icon button that ensures a perfect 1:1 circle shape.
class SynqIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Color? iconColor;
  final double size;
  final double iconSize;
  final String? tooltip;

  const SynqIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.iconColor,
    this.size = 40,
    this.iconSize = 20,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: color ?? Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.none,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A premium, perfectly smooth Floating Action Button.
/// Bypasses the native [FloatingActionButton]'s physical model shadow
/// which occasionally causes jagged edges on Skia/Impeller backends.
class SynqFab extends StatelessWidget {
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final Widget icon;
  final Color? backgroundColor;

  const SynqFab({
    super.key,
    required this.onPressed,
    this.onLongPress,
    required this.icon,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Theme.of(context).primaryColor;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: bgColor.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}
