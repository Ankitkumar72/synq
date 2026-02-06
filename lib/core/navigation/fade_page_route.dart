import 'package:flutter/material.dart';

/// Custom page route that uses a fade transition instead of the default slide
/// to prevent black background flashes during navigation.
/// 
/// Key features:
/// - Uses FadeTransition for both push and pop
/// - Wraps content in a container with theme background to prevent black flash
/// - Faster transitions (150ms) for snappy feel
class FadePageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;

  FadePageRoute({required this.builder});

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    // Wrap in a Material with theme background to prevent any black from showing
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: builder(context),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    // Use curved animation for smoother feel
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    
    return FadeTransition(
      opacity: curvedAnimation,
      child: child,
    );
  }
}
