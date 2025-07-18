import 'package:flutter/material.dart';
import 'package:skylink/responsive/demension.dart';

class DesktopBody extends StatelessWidget {
  final Widget child;
  final bool hasScrollbar;
  final EdgeInsets? padding;
  final double? maxWidth;

  const DesktopBody({
    super.key,
    required this.child,
    this.hasScrollbar = true,
    this.padding,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    Widget body = Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: maxWidth ?? 1200),
      padding:
          padding ??
          context.responsivePadding(
            desktop: const EdgeInsets.all(ResponsiveDimensions.spacingXXL),
          ),
      child: child,
    );

    if (hasScrollbar) {
      body = SingleChildScrollView(child: Center(child: body));
    } else {
      body = Center(child: body);
    }

    return body;
  }
}

class DesktopGrid extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;

  const DesktopGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 3,
    this.crossAxisSpacing = ResponsiveDimensions.spacingL,
    this.mainAxisSpacing = ResponsiveDimensions.spacingL,
    this.childAspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

class DesktopTwoColumnLayout extends StatelessWidget {
  final Widget leftChild;
  final Widget rightChild;
  final double leftFlex;
  final double rightFlex;
  final double spacing;

  const DesktopTwoColumnLayout({
    super.key,
    required this.leftChild,
    required this.rightChild,
    this.leftFlex = 1.0,
    this.rightFlex = 1.0,
    this.spacing = ResponsiveDimensions.spacingXL,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: leftFlex.round(), child: leftChild),
        SizedBox(width: spacing),
        Expanded(flex: rightFlex.round(), child: rightChild),
      ],
    );
  }
}

class DesktopCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? elevation;
  final double? width;

  const DesktopCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.elevation,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: margin ?? const EdgeInsets.all(ResponsiveDimensions.spacingM),
      child: Card(
        elevation: elevation ?? 4.0,
        child: Padding(
          padding:
              padding ?? const EdgeInsets.all(ResponsiveDimensions.spacingXL),
          child: child,
        ),
      ),
    );
  }
}
