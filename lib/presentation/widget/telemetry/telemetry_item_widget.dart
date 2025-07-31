import 'package:flutter/material.dart';
import 'package:skylink/data/telemetry_data.dart';

class TelemetryItemWidget extends StatelessWidget {
  final TelemetryData telemetry;
  final VoidCallback onTap;

  const TelemetryItemWidget({
    super.key,
    required this.telemetry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(6), // Reduced from 8
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade800.withValues(alpha: 0.5),
          border: Border.all(
            color: telemetry.color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              telemetry.label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10, // Reduced from 11
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2), // Reduced from 4
            Row(
              children: [
                Flexible(
                  child: Text(
                    telemetry.value,
                    style: TextStyle(
                      color: telemetry.color,
                      fontSize: 14, // Reduced from 16
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (telemetry.unit.isNotEmpty) ...[
                  SizedBox(width: 2),
                  Text(
                    telemetry.unit,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 9, // Reduced from 10
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
