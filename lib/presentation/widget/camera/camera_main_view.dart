import 'package:flutter/material.dart';
import 'package:skylink/core/constant/app_image.dart';
import 'package:skylink/presentation/widget/camera/camera_status.dart';

class CameraMainView extends StatefulWidget {
  const CameraMainView({super.key});

  @override
  State<CameraMainView> createState() => _CameraMainViewState();
}

class _CameraMainViewState extends State<CameraMainView> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.expand(
              child: Image.asset(
                AppImage.camImage,
                fit: BoxFit
                    .cover, // Changed from fill to cover for better aspect ratio
              ),
            ),
          ),
          // Camera overlay elements
          Positioned(top: 0, left: 0, bottom: 0, child: CameraStatus()),
          // Optional: Add fullscreen button for camera
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.fullscreen, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
