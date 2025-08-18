import 'dart:async';
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

/// Main API class for Drone MAVLink communications, split by event handlers
class DroneMAVLinkAPI {
	SerialPort? _serialPort;
	StreamSubscription? _subscription;
	StreamSubscription? _parserSubscription;
	bool _isConnected = false;
	String _selectedPort = '';
	int _baudRate = 115200;

	late final MavlinkDialectCommon _dialect;
	late final MavlinkParser _parser;

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

	// Sequence number and identity
	int _sequence = 0;
	// Source IDs (GCS)
	int _sourceSystemId = 255; // GCS
	final int _sourceComponentId = 190; // MAV_COMP_ID_MISSIONPLANNER
	// Target IDs (vehicle)
	int _targetSystemId = 1; // will be updated from Heartbeat
	final int _targetComponentId = 1; // MAV_COMP_ID_AUTOPILOT1

	// Parameter storage
	final Map<String, double> parameters = {};

	DroneMAVLinkAPI({String? port, int baudRate = 115200}) {
		_selectedPort = port ?? '';
		_baudRate = baudRate;
		_dialect = MavlinkDialectCommon();
		_parser = MavlinkParser(_dialect);

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

		_setupParserStream();
	}

	bool get isConnected => _isConnected;
	String get selectedPort => _selectedPort;
	int get baudRate => _baudRate;

	void _setupParserStream() {
		// Avoid duplicating the subscription across reconnects
		if (_parserSubscription != null) return;
		_parserSubscription = _parser.stream.listen((frame) {
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
			}
		});
	}

	Future<void> connect(String port, {int? baudRate}) async {
		_selectedPort = port;
		if (baudRate != null) _baudRate = baudRate;
		final sp = SerialPort(_selectedPort);
		if (!sp.openReadWrite()) {
			_eventController.add(MAVLinkEvent(MAVLinkEventType.connectionStateChanged, MAVLinkConnectionState.error));
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
		_subscription = reader.stream.listen((Uint8List data) {
			_parser.parse(data);
		}, onDone: () => disconnect(), onError: (_) => disconnect());
		_isConnected = true;
		_eventController.add(MAVLinkEvent(MAVLinkEventType.connectionStateChanged, MAVLinkConnectionState.connected));
	}

	void disconnect() {
		_subscription?.cancel();
		_subscription = null;
		_serialPort?.close();
		_isConnected = false;
		_eventController.add(MAVLinkEvent(MAVLinkEventType.connectionStateChanged, MAVLinkConnectionState.disconnected));
	}

	void dispose() {
		disconnect();
		_eventController.close();
	}

	// Sending utilities
	void sendMessage(MavlinkMessage msg) {
		if (_serialPort == null) return;
		final frame = MavlinkFrame.v2(_sequence, _sourceSystemId, _sourceComponentId, msg);
		_serialPort!.write(frame.serialize());
		_sequence = (_sequence + 1) % 255;
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

		/// Request a standard set of data streams at typical rates
		void requestAllDataStreams() {
			// All data at 4Hz
			_requestDataStream(MAV_DATA_STREAM_ALL, 4);
			// Attitude 10Hz
			_requestDataStream(MAV_DATA_STREAM_EXTRA1, 10);
			// VFR HUD 5Hz
			_requestDataStream(MAV_DATA_STREAM_EXTRA2, 5);
			// Position 3Hz
			_requestDataStream(MAV_DATA_STREAM_POSITION, 3);
			// Extended status 2Hz
			_requestDataStream(MAV_DATA_STREAM_EXTENDED_STATUS, 2);
		}

		void _requestDataStream(int streamId, int rate) {
			final request = RequestDataStream(
				targetSystem: _targetSystemId,
				targetComponent: _targetComponentId,
				reqStreamId: streamId,
				reqMessageRate: rate,
				startStop: 1,
			);
			final frame = MavlinkFrame.v2(_sequence, _sourceSystemId, _sourceComponentId, request);
			_sequence = (_sequence + 1) % 255;
			_serialPort?.write(frame.serialize());
			// Send again after delay to improve reliability
			Future.delayed(const Duration(milliseconds: 300), () {
				if (_serialPort != null) {
					_serialPort!.write(frame.serialize());
				}
			});
		}

		/// Request all parameters from the vehicle
		void requestAllParameters() {
			final msg = ParamRequestList(
				targetSystem: _targetSystemId,
				targetComponent: _targetComponentId,
			);
			final frame = MavlinkFrame.v1(_sequence, _sourceSystemId, _sourceComponentId, msg);
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
			final frame = MavlinkFrame.v1(_sequence, _sourceSystemId, _sourceComponentId, msg);
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
			final frame = MavlinkFrame.v1(_sequence, _sourceSystemId, _sourceComponentId, msg);
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
			final frame = MavlinkFrame.v1(_sequence, _sourceSystemId, _sourceComponentId, msg);
			_sequence = (
				_sequence + 1
			) % 255;
			_serialPort?.write(frame.serialize());
		}

		/// Change the flight mode (ArduPilot custom mode)
		void setFlightMode(int mode) {
			final msg = SetMode(
				targetSystem: _targetSystemId,
				baseMode: 1, // MAV_MODE_FLAG_CUSTOM_MODE_ENABLED
				customMode: mode,
			);
			final frame = MavlinkFrame.v1(_sequence, _sourceSystemId, _sourceComponentId, msg);
			_sequence = (_sequence + 1) % 255;
			_serialPort?.write(frame.serialize());
		}
}
