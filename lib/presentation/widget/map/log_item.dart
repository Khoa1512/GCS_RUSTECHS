import 'package:flutter/material.dart';
import 'package:skylink/data/models/flight_log_model.dart';

class FlightLogItem extends StatelessWidget {
  final FlightLog flightLog;
  const FlightLogItem({super.key, required this.flightLog});

  Color _getTypeColor() {
    switch (flightLog.type) {
      case FlightLogType.notification:
        return Colors.blue;
      case FlightLogType.warning:
        return Colors.orange;
      case FlightLogType.error:
        return Colors.red;
      case FlightLogType.success:
        return Colors.green;
    }
  }

  String _getTypeText() {
    switch (flightLog.type) {
      case FlightLogType.notification:
        return 'INFO';
      case FlightLogType.warning:
        return 'WARN';
      case FlightLogType.error:
        return 'ERROR';
      case FlightLogType.success:
        return 'SUCCESS';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.3),
        border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flightLog.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${flightLog.time.hour.toString().padLeft(2, '0')}:${flightLog.time.minute.toString().padLeft(2, '0')}:${flightLog.time.second.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[300],
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getTypeColor(),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _getTypeColor().withOpacity(0.7)),
            ),
            child: Text(
              _getTypeText(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
