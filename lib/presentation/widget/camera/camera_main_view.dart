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
      constraints: BoxConstraints(minHeight: 700, minWidth: 300),
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
              fit: BoxFit.fill,
              height: 700,
              width: 2000,
            ),
          ),
          Positioned(top: 0, left: 0, bottom: 0, child: CameraStatus()),
          // Positioned(top: 550, right: 0, bottom: 0, child: CameraCompass()),
        ],
      ),
    );
  }
}
