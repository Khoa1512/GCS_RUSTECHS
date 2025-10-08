import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:skylink/api/telemetry/mavlink_api.dart';
import 'package:skylink/api/5G/services/mqtt_service.dart';
import 'package:skylink/services/mqtt_data_adapter.dart';
import 'package:skylink/data/telemetry_data.dart';
import 'package:skylink/data/constants/telemetry_constants.dart';

/// Service for managing telemetry data from MAVLink API
class TelemetryService {
  static final TelemetryService _instance = TelemetryService._internal();
  factory TelemetryService() => _instance;

  bool _hasReceivedData = false;
  final _dataReceiveController = StreamController<bool>.broadcast();

  TelemetryService._internal() {
    // Khởi tạo service
    initialize();
  }

  final DroneMAVLinkAPI _api = DroneMAVLinkAPI();
  StreamSubscription? _apiSubscription;

  // MQTT fallback services
  final MqttService _mqttService = MqttService();
  StreamSubscription? _mqttSubscription;
  bool _isMqttFallbackActive = false;
  Timer? _connectionMonitor;

  // Stream controllers for real-time data
  final _telemetryController =
      StreamController<Map<String, double>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  // Current telemetry data
  final Map<String, double> _currentTelemetry = {};
  bool _isConnected = false;
  String _currentMode = 'Unknown';
  bool _armed = false;
  String _lastGpsFixType = 'No GPS';
  String _vehicleType = 'Unknown'; // Vehicle type from heartbeat

  // Heading stabilization - Optimized for ATTITUDE.yaw (more stable than VFR_HUD)
  double _lastStableHeading = 0.0;
  DateTime _lastHeadingUpdate = DateTime.now();
  static const double _headingStabilityThreshold =
      3.0; // degrees - Reduced since ATTITUDE.yaw is much more stable
  static const Duration _headingUpdateInterval = Duration(
    milliseconds: 500,
  ); // Reduced since we're using stable ATTITUDE.yaw instead of noisy VFR_HUD

  // Moving average filter for heading (reduce magnetometer noise)
  final List<double> _headingBuffer = [];
  static const int _headingBufferSize =
      8; // increased from 5 for stronger filtering

  Stream<Map<String, double>> get telemetryStream =>
      _telemetryController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<bool> get dataReceiveStream => _dataReceiveController.stream;
  bool get isConnected => _isConnected;
  bool get hasReceivedData => _hasReceivedData;
  Map<String, double> get currentTelemetry => Map.from(_currentTelemetry);

  // Public getters for vehicle info
  String get vehicleType => _vehicleType;

  /// Set connection state and notify listeners
  void setConnected(bool connected) {
    _isConnected = connected;
    _connectionController.add(connected);
  }

  /// Update telemetry data from MQTT source (ULTRA-FAST 10ms rendering)
  void updateTelemetryFromMqtt(Map<String, double> mqttData) {
    if (mqttData.isEmpty) return;

    // INSTANT update - zero overhead for 10ms rendering
    _currentTelemetry.addAll(mqttData);

    // One-time flag set
    if (!_hasReceivedData) {
      _hasReceivedData = true;
      _dataReceiveController.add(true);
    }

    // INSTANT UI notification - direct stream for 10ms real-time
    _telemetryController.add(_currentTelemetry);
  }

  // Expose MAVLink API for accessing other event types (like statusText)
  DroneMAVLinkAPI get mavlinkAPI => _api;

  /// Apply moving average filter to reduce magnetometer noise
  double _filterHeading(double newHeading) {
    // Add to buffer
    _headingBuffer.add(newHeading);

    // Keep buffer size limited
    if (_headingBuffer.length > _headingBufferSize) {
      _headingBuffer.removeAt(0);
    }

    // Return simple average if buffer not full
    if (_headingBuffer.length < 3) {
      return newHeading;
    }

    // Calculate weighted average (recent values have more weight)
    double sum = 0.0;
    double weightSum = 0.0;

    for (int i = 0; i < _headingBuffer.length; i++) {
      double weight = (i + 1).toDouble(); // Recent values get higher weight
      sum += _headingBuffer[i] * weight;
      weightSum += weight;
    }

    return sum / weightSum;
  }

