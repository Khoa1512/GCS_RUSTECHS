import 'package:flutter/material.dart';
import 'package:skylink/core/constant/app_color.dart';

enum ConnectionState { disconnected, gpsConnected, fullyConnected }

class ConnectionManager {
  static ConnectionState _currentState = ConnectionState.disconnected;
  static VoidCallback? _onDisconnect;

  static ConnectionState get currentState => _currentState;
  static VoidCallback? get onDisconnect => _onDisconnect;

  static void updateState(
    ConnectionState newState, {
    VoidCallback? onDisconnect,
  }) {
    _currentState = newState;
    _onDisconnect = onDisconnect;
  }
}

class ConnectionWidget extends StatefulWidget {
  final ConnectionState connectionState;
  final VoidCallback? onConnectPressed;
  final VoidCallback? onDisconnectPressed;

  const ConnectionWidget({
    super.key,
    required this.connectionState,
    this.onConnectPressed,
    this.onDisconnectPressed,
  });

  @override
  State<ConnectionWidget> createState() => _ConnectionWidgetState();
}

class _ConnectionWidgetState extends State<ConnectionWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.connectionState != ConnectionState.disconnected) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ConnectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connectionState != oldWidget.connectionState) {
      if (widget.connectionState != ConnectionState.disconnected) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade800, Colors.grey.shade900],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildConnectionIcon(),
          SizedBox(height: 24),
          _buildConnectionStatus(),
          SizedBox(height: 32),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildConnectionIcon() {
    IconData icon;
    Color color;

    switch (widget.connectionState) {
      case ConnectionState.disconnected:
        icon = Icons.signal_wifi_off;
        color = Colors.red.shade400;
        break;
      case ConnectionState.gpsConnected:
        icon = Icons.gps_fixed;
        color = Colors.orange.shade400;
        break;
      case ConnectionState.fullyConnected:
        icon = Icons.videocam;
        color = AppColors.primaryColor;
        break;
    }

    Widget iconWidget = Icon(icon, size: 64, color: color);

    if (widget.connectionState != ConnectionState.disconnected) {
      iconWidget = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: iconWidget,
          );
        },
      );
    }

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Center(child: iconWidget),
    );
  }

  Widget _buildConnectionStatus() {
    String title;
    String subtitle;

    switch (widget.connectionState) {
      case ConnectionState.disconnected:
        title = 'UAV Disconnected';
        subtitle = 'Press connect to establish connection with your drone';
        break;
      case ConnectionState.gpsConnected:
        title = 'GPS Connected';
        subtitle = 'Waiting for gimbal camera connection...';
        break;
      case ConnectionState.fullyConnected:
        title = 'Fully Connected';
        subtitle = 'GPS and camera feed active';
        break;
    }

    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    if (widget.connectionState == ConnectionState.fullyConnected) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildButton(
            'Disconnect',
            Icons.power_off,
            Colors.red.shade600,
            widget.onDisconnectPressed,
          ),
        ],
      );
    }

    return _buildButton(
      widget.connectionState == ConnectionState.disconnected
          ? 'Connect to UAV'
          : 'Connecting...',
      widget.connectionState == ConnectionState.disconnected
          ? Icons.power
          : Icons.hourglass_empty,
      AppColors.primaryColor,
      widget.connectionState == ConnectionState.disconnected
          ? widget.onConnectPressed
          : null,
    );
  }

  Widget _buildButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback? onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      label: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
      ),
    );
  }
}
