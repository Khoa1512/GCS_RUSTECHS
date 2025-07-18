import 'package:flutter/material.dart';
import 'package:skylink/responsive/demension.dart';

class MobileBody extends StatelessWidget {
  final Widget child;
  final bool hasScrollbar;
  final EdgeInsets? padding;
  final bool safeArea;

  const MobileBody({
    super.key,
    required this.child,
    this.hasScrollbar = true,
    this.padding,
    this.safeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget body = Container(
      width: double.infinity,
      padding:
          padding ??
          context.responsivePadding(
            mobile: const EdgeInsets.all(ResponsiveDimensions.spacingM),
          ),
      child: child,
    );

    if (hasScrollbar) {
      body = SingleChildScrollView(child: body);
    }

    if (safeArea) {
      body = SafeArea(child: body);
    }

    return body;
  }
}

class MobileGrid extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;

  const MobileGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 1,
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

class MobileCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? elevation;

  const MobileCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.all(ResponsiveDimensions.spacingS),
      child: Card(
        elevation: elevation ?? 2.0,
        child: Padding(
          padding:
              padding ?? const EdgeInsets.all(ResponsiveDimensions.spacingM),
          child: child,
        ),
      ),
    );
  }
}