  /// Update compass heading with stability filtering
  void _updateCompassHeading(double newHeading) {
    final now = DateTime.now();

    // Skip update if too frequent (reduce noise)
    if (now.difference(_lastHeadingUpdate) < _headingUpdateInterval) {
      return;
    }

    // Normalize heading to 0-360
    newHeading = newHeading % 360;
    if (newHeading < 0) newHeading += 360;

    // Apply moving average filter to smooth out noise
    final filteredHeading = _filterHeading(newHeading);

    // Calculate heading difference handling 360/0 wraparound
    double headingDiff = (filteredHeading - _lastStableHeading).abs();
    if (headingDiff > 180) {
      headingDiff = 360 - headingDiff;
    }

    // Only update if change is significant enough to be meaningful
    // Reduced threshold for more responsive updates while filtering noise
    if (headingDiff > _headingStabilityThreshold ||
        now.difference(_lastHeadingUpdate) > Duration(seconds: 2)) {
      _currentTelemetry['compass_heading'] = filteredHeading;
      _lastStableHeading = filteredHeading;
      _lastHeadingUpdate = now;
    }
  }

  /// Initialize the service
  void initialize() {
    _apiSubscription?.cancel();
    _setupApiListener();
  }

  /// Connect to drone via specified port
  Future<bool> connect(String port, {int baudRate = 115200}) async {
    try {
      final availablePorts = getAvailablePorts();
      if (!availablePorts.contains(port)) {
        return false;
      }

      await _api.connect(port, baudRate: baudRate);

      final success = _api.isConnected;
      if (success) {
        _hasReceivedData = false;

        // Setup API listener mới
        _apiSubscription?.cancel();
        _setupApiListener();

        // Thông báo trạng thái - chưa set connected
        _connectionController.add(false);
        _dataReceiveController.add(false);

        // Request all data streams for real-time telemetry với delay
        Timer(const Duration(milliseconds: 1000), () {
          if (_isConnected) {
            _api.requestAllDataStreams();

            // Send again after delay để ensure FC receives
            Timer(const Duration(milliseconds: 500), () {
              if (_isConnected) {
                _api.requestAllDataStreams();
              }
            });
          }
        });
      }
      return success;
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  /// Disconnect from drone
  void disconnect() {
    try {
      // Hủy subscription
      _apiSubscription?.cancel();

      // Disconnect từ API
      _api.disconnect();

      // Reset tất cả trạng thái
      _isConnected = false;
      _hasReceivedData = false;

      // Thông báo cho các listener
      _connectionController.add(false);
      _dataReceiveController.add(false);

      // Xóa dữ liệu telemetry
      _currentTelemetry.clear();
      _telemetryController.add(_currentTelemetry);
    } catch (e) {
      _isConnected = false;
      _hasReceivedData = false;
      _connectionController.add(false);
      _dataReceiveController.add(false);
    }
  }

  /// Get available serial ports
  List<String> getAvailablePorts() {
    final ports = SerialPort.availablePorts;
    return ports;
  }

  /// Setup listener for MAVLink API events
  void _setupApiListener() {
    _apiSubscription = _api.eventStream.listen((event) {
      switch (event.type) {
        case MAVLinkEventType.connectionStateChanged:
          _handleConnectionStateChange(event.data);
          break;
        case MAVLinkEventType.heartbeat:
          if (event.data is Map) {
            final m = (event.data as Map);
            final newMode = (m['mode'] as String?) ?? _currentMode;
            if (newMode != _currentMode) {
              _currentMode = newMode;
            }
            _armed = (m['armed'] as bool?) ?? _armed;
            _vehicleType = (m['type'] as String?) ?? _vehicleType;
            _currentTelemetry['armed'] = _armed ? 1.0 : 0.0;
          }
          _emitTelemetry();
          break;
        case MAVLinkEventType.attitude:
          if (event.data is Map) {
            final m = (event.data as Map);
            _currentTelemetry['roll'] =
                (m['roll'] as num?)?.toDouble() ??
                (_currentTelemetry['roll'] ?? 0.0);
            _currentTelemetry['pitch'] =
                (m['pitch'] as num?)?.toDouble() ??
                (_currentTelemetry['pitch'] ?? 0.0);

            final rawYaw =
                (m['yaw'] as num?)?.toDouble() ??
                (_currentTelemetry['yaw'] ?? 0.0);

            // Convert yaw from radians to degrees if needed
            double yawDegrees = rawYaw;
            if (rawYaw.abs() <= 6.28) {
              // likely radians (-π to π)
              yawDegrees = rawYaw * 180.0 / 3.14159;
              if (yawDegrees < 0) yawDegrees += 360; // normalize 0-360
            }
            _currentTelemetry['yaw'] = yawDegrees;
            _updateCompassHeading(yawDegrees);
          }
          _emitTelemetry();
          break;
        case MAVLinkEventType.vfrHud:
          if (event.data is Map) {
            final m = (event.data as Map);
            _currentTelemetry['airspeed'] =
                (m['airspeed'] as num?)?.toDouble() ??
                (_currentTelemetry['airspeed'] ?? 0.0);
            _currentTelemetry['groundspeed'] =
                (m['groundspeed'] as num?)?.toDouble() ??
                (_currentTelemetry['groundspeed'] ?? 0.0);

            // vfrhud.alt can serve as MSL if GLOBAL_POSITION not yet arrived
            final alt = (m['alt'] as num?)?.toDouble();
            if (alt != null) {
              _currentTelemetry['altitude_msl'] = alt;
            }
          }
          _emitTelemetry();
          break;
        case MAVLinkEventType.position:
          if (event.data is Map) {
            final m = (event.data as Map);

            _currentTelemetry['altitude_msl'] =
                (m['altMSL'] as num?)?.toDouble() ??
                (_currentTelemetry['altitude_msl'] ?? 0.0);
            _currentTelemetry['altitude_rel'] =
                (m['altRelative'] as num?)?.toDouble() ??
                (_currentTelemetry['altitude_rel'] ?? 0.0);
            _currentTelemetry['groundspeed'] =
                (m['groundSpeed'] as num?)?.toDouble() ??
                (_currentTelemetry['groundspeed'] ?? 0.0);
          }
          _emitTelemetry();
          break;
        case MAVLinkEventType.gpsInfo:
          if (event.data is Map) {
            final m = (event.data as Map);
            final fixType = (m['fixType'] as String?) ?? 'No GPS';
            _currentTelemetry['satellites'] =
                ((m['satellites'] as num?)?.toDouble() ?? 0.0);
            _currentTelemetry['gps_fix'] = _getGpsFixValue(fixType);

            final newLat =
                (m['lat'] as num?)?.toDouble() ??
                (_currentTelemetry['gps_latitude'] ?? 0.0);
            final newLon =
                (m['lon'] as num?)?.toDouble() ??
                (_currentTelemetry['gps_longitude'] ?? 0.0);

            _currentTelemetry['gps_latitude'] = newLat;
            _currentTelemetry['gps_longitude'] = newLon;
            _currentTelemetry['gps_altitude'] =
                (m['alt'] as num?)?.toDouble() ??
                (_currentTelemetry['gps_altitude'] ?? 0.0);
            _currentTelemetry['gps_speed'] =
                (m['vel'] as num?)?.toDouble() ??
                (_currentTelemetry['gps_speed'] ?? 0.0);
            _currentTelemetry['gps_course'] =
                (m['cog'] as num?)?.toDouble() ??
                (_currentTelemetry['gps_course'] ?? 0.0);
            _currentTelemetry['gps_horizontal_accuracy'] =
                (m['eph'] as num?)?.toDouble() ??
                (_currentTelemetry['gps_horizontal_accuracy'] ?? 0.0);
            _currentTelemetry['gps_vertical_accuracy'] =
                (m['epv'] as num?)?.toDouble() ??
                (_currentTelemetry['gps_vertical_accuracy'] ?? 0.0);

            _lastGpsFixType = fixType;
          }
          _emitTelemetry();
          break;
        case MAVLinkEventType.batteryStatus:
          if (event.data is Map) {
            final m = (event.data as Map);
            final bp = (m['batteryPercent'] as num?)?.toDouble();
            final vb = (m['voltageBattery'] as num?)?.toDouble();
            if (bp != null) {
              _currentTelemetry['battery'] = bp;
            }
            if (vb != null) {
              _currentTelemetry['voltageBattery'] = vb;
            }
          }
          _emitTelemetry();
          break;
        default:
          // no-op for other events
          break;
      }
    });
  }

  /// Handle connection state changes
  void _handleConnectionStateChange(MAVLinkConnectionState state) {
    bool connected = state == MAVLinkConnectionState.connected;
    if (_isConnected != connected) {
      _isConnected = connected;
      _connectionController.add(connected);

      if (!connected) {
        _showFallbackDialog();

        _currentTelemetry.clear();
        _telemetryController.add(_currentTelemetry);
      } else {
        if (_isMqttFallbackActive) {
          _stopMqttFallback();
        }
      }
    }
  }

  void _showFallbackDialog() async {

    try {
      final context =
          WidgetsBinding.instance.focusManager.primaryFocus?.context;
      if (context == null) {
        await _attemptMqttFallback();
        return;
      }

      // Show dialog using Flutter's native showDialog
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.grey.shade900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.red, size: 24),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Mất kết nối MAVLink',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kết nối MAVLink đã bị mất',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.router, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bạn có muốn chuyển sang MQTT để tiếp tục nhận dữ liệu?',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false); // User cancelled
                },
                child: Text('Hủy', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true); // User confirmed
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: Text(
                  'Chuyển MQTT',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );


      // Only proceed with MQTT fallback if user confirmed
      if (result == true) {
        await _attemptMqttFallback();
      }
    } catch (e) {
      await _attemptMqttFallback();
    }
  }

