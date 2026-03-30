import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onAnimationComplete;

  const SplashScreen({super.key, this.onAnimationComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn)),
    );

    _startAnimation();
  }

  @override
  void didChangeDependencies() {
    precacheImage(const AssetImage("assets/images/logo.png"), context);
    super.didChangeDependencies();
  }

  Future<void> _startAnimation() async {
    FlutterNativeSplash.remove();
    
    // 1. Initial Entrance
    await _controller.forward();
    
    // 2. Transition to "Alive" Pulse
    _controller.duration = const Duration(milliseconds: 1500);
    _scale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    _controller.repeat(reverse: true);

    // 3. Minimum display time and ready check handoff
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted && widget.onAnimationComplete != null) {
      widget.onAnimationComplete!();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Image.asset(
              "assets/images/logo.png",
              width: 140,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
