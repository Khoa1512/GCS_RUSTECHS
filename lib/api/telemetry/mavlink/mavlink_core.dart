import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';

import 'events.dart';
import 'handlers/heartbeat_handler.dart';
import 'handlers/attitude_handler.dart';
import 'handlers/position_handler.dart';
import 'handlers/status_text_handler.dart';
import 'handlers/battery_handler.dart';
import 'handlers/gps_handler.dart';
import 'handlers/vfrhud_handler.dart';
import 'handlers/params_handler.dart';
import 'handlers/sys_status_handler.dart';
import 'handlers/command_ack_handler.dart';
import 'handlers/mission_handler.dart';
import 'mission/mission_models.dart' as mission_model;
import 'command_manager.dart';

/// Main API class for Drone MAVLink communications, split by event handlers
class DroneMAVLinkAPI {
  SerialPort? _serialPort;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  String _selectedPort = '';
  int _baudRate = 115200;

  // Event controller for subscribers
  final _eventController = StreamController<MAVLinkEvent>.broadcast();
  Stream<MAVLinkEvent> get eventStream => _eventController.stream;

  // Handlers
  late final HeartbeatHandler _heartbeatHandler;
  late final AttitudeHandler _attitudeHandler;
  late final PositionHandler _positionHandler;
  late final StatusTextHandler _statusTextHandler;
  late final BatteryHandler _batteryHandler;
  late final GpsHandler _gpsHandler;
  late final VfrHudHandler _vfrHudHandler;
  late final ParamsHandler _paramsHandler;
  late final SysStatusHandler _sysStatusHandler;
  late final CommandAckHandler _commandAckHandler;
  late final MissionHandler _missionHandler;

  // Sequence number and identity
  int _sequence = 0;
  // Source IDs (GCS)
  final int _sourceSystemId = 255; // GCS
  final int _sourceComponentId = 190; // MAV_COMP_ID_MISSIONPLANNER
  // Target IDs (vehicle)
  int _targetSystemId = 1; // will be updated from Heartbeat
  final int _targetComponentId = 1; // MAV_COMP_ID_AUTOPILOT1

  // Parameter storage
  final Map<String, double> parameters = {};

  // Isolate communication
  Isolate? _parserIsolate;
  SendPort? _isolateSendPort;
  ReceivePort? _isolateReceivePort;

  // Command Manager
  late final CommandManager _commandManager;

  DroneMAVLinkAPI({String? port, int baudRate = 115200}) {
    _selectedPort = port ?? '';
    _baudRate = baudRate;

    // NOTE: Dialect and Parser are now managed inside the Isolate
    // _dialect = MavlinkDialectCommon();
    // _parser = MavlinkParser(_dialect);

    // init handlers with emitter
    void emit(MAVLinkEvent e) => _eventController.add(e);
    _heartbeatHandler = HeartbeatHandler(emit);
    _attitudeHandler = AttitudeHandler(emit);
    _positionHandler = PositionHandler(emit);
    _statusTextHandler = StatusTextHandler(emit);
    _batteryHandler = BatteryHandler(emit);
    _gpsHandler = GpsHandler(emit);
    _vfrHudHandler = VfrHudHandler(emit);
    _paramsHandler = ParamsHandler(emit, parameters);
    _sysStatusHandler = SysStatusHandler(emit);
    _commandAckHandler = CommandAckHandler(emit);
    _missionHandler = MissionHandler(emit);

    _spawnParserIsolate();

    // Initialize Command Manager
    _commandManager = CommandManager(sendMessage);
  }

  /// Spawn the background isolate for parsing
  Future<void> _spawnParserIsolate() async {
    _isolateReceivePort = ReceivePort();
    _parserIsolate = await Isolate.spawn(
      _mavlinkParserIsolate,
      _isolateReceivePort!.sendPort,
    );

    // Wait for the isolate to send its SendPort
    _isolateReceivePort!.listen((message) {
      if (message is SendPort) {
        _isolateSendPort = message;
      } else if (message is MavlinkFrame) {
        _handleParsedFrame(message);
      }
    });
  }

