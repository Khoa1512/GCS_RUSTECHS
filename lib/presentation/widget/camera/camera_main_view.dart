import 'package:flutter/material.dart';
import 'package:skylink/presentation/widget/camera/platform_webview.dart';
import 'package:skylink/presentation/widget/camera/camera_stream_settings.dart';

class CameraMainView extends StatefulWidget {
  const CameraMainView({super.key});

  @override
  State<CameraMainView> createState() => _CameraMainViewState();
}

class _CameraMainViewState extends State<CameraMainView>
    with AutomaticKeepAliveClientMixin {
  // Camera stream URL from third-party web service
  // Actual gimbal camera stream URL
  String cameraStreamUrl = "https://szx3j7twuwon.connect.remote.it/";

  // Settings overlay
  bool showSettings = false;

  // Key to force rebuild WebView when URL changes
  Key _webViewKey = UniqueKey();

  @override
  bool get wantKeepAlive => true; // Keep widget alive

  void _updateStreamUrl(String newUrl) async {
    // Debug info
    // print('Input URL: "$newUrl"');
    // print('URL trimmed: "${newUrl.trim()}"');

    // Trim whitespace first
    newUrl = newUrl.trim();

    // Validate URL before updating
    final uri = Uri.tryParse(newUrl);

    if (newUrl.isEmpty || uri == null || !uri.hasScheme) {
      print('Validation failed - Invalid URL: $newUrl');
      return;
    }

    setState(() {
      cameraStreamUrl = newUrl;
      _webViewKey = UniqueKey(); // Create new key to force rebuild WebView
    });

    // Small delay to ensure proper rebuild
    await Future.delayed(Duration(milliseconds: 100));

    // print('Camera stream URL updated to: $newUrl');
  }

  void _toggleSettings() {
    setState(() {
      showSettings = !showSettings;
    });
  }

  void _refreshCurrentUrl() {
    setState(() {
      _webViewKey = UniqueKey(); // Create new key to force rebuild WebView
    });

    // print('Camera stream refreshed with URL: $cameraStreamUrl');
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
              screenHeight * 0.4, // 40% of screen height instead of fixed 700
          minWidth: screenWidth > 600 ? 300 : 200, // Responsive min width
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Stack(
          clipBehavior: Clip.none, // Ensure content is not clipped
          children: [
            // WebView/Image layer - placed at the bottom
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
            // Positioned(top: 0, left: 0, bottom: 0, child: CameraStatus()),

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
                      tooltip: 'Refresh camera stream',
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Settings button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _toggleSettings,
                      tooltip: 'Camera Stream Settings',
                    ),
                  ),
                ],
              ),
            ),

            // Settings overlay - placed at the top with highest z-index
            if (showSettings)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CameraStreamSettings(
                        currentUrl: cameraStreamUrl,
                        onUrlChanged: _updateStreamUrl,
                        onClose: _toggleSettings,
                      ),
                    ),
                  ),
                ),
              ),
            // Positioned(top: 550, right: 0, bottom: 0, child: CameraCompass()),
          ],
        ), // Đóng Stack
      ), // Đóng Container
    ); // Đóng Material
  }
}
