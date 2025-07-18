import 'package:flutter/material.dart';
import 'package:skylink/responsive/demension.dart';

class TabletBody extends StatelessWidget {
  final Widget child;
  final bool hasScrollbar;
  final EdgeInsets? padding;
  final double? maxWidth;

  const TabletBody({
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
      constraints: BoxConstraints(maxWidth: maxWidth ?? 800),
      padding:
          padding ??
          context.responsivePadding(
            tablet: const EdgeInsets.all(ResponsiveDimensions.spacingL),
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

class TabletGrid extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;

  const TabletGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = ResponsiveDimensions.spacingM,
    this.mainAxisSpacing = ResponsiveDimensions.spacingM,
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

class TabletTwoColumnLayout extends StatelessWidget {
  final Widget leftChild;
  final Widget rightChild;
  final double leftFlex;
  final double rightFlex;
  final double spacing;

  const TabletTwoColumnLayout({
    super.key,
    required this.leftChild,
    required this.rightChild,
    this.leftFlex = 1.0,
    this.rightFlex = 1.0,
    this.spacing = ResponsiveDimensions.spacingL,
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

class TabletCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? elevation;
  final double? width;

  const TabletCard({
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
        elevation: elevation ?? 3.0,
        child: Padding(
          padding:
              padding ?? const EdgeInsets.all(ResponsiveDimensions.spacingL),
          child: child,
        ),
      ),
    );
  }
}
