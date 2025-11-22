import 'package:flutter/material.dart';
import 'package:skylink/presentation/widget/camera/camera_main_view.dart';

class MapCameraOverlay extends StatefulWidget {
  final bool isVisible;
  final VoidCallback onClose;
  final bool isSwapped;
  final VoidCallback onSwap;
  final Widget? mapWidget;

  const MapCameraOverlay({
    super.key,
    required this.isVisible,
    required this.onClose,
    this.isSwapped = false,
    required this.onSwap,
    this.mapWidget,
  });

  @override
  State<MapCameraOverlay> createState() => _MapCameraOverlayState();
}

class _MapCameraOverlayState extends State<MapCameraOverlay>
    with AutomaticKeepAliveClientMixin {
  // Use static widget instance to prevent recreation during swaps
  static Widget? _sharedCameraWidget;

  Widget get cameraWidget {
    _sharedCameraWidget ??= const CameraMainView(
      key: ValueKey('shared_camera'),
    );
    return _sharedCameraWidget!;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    if (widget.isSwapped) {
      // Full screen camera view
      return Positioned.fill(
        child: Container(
          color: Colors.black,
          child: Stack(
            children: [
              // Full screen camera - reuse same widget instance
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
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          // Actual map widget or placeholder
                          if (widget.mapWidget != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Transform.scale(
                                scale: 0.45,
                                alignment: Alignment.center,
                                child: OverflowBox(
                                  maxWidth:
                                      1200,
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
                          // Shimmer effect to indicate interactivity
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.teal.withValues(alpha: 0.3),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Controls overlay
              // Positioned(
              //   top: 16,
              //   left: 16,
              //   child: Container(
              //     decoration: BoxDecoration(
              //       color: Colors.black.withValues(alpha: 0.7),
              //       borderRadius: BorderRadius.circular(8),
              //     ),
              //     child: Row(
              //       mainAxisSize: MainAxisSize.min,
              //       children: [
              //         Material(
              //           color: Colors.transparent,
              //           child: InkWell(
              //             borderRadius: BorderRadius.circular(8),
              //             onTap: widget.onSwap,
              //             child: Container(
              //               padding: const EdgeInsets.all(8),
              //               child: const Row(
              //                 mainAxisSize: MainAxisSize.min,
              //                 children: [
              //                   Icon(
              //                     Icons.swap_horiz,
              //                     color: Colors.white,
              //                     size: 18,
              //                   ),
              //                   SizedBox(width: 4),
              //                   Text(
              //                     'Swap',
              //                     style: TextStyle(
              //                       color: Colors.white,
              //                       fontSize: 12,
              //                     ),
              //                   ),
              //                 ],
              //               ),
              //             ),
              //           ),
              //         ),
              //         const SizedBox(width: 8),
              //         Material(
              //           color: Colors.transparent,
              //           child: InkWell(
              //             borderRadius: BorderRadius.circular(6),
              //             onTap: widget.onClose,
              //             child: Container(
              //               padding: const EdgeInsets.all(6),
              //               child: const Icon(
              //                 Icons.close,
              //                 color: Colors.white,
              //                 size: 16,
              //               ),
              //             ),
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      );
    }

    return Positioned(
      bottom: 16,
      left: 16,
      child: Container(
        width: 450,
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Camera view - use cached camera widget
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: cameraWidget,
              ),
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 50,
              child: GestureDetector(
                onTap: () {}, // Absorb taps to prevent map interaction
                onPanUpdate: (_) {}, // Absorb pan gestures
                onDoubleTap: widget.onSwap, // Double tap to swap
                child: Container(color: Colors.transparent),
              ),
            ),

            // Camera control buttons
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Double tap swap hint
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
          ],
        ),
      ),
    );
  }
}
