import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';

void main() {
  runApp(
    const MaterialApp(home: UartDisplay(), debugShowCheckedModeBanner: false),
  );
}

class UartDisplay extends StatefulWidget {
  const UartDisplay({super.key});

  @override
  State<UartDisplay> createState() => _UartDisplayState();
}

class _UartDisplayState extends State<UartDisplay>
    with SingleTickerProviderStateMixin {
  SerialPort? _serialPort;
  SerialPortReader? _serialReader;
  StreamSubscription? _subscription;
  final List<String> _receivedData = [];
  bool _isConnected = false;
  Timer? _timer;
  String _selectedPort = "/dev/cu.usbmodem1101";
  int _baudRate = 115200;
  List<String> _availablePorts = [];
  late TabController _tabController;
  int _currentTab = 0; // Tab hiện tại: 0 = Log, 1 = Dashboard

  // MAVLink stream IDs
  // --- Thông tin trạng thái bay bổ sung ---
  String _currentMode = 'Unknown';
  bool _isArmed = false;
  int _currentWaypoint = -1;
  int _totalWaypoints = -1;
  Map<String, double> _homePosition = {};
  String _ekfStatus = 'Unknown';
  static const int MAV_DATA_STREAM_ALL = 0;
  static const int MAV_DATA_STREAM_RAW_SENSORS = 1;
  static const int MAV_DATA_STREAM_EXTENDED_STATUS = 2;
  static const int MAV_DATA_STREAM_RC_CHANNELS = 3;
  static const int MAV_DATA_STREAM_RAW_CONTROLLER = 4;
  static const int MAV_DATA_STREAM_POSITION = 6;
  static const int MAV_DATA_STREAM_EXTRA1 = 10; // Attitude data
  static const int MAV_DATA_STREAM_EXTRA2 = 11; // VFR HUD data
  static const int MAV_DATA_STREAM_EXTRA3 = 12;

  // MAVLink parser
  late MavlinkDialectCommon _dialect;
  late MavlinkParser _parser;
  StreamSubscription? _parserSubscription;

  // Parameter handling
  int _sequence = 0;
  bool _requestingParameters = false;
  final Map<String, double> _parameters = {}; // Store parameters as key-value pairs
  int _systemId = 1; // Default system ID for target system
  final int _componentId =
      0; // Default component ID for target system (0 = all components)

  @override
  void initState() {
    super.initState();
    // Khởi tạo TabController
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTab = _tabController.index;
        });
      }
    });

    // Khởi tạo MAVLink parser
    _dialect = MavlinkDialectCommon();
    _parser = MavlinkParser(_dialect);

    // Đăng ký lắng nghe các gói tin MAVLink
    _setupMavlinkListener();

    _updateAvailablePorts();

    // Thêm thông báo khởi động
    _receivedData.add("Khởi động MAVLink UART Monitor...");
    _receivedData.add("Vui lòng chọn cổng COM và nhấn 'Kết nối'");
  }

  void _setupMavlinkListener() {
    _parserSubscription = _parser.stream.listen((MavlinkFrame frm) {
      print('Received message type: ${frm.message.runtimeType}');
      // Hiển thị giống parser.dart
      if (frm.message is Attitude) {
        var attitude = frm.message as Attitude;
        print('Yaw: ${attitude.yaw / pi * 180} [deg]');
      }

      // --- Lấy thông tin trạng thái bay bổ sung ---
      if (frm.message is Heartbeat) {
        var heartbeat = frm.message as Heartbeat;
        // Chế độ bay
        _currentMode = _decodeFlightMode(
          heartbeat.baseMode,
          heartbeat.customMode,
        );
        // Armed/Disarmed
        _isArmed = (heartbeat.baseMode & 0x80) != 0;
      }
      if (frm.message.runtimeType.toString() == 'MissionCurrent') {
        dynamic msg = frm.message;
        _currentWaypoint = msg.seq;
      }
      if (frm.message.runtimeType.toString() == 'MissionCount') {
        dynamic msg = frm.message;
        _totalWaypoints = msg.count;
      }
      if (frm.message.runtimeType.toString() == 'HomePosition') {
        dynamic msg = frm.message;
        _homePosition = {
          'lat': msg.latitude / 1e7,
          'lon': msg.longitude / 1e7,
          'alt': msg.altitude / 1000.0,
        };
      }
      if (frm.message.runtimeType.toString() == 'EkfStatusReport') {
        dynamic msg = frm.message;
        _ekfStatus = _decodeEkfStatus(msg.flags);
      }

      // Sử dụng biến để theo dõi có cần cập nhật UI hay không
      bool needUIUpdate = false;

      final DateTime timestamp = DateTime.now();
      final String timeStr =
          "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${(timestamp.millisecond ~/ 10).toString().padLeft(2, '0')}";

      // Cập nhật dữ liệu log
      setState(() {
        _receivedData.add(
          '[$timeStr] [MAVLink] Type: ${frm.message.runtimeType}, Sys: ${frm.systemId}, Comp: ${frm.componentId}',
        );

        // Thêm một bản tóm tắt dữ liệu khi nhận được các gói tin quan trọng
        if (frm.message is Attitude ||
            frm.message is GlobalPositionInt ||
            frm.message is VfrHud ||
            frm.message is GpsRawInt ||
            frm.message is SysStatus) {
          _addFlightSummary();
        }

        // Xử lý các loại tin nhắn MAVLink cụ thể
        if (frm.message is Heartbeat) {
          var heartbeat = frm.message as Heartbeat;

          // Tự động cập nhật system ID từ Heartbeat
          if (frm.systemId > 0 && frm.systemId < 255) {
            _systemId = frm.systemId;
          }

          _receivedData.add(
            '  ├─ [Heartbeat] Type: ${_getSystemType(heartbeat.type)}, ' 'Autopilot: ${_getAutopilotType(heartbeat.autopilot)}, ' 'Base Mode: 0x${heartbeat.baseMode.toRadixString(16).padLeft(2, '0')}, ' 'Custom Mode: ${heartbeat.customMode}, ' 'System Status: ${_getSystemStatus(heartbeat.systemStatus)}',
          );
          _receivedData.add(
            '  └─ Version: MAVLink ${heartbeat.mavlinkVersion}',
          );
        } else if (frm.message is SysStatus) {
          var status = frm.message as SysStatus;

          // Cập nhật biến toàn cục
          _batteryPercent = status.batteryRemaining;
          needUIUpdate = true;

          _receivedData.add(
            '  ├─ [SysStatus] Battery: $_batteryPercent%, ' 'Voltage: ${status.voltageBattery / 1000} V, ' 'Current: ${status.currentBattery / 100} A',
          );
          _receivedData.add(
            '  └─ CPU Load: ${status.load / 10}%, ' 'Comms Drop: ${status.dropRateComm}%, ' 'Errors: Comm: ${status.errorsComm}, ' 'Sensor Health: 0x${status.onboardControlSensorsHealth.toRadixString(16)}',
          );
        } else if (frm.message is Attitude) {
          var attitude = frm.message as Attitude;
          // Cập nhật biến toàn cục
          _roll = attitude.roll * 180 / pi;
          _pitch = attitude.pitch * 180 / pi;
          _yaw = attitude.yaw * 180 / pi;
          needUIUpdate = true;

          _receivedData.add(
            '  ├─ [Attitude] Roll: ${_roll.toStringAsFixed(2)}°, ' 'Pitch: ${_pitch.toStringAsFixed(2)}°, ' 'Yaw: ${_yaw.toStringAsFixed(2)}°',
          );
          _receivedData.add(
            '  └─ Roll Rate: ${(attitude.rollspeed * 180 / pi).toStringAsFixed(2)}°/s, ' 'Pitch Rate: ${(attitude.pitchspeed * 180 / pi).toStringAsFixed(2)}°/s, ' 'Yaw Rate: ${(attitude.yawspeed * 180 / pi).toStringAsFixed(2)}°/s',
          );
        } else if (frm.message is GlobalPositionInt) {
          var pos = frm.message as GlobalPositionInt;

          // Cập nhật biến toàn cục
          _altMSL = pos.alt / 1000;
          _altRelative = pos.relativeAlt / 1000;

          // Tính ground speed từ vận tốc theo hướng North và East
          double vx = pos.vx / 100; // m/s
          double vy = pos.vy / 100; // m/s
          _groundSpeed = sqrt(vx * vx + vy * vy);
          needUIUpdate = true;

          _receivedData.add(
            '  ├─ [Position] Lat: ${(pos.lat / 1e7).toStringAsFixed(7)}°, ' 'Lon: ${(pos.lon / 1e7).toStringAsFixed(7)}°',
          );
          _receivedData.add(
            '  ├─ Alt (MSL): ${_altMSL.toStringAsFixed(2)}m, ' 'Alt (Rel): ${_altRelative.toStringAsFixed(2)}m',
          );
          _receivedData.add(
            '  └─ Speed: N: ${vx.toStringAsFixed(1)}m/s, ' 'E: ${vy.toStringAsFixed(1)}m/s, ' 'D: ${(pos.vz / 100).toStringAsFixed(1)}m/s, ' 'Heading: ${(pos.hdg / 100).toStringAsFixed(1)}°',
          );
        } else if (frm.message is VfrHud) {
          var hud = frm.message as VfrHud;

          // Cập nhật biến toàn cục
          _airSpeed = hud.airspeed;
          _groundSpeed = hud
              .groundspeed; // Cập nhật lại ground speed từ VfrHud vì chính xác hơn
          needUIUpdate = true;

          _receivedData.add(
            '  ├─ [VFR HUD] Airspeed: ${_airSpeed.toStringAsFixed(1)}m/s, ' 'Groundspeed: ${_groundSpeed.toStringAsFixed(1)}m/s',
          );
          _receivedData.add(
            '  └─ Alt: ${hud.alt.toStringAsFixed(1)}m, ' 'Climb: ${hud.climb.toStringAsFixed(1)}m/s, ' 'Heading: ${hud.heading}°, ' 'Throttle: ${hud.throttle}%',
          );
        } else if (frm.message is RcChannelsRaw) {
          var rc = frm.message as RcChannelsRaw;
          _receivedData.add(
            '  ├─ [RC Channels] Chan1: ${rc.chan1Raw}, Chan2: ${rc.chan2Raw}, ' 'Chan3: ${rc.chan3Raw}, Chan4: ${rc.chan4Raw}',
          );
          _receivedData.add(
            '  └─ Chan5: ${rc.chan5Raw}, Chan6: ${rc.chan6Raw}, ' 'Chan7: ${rc.chan7Raw}, Chan8: ${rc.chan8Raw}, RSSI: ${rc.rssi}',
          );
        } else if (frm.message is GpsRawInt) {
          var gps = frm.message as GpsRawInt;

          // Cập nhật biến toàn cục
          _gpsFixType = _getGpsFix(gps.fixType);
          _satellites = gps.satellitesVisible;
          needUIUpdate = true;

          _receivedData.add(
            '  ├─ [GPS] Fix: $_gpsFixType, ' 'Satellites: $_satellites',
          );
          _receivedData.add(
            '  └─ Velocity: ${gps.vel / 100}m/s, ' 'Course: ${gps.cog / 100}°',
          );
        } else if (frm.message.runtimeType.toString() == 'StatusText') {
          // Sử dụng dynamic để truy cập các trường khi không biết kiểu trước
          dynamic text = frm.message;
          try {
            _receivedData.add(
              '  └─ [StatusText] [${_getStatusSeverity(text.severity)}] ${text.text}',
            );
          } catch (e) {
            _receivedData.add('  └─ [StatusText] Không thể đọc nội dung: $e');
          }
        } else if (frm.message is CommandAck) {
          var ack = frm.message as CommandAck;
          _receivedData.add(
            '  └─ [CommandAck] Command: ${ack.command}, Result: ${_getCommandResult(ack.result)}',
          );
        } else if (frm.message is ParamValue) {
          var param = frm.message as ParamValue;

          // Convert paramId from byte array to string and trim trailing zeros
          var terminatedIndex = param.paramId.indexOf(0);
          terminatedIndex = terminatedIndex == -1
              ? param.paramId.length
              : terminatedIndex;
          var trimmed = param.paramId.sublist(0, terminatedIndex);
          var paramId = String.fromCharCodes(trimmed);

          // Add to parameters map
          _parameters[paramId] = param.paramValue;

          // Hiển thị thông tin chi tiết
          _receivedData.add(
            '  ├─ [Param] ID: $paramId (${param.paramIndex}/${param.paramCount})',
          );
          _receivedData.add(
            '  ├─ Value: ${param.paramValue}, Type: ${_getParamType(param.paramType)}',
          );
          _receivedData.add(
            '  └─ Raw bytes: ${param.paramId.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ')}',
          );

          // Reset requestingParameters nếu đây là parameter cuối cùng
          if (param.paramIndex == param.paramCount - 1) {
            _requestingParameters = false;
            _receivedData.add(
              "✓ Đã nhận xong tất cả parameters (${_parameters.length} parameters)",
            );

            // Hiển thị dialog thông báo và hỏi người dùng có muốn xem danh sách không
            if (_parameters.length > 5) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Đã nhận ${_parameters.length} parameters'),
                    content: const Text(
                      'Bạn có muốn xem danh sách parameters không?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Đóng'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showParameterListScreen();
                        },
                        child: const Text('Xem danh sách'),
                      ),
                    ],
                  ),
                );
              });
            }
          }
        } else if (frm.message is ScaledImu) {
          var imu = frm.message as ScaledImu;
          _receivedData.add(
            '  ├─ [IMU] Accel: X: ${imu.xacc / 1000}g, Y: ${imu.yacc / 1000}g, Z: ${imu.zacc / 1000}g',
          );
          _receivedData.add(
            '  └─ Gyro: X: ${imu.xgyro / 1000}rad/s, Y: ${imu.ygyro / 1000}rad/s, Z: ${imu.zgyro / 1000}rad/s',
          );
        } else if (frm.message is BatteryStatus) {
          var bat = frm.message as BatteryStatus;
          _receivedData.add(
            '  ├─ [Battery] ID: ${bat.id}, ' 'Voltage: ${bat.voltages[0] != 0 ? (bat.voltages[0] / 1000).toStringAsFixed(2) : "N/A"}V',
          );
          _receivedData.add(
            '  └─ Current: ${bat.currentBattery / 100}A, ' 'Level: ${bat.batteryRemaining}%, ' 'Function: ${_getBatteryFunction(bat.batteryFunction)}',
          );
        } else if (frm.message is RawImu) {
          var imu = frm.message as RawImu;
          _receivedData.add(
            '  ├─ [Raw IMU] Accel: X: ${imu.xacc}, Y: ${imu.yacc}, Z: ${imu.zacc}',
          );
          _receivedData.add(
            '  └─ Gyro: X: ${imu.xgyro}, Y: ${imu.ygyro}, Z: ${imu.zgyro}, Mag: X: ${imu.xmag}, Y: ${imu.ymag}, Z: ${imu.zmag}',
          );
        }

        // Giới hạn số lượng dòng để tránh sử dụng quá nhiều bộ nhớ
        while (_receivedData.length > 100000) {
          _receivedData.removeAt(0);
        }
      });

      // Nếu cần cập nhật UI cho dashboard
      if (needUIUpdate && _currentTab == 1) {
        setState(() {
          // Kích hoạt việc cập nhật UI ở tab Dashboard
        });
      }
    });
  }

  String _getSystemType(int type) {
    switch (type) {
      case 0:
        return 'Generic';
      case 1:
        return 'Fixed Wing';
      case 2:
        return 'Quadrotor';
      case 3:
        return 'Coaxial helicopter';
      case 4:
        return 'Helicopter';
      case 5:
        return 'Antenna Tracker';
      case 6:
        return 'GCS';
      case 7:
        return 'Airship';
      case 8:
        return 'Free Balloon';
      case 9:
        return 'Rocket';
      case 10:
        return 'Ground Rover';
      case 11:
        return 'Surface Boat';
      case 12:
        return 'Submarine';
      case 13:
        return 'Hexarotor';
      case 14:
        return 'Octorotor';
      case 15:
        return 'Tricopter';
      case 19:
        return 'VTOL';
      default:
        return 'Unknown ($type)';
    }
  }

  String _getAutopilotType(int type) {
    switch (type) {
      case 0:
        return 'Generic';
      case 3:
        return 'ArduPilot';
      case 4:
        return 'PX4';
      default:
        return 'Unknown ($type)';
    }
  }

  String _getSystemStatus(int status) {
    switch (status) {
      case 0:
        return 'Uninit';
      case 1:
        return 'Boot';
      case 2:
        return 'Calibrating';
      case 3:
        return 'Standby';
      case 4:
        return 'Active';
      case 5:
        return 'Critical';
      case 6:
        return 'Emergency';
      case 7:
        return 'Poweroff';
      case 8:
        return 'Flight Termination';
      default:
        return 'Unknown ($status)';
    }
  }

  String _getGpsFix(int fixType) {
    switch (fixType) {
      case 0:
        return 'No GPS';
      case 1:
        return 'No Fix';
      case 2:
        return '2D Fix';
      case 3:
        return '3D Fix';
      case 4:
        return 'DGPS';
      case 5:
        return 'RTK Float';
      case 6:
        return 'RTK Fixed';
      case 7:
        return 'Static';
      case 8:
        return 'PPP';
      default:
        return 'Unknown ($fixType)';
    }
  }

  String _getStatusSeverity(int severity) {
    switch (severity) {
      case 0:
        return 'EMERGENCY';
      case 1:
        return 'ALERT';
      case 2:
        return 'CRITICAL';
      case 3:
        return 'ERROR';
      case 4:
        return 'WARNING';
      case 5:
        return 'NOTICE';
      case 6:
        return 'INFO';
      case 7:
        return 'DEBUG';
      default:
        return 'UNKNOWN';
    }
  }

  String _getCommandResult(int result) {
    switch (result) {
      case 0:
        return 'ACCEPTED';
      case 1:
        return 'TEMPORARILY REJECTED';
      case 2:
        return 'DENIED';
      case 3:
        return 'UNSUPPORTED';
      case 4:
        return 'FAILED';
      case 5:
        return 'IN PROGRESS';
      case 6:
        return 'CANCELLED';
      default:
        return 'UNKNOWN ($result)';
    }
  }

  String _getBatteryFunction(int function) {
    switch (function) {
      case 0:
        return 'Unknown';
      case 1:
        return 'All';
      case 2:
        return 'Propulsion';
      case 3:
        return 'Comms';
      case 4:
        return 'Payload';
      default:
        return 'Unknown ($function)';
    }
  }

  String _getParamType(int type) {
    switch (type) {
      case 1:
        return 'UINT8';
      case 2:
        return 'INT8';
      case 3:
        return 'UINT16';
      case 4:
        return 'INT16';
      case 5:
        return 'UINT32';
      case 6:
        return 'INT32';
      case 7:
        return 'UINT64';
      case 8:
        return 'INT64';
      case 9:
        return 'REAL32';
      case 10:
        return 'REAL64';
      default:
        return 'Unknown ($type)';
    }
  }

  // Giải mã chế độ bay từ baseMode và customMode
  String _decodeFlightMode(int baseMode, int customMode) {
    // Chế độ phổ biến: AUTO, GUIDED, LOITER, STABILIZE, MANUAL, RTL, etc.
    if ((baseMode & 0x04) != 0) return 'AUTO';
    if ((baseMode & 0x08) != 0) return 'GUIDED';
    if ((baseMode & 0x10) != 0) return 'STABILIZE';
    if ((baseMode & 0x40) != 0) return 'MANUAL';
    if ((baseMode & 0x80) != 0) return 'ARMED';
    // Có thể mở rộng thêm các chế độ khác dựa vào customMode
    return 'Unknown';
  }

  // Giải mã trạng thái EKF
  String _decodeEkfStatus(int flags) {
    // Xem https://mavlink.io/en/messages/common.html#EKF_STATUS_REPORT
    List<String> status = [];
    if ((flags & 1) != 0) status.add('Attitude OK');
    if ((flags & 2) != 0) status.add('Velocity OK');
    if ((flags & 4) != 0) status.add('Pos (Horiz) OK');
    if ((flags & 8) != 0) status.add('Pos (Vert) OK');
    if ((flags & 16) != 0) status.add('Compass OK');
    if ((flags & 32) != 0) status.add('Terrain OK');
    if ((flags & 64) != 0) status.add('Const Pos Mode');
    if ((flags & 128) != 0) status.add('Pred Pos Horiz OK');
    return status.isEmpty ? 'Unknown' : status.join(', ');
  }

  void _updateAvailablePorts() {
    try {
      _availablePorts = SerialPort.availablePorts;
      if (_availablePorts.isNotEmpty &&
          !_availablePorts.contains(_selectedPort)) {
        setState(() {
          _selectedPort = _availablePorts.first;
        });
      }
    } catch (e) {
      setState(() {
        _receivedData.add("Lỗi khi lấy danh sách cổng: $e");
      });
    }
  }

  void _connectToPort() {
    if (_isConnected) {
      _disconnectPort();
      return;
    }

    try {
      _serialPort = SerialPort(_selectedPort);

      if (_serialPort!.openReadWrite()) {
        _serialPort!.config.baudRate = _baudRate;
        _serialPort!.config.bits = 8;
        _serialPort!.config.stopBits = 1;
        _serialPort!.config.parity = SerialPortParity.none;
        _serialPort!.config.setFlowControl(SerialPortFlowControl.none);

        setState(() {
          _isConnected = true;
          _receivedData.add(
            "Đã kết nối tới $_selectedPort với tốc độ $_baudRate baud",
          );
        });

        _serialReader = SerialPortReader(_serialPort!);

        // Đọc dữ liệu với tần số cao hơn để bắt được tất cả các gói tin
        _timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
          _readData();
        });

        // Thêm delay nhỏ để đảm bảo kết nối ổn định trước khi gửi yêu cầu dữ liệu
        Future.delayed(const Duration(milliseconds: 500), () {
          _requestAllDataStreams();
        });
      } else {
        setState(() {
          _receivedData.add("Không thể mở cổng $_selectedPort");
        });
      }
    } catch (e) {
      setState(() {
        _receivedData.add("Lỗi khi kết nối đến cổng $_selectedPort: $e");
      });
    }
  }

  void _disconnectPort() {
    _timer?.cancel();
    _subscription?.cancel();
    _serialReader?.close();
    _serialPort?.close();

    setState(() {
      _isConnected = false;
      _receivedData.add("Đã ngắt kết nối khỏi $_selectedPort");
    });
  }

  // Biến toàn cục để lưu trữ dữ liệu flight controller gần nhất
  double _roll = 0;
  double _pitch = 0;
  double _yaw = 0;
  double _altMSL = 0;
  double _altRelative = 0;
  double _groundSpeed = 0;
  double _airSpeed = 0;
  String _gpsFixType = 'Unknown';
  int _satellites = 0;
  int _batteryPercent = 0;

  void _readData() {
    if (_serialPort != null && _serialPort!.isOpen) {
      try {
        final Uint8List data = _serialPort!.read(4096); // Tăng từ 1024 lên 4096
        if (data.isNotEmpty) {
          // Chỉ hiển thị raw data hex, không hiển thị thông tin flight controller ở mỗi lần đọc
          final String timeStr = DateTime.now().toIso8601String().substring(
            11,
            23,
          );
          final String hexData = data
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join(' ');

          setState(() {
            _receivedData.add("[$timeStr] Raw data [${data.length} bytes]");
            _receivedData.add(
              "  └─ HEX: ${hexData.length > 10000 ? '${hexData.substring(0, 10000)}...' : hexData}",
            );
          });

          // Phân tích dữ liệu MAVLink và kích hoạt _setupMavlinkListener để cập nhật UI
          _parser.parse(data);
        }
      } catch (e) {
        setState(() {
          _receivedData.add("Lỗi khi đọc dữ liệu: $e");
        });
      }
    }
  }

  void _addFlightSummary() {
    final DateTime timestamp = DateTime.now();
    final String timeStr =
        "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${(timestamp.millisecond ~/ 10).toString().padLeft(2, '0')}";

    _receivedData.add(
      '[$timeStr] ┌── Flight Controller Status ──────────────────────',
    );
    _receivedData.add(
      '        ├── Mode: $_currentMode | ${_isArmed ? "ARMED" : "DISARMED"}',
    );
    if (_currentWaypoint >= 0 && _totalWaypoints > 0) {
      _receivedData.add(
        '        ├── Waypoint: $_currentWaypoint / $_totalWaypoints',
      );
    }
    if (_homePosition.isNotEmpty) {
      _receivedData.add(
        '        ├── Home: Lat: ${_homePosition['lat']?.toStringAsFixed(7)}, Lon: ${_homePosition['lon']?.toStringAsFixed(7)}, Alt: ${_homePosition['alt']?.toStringAsFixed(2)}m',
      );
    }
    if (_ekfStatus != 'Unknown') {
      _receivedData.add('        ├── EKF: $_ekfStatus');
    }
    _receivedData.add(
      '        ├── Attitude: Roll: ${_roll.toStringAsFixed(2)}°, Pitch: ${_pitch.toStringAsFixed(2)}°, Yaw: ${_yaw.toStringAsFixed(2)}°',
    );
    _receivedData.add(
      '        ├── Altitude: MSL: ${_altMSL.toStringAsFixed(2)}m, Relative: ${_altRelative.toStringAsFixed(2)}m',
    );
    _receivedData.add(
      '        ├── Speed: Ground: ${_groundSpeed.toStringAsFixed(1)}m/s, Air: ${_airSpeed.toStringAsFixed(1)}m/s',
    );
    _receivedData.add(
      '        ├── GPS: $_gpsFixType, Satellites: $_satellites',
    );
    _receivedData.add('        └── Battery: $_batteryPercent%');
  }

  // Gửi yêu cầu danh sách tất cả các parameter
  void _requestAllParameters() {
    if (!_isConnected || _serialPort == null) {
      setState(() {
        _receivedData.add("Không thể yêu cầu parameters: chưa kết nối");
      });
      return;
    }

    setState(() {
      _requestingParameters = true;
      _parameters.clear(); // Xóa các parameter cũ
      _receivedData.add(
        "Đang yêu cầu tất cả các parameter từ flight controller...",
      );
    });

    try {
      // Tạo gói tin ParamRequestList
      var paramRequestList = ParamRequestList(
        targetSystem: _systemId,
        targetComponent: _componentId,
      );

      // Đóng gói và gửi - sử dụng component ID 0 hoặc MAV_COMP_ID_ALL để yêu cầu từ tất cả component
      var frm = MavlinkFrame.v1(_sequence++, 255, 0, paramRequestList);
      final data = frm.serialize();

      // Log dữ liệu gửi đi để debug
      final String hexData = data
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join(' ');

      // Ghi dữ liệu ra cổng serial
      final int bytesWritten = _serialPort!.write(data);

      setState(() {
        _receivedData.add(
          "Đã gửi yêu cầu danh sách parameter ($bytesWritten bytes)",
        );
        _receivedData.add("  └─ HEX: $hexData");
      });
    } catch (e) {
      setState(() {
        _receivedData.add("Lỗi khi gửi yêu cầu parameter: $e");
        _requestingParameters = false;
      });
    }
  }

  // Gửi yêu cầu một parameter cụ thể theo tên
  void _requestParameter(String paramName) {
    if (!_isConnected || _serialPort == null) {
      setState(() {
        _receivedData.add("Không thể yêu cầu parameter: chưa kết nối");
      });
      return;
    }

    setState(() {
      _receivedData.add(
        "Đang yêu cầu parameter '$paramName' từ flight controller...",
      );
    });

    try {
      // Convert param name to list of int with -1 terminator
      List<int> paramId = List<int>.filled(16, 0);
      for (int i = 0; i < paramName.length && i < 16; i++) {
        paramId[i] = paramName.codeUnitAt(i);
      }

      // Tạo gói tin ParamRequestRead
      var paramRequestRead = ParamRequestRead(
        targetSystem: _systemId,
        targetComponent: _componentId,
        paramId: paramId,
        paramIndex: -1, // -1 to use param_id
      );

      // Đóng gói và gửi - sử dụng component ID 0 hoặc MAV_COMP_ID_ALL để yêu cầu từ tất cả component
      var frm = MavlinkFrame.v1(_sequence++, 255, 0, paramRequestRead);
      final data = frm.serialize();

      // Log dữ liệu gửi đi để debug
      final String hexData = data
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join(' ');

      // Ghi dữ liệu ra cổng serial
      final int bytesWritten = _serialPort!.write(data);

      setState(() {
        _receivedData.add(
          "Đã gửi yêu cầu parameter '$paramName' ($bytesWritten bytes)",
        );
        _receivedData.add("  └─ HEX: $hexData");
      });
    } catch (e) {
      setState(() {
        _receivedData.add("Lỗi khi gửi yêu cầu parameter: $e");
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    _parserSubscription?.cancel();
    _serialReader?.close();
    _serialPort?.close();
    super.dispose();
  }

  // Hiển thị hộp thoại tùy chọn parameter
  void _showParameterDialog() {
    // Controller for the parameter name text field
    final paramNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Yêu cầu Parameters'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Tải tất cả parameters'),
                onPressed: () {
                  _requestAllParameters();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Hoặc yêu cầu một parameter cụ thể:'),
              const SizedBox(height: 8),
              TextField(
                controller: paramNameController,
                decoration: const InputDecoration(
                  labelText: 'Tên parameter',
                  hintText: 'Ví dụ: BATT_CAPACITY',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('Yêu cầu parameter'),
                onPressed: () {
                  if (paramNameController.text.isNotEmpty) {
                    _requestParameter(paramNameController.text);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
              const SizedBox(height: 16),
              if (_parameters.isNotEmpty)
                ElevatedButton.icon(
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Xem danh sách parameters'),
                  onPressed: () {
                    Navigator.pop(context);
                    _showParameterListScreen();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  // Hiển thị màn hình danh sách parameters
  void _showParameterListScreen() {
    // Kiểm tra xem có parameter nào không
    if (_parameters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có parameter nào. Hãy yêu cầu parameters trước!'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParameterListScreen(parameters: _parameters),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MAVLink UART Monitor - ${_isConnected ? "Đã kết nối $_selectedPort" : "Chưa kết nối"}',
        ),
        actions: [
          // Nút yêu cầu parameter - chỉ hiện khi đã kết nối
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.list_alt),
              onPressed: _showParameterDialog,
              tooltip: 'Yêu cầu parameters',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _updateAvailablePorts();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã cập nhật danh sách cổng')),
              );
            },
            tooltip: 'Làm mới danh sách cổng',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              setState(() {
                _receivedData.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã xóa toàn bộ dữ liệu')),
              );
            },
            tooltip: 'Xóa màn hình',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            setState(() {
              _currentTab = index;
            });
          },
          tabs: const [
            Tab(icon: Icon(Icons.view_list), text: "Log"),
            Tab(icon: Icon(Icons.dashboard), text: "Dashboard"),
          ],
        ),
      ),
      body: Column(
        children: [
          // Khu vực cài đặt kết nối
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                // Dropdown chọn cổng COM
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Cổng COM',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      value: _availablePorts.contains(_selectedPort)
                          ? _selectedPort
                          : null,
                      items: _availablePorts.map((port) {
                        return DropdownMenuItem<String>(
                          value: port,
                          child: Text(port),
                        );
                      }).toList(),
                      onChanged: _isConnected
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedPort = value;
                                });
                              }
                            },
                    ),
                  ),
                ),
                // Dropdown chọn tốc độ Baud
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Baud rate',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      value: _baudRate,
                      items:
                          [
                            9600,
                            19200,
                            38400,
                            57600,
                            115200,
                            230400,
                            460800,
                            921600,
                          ].map((rate) {
                            return DropdownMenuItem<int>(
                              value: rate,
                              child: Text(rate.toString()),
                            );
                          }).toList(),
                      onChanged: _isConnected
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() {
                                  _baudRate = value;
                                });
                              }
                            },
                    ),
                  ),
                ),
                // Nút kết nối/ngắt kết nối
                ElevatedButton.icon(
                  icon: Icon(_isConnected ? Icons.link_off : Icons.link),
                  label: Text(_isConnected ? 'Ngắt kết nối' : 'Kết nối'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isConnected ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onPressed: _connectToPort,
                ),
              ],
            ),
          ),

          // Khu vực hiển thị dữ liệu - thay đổi theo tab
          Expanded(
            child: _currentTab == 0 ? _buildLogTab() : _buildDashboardTab(),
          ),

          // Thanh trạng thái
          Container(
            padding: const EdgeInsets.all(8.0),
            color: _isConnected ? Colors.green[100] : Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trạng thái: ${_isConnected ? "Đang kết nối" : "Chưa kết nối"}${_requestingParameters ? " | Đang tải parameters..." : ""}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isConnected ? Colors.green[700] : Colors.grey[700],
                  ),
                ),
                if (_isConnected)
                  Row(
                    children: [
                      if (_requestingParameters)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      Text(
                        '$_selectedPort - $_baudRate baud',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget hiển thị tab Log
  Widget _buildLogTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black,
      child: ListView.builder(
        reverse: true,
        itemCount: _receivedData.length,
        itemBuilder: (context, index) {
          final int reverseIndex = _receivedData.length - 1 - index;
          final String line = _receivedData[reverseIndex];

          // Định dạng màu cho các loại thông báo khác nhau
          Color textColor = Colors.green;

          // Tô màu theo loại thông báo
          if (line.contains('[Heartbeat]')) {
            textColor = Colors.cyan;
          } else if (line.contains('[Position]')) {
            textColor = Colors.yellow;
          } else if (line.contains('[Attitude]')) {
            textColor = Colors.orange;
          } else if (line.contains('[SysStatus]')) {
            textColor = Colors.lightBlue;
          } else if (line.contains('[VFR HUD]')) {
            textColor = Colors.lightGreen;
          } else if (line.contains('[GPS]')) {
            textColor = Colors.purple;
          } else if (line.contains('[StatusText]')) {
            if (line.contains('ERROR') ||
                line.contains('CRITICAL') ||
                line.contains('ALERT') ||
                line.contains('EMERGENCY')) {
              textColor = Colors.red;
            } else if (line.contains('WARNING')) {
              textColor = Colors.amber;
            } else {
              textColor = Colors.white;
            }
          } else if (line.contains('[Battery]')) {
            textColor = Colors.pink;
          } else if (line.contains('[IMU]')) {
            textColor = Colors.teal;
          } else if (line.contains('Raw data')) {
            textColor = Colors.grey;
          } else if (line.contains('Flight Controller Status')) {
            textColor = Colors.blue;
          } else if (line.contains('[Param]')) {
            textColor = Colors.lime;
          }

          return Text(
            line,
            style: TextStyle(
              color: textColor,
              fontFamily: 'Courier',
              fontSize: 12,
              fontWeight:
                  line.contains('[StatusText]') &&
                      (line.contains('EMERGENCY') ||
                          line.contains('ALERT') ||
                          line.contains('CRITICAL') ||
                          line.contains('ERROR'))
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          );
        },
      ),
    );
  }

  // Widget hiển thị tab Dashboard
  Widget _buildDashboardTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[900],
      child: _isConnected
          ? SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thông tin chế độ bay, armed, waypoint, home, EKF
                  _buildDashboardCard(
                    icon: Icons.flight,
                    title: 'FLIGHT MODE',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildValueDisplay(
                          label: 'MODE',
                          value: _currentMode,
                          color: Colors.cyan,
                          isImportant: true,
                        ),
                        _buildValueDisplay(
                          label: 'ARMED',
                          value: _isArmed ? 'ARMED' : 'DISARMED',
                          color: _isArmed ? Colors.green : Colors.red,
                          isImportant: true,
                        ),
                        if (_currentWaypoint >= 0 && _totalWaypoints > 0)
                          _buildValueDisplay(
                            label: 'WAYPOINT',
                            value: '$_currentWaypoint / $_totalWaypoints',
                            color: Colors.orange,
                            isImportant: false,
                          ),
                        if (_homePosition.isNotEmpty)
                          _buildValueDisplay(
                            label: 'HOME',
                            value:
                                'Lat: ${_homePosition['lat']?.toStringAsFixed(7)}, Lon: ${_homePosition['lon']?.toStringAsFixed(7)}, Alt: ${_homePosition['alt']?.toStringAsFixed(2)}m',
                            color: Colors.blue,
                            isImportant: false,
                          ),
                        if (_ekfStatus != 'Unknown')
                          _buildValueDisplay(
                            label: 'EKF',
                            value: _ekfStatus,
                            color: Colors.purple,
                            isImportant: false,
                          ),
                      ],
                    ),
                  ),
                  // Thông tin Attitude (Roll, Pitch, Yaw)
                  _buildDashboardCard(
                    icon: Icons.rowing,
                    title: 'ATTITUDE',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAttitudeIndicator(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildValueDisplay(
                              label: 'ROLL',
                              value: '${_roll.toStringAsFixed(1)}°',
                              color: Colors.blue,
                              isImportant: true,
                            ),
                            _buildValueDisplay(
                              label: 'PITCH',
                              value: '${_pitch.toStringAsFixed(1)}°',
                              color: Colors.green,
                              isImportant: true,
                            ),
                            _buildValueDisplay(
                              label: 'YAW',
                              value: '${_yaw.toStringAsFixed(1)}°',
                              color: Colors.amber,
                              isImportant: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Thông tin Altitude và Speed
                  Row(
                    children: [
                      // Altitude
                      Expanded(
                        child: _buildDashboardCard(
                          icon: Icons.height,
                          title: 'ALTITUDE',
                          child: Column(
                            children: [
                              _buildAltitudeIndicator(),
                              const SizedBox(height: 8),
                              _buildValueDisplay(
                                label: 'MSL',
                                value: '${_altMSL.toStringAsFixed(1)} m',
                                color: Colors.lightBlue,
                                isImportant: false,
                              ),
                              _buildValueDisplay(
                                label: 'RELATIVE',
                                value: '${_altRelative.toStringAsFixed(1)} m',
                                color: Colors.cyan,
                                isImportant: true,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Speed
                      Expanded(
                        child: _buildDashboardCard(
                          icon: Icons.speed,
                          title: 'SPEED',
                          child: Column(
                            children: [
                              _buildSpeedIndicator(),
                              const SizedBox(height: 8),
                              _buildValueDisplay(
                                label: 'GROUND',
                                value: '${_groundSpeed.toStringAsFixed(1)} m/s',
                                color: Colors.orange,
                                isImportant: true,
                              ),
                              _buildValueDisplay(
                                label: 'AIR',
                                value: '${_airSpeed.toStringAsFixed(1)} m/s',
                                color: Colors.amber,
                                isImportant: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Thông tin GPS và Battery
                  Row(
                    children: [
                      // GPS
                      Expanded(
                        child: _buildDashboardCard(
                          icon: Icons.gps_fixed,
                          title: 'GPS',
                          child: Column(
                            children: [
                              _buildGpsIndicator(),
                              const SizedBox(height: 8),
                              _buildValueDisplay(
                                label: 'FIX',
                                value: _gpsFixType,
                                color: _gpsFixType == 'No Fix'
                                    ? Colors.red
                                    : _gpsFixType == '2D Fix'
                                    ? Colors.orange
                                    : Colors.green,
                                isImportant: true,
                              ),
                              _buildValueDisplay(
                                label: 'SATELLITES',
                                value: '$_satellites',
                                color: _satellites < 5
                                    ? Colors.red
                                    : _satellites < 8
                                    ? Colors.orange
                                    : Colors.green,
                                isImportant: false,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Battery
                      Expanded(
                        child: _buildDashboardCard(
                          icon: Icons.battery_charging_full,
                          title: 'BATTERY',
                          child: Column(
                            children: [
                              _buildBatteryIndicator(),
                              const SizedBox(height: 8),
                              _buildValueDisplay(
                                label: 'LEVEL',
                                value: '$_batteryPercent%',
                                color: _batteryPercent < 20
                                    ? Colors.red
                                    : _batteryPercent < 50
                                    ? Colors.orange
                                    : Colors.green,
                                isImportant: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.signal_wifi_off, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Chưa kết nối tới flight controller',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Vui lòng kết nối để xem dữ liệu bay',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
    );
  }

  // Widget để hiển thị một giá trị với nhãn
  Widget _buildValueDisplay({
    required String label,
    required String value,
    required Color color,
    required bool isImportant,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: isImportant ? 24 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Widget để tạo card trong dashboard
  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.grey[850],
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.grey),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  // Widget hiển thị attitude (roll, pitch) theo dạng horizon
  Widget _buildAttitudeIndicator() {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: CustomPaint(
        painter: AttitudeIndicatorPainter(
          roll: _roll * (pi / 180), // Chuyển từ độ sang radian
          pitch: _pitch * (pi / 180), // Chuyển từ độ sang radian
        ),
      ),
    );
  }

  // Widget hiển thị altitude dạng đồng hồ đo
  Widget _buildAltitudeIndicator() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: CustomPaint(
        painter: AltitudeIndicatorPainter(altitude: _altRelative),
      ),
    );
  }

  // Widget hiển thị speed dạng đồng hồ đo
  Widget _buildSpeedIndicator() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: CustomPaint(painter: SpeedIndicatorPainter(speed: _groundSpeed)),
    );
  }

  // Widget hiển thị GPS quality
  Widget _buildGpsIndicator() {
    // Xác định màu dựa trên tình trạng GPS
    Color signalColor;
    int signalBars;

    if (_gpsFixType == 'No Fix') {
      signalColor = Colors.red;
      signalBars = 0;
    } else if (_gpsFixType == '2D Fix') {
      signalColor = Colors.orange;
      signalBars = 2;
    } else if (_satellites < 5) {
      signalColor = Colors.orange;
      signalBars = 2;
    } else if (_satellites < 8) {
      signalColor = Colors.yellow;
      signalBars = 3;
    } else {
      signalColor = Colors.green;
      signalBars = 4;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          width: 15,
          height: 10 + index * 5,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          color: index < signalBars ? signalColor : Colors.grey[700],
        );
      }),
    );
  }

  // Widget hiển thị Battery level
  Widget _buildBatteryIndicator() {
    // Xác định màu dựa trên phần trăm pin
    Color batteryColor;

    if (_batteryPercent < 20) {
      batteryColor = Colors.red;
    } else if (_batteryPercent < 50) {
      batteryColor = Colors.orange;
    } else {
      batteryColor = Colors.green;
    }

    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Expanded(
            flex: _batteryPercent,
            child: Container(
              decoration: BoxDecoration(
                color: batteryColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(3),
                  bottomLeft: const Radius.circular(3),
                  topRight: _batteryPercent == 100
                      ? const Radius.circular(3)
                      : Radius.zero,
                  bottomRight: _batteryPercent == 100
                      ? const Radius.circular(3)
                      : Radius.zero,
                ),
              ),
            ),
          ),
          if (_batteryPercent < 100)
            Expanded(flex: 100 - _batteryPercent, child: Container()),
        ],
      ),
    );
  }

  void _requestAttitudeData() {
    if (!_isConnected || _serialPort == null) return;

    try {
      // Yêu cầu dữ liệu attitude (EXTRA1) với tần suất cao (10Hz)
      _requestDataStream(MAV_DATA_STREAM_EXTRA1, 10);

      // Thêm yêu cầu cho VFR HUD data để lấy thông tin tốc độ
      _requestDataStream(MAV_DATA_STREAM_EXTRA2, 5);

      setState(() {
        _receivedData.add("Đã yêu cầu dữ liệu attitude với tần suất 10Hz");
      });
    } catch (e) {
      setState(() {
        _receivedData.add("Error requesting data: $e");
      });
    }
  }

  // Gửi yêu cầu tất cả các luồng dữ liệu
  void _requestAllDataStreams() {
    if (!_isConnected || _serialPort == null) return;

    try {
      // Yêu cầu tất cả các loại dữ liệu với tần suất 4Hz
      _requestDataStream(MAV_DATA_STREAM_ALL, 4);

      // Yêu cầu dữ liệu attitude với tần suất cao hơn (10Hz)
      _requestDataStream(MAV_DATA_STREAM_EXTRA1, 10);

      // Yêu cầu dữ liệu VFR_HUD (tốc độ, độ cao) với tần suất 5Hz
      _requestDataStream(MAV_DATA_STREAM_EXTRA2, 5);

      // Yêu cầu dữ liệu vị trí với tần suất 3Hz
      _requestDataStream(MAV_DATA_STREAM_POSITION, 3);

      // Yêu cầu dữ liệu trạng thái mở rộng với tần suất 2Hz
      _requestDataStream(MAV_DATA_STREAM_EXTENDED_STATUS, 2);

      setState(() {
        _receivedData.add(
          "Đã gửi yêu cầu dữ liệu telemetry tới flight controller",
        );
      });
    } catch (e) {
      setState(() {
        _receivedData.add("Lỗi khi gửi yêu cầu dữ liệu: $e");
      });
    }
  }

  // Hàm yêu cầu một luồng dữ liệu cụ thể
  void _requestDataStream(int streamId, int rate) {
    if (!_isConnected || _serialPort == null) return;

    try {
      // Tạo message
      var requestDataStream = RequestDataStream(
        targetSystem: _systemId, // ID của hệ thống đích
        targetComponent: _componentId, // ID của component đích
        reqStreamId: streamId, // ID của luồng dữ liệu cần yêu cầu
        reqMessageRate: rate, // Tần suất yêu cầu (Hz)
        startStop: 1, // 1 = start, 0 = stop
      );

      // Tạo frame - sử dụng v2 để tương thích cao hơn như sitl_test.dart
      var frm = MavlinkFrame.v2(_sequence, 255, 0, requestDataStream);
      _sequence =
          (_sequence + 1) % 255; // Tăng sequence và giữ trong khoảng 0-255

      // Serialize và gửi
      final data = frm.serialize();
      _serialPort!.write(data);

      // Gửi lại lệnh sau một khoảng thời gian để đảm bảo flight controller nhận được
      Future.delayed(const Duration(milliseconds: 300), () {
        _serialPort!.write(data);
      });

      print(
        "Đã gửi yêu cầu dữ liệu Stream ID: $streamId với tần suất: $rate Hz",
      );
    } catch (e) {
      setState(() {
        _receivedData.add("Lỗi khi gửi yêu cầu dữ liệu stream $streamId: $e");
      });
    }
  }
}

// Màn hình hiển thị danh sách parameters
class ParameterListScreen extends StatefulWidget {
  final Map<String, double> parameters;

  const ParameterListScreen({super.key, required this.parameters});

  @override
  State<ParameterListScreen> createState() => _ParameterListScreenState();
}

class _ParameterListScreenState extends State<ParameterListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    // Sắp xếp các parameters theo tên
    final sortedEntries = widget.parameters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Lọc theo tìm kiếm nếu có
    final filteredEntries = _searchQuery.isEmpty
        ? sortedEntries
        : sortedEntries
              .where(
                (e) => e.key.toLowerCase().contains(_searchQuery.toLowerCase()),
              )
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Danh sách Parameters (${filteredEntries.length}/${widget.parameters.length})',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              // Tạo text để copy vào clipboard
              final paramText = sortedEntries
                  .map((e) => '${e.key}=${e.value}')
                  .join('\n');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chức năng lưu sẽ được thêm sau!'),
                ),
              );
            },
            tooltip: 'Lưu parameters',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Tìm parameter',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Parameter list
          Expanded(
            child: widget.parameters.isEmpty
                ? const Center(child: Text('Chưa có parameters nào'))
                : ListView.separated(
                    itemCount: filteredEntries.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      return ListTile(
                        title: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Giá trị: ${entry.value}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        trailing: const Icon(Icons.arrow_right),
                        onTap: () {
                          // Hiển thị chi tiết parameter
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Parameter: ${entry.key}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Giá trị: ${entry.value}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Đóng'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Vẽ chỉ báo attitude (artificial horizon)
class AttitudeIndicatorPainter extends CustomPainter {
  final double roll;
  final double pitch;

  AttitudeIndicatorPainter({required this.roll, required this.pitch});

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = min(centerX, centerY) * 0.9;

    // Vẽ viền tròn
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(centerX, centerY), radius, borderPaint);

    // Lưu trạng thái canvas
    canvas.save();

    // Di chuyển canvas đến tâm
    canvas.translate(centerX, centerY);

    // Xoay theo góc roll
    canvas.rotate(roll);

    // Di chuyển theo góc pitch (up/down)
    final double pitchOffset = radius * sin(pitch);
    canvas.translate(0, pitchOffset);

    // Vẽ nền trời và đất
    final skyPaint = Paint()..color = Colors.blue[900]!;
    final groundPaint = Paint()..color = Colors.brown[700]!;

    // Vẽ nền trời (nửa trên)
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(0, -radius),
        width: radius * 2,
        height: radius * 2,
      ),
      skyPaint,
    );

    // Vẽ mặt đất (nửa dưới)
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(0, radius),
        width: radius * 2,
        height: radius * 2,
      ),
      groundPaint,
    );

    // Vẽ đường chân trời
    final horizonPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawLine(Offset(-radius, 0), Offset(radius, 0), horizonPaint);

    // Vẽ các vạch đánh dấu cho góc pitch
    final markingsPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    for (int i = -30; i <= 30; i += 10) {
      if (i == 0) continue; // Đã vẽ đường chân trời

      final markY =
          -i * radius / 40; // Scale để vạch nằm trong phạm vi của chỉ báo
      final width = i % 20 == 0 ? radius * 0.4 : radius * 0.2;

      canvas.drawLine(
        Offset(-width, markY),
        Offset(width, markY),
        markingsPaint,
      );

      // Thêm số cho các vạch chính
      if (i % 20 == 0) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: i.abs().toString(),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(width + 5, markY - textPainter.height / 2),
        );
        textPainter.paint(
          canvas,
          Offset(
            -width - 5 - textPainter.width,
            markY - textPainter.height / 2,
          ),
        );
      }
    }

    // Phục hồi canvas
    canvas.restore();

    // Vẽ chỉ báo máy bay ở giữa (cố định)
    final planePaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Vẽ biểu tượng máy bay đơn giản
    canvas.drawLine(
      Offset(centerX - 20, centerY),
      Offset(centerX + 20, centerY),
      planePaint,
    );

    canvas.drawLine(
      Offset(centerX, centerY - 5),
      Offset(centerX, centerY + 5),
      planePaint,
    );

    // Vẽ các dấu đánh dấu cho góc roll
    final rollMarkPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    for (int i = -60; i <= 60; i += 30) {
      final angle = i * pi / 180;
      final markLength = i % 60 == 0 ? 10.0 : 5.0;

      final startX = centerX + (radius - 5) * sin(angle);
      final startY = centerY - (radius - 5) * cos(angle);

      final endX = centerX + (radius - 5 - markLength) * sin(angle);
      final endY = centerY - (radius - 5 - markLength) * cos(angle);

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        rollMarkPaint,
      );
    }

    // Vẽ tam giác chỉ báo roll hiện tại
    final rollTrianglePaint = Paint()..color = Colors.yellow;

    final rollTriangleX = centerX + radius * sin(roll);
    final rollTriangleY = centerY - radius * cos(roll);

    final path = Path();
    path.moveTo(rollTriangleX, rollTriangleY - 5);
    path.lineTo(rollTriangleX + 5, rollTriangleY + 5);
    path.lineTo(rollTriangleX - 5, rollTriangleY + 5);
    path.close();

    canvas.drawPath(path, rollTrianglePaint);
  }

  @override
  bool shouldRepaint(covariant AttitudeIndicatorPainter oldDelegate) {
    return oldDelegate.roll != roll || oldDelegate.pitch != pitch;
  }
}

// Vẽ đồng hồ đo altitude
class AltitudeIndicatorPainter extends CustomPainter {
  final double altitude;
  static const double maxAltitude = 100.0; // Đặt giới hạn hiển thị là 100m

  AltitudeIndicatorPainter({required this.altitude});

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double centerX = width / 2;

    // Đường dẫn cho đồng hồ
    final Paint bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.blue[900]!,
          Colors.blue[600]!,
          Colors.blue[300]!,
          Colors.green,
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    // Vẽ các vạch chia
    final tickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    for (int i = 0; i <= maxAltitude.toInt(); i += 10) {
      final y = height - (height * i / maxAltitude);
      final isMajorTick = i % 20 == 0;

      canvas.drawLine(
        Offset(0, y),
        Offset(isMajorTick ? width * 0.2 : width * 0.1, y),
        tickPaint,
      );

      canvas.drawLine(
        Offset(width, y),
        Offset(width - (isMajorTick ? width * 0.2 : width * 0.1), y),
        tickPaint,
      );

      if (isMajorTick) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: i.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(width * 0.25, y - textPainter.height / 2),
        );
      }
    }

    // Vẽ con trỏ hiện tại
    final pointerY =
        height - (height * min(altitude, maxAltitude) / maxAltitude);

    final pointerPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2;

    // Tam giác ở bên trái
    final leftPath = Path();
    leftPath.moveTo(0, pointerY);
    leftPath.lineTo(width * 0.1, pointerY - 5);
    leftPath.lineTo(width * 0.1, pointerY + 5);
    leftPath.close();
    canvas.drawPath(leftPath, pointerPaint);

    // Tam giác ở bên phải
    final rightPath = Path();
    rightPath.moveTo(width, pointerY);
    rightPath.lineTo(width * 0.9, pointerY - 5);
    rightPath.lineTo(width * 0.9, pointerY + 5);
    rightPath.close();
    canvas.drawPath(rightPath, pointerPaint);

    // Vẽ đường nối giữa hai tam giác
    canvas.drawLine(
      Offset(width * 0.1, pointerY),
      Offset(width * 0.9, pointerY),
      pointerPaint,
    );

    // Hiển thị giá trị hiện tại
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${altitude.toStringAsFixed(1)}m',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black45,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(minWidth: width * 0.3);
    textPainter.paint(
      canvas,
      Offset(centerX - textPainter.width / 2, pointerY - 20),
    );
  }

  @override
  bool shouldRepaint(covariant AltitudeIndicatorPainter oldDelegate) {
    return oldDelegate.altitude != altitude;
  }
}

// Vẽ đồng hồ đo tốc độ
class SpeedIndicatorPainter extends CustomPainter {
  final double speed;
  static const double maxSpeed = 30.0; // Đặt giới hạn hiển thị là 30m/s

  SpeedIndicatorPainter({required this.speed});

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double centerX = width / 2;
    final double centerY = height / 2;
    final double radius = min(centerX, centerY) * 0.8;

    // Vẽ nền đồng hồ tốc độ
    final bgPaint = Paint()..color = Colors.black;
    canvas.drawCircle(Offset(centerX, centerY), radius, bgPaint);

    // Vẽ viền đồng hồ
    final borderPaint = Paint()
      ..color = Colors.grey[700]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(centerX, centerY), radius, borderPaint);

    // Vẽ các vạch chia và số
    final tickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    for (int i = 0; i <= maxSpeed.toInt(); i += 5) {
      final angle = pi + (i / maxSpeed) * pi;
      final isMajorTick = i % 10 == 0;

      final innerRadius = radius - (isMajorTick ? 15 : 10);

      final startX = centerX + radius * cos(angle);
      final startY = centerY + radius * sin(angle);

      final endX = centerX + innerRadius * cos(angle);
      final endY = centerY + innerRadius * sin(angle);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), tickPaint);

      if (isMajorTick) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: i.toString(),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        textPainter.layout();

        final textRadius = innerRadius - 15;
        final textX = centerX + textRadius * cos(angle) - textPainter.width / 2;
        final textY =
            centerY + textRadius * sin(angle) - textPainter.height / 2;

        textPainter.paint(canvas, Offset(textX, textY));
      }
    }

    // Vẽ kim tốc độ
    final needlePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2;

    final needleAngle = pi + min(speed, maxSpeed) / maxSpeed * pi;

    final needleLength = radius - 10;
    final needleX = centerX + needleLength * cos(needleAngle);
    final needleY = centerY + needleLength * sin(needleAngle);

    canvas.drawLine(
      Offset(centerX, centerY),
      Offset(needleX, needleY),
      needlePaint,
    );

    // Vẽ điểm trung tâm
    final centerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(centerX, centerY), 5, centerPaint);

    // Hiển thị giá trị hiện tại
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${speed.toStringAsFixed(1)} m/s',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(centerX - textPainter.width / 2, centerY + 30),
    );
  }

  @override
  bool shouldRepaint(covariant SpeedIndicatorPainter oldDelegate) {
    return oldDelegate.speed != speed;
  }
}
