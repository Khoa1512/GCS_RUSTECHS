import 'package:flutter/material.dart';
import 'package:skylink/core/constant/app_color.dart';
import 'package:skylink/data/model/flight_information_model.dart';
import 'package:skylink/presentation/widget/custom/custom_corner_border.dart';

class BatteryStatus extends StatefulWidget {
  final FlightInformationModel flightInformation;
  const BatteryStatus({super.key, required this.flightInformation});

  @override
  State<BatteryStatus> createState() => _BatteryStatusState();
}

class _BatteryStatusState extends State<BatteryStatus> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Battery Status",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
              child: CustomPaint(
                painter: CornerBorderPainter(),
                child: Container(
                  color: _isHovered
                      ? AppColors.primaryColor
                      : Colors.grey.shade800,
                  padding: EdgeInsets.all(10),
                  height: 50,
                  width: double.infinity,
                  child: Row(
                    children: [
                      Icon(
                        Icons.battery_charging_full,
                        color: _isHovered
                            ? Colors.black
                            : AppColors.primaryColor,
                      ),
                      Text("${widget.flightInformation.battery} %"),
                      const Spacer(),

                      Text("4500/4500 mAh |"),
                      const SizedBox(width: 10),
                      Text("27°C"),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