  /// The Isolate entry point
  static void _mavlinkParserIsolate(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    final dialect = MavlinkDialectCommon();
    final parser = MavlinkParser(dialect);

    // Listen for parsed frames from the parser and send back to main thread
    parser.stream.listen((frame) {
      try {
        mainSendPort.send(frame);
      } catch (e) {
        print('Isolate send error: $e');
      }
    });

    // Listen for raw data from main thread
    receivePort.listen((message) {
      if (message is Uint8List) {
        parser.parse(message);
      }
    });
  }

  bool get isConnected => _isConnected;
  String get selectedPort => _selectedPort;
  int get baudRate => _baudRate;

  // Link Statistics
  int _totalPackets = 0;
  int _packetLossCount = 0;
  int _lastSequence = -1;

  /// Get current link statistics
  Map<String, dynamic> getLinkStats() {
    return {
      'totalPackets': _totalPackets,
      'packetLoss': _packetLossCount,
      'lossRate': _totalPackets > 0
          ? (_packetLossCount / _totalPackets) * 100
          : 0.0,
    };
  }

  void _handleParsedFrame(MavlinkFrame frame) {
    // Track Link Statistics
    _totalPackets++;
    if (_lastSequence != -1) {
      final expected = (_lastSequence + 1) % 256; // Sequence is 0-255
      if (frame.sequence != expected) {
        // Calculate lost packets (handling wrap-around)
        int lost = (frame.sequence - expected + 256) % 256;
        _packetLossCount += lost;
      }
    }
    _lastSequence = frame.sequence;

    final msg = frame.message;
    // Route by type
    if (msg is Heartbeat) {
      // Update target system when receiving heartbeat from AUTOPILOT
      if (frame.componentId == _targetComponentId) {
        _targetSystemId = frame.systemId;
      }
      _heartbeatHandler.handle(msg);
    } else if (msg is Attitude) {
      _attitudeHandler.handle(msg);
    } else if (msg is GlobalPositionInt) {
      _positionHandler.handle(msg);
    } else if (msg is Statustext) {
      _statusTextHandler.handle(msg);
    } else if (msg is BatteryStatus) {
      _batteryHandler.handle(msg);
    } else if (msg is GpsRawInt) {
      _gpsHandler.handle(msg);
    } else if (msg is VfrHud) {
      _vfrHudHandler.handle(msg);
    } else if (msg is ParamValue) {
      _paramsHandler.handle(msg);
    } else if (msg is SysStatus) {
      _sysStatusHandler.handle(msg);
    } else if (msg is CommandAck) {
      _commandAckHandler.handle(msg);
      // Pass ACK to CommandManager
      _commandManager.handleAck(msg);

      // Mission protocol messages
    } else if (msg is MissionCount) {
      _missionHandler.handleMissionCount(msg);
    } else if (msg is MissionItemInt) {
      _missionHandler.handleMissionItemInt(msg);
    } else if (msg is MissionItem) {
      _missionHandler.handleMissionItem(msg);
    } else if (msg is MissionCurrent) {
      _missionHandler.handleMissionCurrent(msg);
    } else if (msg is MissionItemReached) {
      _missionHandler.handleMissionItemReached(msg);
    } else if (msg is MissionAck) {
      _missionHandler.handleMissionAck(msg);
    } else if (msg is MissionRequestInt) {
      respondToMissionRequestInt(msg);
    } else if (msg is MissionRequest) {
      respondToMissionRequest(msg);
    } else if (msg is HomePosition) {
      // lat/lon in 1e7, alt in mm
      final lat = msg.latitude / 1e7;
      final lon = msg.longitude / 1e7;
      final alt = msg.altitude / 1000.0;
      _eventController.add(
        MAVLinkEvent(MAVLinkEventType.homePosition, {
          'lat': lat,
          'lon': lon,
          'alt': alt,
          'source': 'HOME_POSITION',
        }),
      );
    } else if (msg is GpsGlobalOrigin) {
      // GPS_GLOBAL_ORIGIN lat/lon in 1e7, alt in mm
      final lat = msg.latitude / 1e7;
      final lon = msg.longitude / 1e7;
      final alt = msg.altitude / 1000.0;
      _eventController.add(
        MAVLinkEvent(MAVLinkEventType.homePosition, {
          'lat': lat,
          'lon': lon,
          'alt': alt,
          'source': 'GPS_GLOBAL_ORIGIN',
        }),
      );
    }
  }

