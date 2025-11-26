import 'package:flutter/material.dart';
import 'package:skylink/presentation/widget/camera/camera_main_view.dart';

class ResizableCameraOverlay extends StatefulWidget {
  final bool isVisible;
  final VoidCallback onClose;
  final bool isSwapped;
  final VoidCallback onSwap;
  final Widget? mapWidget;
  final Function(double width)? onSizeChanged;

  const ResizableCameraOverlay({
    super.key,
    required this.isVisible,
    required this.onClose,
    this.isSwapped = false,
    required this.onSwap,
    this.mapWidget,
    this.onSizeChanged,
  });

  @override
  State<ResizableCameraOverlay> createState() => _ResizableCameraOverlayState();
}

class _ResizableCameraOverlayState extends State<ResizableCameraOverlay>
    with AutomaticKeepAliveClientMixin {
  // Static camera widget instance
  static Widget? _sharedCameraWidget;

  Widget get cameraWidget {
    _sharedCameraWidget ??= const CameraMainView(
      key: ValueKey('shared_camera'),
    );
    return _sharedCameraWidget!;
  }

  @override
  bool get wantKeepAlive => true;

  // Resizable state
  double _width = 450;
  double _height = 300;
  bool _isResizing = false;

  @override
  void initState() {
    super.initState();
    // Notify initial size
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onSizeChanged?.call(_width);
    });
  }

  // Min/Max constraints
  static const double _minWidth = 300;
  static const double _maxWidth = 800;
  static const double _minHeight = 200;
  static const double _maxHeight = 600;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    if (widget.isSwapped) {
      // Fullscreen mode - không resize
      return _buildFullscreenView();
    }

    // Resizable mode - góc trái-dưới cố định
    return Positioned(
      bottom: 16,
      left: 16,
      child: Container(
        width: _width,
        height: _height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Camera view
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: cameraWidget,
              ),
            ),

            // Absorb gestures except for controls
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 50,
              child: GestureDetector(
                onTap: () {},
                onPanUpdate: (_) {},
                onDoubleTap: widget.onSwap,
                child: Container(color: Colors.transparent),
              ),
            ),

            // Control buttons (top-left) - di chuyển sang trái để tránh trùng resize
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: widget.onSwap,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: widget.onClose,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Resize handle - Vùng 50x50 ở góc phải-trên
            Positioned(
              top: -5,
              right: -5,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpRightDownLeft,
                child: Listener(
                  onPointerDown: (event) {
                    setState(() => _isResizing = true);
                  },
                  onPointerUp: (event) {
                    setState(() => _isResizing = false);
                  },
                  onPointerMove: (event) {
                    if (_isResizing) {
                      setState(() {
                        _width = (_width + event.delta.dx).clamp(
                          _minWidth,
                          _maxWidth,
                        );
                        _height = (_height - event.delta.dy).clamp(
                          _minHeight,
                          _maxHeight,
                        );
                        // Notify parent about size change
                        widget.onSizeChanged?.call(_width);
                      });
                    }
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(),
                    child: const Center(
                      child: Icon(
                        Icons.open_in_full,
                        color: Colors.white70,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreenView() {
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(child: cameraWidget),

            // Map preview in corner
            Positioned(
              bottom: 16,
              left: 16,
              child: GestureDetector(
                onTap: widget.onSwap,
                child: Container(
                  width: 450,
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        if (widget.mapWidget != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Transform.scale(
                              scale: 0.45,
                              alignment: Alignment.center,
                              child: OverflowBox(
                                maxWidth: 1200,
                                maxHeight: 800,
                                child: SizedBox(
                                  width: 1200,
                                  height: 800,
                                  child: widget.mapWidget!,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            color: Colors.grey.shade800,
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.map,
                                    color: Colors.white70,
                                    size: 32,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Map View',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Tap to swap back',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
