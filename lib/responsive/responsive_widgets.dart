// Responsive Widgets Library
// This file exports all responsive components and provides utility widgets

export 'responsive_layout.dart';
export 'mobile_body.dart';
export 'tablet_body.dart';
export 'desktop_body.dart';
export 'demension.dart';

import 'package:flutter/material.dart';
import 'demension.dart';

/// A responsive container that adapts its properties based on screen size
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? mobilePadding;
  final EdgeInsets? tabletPadding;
  final EdgeInsets? desktopPadding;
  final double? mobileMaxWidth;
  final double? tabletMaxWidth;
  final double? desktopMaxWidth;
  final Color? backgroundColor;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.mobilePadding,
    this.tabletPadding,
    this.desktopPadding,
    this.mobileMaxWidth,
    this.tabletMaxWidth,
    this.desktopMaxWidth,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveDimensions.getDeviceType(context);

    EdgeInsets padding;
    double? maxWidth;

    switch (deviceType) {
      case DeviceType.mobile:
        padding =
            mobilePadding ??
            const EdgeInsets.all(ResponsiveDimensions.spacingM);
        maxWidth = mobileMaxWidth;
        break;
      case DeviceType.tablet:
        padding =
            tabletPadding ??
            const EdgeInsets.all(ResponsiveDimensions.spacingL);
        maxWidth = tabletMaxWidth ?? 800;
        break;
      case DeviceType.desktop:
        padding =
            desktopPadding ??
            const EdgeInsets.all(ResponsiveDimensions.spacingXL);
        maxWidth = desktopMaxWidth ?? 1200;
        break;
    }

    return Center(
      child: Container(
        constraints: maxWidth != null
            ? BoxConstraints(maxWidth: maxWidth)
            : null,
        padding: padding,
        color: backgroundColor,
        child: child,
      ),
    );
  }
}

/// A responsive text widget that adapts its style based on screen size
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? mobileStyle;
  final TextStyle? tabletStyle;
  final TextStyle? desktopStyle;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ResponsiveText(
    this.text, {
    super.key,
    this.mobileStyle,
    this.tabletStyle,
    this.desktopStyle,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveDimensions.getDeviceType(context);

    TextStyle? style;
    switch (deviceType) {
      case DeviceType.mobile:
        style = mobileStyle;
        break;
      case DeviceType.tablet:
        style = tabletStyle ?? mobileStyle;
        break;
      case DeviceType.desktop:
        style = desktopStyle ?? tabletStyle ?? mobileStyle;
        break;
    }

    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// A responsive gap (SizedBox) that adapts its size based on screen size
class ResponsiveGap extends StatelessWidget {
  final double? mobileSize;
  final double? tabletSize;
  final double? desktopSize;
  final bool isVertical;

  const ResponsiveGap({
    super.key,
    this.mobileSize,
    this.tabletSize,
    this.desktopSize,
    this.isVertical = true,
  });

  const ResponsiveGap.horizontal({
    super.key,
    this.mobileSize,
    this.tabletSize,
    this.desktopSize,
  }) : isVertical = false;

  @override
  Widget build(BuildContext context) {
    final size = context.responsiveSpacing(
      mobile: mobileSize ?? ResponsiveDimensions.spacingM,
      tablet: tabletSize ?? ResponsiveDimensions.spacingL,
      desktop: desktopSize ?? ResponsiveDimensions.spacingXL,
    );

    return SizedBox(
      width: isVertical ? null : size,
      height: isVertical ? size : null,
    );
  }
}

/// A responsive flex widget (Row or Column) that adapts based on screen size
class ResponsiveFlex extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final bool forceVerticalOnMobile;
  final double spacing;

  const ResponsiveFlex({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.forceVerticalOnMobile = true,
    this.spacing = ResponsiveDimensions.spacingM,
  });

  @override
  Widget build(BuildContext context) {
    final useVertical = forceVerticalOnMobile && context.isMobile;

    final spacedChildren = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i < children.length - 1) {
        spacedChildren.add(
          useVertical ? SizedBox(height: spacing) : SizedBox(width: spacing),
        );
      }
    }

    if (useVertical) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: spacedChildren,
      );
    } else {
      return Row(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: spacedChildren,
      );
    }
  }
}