  /// Automatically attempt MQTT fallback when MAVLink is lost
  Future<void> _attemptMqttFallback() async {
    if (_isMqttFallbackActive) return; // Already in fallback mode

    try {
      await _mqttService.connect();
      await _mqttService.subscribeAllDevices();

      if (_mqttService.isConnected) {
        _isMqttFallbackActive = true;

        // Use the SAME logic as ConnectionManager._listenToMqttData()
        _mqttSubscription = _mqttService.listenTelemetryData().listen(
          (data) {
            // Instant convert and render - no delays for 10ms intervals
            final telemetryData = MqttDataAdapter.convertMqttToTelemetry(
              jsonEncode(data),
            );

            if (telemetryData.isNotEmpty) {
              updateTelemetryFromMqtt(telemetryData);
            }
          },
          onError: (error) {
            _stopMqttFallback();
          },
        );

      } else {
        throw Exception('MQTT connection failed');
      }
    } catch (e) {
      _isMqttFallbackActive = false;
    }
  }

  void _stopMqttFallback() {
    if (!_isMqttFallbackActive) return;

    _mqttSubscription?.cancel();
    _mqttService.disconnect();
    _isMqttFallbackActive = false;

  }

  /// Emit current telemetry map and mark data received when first meaningful data arrives
  void _emitTelemetry() {
    if (!_hasReceivedData) {
      // Relaxed meaningful data detection - accept basic telemetry
      final hasPosition =
          ((_currentTelemetry['gps_latitude'] ?? 0.0) != 0.0) ||
          ((_currentTelemetry['gps_longitude'] ?? 0.0) != 0.0);
      final hasBattery =
          (_currentTelemetry['battery'] ?? 0.0) > 0.0 ||
          (_currentTelemetry['voltageBattery'] ?? 0.00) > 0.00;
      final hasAttitude =
          (_currentTelemetry['roll'] != null) ||
          (_currentTelemetry['pitch'] != null) ||
          (_currentTelemetry['yaw'] != null);
      final hasBasicData =
          (_currentTelemetry['armed'] != null) ||
          (_currentTelemetry['airspeed'] != null) ||
          (_currentTelemetry['groundspeed'] != null);

      // Accept data if we have any meaningful telemetry (not just GPS+battery)
      if (hasPosition || hasBattery || hasAttitude || hasBasicData) {
        _hasReceivedData = true;
        _dataReceiveController.add(true);
      }
    }
    _telemetryController.add(Map.from(_currentTelemetry));
  }

