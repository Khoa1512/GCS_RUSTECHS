import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';

/// Event types cho MAVLink message callbacks
enum MAVLinkEventType {
  heartbeat,
  attitude,
  position,
  statusText,
  batteryStatus,
  gpsInfo,
  vfrHud,
  parameterReceived,
  allParametersReceived,
  connectionStateChanged,
}

/// Connection state of the MAVLink connection
enum MAVLinkConnectionState {
  disconnected,
  connected,
  connecting,
  error,
}

/// A class representing a MAVLink message event
class MAVLinkEvent {
  final MAVLinkEventType type;
  final dynamic data;
  final DateTime timestamp;

  MAVLinkEvent(this.type, this.data) : timestamp = DateTime.now();
}

/// Main API class for Drone MAVLink communications
class DroneMAVLinkAPI {
  // Biến Private
  SerialPort? _serialPort;
  StreamSubscription? _subscription;
  Timer? _timer;
  bool _isConnected = false;
  String _selectedPort = "";
  int _baudRate = 115200;
  
  // MAVLink parser
  late MavlinkDialectCommon _dialect;
  late MavlinkParser _parser;
  StreamSubscription? _parserSubscription;
  
  // Sequence number for MAVLink messages
  int _sequence = 0;
  
  // Target system and component IDs
  int _systemId = 1;
  int _componentId = 0;
  
  // Parameters storage
  Map<String, double> _parameters = {};
  bool _requestingParameters = false;
  
  // MAVLink stream IDs
  static const int MAV_DATA_STREAM_ALL = 0;
  static const int MAV_DATA_STREAM_RAW_SENSORS = 1;
  static const int MAV_DATA_STREAM_EXTENDED_STATUS = 2;
  static const int MAV_DATA_STREAM_RC_CHANNELS = 3;
  static const int MAV_DATA_STREAM_RAW_CONTROLLER = 4;
  static const int MAV_DATA_STREAM_POSITION = 6;
  static const int MAV_DATA_STREAM_EXTRA1 = 10;  // Attitude data
  static const int MAV_DATA_STREAM_EXTRA2 = 11;  // VFR HUD data
  static const int MAV_DATA_STREAM_EXTRA3 = 12;
  
  // Vehicle state storage
  String _currentMode = 'Unknown';
  bool _isArmed = false;
  int _currentWaypoint = -1;
  int _totalWaypoints = -1;
  Map<String, double> _homePosition = {};
  String _ekfStatus = 'Unknown';
  
  // Attitude data
  double _roll = 0.0;
  double _pitch = 0.0;
  double _yaw = 0.0;
  
  // Speed data
  double _airSpeed = 0.0;
  double _groundSpeed = 0.0;
  
  // Altitude data
  double _altMSL = 0.0;
  double _altRelative = 0.0;
  
  // GPS data
  String _gpsFixType = 'No GPS';
  int _satellites = 0;
  
  // Battery data
  int _batteryPercent = 0;
  
  // Event controller for subscribers
  final _eventController = StreamController<MAVLinkEvent>.broadcast();
  
  // Public accessors
  Stream<MAVLinkEvent> get eventStream => _eventController.stream;
  bool get isConnected => _isConnected;
  String get currentMode => _currentMode;
  bool get isArmed => _isArmed;
  int get currentWaypoint => _currentWaypoint;
  int get totalWaypoints => _totalWaypoints;
  Map<String, double> get homePosition => _homePosition;
  String get ekfStatus => _ekfStatus;
  double get roll => _roll;
  double get pitch => _pitch;
  double get yaw => _yaw;
  double get airSpeed => _airSpeed;
  double get groundSpeed => _groundSpeed;
  double get altitudeMSL => _altMSL;
  double get altitudeRelative => _altRelative;
  String get gpsFixType => _gpsFixType;
  int get satellites => _satellites;
  int get batteryPercent => _batteryPercent;
  Map<String, double> get parameters => _parameters;

  /// Constructor
  DroneMAVLinkAPI() {
    _dialect = MavlinkDialectCommon();
    _parser = MavlinkParser(_dialect);
    _setupMavlinkListener();
  }

  /// Initialize the API with optional default port and baud rate
  void initialize({String defaultPort = "", int baudRate = 115200}) {
    _selectedPort = defaultPort;
    _baudRate = baudRate;
  }

  /// Get a list of available serial ports
  List<String> getAvailablePorts() {
    return SerialPort.availablePorts;
  }

