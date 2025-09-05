import 'package:flutter/material.dart';
import 'package:skylink/core/constant/app_color.dart';
import 'package:skylink/data/telemetry_data.dart';
import 'package:skylink/presentation/widget/telemetry/telemetry_selector_dialog.dart';
import 'package:skylink/presentation/widget/telemetry/telemetry_item_widget.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'package:skylink/api/telemetry/mavlink_api.dart';
import 'dart:async';

// Class to hold MAVLink status messages
class MAVLinkStatusMessage {
  final String severity;
  final String text;
  final DateTime timestamp;

  MAVLinkStatusMessage({
    required this.severity,
    required this.text,
    required this.timestamp,
  });
}

class RealTimeInfoWidget extends StatefulWidget {
  const RealTimeInfoWidget({super.key});

  @override
  State<RealTimeInfoWidget> createState() => _RealTimeInfoWidgetState();
}

class _RealTimeInfoWidgetState extends State<RealTimeInfoWidget> {
  // TelemetryService instance
  final TelemetryService _telemetryService = TelemetryService();

  // Currently displayed telemetry (9 items)
  late List<TelemetryData> displayedTelemetry;

  // Status messages from MAVLink
  List<MAVLinkStatusMessage> _statusMessages = [];

  // Stream subscriptions
  StreamSubscription? _telemetrySubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _mavlinkSubscription;

  // Connection status
  bool _isConnected = false;

  // ============================================================================
  // PROFESSIONAL STATE TRACKING FOR UAV SYSTEMS
  // ============================================================================
  String? _lastFlightMode;
  bool _lastArmedStatus = false;
  String? _lastGpsFixType;
  int _lastSatelliteCount = -1;
  int _lastBatteryPercent = -1;
  bool _connectionEstablished = false;

