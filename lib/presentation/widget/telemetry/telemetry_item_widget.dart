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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          // Responsive breakpoints based on available space
          final isTiny = width < 60 || height < 50;
          final isSmall = width < 80 || height < 60;
          final isMedium = width < 100 || height < 70;

          // Adaptive sizing
          final padding = isTiny ? 4.0 : (isSmall ? 6.0 : 8.0);
          final borderRadius = isTiny ? 4.0 : (isSmall ? 6.0 : 8.0);
          final labelFontSize = isTiny
              ? 10.0
              : (isSmall ? 11.0 : (isMedium ? 12.0 : 13.0)); // Increased
          final valueFontSize = isTiny
              ? 10.0
              : (isSmall ? 12.0 : (isMedium ? 14.0 : 16.0));
          final unitFontSize = isTiny
              ? 7.0
              : (isSmall ? 8.0 : (isMedium ? 9.0 : 10.0));
          final spacing = isTiny ? 1.0 : (isSmall ? 2.0 : 4.0);
          final unitSpacing = isTiny ? 0.5 : (isSmall ? 1.0 : 2.0);

          return Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: Colors.grey.shade800.withValues(alpha: 0.5),
              border: Border.all(
                color: telemetry.color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  telemetry.label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: spacing),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          telemetry.value,
                          style: TextStyle(
                            color: telemetry.color,
                            fontSize: valueFontSize,
                            fontWeight: FontWeight.w700,
                            letterSpacing: isTiny ? 0.1 : (isSmall ? 0.2 : 0.5),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (telemetry.unit.isNotEmpty) ...[
                        SizedBox(
                          width: isTiny ? 1.0 : 2.0,
                        ), // Much smaller spacing
                        Text(
                          telemetry.unit,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: unitFontSize,
                            fontWeight: FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
