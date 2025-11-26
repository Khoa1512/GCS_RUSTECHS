import 'package:flutter/material.dart';
import 'package:skylink/presentation/widget/camera/platform_webview.dart';

class CameraMainView extends StatefulWidget {
  const CameraMainView({super.key});

  @override
  State<CameraMainView> createState() => _CameraMainViewState();
}

class _CameraMainViewState extends State<CameraMainView>
    with AutomaticKeepAliveClientMixin {
  String cameraStreamUrl = "https://mwnijb6jsdya.connect.remote.it/";

  // Use stable key to prevent WebView rebuild during parent widget changes
  static const Key _stableWebViewKey = ValueKey('camera_webview_stable');
  Key _webViewKey = _stableWebViewKey;

  @override
  bool get wantKeepAlive => true;

  void _refreshCurrentUrl() {
    setState(() {
      // Only create new key when explicitly refreshing
      _webViewKey = UniqueKey();
    });

    // Reset to stable key after a frame to allow WebView to rebuild once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _webViewKey = _stableWebViewKey;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Material(
      elevation: 8, // Add elevation to ensure it stays above other elements
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: BoxConstraints(
          minHeight:
              screenHeight * 0.2, // 40% of screen height instead of fixed 700
          minWidth: screenWidth > 500 ? 300 : 200, // Responsive min width
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Stack(
          clipBehavior: Clip.none, // Ensure content is not clipped
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PlatformWebView(
                  key: _webViewKey,
                  url: cameraStreamUrl,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),

            // Control buttons
            Positioned(
              bottom: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Refresh button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _refreshCurrentUrl,
                      tooltip: 'Tải lại luồng stream',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