  /// Convert GPS fix type string to numeric value
  double _getGpsFixValue(String fixType) {
    switch (fixType) {
      case 'No GPS':
        return 0.0;
      case 'No Fix':
        return 1.0;
      case '2D Fix':
        return 2.0;
      case '3D Fix':
        return 3.0;
      case 'DGPS':
        return 4.0;
      case 'RTK Float':
        return 5.0;
      case 'RTK Fixed':
        return 6.0;
      default:
        return 0.0;
    }
  }

  /// Get telemetry data as TelemetryData objects for UI
  List<TelemetryData> getTelemetryDataList() {
    if (_currentTelemetry.isEmpty) {
      return TelemetryConstants.getDefaultTelemetryData();
    }
    return TelemetryConstants.buildTelemetryDataList(_currentTelemetry);
  }

  /// Get all available telemetry data items for selector dialog
  List<TelemetryData> getAllAvailableTelemetryData() {
    return TelemetryConstants.buildAllAvailableTelemetryData(
      _currentTelemetry,
      gpsFixType,
    );
  }

  /// Send arm/disarm command
  void sendArmCommand(bool arm) {
    _api.sendArmCommand(arm);
  }

  /// Set flight mode
  void setFlightMode(int mode) {
    _api.setFlightMode(mode);
  }

