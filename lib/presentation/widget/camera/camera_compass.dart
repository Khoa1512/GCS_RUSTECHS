import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:glass_kit/glass_kit.dart';

class CameraCompass extends StatefulWidget {
  const CameraCompass({super.key});

  @override
  State<CameraCompass> createState() => _CameraCompassState();
}

class _CameraCompassState extends State<CameraCompass> {
  final double _fakeDirection = 45.0; // Fake compass direction in degrees

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(12),
      height: 120,
      width: 120,
      gradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.40),
          Colors.white.withOpacity(0.10),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderGradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.60),
          Colors.white.withOpacity(0.10),
          Colors.lightBlueAccent.withOpacity(0.05),
          Colors.lightBlueAccent.withOpacity(0.6),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: [0.0, 0.39, 0.40, 1.0],
      ),
      blur: 15.0,
      borderWidth: 1.5,
      elevation: 3.0,
      isFrostedGlass: true,
      shadowColor: Colors.black.withOpacity(0.20),
      alignment: Alignment.center,
      frostedOpacity: 0.12,
      margin: EdgeInsets.all(8.0),
      padding: EdgeInsets.all(16.0),
      child: _buildCompass(),
    );
  }

  Widget _buildCompass() {
    return StreamBuilder<CompassEvent>(
      stream: FlutterCompass.events,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Icon(Icons.error, color: Colors.red);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          );
        }

        double? direction = snapshot.data!.heading;

        if (direction == null) {
          return Icon(Icons.error, color: Colors.red);
        }

        return Transform.rotate(
          angle: (direction * (math.pi / 180) * -1),
          child: Icon(Icons.navigation, size: 48, color: Colors.white),
        );
      },
    );
  }
}
