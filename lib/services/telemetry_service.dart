import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:skylink/api/telemetry/mavlink_api.dart';
import 'package:skylink/data/telemetry_data.dart';

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
    // print('TelemetryService: Attempting to connect to $port at $baudRate baud');

    try {
      // Check if port is available
      final availablePorts = getAvailablePorts();
      if (!availablePorts.contains(port)) {
        return false;
      }

      // print('TelemetryService: Calling API connect');
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
            // if (kDebugMode) {
            //   print('TelemetryService: Requesting data streams...');
            // }
            _api.requestAllDataStreams();

            // Send again after delay để ensure FC receives
            Timer(const Duration(milliseconds: 500), () {
              if (_isConnected) {
                _api.requestAllDataStreams();
                // if (kDebugMode) {
                //   print('TelemetryService: Data streams requested (retry)');
                // }
              }
            });
          }
        });
      } else {
        // print('TelemetryService: Connection failed');
      }

      return success;
    } catch (e) {
      // print('TelemetryService: Connect error: $e');
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  /// Disconnect from drone
  void disconnect() {
    // print('TelemetryService: Disconnecting');
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
            _currentMode = (m['mode'] as String?) ?? _currentMode;
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
            // KHÔNG cập nhật GPS coordinates từ position event nữa
            // Chỉ ưu tiên gpsInfo event cho GPS coordinates để tránh conflict
            // Position event chỉ cập nhật altitude và movement data

            _currentTelemetry['altitude_msl'] =
                (m['altMSL'] as num?)?.toDouble() ??
                (_currentTelemetry['altitude_msl'] ?? 0.0);
            _currentTelemetry['altitude_rel'] =
                (m['altRelative'] as num?)?.toDouble() ??
                (_currentTelemetry['altitude_rel'] ?? 0.0);
            _currentTelemetry['groundspeed'] =
                (m['groundSpeed'] as num?)?.toDouble() ??
                (_currentTelemetry['groundspeed'] ?? 0.0);

            // Don't use GLOBAL_POSITION_INT heading to avoid conflicts
            // Priority: GPS course > Yaw (handled in other events)
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
            // also store the string fix type for UI when needed
            // store separately in a special bucket using a sentinel negative value is messy; keep outside map for strings
            // However, some UI expects 'gps_fix_type' string
            // We can't store string in Map<String,double>, so expose via getter only

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

            // GPS course is for navigation, not compass display
            // Compass should show FC orientation (IMU yaw), not movement direction
            // Comment out GPS course override to keep IMU yaw priority
            // final gpsCourse = _currentTelemetry['gps_course'] ?? 0.0;
            // if (gpsCourse > 0.0) {
            //   _updateCompassHeading(gpsCourse);
            // }
            // Cache last fix type string in a field for getters
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
        _currentTelemetry.clear();
        _telemetryController.add(_currentTelemetry);
      }
    }
  }

  /// Emit current telemetry map and mark data received when first meaningful data arrives
  void _emitTelemetry() {
    if (!_hasReceivedData) {
      final hasPosition =
          ((_currentTelemetry['gps_latitude'] ?? 0.0) != 0.0) ||
          ((_currentTelemetry['gps_longitude'] ?? 0.0) != 0.0);
      final hasBattery = (_currentTelemetry['battery'] ?? 0.0) > 0.0;
      if (hasPosition || hasBattery) {
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
      // Return default/empty telemetry data when no connection
      return [
        TelemetryData(
          label: 'Roll',
          value: '0.0',
          unit: '°',
          color: Colors.blue,
        ),
        TelemetryData(
          label: 'Pitch',
          value: '0.0',
          unit: '°',
          color: Colors.green,
        ),
        TelemetryData(
          label: 'Yaw',
          value: '0.0',
          unit: '°',
          color: Colors.purple,
        ),
        TelemetryData(
          label: 'Airspeed',
          value: '0.0',
          unit: 'm/s',
          color: Colors.orange,
        ),
        TelemetryData(
          label: 'Groundspeed',
          value: '0.0',
          unit: 'm/s',
          color: Colors.cyan,
        ),
        TelemetryData(
          label: 'Altitude MSL',
          value: '0.0',
          unit: 'm',
          color: Colors.red,
        ),
        TelemetryData(
          label: 'Altitude Rel',
          value: '0.0',
          unit: 'm',
          color: Colors.pink,
        ),
        TelemetryData(
          label: 'Satellites',
          value: '0',
          unit: '',
          color: Colors.amber,
        ),
        TelemetryData(
          label: 'GPS Lat',
          value: '0.0',
          unit: '°',
          color: Colors.deepOrange,
        ),
        TelemetryData(
          label: 'GPS Lon',
          value: '0.0',
          unit: '°',
          color: Colors.deepPurple,
        ),
        TelemetryData(
          label: 'GPS Alt',
          value: '0.0',
          unit: 'm',
          color: Colors.indigo,
        ),
        TelemetryData(
          label: 'GPS Speed',
          value: '0.0',
          unit: 'm/s',
          color: Colors.lime,
        ),
        TelemetryData(
          label: 'GPS Course',
          value: '0.0',
          unit: '°',
          color: Colors.brown,
        ),
        TelemetryData(
          label: 'GPS H.Acc',
          value: '0.0',
          unit: 'm',
          color: Colors.grey,
        ),
        TelemetryData(
          label: 'Battery',
          value: '0',
          unit: '%',
          color: Colors.teal,
        ),
      ];
    }

    return [
      TelemetryData(
        label: 'Roll',
        value: (_currentTelemetry['roll'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.blue,
      ),
      TelemetryData(
        label: 'Pitch',
        value: (_currentTelemetry['pitch'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.green,
      ),
      TelemetryData(
        label: 'Yaw',
        value: (_currentTelemetry['yaw'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.purple,
      ),
      TelemetryData(
        label: 'Airspeed',
        value: (_currentTelemetry['airspeed'] ?? 0.0).toStringAsFixed(1),
        unit: 'm/s',
        color: Colors.orange,
      ),
      TelemetryData(
        label: 'Groundspeed',
        value: (_currentTelemetry['groundspeed'] ?? 0.0).toStringAsFixed(1),
        unit: 'm/s',
        color: Colors.cyan,
      ),
      TelemetryData(
        label: 'Altitude MSL',
        value: (_currentTelemetry['altitude_msl'] ?? 0.0).toStringAsFixed(1),
        unit: 'm',
        color: Colors.red,
      ),
      TelemetryData(
        label: 'Altitude Rel',
        value: (_currentTelemetry['altitude_rel'] ?? 0.0).toStringAsFixed(1),
        unit: 'm',
        color: Colors.pink,
      ),
      TelemetryData(
        label: 'Satellites',
        value: (_currentTelemetry['satellites'] ?? 0.0).toInt().toString(),
        unit: '',
        color: Colors.amber,
      ),
      TelemetryData(
        label: 'GPS Lat',
        value: (_currentTelemetry['gps_latitude'] ?? 0.0).toStringAsFixed(6),
        unit: '°',
        color: Colors.deepOrange,
      ),
      TelemetryData(
        label: 'GPS Lon',
        value: (_currentTelemetry['gps_longitude'] ?? 0.0).toStringAsFixed(6),
        unit: '°',
        color: Colors.deepPurple,
      ),
      TelemetryData(
        label: 'GPS Alt',
        value: (_currentTelemetry['gps_altitude'] ?? 0.0).toStringAsFixed(1),
        unit: 'm',
        color: Colors.indigo,
      ),
      TelemetryData(
        label: 'GPS Speed',
        value: (_currentTelemetry['gps_speed'] ?? 0.0).toStringAsFixed(1),
        unit: 'm/s',
        color: Colors.lime,
      ),
      TelemetryData(
        label: 'GPS Course',
        value: (_currentTelemetry['gps_course'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.brown,
      ),
      TelemetryData(
        label: 'GPS H.Acc',
        value: (_currentTelemetry['gps_horizontal_accuracy'] ?? 0.0)
            .toStringAsFixed(2),
        unit: 'm',
        color: Colors.grey,
      ),
      TelemetryData(
        label: 'Battery',
        value: (_currentTelemetry['battery'] ?? 0.0).toInt().toString(),
        unit: '%',
        color: Colors.teal,
      ),
    ];
  }

  /// Get all available telemetry data items for selector dialog
  List<TelemetryData> getAllAvailableTelemetryData() {
    return [
      // Flight Attitude
      TelemetryData(
        label: 'Roll',
        value: (_currentTelemetry['roll'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.blue,
      ),
      TelemetryData(
        label: 'Pitch',
        value: (_currentTelemetry['pitch'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.green,
      ),
      TelemetryData(
        label: 'Yaw',
        value: (_currentTelemetry['yaw'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.purple,
      ),

      // Speed Data
      TelemetryData(
        label: 'Airspeed',
        value: (_currentTelemetry['airspeed'] ?? 0.0).toStringAsFixed(1),
        unit: 'm/s',
        color: Colors.orange,
      ),
      TelemetryData(
        label: 'Groundspeed',
        value: (_currentTelemetry['groundspeed'] ?? 0.0).toStringAsFixed(1),
        unit: 'm/s',
        color: Colors.cyan,
      ),

      // Altitude Data
      TelemetryData(
        label: 'Altitude MSL',
        value: (_currentTelemetry['altitude_msl'] ?? 0.0).toStringAsFixed(1),
        unit: 'm',
        color: Colors.red,
      ),
      TelemetryData(
        label: 'Altitude Rel',
        value: (_currentTelemetry['altitude_rel'] ?? 0.0).toStringAsFixed(1),
        unit: 'm',
        color: Colors.pink,
      ),

      // GPS Data
      TelemetryData(
        label: 'GPS Latitude',
        value: (_currentTelemetry['gps_latitude'] ?? 0.0).toStringAsFixed(6),
        unit: '°',
        color: Colors.deepOrange,
      ),
      TelemetryData(
        label: 'GPS Longitude',
        value: (_currentTelemetry['gps_longitude'] ?? 0.0).toStringAsFixed(6),
        unit: '°',
        color: Colors.deepPurple,
      ),
      TelemetryData(
        label: 'GPS Altitude',
        value: (_currentTelemetry['gps_altitude'] ?? 0.0).toStringAsFixed(1),
        unit: 'm',
        color: Colors.indigo,
      ),
      TelemetryData(
        label: 'GPS Speed',
        value: (_currentTelemetry['gps_speed'] ?? 0.0).toStringAsFixed(1),
        unit: 'm/s',
        color: Colors.lime,
      ),
      TelemetryData(
        label: 'GPS Course',
        value: (_currentTelemetry['gps_course'] ?? 0.0).toStringAsFixed(1),
        unit: '°',
        color: Colors.brown,
      ),
      TelemetryData(
        label: 'GPS H.Accuracy',
        value: (_currentTelemetry['gps_horizontal_accuracy'] ?? 0.0)
            .toStringAsFixed(2),
        unit: 'm',
        color: Colors.grey,
      ),
      TelemetryData(
        label: 'GPS V.Accuracy',
        value: (_currentTelemetry['gps_vertical_accuracy'] ?? 0.0)
            .toStringAsFixed(2),
        unit: 'm',
        color: Colors.blueGrey,
      ),
      TelemetryData(
        label: 'GPS Fix Type',
        value: gpsFixType,
        unit: '',
        color: Colors.lightGreen,
      ),
      TelemetryData(
        label: 'Satellites',
        value: (_currentTelemetry['satellites'] ?? 0.0).toInt().toString(),
        unit: '',
        color: Colors.amber,
      ),

      // Battery & Power
      TelemetryData(
        label: 'Battery',
        value: (_currentTelemetry['battery'] ?? 0.0).toInt().toString(),
        unit: '%',
        color: Colors.teal,
      ),

      // Flight Status
      TelemetryData(
        label: 'Flight Mode',
        value: _currentTelemetry['mode']?.toString() ?? 'Unknown',
        unit: '',
        color: Colors.deepOrangeAccent,
      ),
    ];
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

    // Dispose API
    _api.dispose();

    // Đóng tất cả stream controller
    _telemetryController.close();
    _connectionController.close();
    _dataReceiveController.close();
  }
}
