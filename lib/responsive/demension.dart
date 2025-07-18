import 'package:flutter/material.dart';

class ResponsiveDimensions {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1200;
  static const double desktopBreakpoint = 1200;

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // Get device type
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) return DeviceType.mobile;
    if (width < tabletBreakpoint) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  // Responsive spacing
  static double spacing(
    BuildContext context, {
    double mobile = spacingM,
    double tablet = spacingL,
    double desktop = spacingXL,
  }) {
    switch (getDeviceType(context)) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet;
      case DeviceType.desktop:
        return desktop;
    }
  }

  // Responsive padding
  static EdgeInsets padding(
    BuildContext context, {
    EdgeInsets? mobile,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
  }) {
    final defaultMobile = const EdgeInsets.all(spacingM);
    final defaultTablet = const EdgeInsets.all(spacingL);
    final defaultDesktop = const EdgeInsets.all(spacingXL);

    switch (getDeviceType(context)) {
      case DeviceType.mobile:
        return mobile ?? defaultMobile;
      case DeviceType.tablet:
        return tablet ?? defaultTablet;
      case DeviceType.desktop:
        return desktop ?? defaultDesktop;
    }
  }

  // Responsive width
  static double width(
    BuildContext context, {
    double mobile = 1.0,
    double tablet = 0.8,
    double desktop = 0.6,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    switch (getDeviceType(context)) {
      case DeviceType.mobile:
        return screenWidth * mobile;
      case DeviceType.tablet:
        return screenWidth * tablet;
      case DeviceType.desktop:
        return screenWidth * desktop;
    }
  }

  // Grid columns
  static int gridColumns(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
  }) {
    switch (getDeviceType(context)) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet;
      case DeviceType.desktop:
        return desktop;
    }
  }
}

enum DeviceType { mobile, tablet, desktop }

// Extension for easier access
extension ResponsiveContext on BuildContext {
  bool get isMobile =>
      ResponsiveDimensions.getDeviceType(this) == DeviceType.mobile;
  bool get isTablet =>
      ResponsiveDimensions.getDeviceType(this) == DeviceType.tablet;
  bool get isDesktop =>
      ResponsiveDimensions.getDeviceType(this) == DeviceType.desktop;

  double responsiveSpacing({
    double mobile = ResponsiveDimensions.spacingM,
    double tablet = ResponsiveDimensions.spacingL,
    double desktop = ResponsiveDimensions.spacingXL,
  }) => ResponsiveDimensions.spacing(
    this,
    mobile: mobile,
    tablet: tablet,
    desktop: desktop,
  );

  EdgeInsets responsivePadding({
    EdgeInsets? mobile,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
  }) => ResponsiveDimensions.padding(
    this,
    mobile: mobile,
    tablet: tablet,
    desktop: desktop,
  );

  double responsiveWidth({
    double mobile = 1.0,
    double tablet = 0.8,
    double desktop = 0.6,
  }) => ResponsiveDimensions.width(
    this,
    mobile: mobile,
    tablet: tablet,
    desktop: desktop,
  );

  int gridColumns({int mobile = 1, int tablet = 2, int desktop = 3}) =>
      ResponsiveDimensions.gridColumns(
        this,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
      );
}