  @override
  void initState() {
    super.initState();
    // Initialize telemetry service
    _telemetryService.initialize();

    // Initialize with default telemetry or real data
    _updateDisplayedTelemetry();

    // Initialize state tracking
    _initializeStateTracking();

    // Listen to telemetry updates
    _telemetrySubscription = _telemetryService.telemetryStream.listen((
      telemetryData,
    ) {
      if (mounted) {
        setState(() {
          _updateDisplayedTelemetry();
        });
      }
    });

    // Listen to connection status
    _connectionSubscription = _telemetryService.connectionStream.listen((
      connected,
    ) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
          if (!connected) {
            _handleDisconnection();
          }
        });
      }
    });

    // Listen to MAVLink events - PROFESSIONAL SYSTEM
    _mavlinkSubscription = _telemetryService.mavlinkAPI.eventStream.listen((
      event,
    ) {
      _handleProfessionalMAVLinkEvents(event);
    });
  }

  void _initializeStateTracking() {
  _lastFlightMode = _telemetryService.currentMode;
  _lastArmedStatus = _telemetryService.isArmed;
  _lastGpsFixType = _telemetryService.gpsFixType;
  _lastSatelliteCount =
    _telemetryService.currentTelemetry['satellites']?.toInt() ?? -1;
  _lastBatteryPercent =
    _telemetryService.currentTelemetry['battery']?.toInt() ?? -1;
  }

  void _handleDisconnection() {
    // Clear messages and reset all tracking when disconnected
    _statusMessages.clear();
    _connectionEstablished = false;
    _lastFlightMode = null;
    _lastGpsFixType = null;
    _lastSatelliteCount = -1;
    _lastBatteryPercent = -1;
  }

  // ============================================================================
  // PROFESSIONAL MAVLINK EVENT HANDLER
  // ============================================================================
  void _handleProfessionalMAVLinkEvents(MAVLinkEvent event) {
    if (!mounted) return;

    switch (event.type) {
      // ========================================
      // PRIORITY 1: SAFETY CRITICAL MESSAGES
      // ========================================

      case MAVLinkEventType.statusText:
        // Real autopilot messages - HIGHEST PRIORITY
        _handleAutopilotStatusText(event);
        break;

      case MAVLinkEventType.heartbeat:
        // System status, mode changes, arm/disarm
        _handleSystemHeartbeat(event);
        break;

      case MAVLinkEventType.connectionStateChanged:
        // Connection status changes
        _handleConnectionChanges(event);
        break;

      // ========================================
      // PRIORITY 2: OPERATIONAL MESSAGES
      // ========================================

      case MAVLinkEventType.gpsInfo:
        // GPS status changes only (not every update)
        _handleGpsStatusChanges(event);
        break;

      case MAVLinkEventType.batteryStatus:
        // Battery warnings and critical levels
        _handleBatteryWarnings(event);
        break;

      case MAVLinkEventType.allParametersReceived:
        // Parameter loading complete
        _addProfessionalMessage(
          'Info',
          'Parameters loaded successfully',
          event.timestamp,
        );
        break;

      // ========================================
      // SKIP HIGH-FREQUENCY DATA
      // ========================================
      case MAVLinkEventType.attitude:
      case MAVLinkEventType.position:
      case MAVLinkEventType.vfrHud:
      case MAVLinkEventType.parameterReceived:
        // These are for telemetry display, NOT status messages
        break;
      case MAVLinkEventType.sysStatus:
        // Not producing user-facing messages here
        break;
      case MAVLinkEventType.commandAck:
        // Could add command feedback later
        break;
      // ========================================
      // MISSION EVENTS (ignored here for status panel)
      // ========================================
      case MAVLinkEventType.missionCount:
      case MAVLinkEventType.missionItem:
      case MAVLinkEventType.missionCurrent:
      case MAVLinkEventType.missionItemReached:
      case MAVLinkEventType.missionAck:
      case MAVLinkEventType.missionUploadProgress:
      case MAVLinkEventType.missionUploadComplete:
      case MAVLinkEventType.missionDownloadProgress:
      case MAVLinkEventType.missionDownloadComplete:
      case MAVLinkEventType.missionCleared:
      case MAVLinkEventType.homePosition:
        // Not surfaced in this widget; handled by mission UI/flows
        break;
    }
  }

  // ============================================================================
  // PROFESSIONAL MESSAGE HANDLERS
  // ============================================================================

  void _handleAutopilotStatusText(MAVLinkEvent event) {
    // Real autopilot messages are HIGHEST priority
    final data = event.data as Map<String, dynamic>;
    final severity = data['severity'] ?? 'Info';
    final text = data['text'] ?? '';

    if (text.isNotEmpty) {
      _addProfessionalMessage(severity, text, event.timestamp);
    }
  }

  void _handleSystemHeartbeat(MAVLinkEvent event) {
  final currentMode = _telemetryService.currentMode;
  final isArmed = _telemetryService.isArmed;

    // First connection establishment
    if (!_connectionEstablished) {
      _addProfessionalMessage(
        'Info',
        'MAVLink heartbeat received',
        event.timestamp,
      );
      _addProfessionalMessage(
        'Info',
        'System online: $currentMode mode',
        event.timestamp,
      );
      _connectionEstablished = true;
    }

    // Flight mode changes
    if (_lastFlightMode != null && _lastFlightMode != currentMode) {
      _addProfessionalMessage(
        'Notice',
        'Mode: $_lastFlightMode → $currentMode',
        event.timestamp,
      );
    }
    _lastFlightMode = currentMode;

    // Arm/Disarm changes
    if (_lastArmedStatus != isArmed) {
      final severity = isArmed ? 'Warning' : 'Info';
      final status = isArmed ? 'ARMED' : 'DISARMED';
      _addProfessionalMessage(severity, 'Vehicle $status', event.timestamp);

      // Additional safety message for arming
      if (isArmed) {
        _addProfessionalMessage(
          'Warning',
          'Motors are now live - Exercise caution',
          event.timestamp,
        );
      }
    }
    _lastArmedStatus = isArmed;
  }

  void _handleConnectionChanges(MAVLinkEvent event) {
    final state = event.data as MAVLinkConnectionState;
    String message;
    String severity;

    switch (state) {
      case MAVLinkConnectionState.connected:
        message = 'MAVLink connection established';
        severity = 'Info';
        _connectionEstablished = true;
        break;
      case MAVLinkConnectionState.disconnected:
        message = 'MAVLink connection lost';
        severity = 'Error';
        _connectionEstablished = false;
        break;
      default:
        return;
    }

    _addProfessionalMessage(severity, message, event.timestamp);
  }

  void _handleGpsStatusChanges(MAVLinkEvent event) {
  final fixType = _telemetryService.gpsFixType;
  final satellites =
    _telemetryService.currentTelemetry['satellites']?.toInt() ?? 0;

    // GPS Fix Type changes
    if (_lastGpsFixType != null && _lastGpsFixType != fixType) {
      String severity = 'Info';
      String message = 'GPS: $_lastGpsFixType → $fixType';

      if (fixType.contains('No')) {
        severity = 'Error';
        message += ' - Navigation degraded';
      } else if (fixType.contains('2D')) {
        severity = 'Warning';
        message += ' - Altitude unreliable';
      } else if (fixType.contains('3D')) {
        severity = 'Info';
        message += ' - Full navigation available';
      } else if (fixType.contains('RTK')) {
        severity = 'Info';
        message += ' - High precision active';
      }

      _addProfessionalMessage(severity, message, event.timestamp);
    }
    _lastGpsFixType = fixType;

    // Significant satellite count changes
    if (_lastSatelliteCount != -1) {
      if (_lastSatelliteCount < 6 && satellites >= 6) {
        _addProfessionalMessage(
          'Info',
          'GPS lock acquired: $satellites satellites',
          event.timestamp,
        );
      } else if (_lastSatelliteCount >= 6 && satellites < 6) {
        _addProfessionalMessage(
          'Warning',
          'GPS lock degraded: $satellites satellites',
          event.timestamp,
        );
      } else if (_lastSatelliteCount > 0 && satellites == 0) {
        _addProfessionalMessage(
          'Error',
          'GPS signal lost - No satellites visible',
          event.timestamp,
        );
      }
    }
    _lastSatelliteCount = satellites;
  }

  void _handleBatteryWarnings(MAVLinkEvent event) {
  final battery =
    _telemetryService.currentTelemetry['battery']?.toInt() ?? 0;

    // Battery threshold warnings
    if (_lastBatteryPercent != -1) {
      // Critical levels
      if (_lastBatteryPercent > 15 && battery <= 15) {
        _addProfessionalMessage(
          'Critical',
          'BATTERY CRITICAL: $battery% - LAND IMMEDIATELY',
          event.timestamp,
        );
      }
      // Low levels
      else if (_lastBatteryPercent > 25 && battery <= 25) {
        _addProfessionalMessage(
          'Warning',
          'Battery low: $battery% - Consider landing soon',
          event.timestamp,
        );
      }
      // Very low levels
      else if (_lastBatteryPercent > 10 && battery <= 10) {
        _addProfessionalMessage(
          'Critical',
          'BATTERY FAILSAFE: $battery% - EMERGENCY LANDING REQUIRED',
          event.timestamp,
        );
      }
      // Recovery
      else if (_lastBatteryPercent <= 25 && battery > 30) {
        _addProfessionalMessage(
          'Info',
          'Battery level restored: $battery%',
          event.timestamp,
        );
      }
    }
    _lastBatteryPercent = battery;
  }

  void _addProfessionalMessage(
    String severity,
    String text,
    DateTime timestamp,
  ) {
    if (!mounted) return;

    setState(() {
      final message = MAVLinkStatusMessage(
        severity: severity,
        text: text,
        timestamp: timestamp,
      );
      _statusMessages.insert(0, message);

      // Keep message history reasonable
      if (_statusMessages.length > 100) {
        _statusMessages = _statusMessages.take(100).toList();
      }
    });
  }

  @override
  void dispose() {
    _telemetrySubscription?.cancel();
    _connectionSubscription?.cancel();
    _mavlinkSubscription?.cancel();
    super.dispose();
  }

  void _updateDisplayedTelemetry() {
    // Always use real telemetry data from service
    displayedTelemetry = _telemetryService.getTelemetryDataList();
  }

  void _onTelemetrySelected(int index, TelemetryData newTelemetry) {
    setState(() {
      displayedTelemetry[index] = newTelemetry;
    });
  }

  void _showTelemetrySelector(int index) {
    TelemetrySelector.show(
      context: context,
      index: index,
      displayedTelemetry: displayedTelemetry,
      onTelemetrySelected: _onTelemetrySelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 12),
            Expanded(child: _buildMainContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [_buildLiveIndicator(), _buildConnectionStatus()],
    );
  }

  Widget _buildLiveIndicator() {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isConnected ? AppColors.primaryColor : Colors.grey,
            boxShadow: _isConnected
                ? [
                    BoxShadow(
                      color: AppColors.primaryColor.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: Offset(0, 0),
                    ),
                  ]
                : null,
          ),
        ),
        SizedBox(width: 12),
        Text(
          _isConnected ? 'Live' : 'Offline',
          style: TextStyle(
            color: _isConnected ? AppColors.primaryColor : Colors.grey,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: _isConnected
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.2),
        border: Border.all(
          color: _isConnected ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Text(
        _isConnected ? 'Connected' : 'Disconnected',
        style: TextStyle(
          color: _isConnected ? Colors.green : Colors.red,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Row(
      children: [
        _buildProfessionalMessageSection(),
        SizedBox(width: 20),
        _buildTelemetrySection(),
      ],
    );
  }

  Widget _buildProfessionalMessageSection() {
    return Expanded(
      flex: 5,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.shade900, Colors.black],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMessageHeader(),
            Expanded(child: _buildProfessionalMessageList()),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(Icons.message_outlined, color: AppColors.primaryColor, size: 18),
          SizedBox(width: 8),
          Text(
            'System Messages',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalMessageList() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: !_isConnected
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_off, color: Colors.grey.shade600, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'No MAVLink Connection',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Connect to see professional system messages',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
            )
          : _statusMessages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    color: Colors.grey.shade600,
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'System ready for messages...',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'UAV message system active',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _statusMessages.length,
              itemBuilder: (context, index) {
                final message = _statusMessages[index];
                return _buildProfessionalMessageItem(
                  message.severity,
                  message.text,
                  message.timestamp,
                  _getProfessionalSeverityColor(message.severity),
                );
              },
            ),
    );
  }

  Color _getProfessionalSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'emergency':
      case 'alert':
      case 'critical':
        return Colors.red.shade400;
      case 'error':
        return Colors.red.shade300;
      case 'warning':
        return Colors.orange.shade400;
      case 'notice':
        return Colors.blue.shade300;
      case 'info':
        return Colors.green.shade300;
      case 'debug':
        return Colors.grey.shade400;
      default:
        return Colors.white;
    }
  }

  Widget _buildProfessionalMessageItem(
    String severity,
    String message,
    DateTime timestamp,
    Color severityColor,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: severityColor.withValues(alpha: 0.2),
              border: Border.all(color: severityColor, width: 1),
            ),
            child: Text(
              severity.toUpperCase(),
              style: TextStyle(
                color: severityColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetrySection() {
    return Expanded(
      flex: 5,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isTiny = width < 400;
          final isSmall = width < 600;

          // Responsive padding and spacing
          final padding = isTiny ? 6.0 : (isSmall ? 8.0 : 12.0);
          final headerSpacing = isTiny ? 4.0 : (isSmall ? 6.0 : 8.0);

          return Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.grey.shade900, Colors.black],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTelemetryHeader(),
                SizedBox(height: headerSpacing),
                Expanded(child: _buildTelemetryGrid()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTelemetryHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isTiny = width < 400;
        final isSmall = width < 600;

        // Responsive sizes
        final iconSize = isTiny ? 14.0 : (isSmall ? 16.0 : 18.0);
        final fontSize = isTiny ? 12.0 : (isSmall ? 14.0 : 16.0);
        final spacing = isTiny ? 4.0 : 6.0;

        return Row(
          children: [
            Icon(
              Icons.analytics_outlined,
              color: AppColors.primaryColor,
              size: iconSize,
            ),
            SizedBox(width: spacing),
            Flexible(
              child: Text(
                'Flight Telemetry',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTelemetryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        // More aggressive responsive breakpoints
        final isTiny = width < 300 || height < 150;
        final isSmall = width < 450 || height < 200;
        final isMedium = width < 600 || height < 250;

        // Responsive row spacing - more conservative for small spaces
        final rowSpacing = isTiny
            ? 2.0
            : (isSmall ? 3.0 : (isMedium ? 4.0 : 6.0));

        return Column(
          children: [
            Expanded(child: _buildTelemetryRow([0, 1, 2])),
            SizedBox(height: rowSpacing),
            Expanded(child: _buildTelemetryRow([3, 4, 5])),
            SizedBox(height: rowSpacing),
            Expanded(child: _buildTelemetryRow([6, 7, 8])),
          ],
        );
      },
    );
  }

  Widget _buildTelemetryRow(List<int> indices) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        // Match grid breakpoints
        final isTiny = width < 300 || height < 50;
        final isSmall = width < 450 || height < 60;
        final isMedium = width < 600 || height < 70;

        // More conservative spacing for very small containers
        final spacing = isTiny ? 1.0 : (isSmall ? 2.0 : (isMedium ? 3.0 : 6.0));

        return Row(
          children: [
            for (int i = 0; i < indices.length; i++) ...[
              Expanded(
                child: TelemetryItemWidget(
                  telemetry: displayedTelemetry[indices[i]],
                  onTap: () => _showTelemetrySelector(indices[i]),
                ),
              ),
              if (i < indices.length - 1) SizedBox(width: spacing),
            ],
          ],
        );
      },
    );
  }
}
