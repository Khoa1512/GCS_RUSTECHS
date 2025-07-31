import 'package:flutter/material.dart';
import 'package:skylink/responsive/demension.dart';
import 'package:skylink/presentation/widget/connection/connection_widget.dart'
    as connection;
import 'dart:async';

class AppStatusBar extends StatefulWidget {
  const AppStatusBar({super.key});

  @override
  State<AppStatusBar> createState() => _AppStatusBarState();
}

class _AppStatusBarState extends State<AppStatusBar> {
  bool _isHovered = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh every 500ms to update connection status
    _refreshTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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
              margin: EdgeInsets.all(
                context.responsiveSpacing(mobile: 4, tablet: 6, desktop: 8),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: context.responsiveSpacing(
                  mobile: 12,
                  tablet: 16,
                  desktop: 20,
                ),
                vertical: context.responsiveSpacing(
                  mobile: 8,
                  tablet: 10,
                  desktop: 12,
                ),
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
                    _buildConnectionStatus(),
                    SizedBox(width: ResponsiveDimensions.spacingM),
                    _buildTimeItem(text: '11:43 AM'),
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

  Widget _buildConnectionStatus() {
    final connectionState = connection.ConnectionManager.currentState;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (connectionState) {
      case connection.ConnectionState.disconnected:
        statusText = 'Disconnected';
        statusColor = Colors.red.shade600;
        statusIcon = Icons.wifi_off;
        break;
      case connection.ConnectionState.gpsConnected:
        statusText = 'GPS Only';
        statusColor = Colors.orange.shade600;
        statusIcon = Icons.gps_fixed;
        break;
      case connection.ConnectionState.fullyConnected:
        statusText = 'Connected';
        statusColor = const Color(0xFF00C896);
        statusIcon = Icons.wifi;
        break;
    }

    return GestureDetector(
      onTap: connectionState != connection.ConnectionState.disconnected
          ? connection.ConnectionManager.onDisconnect
          : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, size: 12, color: Colors.white),
            SizedBox(width: 4),
            Text(
              statusText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (connectionState != connection.ConnectionState.disconnected) ...[
              SizedBox(width: 4),
              Icon(Icons.close, size: 10, color: Colors.white70),
            ],
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
