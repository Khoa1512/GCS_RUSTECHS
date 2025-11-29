import 'dart:async';
import 'dart:math' as math; // Import thư viện toán học
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:skylink/api/telemetry/mavlink_api.dart';
import 'package:skylink/data/telemetry_data.dart';
import 'package:skylink/data/constants/telemetry_constants.dart';

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
  String _vehicleType = 'Unknown';

  // --- COMPASS SMOOTHING VARIABLES ---
  double _lastStableHeading = 0.0;
  DateTime _lastHeadingUpdate = DateTime.now();

  // DEBUG: Data Rate Tracking
  DateTime? _lastGpsUpdateTime;
  DateTime? _lastAttitudeUpdateTime;

  // Giảm threshold để compass nhạy hơn
  static const double _headingStabilityThreshold = 0.1;

  // Tăng tốc độ update (30ms ~ 33fps) để animation không bị giật
  static const Duration _headingUpdateInterval = Duration(milliseconds: 30);

  final List<double> _headingBuffer = [];
  // Buffer size vừa phải, quá lớn sẽ gây lag (delay), quá nhỏ sẽ bị rung
  static const int _headingBufferSize = 5;

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

  /// Apply Circular Mean filter - handles 360°/0° boundary correctly
  double _filterHeading(double normalizedHeading) {
    // Add to buffer
    _headingBuffer.add(normalizedHeading);
    if (_headingBuffer.length > _headingBufferSize) {
      _headingBuffer.removeAt(0);
    }

    // If insufficient data, return input directly
    if (_headingBuffer.length < 2) return normalizedHeading;

    // --- CIRCULAR MEAN CALCULATION (FIXED) ---
    double sumSin = 0.0;
    double sumCos = 0.0;

    // Equal weight for all samples (no weighting to avoid bias)
    for (int i = 0; i < _headingBuffer.length; i++) {
      // Convert to radians for trigonometric calculation
      double radians = _headingBuffer[i] * (math.pi / 180.0);

      // Sum unit vectors
      sumSin += math.sin(radians);
      sumCos += math.cos(radians);
    }

    // Calculate average direction
    double resultRadians = math.atan2(sumSin, sumCos);
    double resultDegrees = resultRadians * (180.0 / math.pi);

    // Normalize to 0-360° range (atan2 returns -180° to 180°)
    if (resultDegrees < 0) {
      resultDegrees += 360.0;
    }

    return resultDegrees;
  }

  /// Update compass heading with proper validation and rate limiting
  void _updateCompassHeading(double rawHeading) {
    final now = DateTime.now();

    // Rate limiting - prevent excessive updates
    if (now.difference(_lastHeadingUpdate) < _headingUpdateInterval) {
      return;
    }

    // Normalize input to valid 0-360° range
    double normalizedHeading = rawHeading;

    // Handle negative values
    if (normalizedHeading < 0) {
      normalizedHeading = (normalizedHeading % 360) + 360;
    }
    // Handle values > 360
    else if (normalizedHeading > 360) {
      normalizedHeading = normalizedHeading % 360;
    }

    // STABILITY CHECK: Temporarily disabled for testing
    // if (_lastStableHeading != 0.0) {
    //   double suddenDiff = (normalizedHeading - _lastStableHeading).abs();
    //   if (suddenDiff > 180) {
    //     suddenDiff = 360 - suddenDiff;
    //   }
    //
    //   if (suddenDiff > 45.0) {
    //     return;
    //   }
    // }

    // Apply circular mean filter
    final filteredHeading = _filterHeading(normalizedHeading);

    // Calculate difference for update threshold check
    double headingDiff = (filteredHeading - _lastStableHeading).abs();

    // Handle wrap-around difference (359° vs 1° should be 2°, not 358°)
    if (headingDiff > 180) {
      headingDiff = 360 - headingDiff;
    }

    // Update if significant change OR to prevent UI freeze
    bool significantChange = headingDiff > _headingStabilityThreshold;
    bool preventFreeze =
        now.difference(_lastHeadingUpdate).inMilliseconds >
        1000; // Increase to 1 second

    if (significantChange || preventFreeze) {
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

  Timer? _dataRequestRetryTimer;

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
        _apiSubscription?.cancel();
        _setupApiListener();

        _connectionController.add(false);
        _dataReceiveController.add(false);

        // Cancel existing timer if any
        _dataRequestRetryTimer?.cancel();

        // Initial request
        Timer(const Duration(milliseconds: 1000), () {
          if (_isConnected) {
            _api.requestAllDataStreams();
          }
        });

        // Smart retry mechanism: Check every 2 seconds
        // If connected but NO rich data (Attitude/GPS) received yet, re-send request
        _dataRequestRetryTimer = Timer.periodic(const Duration(seconds: 2), (
          timer,
        ) {
          if (!_isConnected) {
            timer.cancel();
            return;
          }

          // Check if we have received RICH data (Attitude or GPS)
          // Heartbeat gives us Mode/Armed (Basic data), but we need the streams for the rest
          final hasRichData =
              (_currentTelemetry['roll'] != null) ||
              ((_currentTelemetry['gps_latitude'] ?? 0.0) != 0.0);

          if (!hasRichData) {
            print(
              'Waiting for rich data (Attitude/GPS)... Retrying stream request...',
            );
            _api.requestAllDataStreams();
          } else {
            // Once we have rich data, we can stop retrying
            print('Rich data received! Stopping retry timer.');
            timer.cancel();
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
      _dataRequestRetryTimer?.cancel(); // Cancel retry timer
      _apiSubscription?.cancel();
      _api.disconnect();
      _isConnected = false;
      _hasReceivedData = false;
      _currentMode = 'Unknown';
      _armed = false;
      _connectionController.add(false);
      _dataReceiveController.add(false);
      _currentTelemetry.clear();
      _telemetryController.add(_currentTelemetry);
    } catch (e) {
      _isConnected = false;
      _hasReceivedData = false;
      _currentMode = 'Unknown';
      _armed = false;
      _connectionController.add(false);
      _dataReceiveController.add(false);
    }
  }

  /// Get available serial ports
  List<String> getAvailablePorts() {
    return SerialPort.availablePorts;
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

            // --- DEBUG: Measure Attitude Data Rate ---
            final now = DateTime.now();
            if (_lastAttitudeUpdateTime != null) {
              final diff = now
                  .difference(_lastAttitudeUpdateTime!)
                  .inMilliseconds;
              if (diff > 0) {
                // Only print every 10th update to avoid spamming console too much (since it's 10Hz)
                if (now.second != _lastAttitudeUpdateTime!.second) {
                  print(
                    'Attitude Update: ${diff}ms (~${(1000 / diff).toStringAsFixed(1)}Hz)',
                  );
                }
              }
            }
            _lastAttitudeUpdateTime = now;
            // --------------------------------

            _currentTelemetry['roll'] =
                (m['roll'] as num?)?.toDouble() ??
                (_currentTelemetry['roll'] ?? 0.0);
            _currentTelemetry['pitch'] =
                (m['pitch'] as num?)?.toDouble() ??
                (_currentTelemetry['pitch'] ?? 0.0);

            final rawYaw =
                (m['yaw'] as num?)?.toDouble() ??
                (_currentTelemetry['yaw'] ?? 0.0);

            double yawDegrees = rawYaw;
            double compassHeading = rawYaw;

            // Check if yaw is in radians (typical range: -π to π or -3.14 to 3.14)
            if (rawYaw.abs() <= 6.28) {
              // Convert from radians to degrees
              yawDegrees = rawYaw * 180.0 / math.pi;

              // Convert yaw to compass heading (0-360°)
              compassHeading = yawDegrees;

              // Normalize to 0-360° range
              while (compassHeading < 0) {
                compassHeading += 360;
              }
              while (compassHeading > 360) {
                compassHeading -= 360;
              }
            } else {
              // Already in degrees format
              compassHeading = rawYaw;
              yawDegrees = rawYaw;

              // Normalize to 0-360° range
              while (compassHeading < 0) {
                compassHeading += 360;
              }
              while (compassHeading > 360) {
                compassHeading -= 360;
              }
            }

            _currentTelemetry['yaw'] = yawDegrees;

            // Use converted compass heading for navigation
            if (compassHeading >= 0 && compassHeading <= 360) {
              _updateCompassHeading(compassHeading);
            }
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

            // [NEW] Use Fused Global Position for main coordinates (Smoother & More Accurate)
            final newLat = (m['lat'] as num?)?.toDouble();
            final newLon = (m['lon'] as num?)?.toDouble();

            if (newLat != null && newLon != null) {
              _currentTelemetry['gps_latitude'] = newLat;
              _currentTelemetry['gps_longitude'] = newLon;
            }
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

            // [CHANGED] Raw GPS coordinates are NO LONGER used for main display
            // to avoid jitter. We now use GLOBAL_POSITION_INT (Fused) above.
            // Only use Raw GPS as fallback if needed, or just ignore.
            // For now, we comment them out to ensure we only use the Fused position.
            /*
            final newLat =
                (m['lat'] as num?)?.toDouble() ??
                (_currentTelemetry['gps_latitude'] ?? 0.0);
            final newLon =
                (m['lon'] as num?)?.toDouble() ??
                (_currentTelemetry['gps_longitude'] ?? 0.0);

            _currentTelemetry['gps_latitude'] = newLat;
            _currentTelemetry['gps_longitude'] = newLon;
            */
            _currentTelemetry['gps_altitude'] =
                (m['alt'] as num?)?.toDouble() ??
                (_currentTelemetry['gps_altitude'] ?? 0.0);
            _currentTelemetry['gps_speed'] =
                (m['vel'] as num?)?.toDouble() ??
                (_currentTelemetry['gps_speed'] ?? 0.0);
            _currentTelemetry['gps_course'] =
                (m['cog'] as num?)?.toDouble() ??
                (_currentTelemetry['gps_course'] ?? 0.0);

            // Use GPS course as BACKUP compass heading
            final currentHeading = _currentTelemetry['compass_heading'] ?? 0.0;
            if (currentHeading == 0.0) {
              final gpsHeading = _currentTelemetry['gps_course'];
              if (gpsHeading != null &&
                  gpsHeading > 0.0 &&
                  gpsHeading <= 360.0) {
                _updateCompassHeading(gpsHeading);
              }
            }
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

  /// Emit current telemetry map
  void _emitTelemetry() {
    if (!_hasReceivedData) {
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
      return _lastGpsFixType;
    }
    return '±${gpsHorizontalAccuracy.toStringAsFixed(1)}m';
  }

  /// Dispose service and cleanup resources
  void dispose() {
    _apiSubscription?.cancel();
    _api.dispose();
    _telemetryController.close();
    _connectionController.close();
    _dataReceiveController.close();
  }

  // --- SIMULATION HELPERS (For Testing) ---
  void simulateTelemetry(Map<String, dynamic> data) {
    if (data.containsKey('connected')) {
      setConnected(data['connected']);
    }

    if (data.containsKey('gps_fix_type')) {
      _lastGpsFixType = data['gps_fix_type'];
    }

    if (data.containsKey('mode')) {
      _currentMode = data['mode'];
    }

    if (data.containsKey('armed')) {
      _armed = data['armed'];
      _currentTelemetry['armed'] = _armed ? 1.0 : 0.0;
    }

    data.forEach((key, value) {
      if (value is num) {
        _currentTelemetry[key] = value.toDouble();
      }
    });

    _emitTelemetry();
  }
}