  Future<void> connect(String port, {int? baudRate}) async {
    _selectedPort = port;
    if (baudRate != null) _baudRate = baudRate;
    final sp = SerialPort(_selectedPort);
    if (!sp.openReadWrite()) {
      _eventController.add(
        MAVLinkEvent(
          MAVLinkEventType.connectionStateChanged,
          MAVLinkConnectionState.error,
        ),
      );
      return;
    }
    // Apply serial configuration
    final cfg = SerialPortConfig();
    cfg.baudRate = _baudRate;
    cfg.bits = 8;
    cfg.stopBits = 1;
    cfg.parity = 0; // none
    sp.config = cfg;

    _serialPort = sp;
    final reader = SerialPortReader(sp);
    _subscription = reader.stream.listen(
      (Uint8List data) {
        // Send raw data to Isolate for parsing
        _isolateSendPort?.send(data);
      },
      onDone: () => disconnect(),
      onError: (_) => disconnect(),
    );
    _isConnected = true;
    _eventController.add(
      MAVLinkEvent(
        MAVLinkEventType.connectionStateChanged,
        MAVLinkConnectionState.connected,
      ),
    );
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _serialPort?.close();
    _isConnected = false;
    _eventController.add(
      MAVLinkEvent(
        MAVLinkEventType.connectionStateChanged,
        MAVLinkConnectionState.disconnected,
      ),
    );
  }

  void dispose() {
    disconnect();
    _eventController.close();
    _isolateReceivePort?.close();
    _parserIsolate?.kill();
  }

  // Sending utilities
  void sendMessage(MavlinkMessage msg) {
    if (_serialPort == null) return;
    final frame = MavlinkFrame.v2(
      _sequence,
      _sourceSystemId,
      _sourceComponentId,
      msg,
    );
    _serialPort!.write(frame.serialize());
    _sequence = (_sequence + 1) % 255;
  }

  // ====== Mission API ======
  /// Request mission list (download start)
  void requestMissionList() {
    final req = MissionRequestList(
      targetSystem: _targetSystemId,
      targetComponent: _targetComponentId,
      missionType: mavMissionTypeMission,
    );
    sendMessage(req);
  }

  /// After MissionCount is received, request each item by seq.
  void requestMissionItem(int seq) {
    final req = MissionRequestInt(
      seq: seq,
      targetSystem: _targetSystemId,
      targetComponent: _targetComponentId,
      missionType: mavMissionTypeMission,
    );
    sendMessage(req);
  }

  /// Clear all mission items on vehicle
  void clearMission() {
    final clr = MissionClearAll(
      targetSystem: _targetSystemId,
      targetComponent: _targetComponentId,
      missionType: mavMissionTypeMission,
    );
    sendMessage(clr);
    // Optimistically emit cleared event; final ACK will also arrive
    _eventController.add(MAVLinkEvent(MAVLinkEventType.missionCleared, null));
  }

  /// Set current mission index
  void setCurrentMissionItem(int seq) {
    final setc = MissionSetCurrent(
      seq: seq,
      targetSystem: _targetSystemId,
      targetComponent: _targetComponentId,
    );
    sendMessage(setc);
  }

  /// Upload a mission plan using MISSION_COUNT -> then respond to MISSION_REQUEST_INT items
  void startMissionUpload(List<mission_model.PlanMissionItem> items) {
    // send count first
    _missionHandler.startUpload(items);
    final count = MissionCount(
      count: items.length,
      targetSystem: _targetSystemId,
      targetComponent: _targetComponentId,
      missionType: mavMissionTypeMission,
      opaqueId: 0,
    );
    sendMessage(count);
  }

  /// Provide next MissionItemInt when vehicle requests it (call from outside upon MissionRequestInt reception, or handled internally via routing)
  void respondToMissionRequestInt(MissionRequestInt req) {
    final next = _missionHandler.dequeueNextUploadItem();
    if (next == null) return;
    final item = _missionHandler.makeMissionItemInt(
      _targetSystemId,
      _targetComponentId,
      next,
    );
    sendMessage(item);
  }

