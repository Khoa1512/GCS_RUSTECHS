import 'package:flutter/material.dart';

/// A responsive scaffold wrapper for desktop-only VTOL control system
class ResponsiveScaffold extends StatelessWidget {
  final Widget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Widget? endDrawer;
  final Color? backgroundColor;
  final bool extendBody;
  final bool extendBodyBehindAppBar;

  const ResponsiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.drawer,
    this.endDrawer,
    this.backgroundColor,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      drawer: drawer,
      endDrawer: endDrawer,
      appBar: appBar != null ? _buildAppBar() : null,
      body: _buildBody(),
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (appBar == null) return null;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: appBar!,
    );
  }

  Widget _buildBody() {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Ensure we have valid constraints
          final hasValidConstraints =
              constraints.maxWidth != double.infinity &&
              constraints.maxHeight != double.infinity &&
              constraints.maxWidth > 0 &&
              constraints.maxHeight > 0;

          if (!hasValidConstraints) {
            // Fallback with minimal size
            return SizedBox(
              width: 100,
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: body,
          );
        },
      ),
    );
  }
}

/// A widget that ensures its child has proper size constraints
class ConstrainedSizeWidget extends StatelessWidget {
  final Widget child;
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;

  const ConstrainedSizeWidget({
    super.key,
    required this.child,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minWidth ?? 0,
            maxWidth:
                maxWidth ??
                (constraints.maxWidth != double.infinity
                    ? constraints.maxWidth
                    : double.infinity),
            minHeight: minHeight ?? 0,
            maxHeight:
                maxHeight ??
                (constraints.maxHeight != double.infinity
                    ? constraints.maxHeight
                    : double.infinity),
          ),
          child: child,
        );
      },
    );
  }
}

/// A size-aware container that prevents hasSize errors
class SafeSizedContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final Decoration? decoration;

  const SafeSizedContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.color,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Enforce minimum sizes for VTOL desktop app
        final screenSize = MediaQuery.of(context).size;
        final minWidth = 1200.0;
        final minHeight = 800.0;

        final safeWidth =
            width ??
            (constraints.maxWidth != double.infinity
                ? constraints.maxWidth.clamp(minWidth, double.infinity)
                : screenSize.width.clamp(minWidth, double.infinity));

        final safeHeight =
            height ??
            (constraints.maxHeight != double.infinity
                ? constraints.maxHeight.clamp(minHeight, double.infinity)
                : screenSize.height.clamp(minHeight, double.infinity));

        return Container(
          width: safeWidth,
          height: safeHeight,
          padding: padding,
          margin: margin,
          color: color,
          decoration: decoration,
          constraints: BoxConstraints(minWidth: minWidth, minHeight: minHeight),
          child: child,
        );
      },
    );
  }
}
