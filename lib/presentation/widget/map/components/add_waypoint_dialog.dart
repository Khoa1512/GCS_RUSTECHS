import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class AddWaypointDialog extends StatefulWidget {
  final Function(LatLng position, double altitude) onAddWaypoint;

  const AddWaypointDialog({super.key, required this.onAddWaypoint});

  @override
  State<AddWaypointDialog> createState() => _AddWaypointDialogState();
}

class _AddWaypointDialogState extends State<AddWaypointDialog> {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _altController = TextEditingController(text: '50');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _altController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.teal.withValues(alpha: 0.3), width: 1),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_location, color: Colors.teal, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Thêm waypoint',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập tọa độ waypoint:',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Latitude input
            _buildCoordinateField(
              controller: _latController,
              label: 'Vĩ độ',
              hint: 'ví dụ: 10.762622',
              icon: Icons.navigation,
              validator: _validateLatitude,
            ),

            const SizedBox(height: 16),

            // Longitude input
            _buildCoordinateField(
              controller: _lngController,
              label: 'Kinh độ',
              hint: 'ví dụ: 106.660172',
              icon: Icons.explore,
              validator: _validateLongitude,
            ),

            const SizedBox(height: 16),

            // Altitude input
            _buildCoordinateField(
              controller: _altController,
              label: 'Độ cao (m)',
              hint: 'ví dụ: 50',
              icon: Icons.height,
              validator: _validateAltitude,
            ),

            const SizedBox(height: 16),

            // Helper text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mẹo: Bạn cũng có thể click trực tiếp trên bản đồ để thêm waypoint.',
                      style: TextStyle(
                        color: Colors.blue.shade200,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton.icon(
          onPressed: _addWaypoint,
          icon: const Icon(Icons.add_location, size: 18),
          label: const Text('Thêm waypoint'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoordinateField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white60, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.teal, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }

  String? _validateLatitude(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vĩ độ là bắt buộc';
    }
    final lat = double.tryParse(value);
    if (lat == null) {
      return 'Định dạng vĩ độ không hợp lệ';
    }
    if (lat < -90 || lat > 90) {
      return 'Vĩ độ phải từ -90 đến 90';
    }
    return null;
  }

  String? _validateLongitude(String? value) {
    if (value == null || value.isEmpty) {
      return 'Kinh độ là bắt buộc';
    }
    final lng = double.tryParse(value);
    if (lng == null) {
      return 'Định dạng kinh độ không hợp lệ';
    }
    if (lng < -180 || lng > 180) {
      return 'Kinh độ phải từ -180 đến 180';
    }
    return null;
  }

  String? _validateAltitude(String? value) {
    if (value == null || value.isEmpty) {
      return 'Độ cao là bắt buộc';
    }
    final alt = double.tryParse(value);
    if (alt == null) {
      return 'Định dạng độ cao không hợp lệ';
    }
    if (alt < 0) {
      return 'Độ cao phải là số dương';
    }
    return null;
  }

  void _addWaypoint() {
    if (_formKey.currentState?.validate() ?? false) {
      final lat = double.parse(_latController.text);
      final lng = double.parse(_lngController.text);
      final alt = double.parse(_altController.text);

      widget.onAddWaypoint(LatLng(lat, lng), alt);
      Navigator.of(context).pop();
    }
  }
}