  /// Get current flight mode
  String get currentMode => _currentMode;

  /// Check if drone is armed
  bool get isArmed => _armed;

  /// Get GPS related data
  double get gpsLatitude => _currentTelemetry['gps_latitude'] ?? 0.0;
  double get gpsLongitude => _currentTelemetry['gps_longitude'] ?? 0.0;
  double get gpsAltitude => _currentTelemetry['gps_altitude'] ?? 0.0;
  double get gpsSpeed => _currentTelemetry['gps_speed'] ?? 0.0;
  double get gpsCourse => _currentTelemetry['gps_course'] ?? 0.0;
  double get gpsHorizontalAccuracy =>
      _currentTelemetry['gps_horizontal_accuracy'] ?? 0.0;
  double get gpsVerticalAccuracy =>
      _currentTelemetry['gps_vertical_accuracy'] ?? 0.0;
  String get gpsFixType => _lastGpsFixType;
  int get gpsFixValue => _getGpsFixValue(_lastGpsFixType).toInt();

  /// Check if GPS has a valid fix
  bool get hasValidGpsFix {
    // Only accept valid GPS fixes that can provide accurate position
    return _lastGpsFixType == '2D Fix' ||
        _lastGpsFixType == '3D Fix' ||
        _lastGpsFixType == 'DGPS' ||
        _lastGpsFixType == 'RTK Float' ||
        _lastGpsFixType == 'RTK Fixed' ||
        _lastGpsFixType == 'Static' ||
        _lastGpsFixType == 'PPP';
  }

  /// Get GPS accuracy in human readable format
  String get gpsAccuracyString {
    if (!hasValidGpsFix) {
      return _lastGpsFixType; // Show actual fix type for debugging
    }
    return '±${gpsHorizontalAccuracy.toStringAsFixed(1)}m';
  }

  /// Dispose service and cleanup resources
  void dispose() {
    // Hủy tất cả subscription và timer
    _apiSubscription?.cancel();
    _mqttSubscription?.cancel();
    _connectionMonitor?.cancel();

    // Stop MQTT fallback if active
    if (_isMqttFallbackActive) {
      _stopMqttFallback();
    }

    // Dispose API
    _api.dispose();

    // Đóng tất cả stream controller
    _telemetryController.close();
    _connectionController.close();
    _dataReceiveController.close();
  }
}
