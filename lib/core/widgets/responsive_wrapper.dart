import 'package:flutter/material.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;

  // The baseline design width for the app (typical modern mobile width, e.g., iPhone 13/14)
  final double designWidth;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.designWidth = 390.0,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQueryData = MediaQuery.of(context);
    final size = mediaQueryData.size;

    // 1. Calculate the scale factor base on the physical width vs our design width
    final double scale = size.width / designWidth;

    // 2. Calculate what the height "feels" like to the app when scaled
    final double simulatedHeight = size.height / scale;

    // 3. Unpack MediaQuery info to cap text scale
    // By default users can increase text scale tremendously.
    // We limit it to exactly 1.3 or less to avoid layout breaks on small screens
    final textScaleFactor = mediaQueryData.textScaler.scale(1) > 1.3
        ? 1.3
        : mediaQueryData.textScaler.scale(1);

    return MediaQuery(
      data: mediaQueryData.copyWith(
        size: Size(designWidth, simulatedHeight),
        devicePixelRatio: mediaQueryData.devicePixelRatio * scale,
        padding: mediaQueryData.padding / scale,
        viewPadding: mediaQueryData.viewPadding / scale,
        viewInsets: mediaQueryData.viewInsets / scale,
        textScaler: TextScaler.linear(textScaleFactor),
      ),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: designWidth,
            height: simulatedHeight,
            child: child,
          ),
        ),
      ),
    );
  }
}
