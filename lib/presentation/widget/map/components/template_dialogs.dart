import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

class OrbitTemplateDialog extends StatefulWidget {
  final LatLng centerPoint;
  final Function(double radius, double altitude, int points) onConfirm;

  const OrbitTemplateDialog({
    super.key,
    required this.centerPoint,
    required this.onConfirm,
  });

  @override
  State<OrbitTemplateDialog> createState() => _OrbitTemplateDialogState();
}

class _OrbitTemplateDialogState extends State<OrbitTemplateDialog> {
  final _radiusController = TextEditingController(text: '100');
  final _altitudeController = TextEditingController(text: '50');
  int _points = 8;

  @override
  void dispose() {
    _radiusController.dispose();
    _altitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2D2D2D),
      title: const Text(
        'Tạo nhiệm vụ bay tròn',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Center point display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location, color: Colors.teal, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tâm: ${widget.centerPoint.latitude.toStringAsFixed(6)}, ${widget.centerPoint.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Radius input
          _buildTextField(
            label: 'Bán kính',
            controller: _radiusController,
            suffix: 'm',
            hint: 'Bán kính bay tròn theo mét',
          ),

          const SizedBox(height: 12),

          // Altitude input
          _buildTextField(
            label: 'Độ cao',
            controller: _altitudeController,
            suffix: 'm',
            hint: 'Độ cao bay',
          ),

          const SizedBox(height: 16),

          // Points slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Điểm waypoint: $_points',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Slider(
                value: _points.toDouble(),
                min: 4,
                max: 16,
                divisions: 12,
                activeColor: Colors.teal,
                inactiveColor: Colors.grey,
                onChanged: (value) {
                  setState(() {
                    _points = value.round();
                  });
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _createOrbit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
          child: const Text('Tạo'),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? suffix,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade700),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade700),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.teal),
            ),
            suffixText: suffix,
            suffixStyle: const TextStyle(color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
        ),
      ],
    );
  }

  void _createOrbit() {
    final radius = double.tryParse(_radiusController.text) ?? 100;
    final altitude = double.tryParse(_altitudeController.text) ?? 50;

    if (radius <= 0 || altitude <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập các giá trị dương hợp lệ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onConfirm(radius, altitude, _points);
    Navigator.of(context).pop();
  }
}

class SurveyTemplateDialog extends StatefulWidget {
  final LatLng centerPoint;
  final Function(
    LatLng topLeft,
    LatLng bottomRight,
    double altitude,
    double spacing,
  )
  onConfirm;

  const SurveyTemplateDialog({
    super.key,
    required this.centerPoint,
    required this.onConfirm,
  });

  @override
  State<SurveyTemplateDialog> createState() => _SurveyTemplateDialogState();
}

class _SurveyTemplateDialogState extends State<SurveyTemplateDialog> {
  final _widthController = TextEditingController(text: '200');
  final _heightController = TextEditingController(text: '200');
  final _altitudeController = TextEditingController(text: '50');
  final _spacingController = TextEditingController(text: '30');

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _altitudeController.dispose();
    _spacingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2D2D2D),
      title: const Text(
        'Tạo nhiệm vụ khảo sát',
        style: TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Center point display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.center_focus_strong,
                  color: Colors.purple,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tâm: ${widget.centerPoint.latitude.toStringAsFixed(6)}, ${widget.centerPoint.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Dimensions
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Chiều rộng',
                  controller: _widthController,
                  suffix: 'm',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  label: 'Chiều dài',
                  controller: _heightController,
                  suffix: 'm',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Flight parameters
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'Độ cao',
                  controller: _altitudeController,
                  suffix: 'm',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  label: 'Khoảng cách làn',
                  controller: _spacingController,
                  suffix: 'm',
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _createSurvey,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
          child: const Text('Tạo'),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade700),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade700),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.purple),
            ),
            suffixText: suffix,
            suffixStyle: const TextStyle(color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
        ),
      ],
    );
  }

  void _createSurvey() {
    final width = double.tryParse(_widthController.text) ?? 200;
    final height = double.tryParse(_heightController.text) ?? 200;
    final altitude = double.tryParse(_altitudeController.text) ?? 50;
    final spacing = double.tryParse(_spacingController.text) ?? 30;

    if (width <= 0 || height <= 0 || altitude <= 0 || spacing <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập các giá trị dương hợp lệ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Calculate corners from center point and dimensions
    final center = widget.centerPoint;

    // Convert meters to degrees (approximate)
    final latOffset = (height / 2) / 111320; // 1 degree lat ≈ 111320 meters
    final lngOffset =
        (width / 2) / (111320 * math.cos(center.latitude * math.pi / 180));

    final topLeft = LatLng(
      center.latitude + latOffset,
      center.longitude - lngOffset,
    );
    final bottomRight = LatLng(
      center.latitude - latOffset,
      center.longitude + lngOffset,
    );

    widget.onConfirm(topLeft, bottomRight, altitude, spacing);
    Navigator.of(context).pop();
  }
}
