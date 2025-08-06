import 'package:flutter/material.dart';
import 'package:skylink/presentation/widget/camera/platform_webview.dart';
import 'package:skylink/presentation/widget/camera/camera_stream_settings.dart';

class CameraMainView extends StatefulWidget {
  const CameraMainView({super.key});

  @override
  State<CameraMainView> createState() => _CameraMainViewState();
}

class _CameraMainViewState extends State<CameraMainView> {
  // URL của camera stream từ web bên thứ 3
  // URL thực tế của gimbal camera stream
  String cameraStreamUrl = "https://mr2v2r37jzqd.connect.remote.it/";

  // Settings overlay
  bool showSettings = false;

  void _updateStreamUrl(String newUrl) {
    setState(() {
      cameraStreamUrl = newUrl;
    });
  }

  void _toggleSettings() {
    setState(() {
      showSettings = !showSettings;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Material(
      elevation: 8, // Thêm elevation để đảm bảo nằm trên các element khác
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
          clipBehavior: Clip.none, // Đảm bảo không clip content
          children: [
            // WebView/Image layer - đặt ở dưới cùng
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PlatformWebView(
                  url: cameraStreamUrl,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            // Positioned(top: 0, left: 0, bottom: 0, child: CameraStatus()),

            // Control buttons - chỉ có settings button
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
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
                  tooltip: 'Cài đặt camera stream',
                ),
              ),
            ),

            // Settings overlay - đặt ở trên cùng với z-index cao nhất
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
