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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
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
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              AppImage.camImage,
              fit: BoxFit
                  .cover, // Changed from fill to cover for better aspect ratio
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Positioned(top: 0, left: 0, bottom: 0, child: CameraStatus()),
          // Positioned(top: 550, right: 0, bottom: 0, child: CameraCompass()),
        ],
      ),
    );
  }
}