  /// Provide next MissionItem (legacy float) when vehicle requests it
  void respondToMissionRequest(MissionRequest req) {
    final next = _missionHandler.dequeueNextUploadItem();
    if (next == null) return;
    final item = _missionHandler.makeMissionItem(
      _targetSystemId,
      _targetComponentId,
      next,
    );
    sendMessage(item);
  }

  /// Request the home position from the vehicle (MAV_CMD_GET_HOME_POSITION)
  void requestHomePosition() {
    final msg = CommandLong(
      command: 410, // MAV_CMD_GET_HOME_POSITION
      targetSystem: _targetSystemId,
      targetComponent: _targetComponentId,
      param1: 0,
      param2: 0,
      param3: 0,
      param4: 0,
      param5: 0,
      param6: 0,
      param7: 0,
      confirmation: 0,
    );
    sendMessage(msg);
  }

  // Examples of some convenience commands
  void requestAllStreams({int rateHz = 1}) {
    final msg = RequestDataStream(
      reqMessageRate: rateHz,
      targetSystem: _targetSystemId,
      targetComponent: _targetComponentId,
      reqStreamId: 0,
      startStop: 1,
    );
    sendMessage(msg);
  }

  // ====== Extended API for compatibility with previous version ======

  // MAVLink stream IDs
  static const int MAV_DATA_STREAM_ALL = 0;
  static const int MAV_DATA_STREAM_RAW_SENSORS = 1;
  static const int MAV_DATA_STREAM_EXTENDED_STATUS = 2;
  static const int MAV_DATA_STREAM_RC_CHANNELS = 3;
  static const int MAV_DATA_STREAM_RAW_CONTROLLER = 4;
  static const int MAV_DATA_STREAM_POSITION = 6;
  static const int MAV_DATA_STREAM_EXTRA1 = 10; // Attitude data
  static const int MAV_DATA_STREAM_EXTRA2 = 11; // VFR HUD data
  static const int MAV_DATA_STREAM_EXTRA3 = 12;

  /// Request specific message interval (MAV_CMD_SET_MESSAGE_INTERVAL)
  /// intervalUs: Interval in microseconds (e.g. 200000 for 5Hz)
  void setMessageInterval(int msgId, int intervalUs) {
    final msg = CommandLong(
      command: 511, // MAV_CMD_SET_MESSAGE_INTERVAL
      targetSystem: _targetSystemId,
      targetComponent: _targetComponentId,
      param1: msgId.toDouble(),
      param2: intervalUs.toDouble(),
      param3: 0,
      param4: 0,
      param5: 0,
      param6: 0,
      param7: 0,
      confirmation: 0,
    );
    sendMessage(msg);
  }

  /// Request a standard set of data streams using PRECISE INTERVALS
  void requestAllDataStreams() {
    // Wait then set our preferred rates
    Future.delayed(const Duration(milliseconds: 200), () {
      // 1. GLOBAL_POSITION_INT (33) -> 5Hz (200,000us)
      // Critical for smooth map movement
      setMessageInterval(33, 200000);

      // 2. ATTITUDE (30) -> 20Hz (50,000us) - Try forcing higher rate
      // Critical for smooth horizon/heading
      // 2. ATTITUDE (30) -> 20Hz (50,000us) - Try forcing higher rate
      // Critical for smooth horizon/heading
      // setMessageInterval(30, 50000); // Disable this to rely on legacy REQUEST_DATA_STREAM below

      // 3. GPS_RAW_INT (24) -> 1Hz (1,000,000us)
      // Satellites, Fix Type - Low priority
      setMessageInterval(24, 1000000);

      // 4. SYS_STATUS (1) -> 1Hz
      // Battery, Voltage - Low priority
      setMessageInterval(1, 1000000);

      // 5. HEARTBEAT (0) -> 5Hz (200,000us)
      // Critical for fast Mode/Arm updates
      setMessageInterval(0, 200000);

      // 6. VFR_HUD (74) -> 2Hz (500,000us)
      // Airspeed, Alt - Medium priority
      setMessageInterval(74, 500000);

      // Fallback: Also request streams for older FCs that don't support SET_MESSAGE_INTERVAL
      _requestDataStream(MAV_DATA_STREAM_POSITION, 5);
      _requestDataStream(
        MAV_DATA_STREAM_EXTRA1,
        20,
      ); // Enable legacy Attitude at 20Hz
      _requestDataStream(MAV_DATA_STREAM_EXTRA2, 2);
      _requestDataStream(MAV_DATA_STREAM_EXTENDED_STATUS, 1);
    });
  }

