import 'package:flutter/material.dart';
import 'package:skylink/responsive/demension.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget desktop;

  const ResponsiveLayout({super.key, required this.desktop});

  @override
  Widget build(BuildContext context) {
    return desktop;
  }
}

// Alternative responsive widget that takes a builder function
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final deviceType = ResponsiveDimensions.getDeviceType(context);
        return builder(context, deviceType);
      },
    );
  }
}

// Simple responsive value selector
class DesktopLayout extends StatelessWidget {
  final Widget child;
  const DesktopLayout({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return child;
  }
}
