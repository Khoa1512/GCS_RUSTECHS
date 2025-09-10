import 'package:flutter/material.dart';

class ResponsiveDimensions {
  // Desktop-only constants for VTOL control system
  static const double minDesktopWidth = 1200;
  static const double minDesktopHeight = 800;

  // Spacing constants
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // Always desktop for VTOL control system
  static DeviceType getDeviceType(BuildContext context) {
    return DeviceType.desktop;
  }

  // Desktop spacing
  static double spacing(BuildContext context, {double desktop = spacingXL}) {
    return desktop;
  }

  // Desktop padding
  static EdgeInsets padding(BuildContext context, {EdgeInsets? desktop}) {
    return desktop ?? const EdgeInsets.all(spacingXL);
  }

  // Desktop width
  static double width(BuildContext context, {double desktop = 0.6}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth * desktop;
  }

  // Grid columns - desktop only
  static int gridColumns(BuildContext context, {int desktop = 3}) {
    return desktop;
  }
}

enum DeviceType { desktop }

// Extension for easier access - desktop only
extension ResponsiveContext on BuildContext {
  bool get isDesktop => true; // Always desktop

  double responsiveSpacing({double desktop = ResponsiveDimensions.spacingXL}) =>
      ResponsiveDimensions.spacing(this, desktop: desktop);

  EdgeInsets responsivePadding({EdgeInsets? desktop}) =>
      ResponsiveDimensions.padding(this, desktop: desktop);

  double responsiveWidth({double desktop = 0.6}) =>
      ResponsiveDimensions.width(this, desktop: desktop);

  int gridColumns({int desktop = 3}) =>
      ResponsiveDimensions.gridColumns(this, desktop: desktop);
}
