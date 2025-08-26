import 'package:flutter/material.dart';
import 'package:skylink/core/constant/app_color.dart';
import 'package:skylink/presentation/widget/custom/custom_corner_border.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'dart:async';

class BatteryStatus extends StatefulWidget {
  const BatteryStatus({super.key});

  @override
  State<BatteryStatus> createState() => _BatteryStatusState();
}

class _BatteryStatusState extends State<BatteryStatus> {
  bool _isHovered = false;
  StreamSubscription? _batterySubscription;
  StreamSubscription? _telemetrySubscription;
  StreamSubscription? _connectionSubscription;
  final TelemetryService _telemetryService = TelemetryService();

  // Battery data from API
  double _batteryPercentage = 0.0;
  double _batteryVoltage = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeBatteryData();
    _startBatteryUpdates();
    _listenToTelemetryStream();
    _listenToConnectionChanges();
  }

  @override
  void dispose() {
    _batterySubscription?.cancel();
    _telemetrySubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  void _initializeBatteryData() {
    // Get initial battery data from TelemetryService
    if (_telemetryService.isConnected) {
      _batteryPercentage = _telemetryService.currentTelemetry['battery'] ?? 0.0;
      _batteryVoltage =
          _telemetryService.currentTelemetry['voltageBattery'] ?? 0.0;
    } else {
      // Set to 0 when not connected
      _batteryPercentage = 0.0;
      _batteryVoltage = 0.0;
    }
  }

  void _startBatteryUpdates() {
    _batterySubscription = Stream.periodic(Duration(seconds: 2)).listen((_) {
      _updateBatteryData();
    });
  }

  void _updateBatteryData() {
    if (mounted) {
      setState(() {
        // Get real-time battery data from TelemetryService
        if (_telemetryService.isConnected) {
          _batteryPercentage =
              _telemetryService.currentTelemetry['battery'] ?? 0.0;
          _batteryVoltage =
              _telemetryService.currentTelemetry['voltageBattery'] ?? 0.0;
        } else {
          // Set to 0 when not connected
          _batteryPercentage = 0.0;
          _batteryVoltage = 0.0;
        }
      });
    }
  }

  void _listenToTelemetryStream() {
    // Listen to telemetry stream for real-time battery updates
    _telemetrySubscription = _telemetryService.telemetryStream.listen((
      telemetryData,
    ) {
      if (mounted) {
        bool needsUpdate = false;

        if (telemetryData.containsKey('battery')) {
          _batteryPercentage = telemetryData['battery'] ?? 0.0;
          needsUpdate = true;
        }

        if (telemetryData.containsKey('voltageBattery')) {
          _batteryVoltage = telemetryData['voltageBattery'] ?? 0.0;
          needsUpdate = true;
        }

        if (needsUpdate) {
          setState(() {});
        }
      }
    });
  }

  void _listenToConnectionChanges() {
    // Listen to connection changes to reset battery data when disconnected
    _connectionSubscription = _telemetryService.connectionStream.listen((
      isConnected,
    ) {
      if (mounted && !isConnected) {
        setState(() {
          _batteryPercentage = 0.0;
          _batteryVoltage = 0.0;
        });
      }
    });
  }

  Color _getBatteryColor() {
    if (_batteryPercentage > 60) return Colors.green;
    if (_batteryPercentage > 30) return Colors.orange;
    return Colors.red;
  }

  IconData _getBatteryIcon() {
    if (_batteryPercentage > 80) return Icons.battery_full;
    if (_batteryPercentage > 60) return Icons.battery_6_bar;
    if (_batteryPercentage > 40) return Icons.battery_4_bar;
    if (_batteryPercentage > 20) return Icons.battery_2_bar;
    return Icons.battery_1_bar;
  }

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
                  padding: EdgeInsets.all(16),
                  width: double.infinity,
                  child: Row(
                    children: [
                      // Battery icon
                      Icon(
                        _getBatteryIcon(),
                        color: _isHovered ? Colors.black : _getBatteryColor(),
                        size: 24,
                      ),
                      SizedBox(width: 12),

                      // Progress bar with percentage and voltage
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Battery info row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Percentage text
                                Text(
                                  "${_batteryPercentage.toStringAsFixed(1)}%",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _isHovered
                                        ? Colors.black
                                        : Colors.white,
                                  ),
                                ),
                                // Voltage text
                                Text(
                                  "${_batteryVoltage.toStringAsFixed(2)}V",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: _isHovered
                                        ? Colors.black87
                                        : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),

                            // Progress bar
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.grey.shade600,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _batteryPercentage / 100,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _getBatteryColor(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
