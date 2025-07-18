import 'package:flutter/material.dart';
import 'package:skylink/responsive/demension.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final deviceType = ResponsiveDimensions.getDeviceType(context);

        switch (deviceType) {
          case DeviceType.mobile:
            return mobile;
          case DeviceType.tablet:
            return tablet ?? mobile; // Fallback to mobile if no tablet layout
          case DeviceType.desktop:
            return desktop;
        }
      },
    );
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
class ResponsiveValue<T> {
  final T mobile;
  final T? tablet;
  final T desktop;

  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  T getValue(BuildContext context) {
    final deviceType = ResponsiveDimensions.getDeviceType(context);

    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop;
    }
  }
}
