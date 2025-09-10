// Responsive Widgets Library - Desktop Only
// This file exports all responsive components for desktop VTOL control system

export 'responsive_layout.dart';
export 'desktop_body.dart';
export 'demension.dart';

import 'package:flutter/material.dart';
import 'demension.dart';

/// A desktop-only container for VTOL control system
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? maxWidth;
  final Color? backgroundColor;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final desktopPadding = padding ?? const EdgeInsets.all(ResponsiveDimensions.spacingXL);

    return Container(
      constraints: BoxConstraints(
        minWidth: ResponsiveDimensions.minDesktopWidth,
        maxWidth: maxWidth ?? double.infinity,
      ),
      padding: desktopPadding,
      color: backgroundColor,
      child: child,
    );
  }
}

/// A responsive text widget for desktop
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double? fontSize;

  const ResponsiveText({
    super.key,
    required this.text,
    this.style,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final defaultFontSize = fontSize ?? 16.0;
    
    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(
        fontSize: defaultFontSize,
      ),
    );
  }
}

/// A responsive grid for desktop layouts
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? columns;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.columns,
    this.mainAxisSpacing = ResponsiveDimensions.spacingM,
    this.crossAxisSpacing = ResponsiveDimensions.spacingM,
  });

  @override
  Widget build(BuildContext context) {
    final columnCount = columns ?? context.gridColumns();

    return GridView.count(
      crossAxisCount: columnCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

/// A responsive row for desktop layouts
class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;

  const ResponsiveRow({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.spacing = ResponsiveDimensions.spacingM,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: _addSpacing(children, spacing),
    );
  }

  List<Widget> _addSpacing(List<Widget> children, double spacing) {
    if (children.isEmpty) return children;

    final spacedChildren = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i < children.length - 1) {
        spacedChildren.add(SizedBox(width: spacing));
      }
    }
    return spacedChildren;
  }
}

/// A responsive column for desktop layouts
class ResponsiveColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;

  const ResponsiveColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.spacing = ResponsiveDimensions.spacingM,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: _addSpacing(children, spacing),
    );
  }

  List<Widget> _addSpacing(List<Widget> children, double spacing) {
    if (children.isEmpty) return children;

    final spacedChildren = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      spacedChildren.add(children[i]);
      if (i < children.length - 1) {
        spacedChildren.add(SizedBox(height: spacing));
      }
    }
    return spacedChildren;
  }
}
