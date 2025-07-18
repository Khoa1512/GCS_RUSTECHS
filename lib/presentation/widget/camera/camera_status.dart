import 'package:flutter/material.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:skylink/presentation/widget/camera/line2_sample_chart.dart';

class CameraStatus extends StatefulWidget {
  const CameraStatus({super.key});

  @override
  State<CameraStatus> createState() => _CameraStatusState();
}

class _CameraStatusState extends State<CameraStatus> {
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(12),
      width: 200,
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
      padding: EdgeInsets.all(8.0),

      child: Column(
        children: [
          _buildHDRStatus(),
          _buildCameraSolution(solution: '4K', fps: '100'),
          const Spacer(),

          Row(
            children: [
              Expanded(
                child: _buildColoredBox(color: Colors.red, text: 'R'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildColoredBox(color: Colors.green, text: 'G'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildColoredBox(color: Colors.blue, text: 'B'),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildColoredBox(color: Colors.yellow, text: 'Y'),
              ),
            ],
          ),
          SizedBox(height: 16),
          LineChartSample2(),
        ],
      ),
    );
  }

  Widget _buildCameraSolution({required String solution, required String fps}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          Text(
            solution,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
          ),
          Text(' - '),
          Text(
            "$fps fps",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  _buildColoredBox({required Color color, required String text}) {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade800,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          SizedBox(width: 8),
          Text(text, style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  _buildHDRStatus() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade800,
      ),
      padding: EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text('HDR'),
            ],
          ),
        ],
      ),
    );
  }
}
