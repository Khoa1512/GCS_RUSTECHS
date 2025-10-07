import 'package:flutter/material.dart';
import 'package:skylink/responsive/demension.dart';
import 'package:get/get.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'package:skylink/services/connection_manager.dart';
import 'package:skylink/presentation/widget/connection/connection_dialog.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class AppStatusBar extends StatefulWidget {
  const AppStatusBar({super.key});

  @override
  State<AppStatusBar> createState() => _AppStatusBarState();
}

class _AppStatusBarState extends State<AppStatusBar> {
  bool _isHovered = false;
  final TelemetryService _telemetryService = TelemetryService();
  StreamSubscription? _connectionSubscription;
  bool _isConnected = false;

  // Time variables
  String _currentTime = '';
  Timer? _timeTimer;

  @override
  void initState() {
    super.initState();
    _isConnected = _telemetryService.isConnected;

    // Listen to connection status changes
    _connectionSubscription = _telemetryService.connectionStream.listen((
      connected,
    ) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
      }
    });

    // Initialize time and start timer
    _updateTime();
    _startTimeUpdates();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _timeTimer?.cancel();
    super.dispose();
  }

  void _showConnectionDialog() {
    ConnectionDialog.show(context);
  }

  void _startMqttTest() async {
    try {
      final connectionManager = Get.find<ConnectionManager>();
      await connectionManager.startMqttOnlyMode();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.science, color: Colors.white),
                SizedBox(width: 8),
                Text('MQTT Test Mode - Receiving telemetry data'),
              ],
            ),
            backgroundColor: Colors.purple,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('MQTT Test Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateTime() {
    final now = DateTime.now();
    final formatter = DateFormat('h:mm a');
    if (mounted) {
      setState(() {
        _currentTime = formatter.format(now);
      });
    }
  }

  void _startTimeUpdates() {
    // Update time every minute
    _timeTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      _updateTime();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ensure we have valid constraints for the status bar
        final maxWidth = constraints.maxWidth != double.infinity
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            minHeight: 30,
            maxHeight: 80,
          ),
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              margin: EdgeInsets.all(context.responsiveSpacing(desktop: 8)),
              padding: EdgeInsets.symmetric(
                horizontal: context.responsiveSpacing(desktop: 20),
                vertical: context.responsiveSpacing(desktop: 12),
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isHovered
                      ? Colors.white.withOpacity(0.2)
                      : Colors.white.withOpacity(0.1),
                ),
                color: _isHovered
                    ? const Color(0xFF3C3C3E)
                    : const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(8),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInfoItem(
                      icon: Icons.speed,
                      text: '243.4 km',
                      iconColor: Colors.white70,
                      textColor: Colors.white,
                    ),
                    SizedBox(width: ResponsiveDimensions.spacingM),
                    _buildInfoItem(
                      icon: Icons.cloud_outlined,
                      text: 'Rain, 36°C',
                      iconColor: Colors.white70,
                      textColor: Colors.white,
                    ),
                    SizedBox(width: ResponsiveDimensions.spacingM),
                    _buildDroneConnection(),
                    SizedBox(width: ResponsiveDimensions.spacingM),
                    _buildTimeItem(
                      text: _currentTime.isNotEmpty ? _currentTime : '11:43 AM',
                    ),
                    SizedBox(width: ResponsiveDimensions.spacingS),
                    _buildBatteryIcon(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDroneConnection() {
    return GestureDetector(
      onTap: _showConnectionDialog,
      onLongPress: _startMqttTest,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _isConnected
              ? const Color(0xFF00C896)
              : const Color(0xFFFF6B6B),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isConnected ? Icons.link : Icons.link_off,
              color: Colors.white,
              size: 14,
            ),
            SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _isConnected ? 'MAVLink' : 'Tap to connect',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String text,
    required Color iconColor,
    required Color textColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 16),
        SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeItem({required String text}) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildBatteryIcon() {
    return Icon(Icons.battery_full, color: Colors.white70, size: 16);
  }
}