  /// Stop all data streams để clear previous settings
  void _stopAllDataStreams() {
    _requestDataStream(MAV_DATA_STREAM_ALL, 0);
  }

  void _requestDataStream(int streamId, int rate) {
    final request = RequestDataStream(
      targetSystem: _targetSystemId,
      targetComponent: _targetComponentId,
      reqStreamId: streamId,
      reqMessageRate: rate,
      startStop: 1,
    );
    final frame = MavlinkFrame.v1(
      // Changed to V1 for better compatibility with legacy commands
      _sequence,
      _sourceSystemId,
      _sourceComponentId,
      request,
    );
    _sequence = (_sequence + 1) % 255;
    _serialPort?.write(frame.serialize());
  }

  /// Request all parameters from the vehicle
  void requestAllParameters() {
    final msg = ParamRequestList(
      targetSystem: _targetSystemId,
      targetComponent: _targetComponentId,
    );
    final frame = MavlinkFrame.v1(
      _sequence,
      _sourceSystemId,
      _sourceComponentId,
      msg,
    );
    _sequence = (_sequence + 1) % 255;
    _serialPort?.write(frame.serialize());
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_serialPort != null) {
        _serialPort!.write(frame.serialize());
      }
    });
  }

  /// Request a specific parameter by name
  void requestParameter(String paramName) {
    final List<int> paramId = List<int>.filled(16, 0);
    final bytes = paramName.codeUnits;
    for (int i = 0; i < bytes.length && i < 16; i++) {
      paramId[i] = bytes[i];
    }
    final msg = ParamRequestRead(
      paramIndex: -1,
      targetSystem: _targetSystemId,
      targetComponent: _targetComponentId,
      paramId: paramId,
    );
    final frame = MavlinkFrame.v1(
      _sequence,
      _sourceSystemId,
      _sourceComponentId,
      msg,
    );
    _sequence = (_sequence + 1) % 255;
    _serialPort?.write(frame.serialize());
  }

  /// Set a parameter value on the vehicle
  void setParameter(String paramName, double value) {
    final List<int> paramId = List<int>.filled(16, 0);
    final bytes = paramName.codeUnits;
    for (int i = 0; i < bytes.length && i < 16; i++) {
      paramId[i] = bytes[i];
    }
    final msg = ParamSet(
      paramValue: value,
      targetSystem: _targetSystemId,
      targetComponent: _targetComponentId,
      paramId: paramId,
      paramType: 9, // MAV_PARAM_TYPE_REAL32
    );
    final frame = MavlinkFrame.v1(
      _sequence,
      _sourceSystemId,
      _sourceComponentId,
      msg,
    );
    _sequence = (_sequence + 1) % 255;
    _serialPort?.write(frame.serialize());
  }

  /// Arm or disarm the vehicle
  void sendArmCommand(bool arm) {
    final msg = CommandLong(
      command: 400, // MAV_CMD_COMPONENT_ARM_DISARM
      param1: arm ? 1.0 : 0.0,
      param2: 0,
      param3: 0,
      param4: 0,
      param5: 0,
      param6: 0,
      param7: 0,
      targetSystem: _targetSystemId,
      targetComponent: _targetComponentId,
      confirmation: 0,
    );
    final frame = MavlinkFrame.v1(
      _sequence,
      _sourceSystemId,
      _sourceComponentId,
      msg,
    );
    _sequence = (_sequence + 1) % 255;
    _serialPort?.write(frame.serialize());
  }

  /// Change the flight mode (ArduPilot custom mode)
  void setFlightMode(int mode) {
    final msg = SetMode(
      targetSystem: _targetSystemId,
      baseMode: 1, // MAV_MODE_FLAG_CUSTOM_MODE_ENABLED
      customMode: mode,
    );
    final frame = MavlinkFrame.v1(
      _sequence,
      _sourceSystemId,
      _sourceComponentId,
      msg,
    );
    _sequence = (_sequence + 1) % 255;
    _serialPort?.write(frame.serialize());
  }
}