  /// Connect to the specified serial port
  /// 
  /// Returns true if connection was successful, false otherwise
  Future<bool> connect(String port, {int? baudRate}) async {
    if (_isConnected) {
      disconnect();
    }
    
    _selectedPort = port;
    if (baudRate != null) {
      _baudRate = baudRate;
    }
    
    try {
      _serialPort = SerialPort(_selectedPort);
      
      if (_serialPort!.openReadWrite()) {
        _serialPort!.config.baudRate = _baudRate;
        _serialPort!.config.bits = 8;
        _serialPort!.config.stopBits = 1;
        _serialPort!.config.parity = SerialPortParity.none;
        _serialPort!.config.setFlowControl(SerialPortFlowControl.none);
        
        _isConnected = true;
        _eventController.add(MAVLinkEvent(MAVLinkEventType.connectionStateChanged, MAVLinkConnectionState.connected));
        
        // Read data at high frequency to catch all packets
        _timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
          _readData();
        });
        
        // Add small delay to ensure stable connection before requesting data
        await Future.delayed(const Duration(milliseconds: 500));
        requestAllDataStreams();
        
        return true;
      } else {
        _eventController.add(MAVLinkEvent(MAVLinkEventType.connectionStateChanged, MAVLinkConnectionState.error));
        return false;
      }
    } catch (e) {
      _eventController.add(MAVLinkEvent(MAVLinkEventType.connectionStateChanged, MAVLinkConnectionState.error));
      return false;
    }
  }

  /// Disconnect from the current serial port
  void disconnect() {
    _timer?.cancel();
    _subscription?.cancel();
    _serialPort?.close();
    
    _isConnected = false;
    _eventController.add(MAVLinkEvent(MAVLinkEventType.connectionStateChanged, MAVLinkConnectionState.disconnected));
  }

  /// Read data from the serial port
  void _readData() {
    if (_serialPort == null || !_isConnected) return;
    
    try {
      // Try to read available bytes from the serial port
      if (_serialPort!.isOpen) {
        final Uint8List data = _serialPort!.read(4096);
        
        if (data.isNotEmpty) {
          // Feed data to the MAVLink parser
          _parser.parse(data);
        }
      }
    } catch (e) {
      // Handle errors silently - if there are persistent errors, connection will be dropped
    }
  }

  /// Set up the MAVLink message listener
  void _setupMavlinkListener() {
    _parserSubscription = _parser.stream.listen((MavlinkFrame frm) {
      // Process the received frame
      _processMAVLinkFrame(frm);
    });
  }

  /// Process a received MAVLink frame
  void _processMAVLinkFrame(MavlinkFrame frm) {
    // Automatically update system ID from heartbeat
    if (frm.systemId > 0 && frm.systemId < 255) {
      _systemId = frm.systemId;
    }
    
    // Process different message types
    if (frm.message is Heartbeat) {
      _processHeartbeat(frm.message as Heartbeat);
    }
    else if (frm.message is SysStatus) {
      _processSysStatus(frm.message as SysStatus);
    }
    else if (frm.message is Attitude) {
      _processAttitude(frm.message as Attitude);
    }
    else if (frm.message is GlobalPositionInt) {
      _processGlobalPosition(frm.message as GlobalPositionInt);
    }
    else if (frm.message is VfrHud) {
      _processVfrHud(frm.message as VfrHud);
    }
    else if (frm.message is GpsRawInt) {
      _processGpsRawInt(frm.message as GpsRawInt);
    }
    else if (frm.message.runtimeType.toString() == 'StatusText') {
      _processStatusText(frm.message);
    }
    else if (frm.message is ParamValue) {
      _processParamValue(frm.message as ParamValue);
    }
    else if (frm.message.runtimeType.toString() == 'MissionCurrent') {
      _processMissionCurrent(frm.message);
    }
    else if (frm.message.runtimeType.toString() == 'MissionCount') {
      _processMissionCount(frm.message);
    }
    else if (frm.message.runtimeType.toString() == 'HomePosition') {
      _processHomePosition(frm.message);
    }
    else if (frm.message.runtimeType.toString() == 'EkfStatusReport') {
      _processEkfStatus(frm.message);
    }
  }

  /// Process heartbeat message
  void _processHeartbeat(Heartbeat heartbeat) {
    // Update flight mode
    _currentMode = _decodeFlightMode(heartbeat.baseMode, heartbeat.customMode);
    // Update armed status
    _isArmed = (heartbeat.baseMode & 0x80) != 0;
    
    // Send event
    _eventController.add(MAVLinkEvent(
      MAVLinkEventType.heartbeat, 
      {
        'mode': _currentMode,
        'armed': _isArmed,
        'type': _getSystemType(heartbeat.type),
        'autopilot': _getAutopilotType(heartbeat.autopilot),
        'baseMode': heartbeat.baseMode,
        'customMode': heartbeat.customMode,
        'systemStatus': _getSystemStatus(heartbeat.systemStatus),
        'mavlinkVersion': heartbeat.mavlinkVersion
      }
    ));
  }

  /// Process system status message
  void _processSysStatus(SysStatus status) {
    _batteryPercent = status.batteryRemaining;
    
    _eventController.add(MAVLinkEvent(
      MAVLinkEventType.batteryStatus, 
      {
        'batteryPercent': status.batteryRemaining,
        'voltageBattery': status.voltageBattery / 1000, // Convert to volts
        'currentBattery': status.currentBattery / 100,  // Convert to amps
        'cpuLoad': status.load / 10, // Convert to percentage
        'commDropRate': status.dropRateComm,
        'errorsComm': status.errorsComm,
        'sensorHealth': status.onboardControlSensorsHealth
      }
    ));
  }

  /// Process attitude message
  void _processAttitude(Attitude attitude) {
    _roll = attitude.roll * 180 / pi;   // Convert to degrees
    _pitch = attitude.pitch * 180 / pi; // Convert to degrees
    _yaw = attitude.yaw * 180 / pi;     // Convert to degrees
    
    _eventController.add(MAVLinkEvent(
      MAVLinkEventType.attitude, 
      {
        'roll': _roll,
        'pitch': _pitch,
        'yaw': _yaw,
        'rollSpeed': attitude.rollspeed * 180 / pi, // Convert to deg/s
        'pitchSpeed': attitude.pitchspeed * 180 / pi, // Convert to deg/s
        'yawSpeed': attitude.yawspeed * 180 / pi // Convert to deg/s
      }
    ));
  }

  /// Process global position message
  void _processGlobalPosition(GlobalPositionInt pos) {
    _altMSL = pos.alt / 1000;           // Convert to meters
    _altRelative = pos.relativeAlt / 1000; // Convert to meters
    
    // Calculate ground speed from North and East velocities
    double vx = pos.vx / 100; // m/s
    double vy = pos.vy / 100; // m/s
    _groundSpeed = sqrt(vx * vx + vy * vy);
    
    _eventController.add(MAVLinkEvent(
      MAVLinkEventType.position, 
      {
        'lat': pos.lat / 1e7,  // Convert to degrees
        'lon': pos.lon / 1e7,  // Convert to degrees
        'altMSL': _altMSL,
        'altRelative': _altRelative,
        'vx': vx, // North velocity in m/s
        'vy': vy, // East velocity in m/s
        'vz': pos.vz / 100, // Down velocity in m/s
        'heading': pos.hdg / 100, // Heading in degrees
        'groundSpeed': _groundSpeed
      }
    ));
  }

  /// Process VFR HUD message
  void _processVfrHud(VfrHud hud) {
    _airSpeed = hud.airspeed;
    _groundSpeed = hud.groundspeed; // More accurate ground speed
    
    _eventController.add(MAVLinkEvent(
      MAVLinkEventType.vfrHud, 
      {
        'airspeed': _airSpeed,
        'groundspeed': _groundSpeed,
        'heading': hud.heading,
        'throttle': hud.throttle,
        'alt': hud.alt,
        'climb': hud.climb
      }
    ));
  }

  /// Process GPS raw message
  void _processGpsRawInt(GpsRawInt gps) {
    _gpsFixType = _getGpsFix(gps.fixType);
    _satellites = gps.satellitesVisible;
    
    _eventController.add(MAVLinkEvent(
      MAVLinkEventType.gpsInfo, 
      {
        'fixType': _gpsFixType,
        'satellites': _satellites,
        'lat': gps.lat / 1e7,  // Convert to degrees
        'lon': gps.lon / 1e7,  // Convert to degrees
        'alt': gps.alt / 1000, // Convert to meters
        'eph': gps.eph / 100,  // Horizontal accuracy in meters
        'epv': gps.epv / 100,  // Vertical accuracy in meters
        'vel': gps.vel / 100,  // Speed in m/s
        'cog': gps.cog / 100   // Course in degrees
      }
    ));
  }

  /// Process status text message
  void _processStatusText(dynamic text) {
    try {
      String statusText = text.text;
      int severity = text.severity;
      
      _eventController.add(MAVLinkEvent(
        MAVLinkEventType.statusText, 
        {
          'severity': _getStatusSeverity(severity),
          'text': statusText
        }
      ));
    } catch (e) {
      // Handle any errors silently
    }
  }

  /// Process parameter value message
  void _processParamValue(ParamValue param) {
    // Convert paramId from byte array to string and trim trailing zeros
    var terminatedIndex = param.paramId.indexOf(0);
    terminatedIndex = terminatedIndex == -1 ? param.paramId.length : terminatedIndex;
    var trimmed = param.paramId.sublist(0, terminatedIndex);
    var paramId = String.fromCharCodes(trimmed);
    
    // Add to parameters map
    _parameters[paramId] = param.paramValue;
    
    _eventController.add(MAVLinkEvent(
      MAVLinkEventType.parameterReceived, 
      {
        'id': paramId,
        'value': param.paramValue,
        'type': _getParamType(param.paramType),
        'index': param.paramIndex,
        'count': param.paramCount
      }
    ));
    
    // Check if this is the last parameter
    if (param.paramIndex == param.paramCount - 1) {
      _requestingParameters = false;
      _eventController.add(MAVLinkEvent(
        MAVLinkEventType.allParametersReceived, 
        _parameters
      ));
    }
  }

  /// Process mission current message
  void _processMissionCurrent(dynamic msg) {
    _currentWaypoint = msg.seq;
  }

  /// Process mission count message
  void _processMissionCount(dynamic msg) {
    _totalWaypoints = msg.count;
  }

  /// Process home position message
  void _processHomePosition(dynamic msg) {
    _homePosition = {
      'lat': msg.latitude / 1e7,
      'lon': msg.longitude / 1e7,
      'alt': msg.altitude / 1000.0,
    };
  }

  /// Process EKF status report
  void _processEkfStatus(dynamic msg) {
    _ekfStatus = _decodeEkfStatus(msg.flags);
  }

  /// Request all available MAVLink data streams
  void requestAllDataStreams() {
    if (!_isConnected || _serialPort == null) return;
    
    try {
      // Request all data types at 4Hz
      _requestDataStream(MAV_DATA_STREAM_ALL, 4);
      
      // Request attitude data at higher rate (10Hz)
      _requestDataStream(MAV_DATA_STREAM_EXTRA1, 10);
      
      // Request VFR_HUD data (speed, altitude) at 5Hz
      _requestDataStream(MAV_DATA_STREAM_EXTRA2, 5);
      
      // Request position data at 3Hz
      _requestDataStream(MAV_DATA_STREAM_POSITION, 3);
      
      // Request extended status data at 2Hz
      _requestDataStream(MAV_DATA_STREAM_EXTENDED_STATUS, 2);
    } catch (e) {
      // Handle errors silently
    }
  }

  /// Request a specific data stream with the given rate
  void _requestDataStream(int streamId, int rate) {
    if (!_isConnected || _serialPort == null) return;
    
    try {
      // Create message
      var requestDataStream = RequestDataStream(
        targetSystem: _systemId,
        targetComponent: _componentId,
        reqStreamId: streamId,
        reqMessageRate: rate,
        startStop: 1,  // 1 = start, 0 = stop
      );
      
      // Create frame - use v2 for better compatibility
      var frm = MavlinkFrame.v2(_sequence, 255, 0, requestDataStream);
      _sequence = (_sequence + 1) % 255; // Increment sequence number
      
      // Serialize and send
      final data = frm.serialize();
      _serialPort!.write(data);
      
      // Send command again after a delay to ensure it's received
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_isConnected && _serialPort != null) {
          _serialPort!.write(data);
        }
      });
    } catch (e) {
      // Handle errors silently
    }
  }

  /// Request all parameters from the vehicle
  void requestAllParameters() {
    if (!_isConnected || _serialPort == null) return;
    
    try {
      _parameters.clear();
      _requestingParameters = true;
      
      // Create ParamRequestList message
      var paramRequestList = ParamRequestList(
        targetSystem: _systemId,
        targetComponent: _componentId,
      );
      
      // Create and send frame
      var frm = MavlinkFrame.v1(_sequence++, 255, 0, paramRequestList);
      _sequence %= 255;
      
      final data = frm.serialize();
      _serialPort!.write(data);
      
      // Send again after delay to ensure receipt
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_isConnected && _serialPort != null) {
          _serialPort!.write(data);
        }
      });
      
      // Set timeout to clear the requesting flag if we don't receive all parameters
      Future.delayed(const Duration(seconds: 15), () {
        if (_requestingParameters) {
          _requestingParameters = false;
        }
      });
    } catch (e) {
      _requestingParameters = false;
    }
  }

  /// Request a specific parameter by name
  void requestParameter(String paramName) {
    if (!_isConnected || _serialPort == null) return;
    
    try {
      // Convert parameter name to byte array
      final List<int> paramId = List<int>.filled(16, 0);
      final List<int> bytes = paramName.codeUnits;
      
      // Copy parameter name to parameter ID field (max 16 bytes)
      for (int i = 0; i < bytes.length && i < 16; i++) {
        paramId[i] = bytes[i];
      }
      
      // Create ParamRequestRead message
      var paramRequestRead = ParamRequestRead(
        paramIndex: -1, // -1 to use param_id instead of index
        targetSystem: _systemId,
        targetComponent: _componentId,
        paramId: paramId,
      );
      
      // Create and send frame
      var frm = MavlinkFrame.v1(_sequence++, 255, 0, paramRequestRead);
      _sequence %= 255;
      
      _serialPort!.write(frm.serialize());
    } catch (e) {
      // Handle errors silently
    }
  }

  /// Set a parameter value on the vehicle
  void setParameter(String paramName, double value) {
    if (!_isConnected || _serialPort == null) return;
    
    try {
      // Convert parameter name to byte array
      final List<int> paramId = List<int>.filled(16, 0);
      final List<int> bytes = paramName.codeUnits;
      
      // Copy parameter name to parameter ID field (max 16 bytes)
      for (int i = 0; i < bytes.length && i < 16; i++) {
        paramId[i] = bytes[i];
      }
      
      // Create ParamSet message
      var paramSet = ParamSet(
        paramValue: value,
        targetSystem: _systemId,
        targetComponent: _componentId,
        paramId: paramId,
        paramType: 9, // MAV_PARAM_TYPE_REAL32
      );
      
      // Create and send frame
      var frm = MavlinkFrame.v1(_sequence++, 255, 0, paramSet);
      _sequence %= 255;
      
      _serialPort!.write(frm.serialize());
    } catch (e) {
      // Handle errors silently
    }
  }

  /// Send a command to arm or disarm the vehicle
  void sendArmCommand(bool arm) {
    if (!_isConnected || _serialPort == null) return;
    
    try {
      // Create CommandLong message for arming/disarming
      var commandLong = CommandLong(
        command: 400, // MAV_CMD_COMPONENT_ARM_DISARM
        param1: arm ? 1.0 : 0.0, // 1 = arm, 0 = disarm
        param2: 0, // 0 = normal, 21196 = force
        param3: 0,
        param4: 0,
        param5: 0,
        param6: 0,
        param7: 0,
        targetSystem: _systemId,
        targetComponent: _componentId,
        confirmation: 0,
      );
      
      // Create and send frame
      var frm = MavlinkFrame.v1(_sequence++, 255, 0, commandLong);
      _sequence %= 255;
      
      _serialPort!.write(frm.serialize());
    } catch (e) {
      // Handle errors silently
    }
  }

  /// Send command to change flight mode
  void setFlightMode(int mode) {
    if (!_isConnected || _serialPort == null) return;
    
    try {
      // Create SetMode message
      var setMode = SetMode(
        targetSystem: _systemId,
        baseMode: 1, // MAV_MODE_FLAG_CUSTOM_MODE_ENABLED
        customMode: mode,
      );
      
      // Create and send frame
      var frm = MavlinkFrame.v1(_sequence++, 255, 0, setMode);
      _sequence %= 255;
      
      _serialPort!.write(frm.serialize());
    } catch (e) {
      // Handle errors silently
    }
  }

  /// Cleanup resources when done with the API
  void dispose() {
    disconnect();
    _parserSubscription?.cancel();
    _eventController.close();
  }

  // Helper methods for decoding MAVLink enumerations
  
  String _getSystemType(int type) {
    switch(type) {
      case 0: return 'Generic';
      case 1: return 'Fixed Wing';
      case 2: return 'Quadrotor';
      case 3: return 'Coaxial helicopter';
      case 4: return 'Helicopter';
      case 5: return 'Antenna Tracker';
      case 6: return 'GCS';
      case 7: return 'Airship';
      case 8: return 'Free Balloon';
      case 9: return 'Rocket';
      case 10: return 'Ground Rover';
      case 11: return 'Surface Boat';
      case 12: return 'Submarine';
      case 13: return 'Hexarotor';
      case 14: return 'Octorotor';
      case 15: return 'Tricopter';
      case 19: return 'VTOL';
      default: return 'Unknown ($type)';
    }
  }
  
  String _getAutopilotType(int type) {
    switch(type) {
      case 0: return 'Generic';
      case 3: return 'ArduPilot';
      case 4: return 'PX4';
      default: return 'Unknown ($type)';
    }
  }
  
  String _getSystemStatus(int status) {
    switch(status) {
      case 0: return 'Uninit';
      case 1: return 'Boot';
      case 2: return 'Calibrating';
      case 3: return 'Standby';
      case 4: return 'Active';
      case 5: return 'Critical';
      case 6: return 'Emergency';
      case 7: return 'Poweroff';
      case 8: return 'Flight Termination';
      default: return 'Unknown ($status)';
    }
  }
  
  String _getGpsFix(int fixType) {
    switch(fixType) {
      case 0: return 'No GPS';
      case 1: return 'No Fix';
      case 2: return '2D Fix';
      case 3: return '3D Fix';
      case 4: return 'DGPS';
      case 5: return 'RTK Float';
      case 6: return 'RTK Fixed';
      case 7: return 'Static';
      case 8: return 'PPP';
      default: return 'Unknown ($fixType)';
    }
  }
  
  String _getStatusSeverity(int severity) {
    switch(severity) {
      case 0: return 'Emergency';
      case 1: return 'Alert';
      case 2: return 'Critical';
      case 3: return 'Error';
      case 4: return 'Warning';
      case 5: return 'Notice';
      case 6: return 'Info';
      case 7: return 'Debug';
      default: return 'Unknown ($severity)';
    }
  }
  
  String _getParamType(int paramType) {
    switch(paramType) {
      case 1: return 'uint8_t';
      case 2: return 'int8_t';
      case 3: return 'uint16_t';
      case 4: return 'int16_t';
      case 5: return 'uint32_t';
      case 6: return 'int32_t';
      case 7: return 'uint64_t';
      case 8: return 'int64_t';
      case 9: return 'float';
      case 10: return 'double';
      default: return 'Unknown ($paramType)';
    }
  }
  
  String _decodeFlightMode(int baseMode, int customMode) {
    // This is primarily for ArduPilot - if you need to support other autopilots
    // like PX4, you'll need to add their mode decoding logic
    const List<String> arduPilotModes = [
      'MANUAL', 'CIRCLE', 'STABILIZE', 'TRAINING', 'ACRO', 'FBWA',
      'FBWB', 'CRUISE', 'AUTOTUNE', 'AUTO', 'RTL', 'LOITER', 
      'TAKEOFF', 'AVOID_ADSB', 'GUIDED', 'INITIALIZING', 'QSTABILIZE',
      'QHOVER', 'QLOITER', 'QLAND', 'QRTL', 'QAUTOTUNE', 'QACRO'
    ];
    
    if (customMode < arduPilotModes.length) {
      return arduPilotModes[customMode];
    }
    
    return 'UNKNOWN MODE ($customMode)';
  }
  
  String _decodeEkfStatus(int flags) {
    if (flags == 0) return 'EKF Inactive';
    
    List<String> status = [];
    
    if ((flags & 0x01) != 0) status.add('OK');
    if ((flags & 0x02) != 0) status.add('Attitude Error');
    if ((flags & 0x04) != 0) status.add('Horizontal Pos Error');
    if ((flags & 0x08) != 0) status.add('Vertical Pos Error');
    if ((flags & 0x10) != 0) status.add('Heading Error');
    if ((flags & 0x20) != 0) status.add('Velocity Error');
    if ((flags & 0x40) != 0) status.add('Position Horiz Error');
    if ((flags & 0x80) != 0) status.add('Position Vert Error');
    
    return status.join(', ');
  }
  
  String _getCommandResult(int result) {
    switch(result) {
      case 0: return 'Accepted';
      case 1: return 'Temporarily Rejected';
      case 2: return 'Denied';
      case 3: return 'Unsupported';
      case 4: return 'Failed';
      case 5: return 'In Progress';
      case 6: return 'Cancelled';
      default: return 'Unknown ($result)';
    }
  }
  
  String _getBatteryFunction(int function) {
    switch(function) {
      case 0: return 'Unknown';
      case 1: return 'All';
      case 2: return 'Propulsion';
      case 3: return 'Comms';
      case 4: return 'Camera';
      default: return 'Other ($function)';
    }
  }
}
