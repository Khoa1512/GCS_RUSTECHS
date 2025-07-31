# Drone MAVLink API Documentation

## 📋 Mục lục

- [Cài đặt](#cài-đặt)
- [Kiến trúc API](#kiến-trúc-api)
- [Class và Enum Reference](#class-và-enum-reference)
- [Hướng dẫn sử dụng](#hướng-dẫn-sử-dụng)
- [Event System](#event-system)
- [Examples](#examples)
- [Troubleshooting](#troubleshooting)

---

## 🚀 Cài đặt

### Dependencies

Thêm các dependencies sau vào `pubspec.yaml`:

```yaml
dependencies:
  flutter_libserialport: ^0.5.0
  dart_mavlink: ^0.1.0
```

### Import

```dart
import 'package:your_package_name/api/telemetry/mavlink_api.dart';
```

---

## 🏗️ Kiến trúc API

API được thiết kế theo mô hình OOP với các component chính:

```
DroneMAVLinkAPI (Main Class)
├── ConnectionManager (Quản lý kết nối)
├── MessageProcessor (Xử lý tin nhắn MAVLink)
├── EventSystem (Hệ thống sự kiện)
├── ParameterManager (Quản lý tham số)
├── CommandSender (Gửi lệnh điều khiển)
└── VehicleStateManager (Quản lý trạng thái máy bay)
```

---

## 📚 Class và Enum Reference

### 1. Enums

#### MAVLinkEventType
```dart
enum MAVLinkEventType {
  heartbeat,              // Nhịp tim từ máy bay
  attitude,               // Dữ liệu góc nghiêng (roll, pitch, yaw)
  position,               // Vị trí GPS và độ cao
  statusText,             // Tin nhắn trạng thái từ máy bay
  batteryStatus,          // Thông tin pin
  gpsInfo,                // Thông tin GPS chi tiết
  vfrHud,                 // Dữ liệu VFR HUD
  parameterReceived,      // Nhận được tham số đơn lẻ
  allParametersReceived,  // Nhận được tất cả tham số
  connectionStateChanged, // Thay đổi trạng thái kết nối
}
```

#### MAVLinkConnectionState
```dart
enum MAVLinkConnectionState {
  disconnected,  // Đã ngắt kết nối
  connected,     // Đã kết nối
  connecting,    // Đang kết nối
  error,         // Lỗi kết nối
}
```

### 2. Main Classes

#### MAVLinkEvent
```dart
class MAVLinkEvent {
  final MAVLinkEventType type;  // Loại sự kiện
  final dynamic data;           // Dữ liệu sự kiện
  final DateTime timestamp;     // Thời gian sự kiện
}
```

#### DroneMAVLinkAPI (Main Class)
```dart
class DroneMAVLinkAPI {
  // Constructor
  DroneMAVLinkAPI();
  
  // Connection Management
  Future<bool> connect(String port, {int? baudRate});
  void disconnect();
  List<String> getAvailablePorts();
  void initialize({String defaultPort, int baudRate});
  
  // Event System
  Stream<MAVLinkEvent> get eventStream;
  
  // Vehicle State Properties (Read-only)
  bool get isConnected;
  String get currentMode;
  bool get isArmed;
  double get roll;
  double get pitch;
  double get yaw;
  double get airSpeed;
  double get groundSpeed;
  double get altitudeMSL;
  double get altitudeRelative;
  String get gpsFixType;
  int get satellites;
  int get batteryPercent;
  
  // Parameter Management
  void requestAllParameters();
  void requestParameter(String paramName);
  void setParameter(String paramName, double value);
  Map<String, double> get parameters;
  
  // Vehicle Control
  void sendArmCommand(bool arm);
  void setFlightMode(int mode);
  
  // Data Stream Management
  void requestAllDataStreams();
  
  // Cleanup
  void dispose();
}
```

---

## 🔧 Hướng dẫn sử dụng

### 1. Khởi tạo và Kết nối

```dart
// Tạo instance API
final api = DroneMAVLinkAPI();

// Khởi tạo với cấu hình mặc định (tùy chọn)
api.initialize(defaultPort: "COM28", baudRate: 115200);

// Lấy danh sách cổng có sẵn
List<String> ports = api.getAvailablePorts();
print("Available ports: $ports");

// Kết nối đến cổng
bool success = await api.connect('COM28', baudRate: 115200);
if (success) {
  print("Kết nối thành công!");
} else {
  print("Kết nối thất bại!");
}
```

### 2. Event Handling System

```dart
// Lắng nghe tất cả sự kiện
api.eventStream.listen((MAVLinkEvent event) {
  switch (event.type) {
    case MAVLinkEventType.connectionStateChanged:
      _handleConnectionChange(event.data);
      break;
      
    case MAVLinkEventType.heartbeat:
      _handleHeartbeat(event.data);
      break;
      
    case MAVLinkEventType.attitude:
      _handleAttitude(event.data);
      break;
      
    case MAVLinkEventType.position:
      _handlePosition(event.data);
      break;
      
    case MAVLinkEventType.batteryStatus:
      _handleBattery(event.data);
      break;
      
    // ... xử lý các event khác
  }
});

// Xử lý sự kiện cụ thể
void _handleAttitude(Map<String, dynamic> data) {
  double roll = data['roll'];
  double pitch = data['pitch'];
  double yaw = data['yaw'];
  
  // Cập nhật UI hoặc xử lý logic
  setState(() {
    _currentRoll = roll;
    _currentPitch = pitch;
    _currentYaw = yaw;
  });
}
```

### 3. Truy cập Trạng thái Máy bay

```dart
// Kiểm tra trạng thái kết nối
if (api.isConnected) {
  // Lấy thông tin góc nghiêng
  double roll = api.roll;
  double pitch = api.pitch;
  double yaw = api.yaw;
  
  // Lấy thông tin tốc độ và độ cao
  double airSpeed = api.airSpeed;
  double groundSpeed = api.groundSpeed;
  double altitude = api.altitudeRelative;
  
  // Lấy thông tin GPS
  String gpsStatus = api.gpsFixType;
  int satellites = api.satellites;
  
  // Lấy thông tin pin
  int battery = api.batteryPercent;
  
  // Lấy trạng thái bay
  String mode = api.currentMode;
  bool armed = api.isArmed;
}
```

### 4. Quản lý Parameters

```dart
// Yêu cầu tất cả parameters
api.requestAllParameters();

// Lắng nghe khi nhận được tất cả parameters
api.eventStream.where((e) => e.type == MAVLinkEventType.allParametersReceived)
    .listen((event) {
  Map<String, double> allParams = event.data;
  print("Received ${allParams.length} parameters");
  
  // Truy cập parameter cụ thể
  double? wpNavSpeed = allParams['WPNAV_SPEED'];
  if (wpNavSpeed != null) {
    print("Waypoint navigation speed: $wpNavSpeed");
  }
});

// Yêu cầu parameter cụ thể
api.requestParameter('WPNAV_SPEED');

// Thiết lập parameter
api.setParameter('WPNAV_SPEED', 500.0);

// Truy cập parameters đã nhận
Map<String, double> currentParams = api.parameters;
```

### 5. Điều khiển Máy bay

```dart
// Arm/Disarm máy bay
api.sendArmCommand(true);  // Arm
api.sendArmCommand(false); // Disarm

// Thay đổi flight mode (ArduPilot)
api.setFlightMode(0);  // STABILIZE
api.setFlightMode(1);  // ACRO
api.setFlightMode(2);  // ALT_HOLD
api.setFlightMode(3);  // AUTO
api.setFlightMode(4);  // GUIDED
api.setFlightMode(5);  // LOITER
api.setFlightMode(6);  // RTL
api.setFlightMode(7);  // CIRCLE
```

### 6. Cleanup

```dart
@override
void dispose() {
  api.dispose(); // Dọn dẹp tài nguyên
  super.dispose();
}
```

---

## 🎯 Event System

### Event Data Structures

#### Heartbeat Event
```dart
{
  'mode': String,           // Flight mode
  'armed': bool,            // Armed status
  'systemType': String,     // Vehicle type
  'autopilotType': String,  // Autopilot type
  'systemStatus': String    // System status
}
```

#### Attitude Event
```dart
{
  'roll': double,      // Roll angle (degrees)
  'pitch': double,     // Pitch angle (degrees)
  'yaw': double,       // Yaw angle (degrees)
  'rollSpeed': double, // Roll rate (deg/s)
  'pitchSpeed': double,// Pitch rate (deg/s)
  'yawSpeed': double   // Yaw rate (deg/s)
}
```

#### Position Event
```dart
{
  'lat': double,        // Latitude (degrees)
  'lon': double,        // Longitude (degrees)
  'altMSL': double,     // Altitude MSL (meters)
  'altRelative': double,// Relative altitude (meters)
  'vx': double,         // North velocity (m/s)
  'vy': double,         // East velocity (m/s)
  'vz': double,         // Down velocity (m/s)
  'heading': double,    // Heading (degrees)
  'groundSpeed': double // Ground speed (m/s)
}
```

#### Battery Status Event
```dart
{
  'batteryPercent': int,    // Battery percentage
  'voltageBattery': double, // Battery voltage (V)
  'currentBattery': double, // Battery current (A)
  'cpuLoad': double,        // CPU load percentage
  'commDropRate': int,      // Communication drop rate
  'errorsComm': int,        // Communication errors
  'sensorHealth': int       // Sensor health bitmask
}
```

#### GPS Info Event
```dart
{
  'fixType': String,    // GPS fix type
  'satellites': int,    // Number of satellites
  'lat': double,        // Latitude (degrees)
  'lon': double,        // Longitude (degrees)
  'alt': double,        // Altitude (meters)
  'eph': double,        // Horizontal accuracy (meters)
  'epv': double,        // Vertical accuracy (meters)
  'vel': double,        // Speed (m/s)
  'cog': double         // Course over ground (degrees)
}
```

#### VFR HUD Event
```dart
{
  'airspeed': double,    // Airspeed (m/s)
  'groundspeed': double, // Ground speed (m/s)
  'heading': int,        // Heading (degrees)
  'throttle': int,       // Throttle percentage
  'alt': double,         // Altitude (meters)
  'climb': double        // Climb rate (m/s)
}
```

#### Status Text Event
```dart
{
  'severity': String,    // Message severity
  'text': String         // Status message text
}
```

---

## 💡 Examples

### Example 1: Simple Connection and Data Display

```dart
import 'package:flutter/material.dart';
import 'mavlink_api.dart';

class SimpleMAVLinkDisplay extends StatefulWidget {
  @override
  _SimpleMAVLinkDisplayState createState() => _SimpleMAVLinkDisplayState();
}

class _SimpleMAVLinkDisplayState extends State<SimpleMAVLinkDisplay> {
  final DroneMAVLinkAPI _api = DroneMAVLinkAPI();
  bool _isConnected = false;
  String _flightMode = "Unknown";
  bool _isArmed = false;
  double _altitude = 0.0;
  int _batteryPercent = 0;

  @override
  void initState() {
    super.initState();
    
    // Lắng nghe events
    _api.eventStream.listen((event) {
      setState(() {
        switch (event.type) {
          case MAVLinkEventType.connectionStateChanged:
            _isConnected = (event.data == MAVLinkConnectionState.connected);
            break;
          case MAVLinkEventType.heartbeat:
            _flightMode = event.data['mode'];
            _isArmed = event.data['armed'];
            break;
          case MAVLinkEventType.position:
            _altitude = event.data['altRelative'];
            break;
          case MAVLinkEventType.batteryStatus:
            _batteryPercent = event.data['batteryPercent'];
            break;
        }
      });
    });
  }

  Future<void> _connect() async {
    List<String> ports = _api.getAvailablePorts();
    if (ports.isNotEmpty) {
      await _api.connect(ports.first, baudRate: 115200);
    }
  }

  void _disconnect() {
    _api.disconnect();
  }

  void _toggleArm() {
    _api.sendArmCommand(!_isArmed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MAVLink Simple Display'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection controls
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isConnected ? _disconnect : _connect,
                  child: Text(_isConnected ? 'Disconnect' : 'Connect'),
                ),
                SizedBox(width: 16),
                Text(
                  'Status: ${_isConnected ? "Connected" : "Disconnected"}',
                  style: TextStyle(
                    color: _isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            
            // Vehicle info
            if (_isConnected) ...[
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Flight Mode: $_flightMode'),
                      Text('Armed: ${_isArmed ? "Yes" : "No"}'),
                      Text('Altitude: ${_altitude.toStringAsFixed(1)}m'),
                      Text('Battery: $_batteryPercent%'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _toggleArm,
                child: Text(_isArmed ? 'Disarm' : 'Arm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isArmed ? Colors.red : Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
```

### Example 2: Parameter Management

```dart
class ParameterManager extends StatefulWidget {
  @override
  _ParameterManagerState createState() => _ParameterManagerState();
}

class _ParameterManagerState extends State<ParameterManager> {
  final DroneMAVLinkAPI _api = DroneMAVLinkAPI();
  Map<String, double> _parameters = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    _api.eventStream.listen((event) {
      if (event.type == MAVLinkEventType.allParametersReceived) {
        setState(() {
          _parameters = Map.from(event.data);
          _isLoading = false;
        });
      }
    });
  }

  void _loadAllParameters() {
    setState(() {
      _isLoading = true;
    });
    _api.requestAllParameters();
  }

  void _setParameter(String name, double value) {
    _api.setParameter(name, value);
    // Optionally request the parameter back to confirm
    Future.delayed(Duration(milliseconds: 500), () {
      _api.requestParameter(name);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Parameter Manager'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadAllParameters,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _parameters.length,
              itemBuilder: (context, index) {
                String paramName = _parameters.keys.elementAt(index);
                double paramValue = _parameters[paramName]!;
                
                return ListTile(
                  title: Text(paramName),
                  subtitle: Text('Value: $paramValue'),
                  trailing: IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () => _showEditDialog(paramName, paramValue),
                  ),
                );
              },
            ),
    );
  }

  void _showEditDialog(String paramName, double currentValue) {
    final controller = TextEditingController(text: currentValue.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Parameter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Parameter: $paramName'),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Value'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              double? newValue = double.tryParse(controller.text);
              if (newValue != null) {
                _setParameter(paramName, newValue);
                Navigator.pop(context);
              }
            },
            child: Text('Set'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
```

---

## 🚨 Troubleshooting

### Vấn đề thường gặp

#### 1. Không thể kết nối đến cổng COM
```dart
// Kiểm tra cổng có sẵn
List<String> ports = api.getAvailablePorts();
if (ports.isEmpty) {
  print("Không có cổng COM nào được phát hiện");
}

// Thử các baud rate khác nhau
List<int> baudRates = [9600, 57600, 115200, 230400, 460800, 921600];
for (int baudRate in baudRates) {
  bool success = await api.connect(port, baudRate: baudRate);
  if (success) break;
}
```

#### 2. Không nhận được dữ liệu
```dart
// Kiểm tra kết nối
if (api.isConnected) {
  // Yêu cầu lại data streams
  api.requestAllDataStreams();
  
  // Kiểm tra heartbeat
  api.eventStream
      .where((e) => e.type == MAVLinkEventType.heartbeat)
      .timeout(Duration(seconds: 5))
      .listen(
        (event) => print("Heartbeat received"),
        onError: (error) => print("No heartbeat in 5 seconds"),
      );
}
```

#### 3. Parameters không được nhận
```dart
// Thử yêu cầu lại sau delay
Future.delayed(Duration(seconds: 2), () {
  api.requestAllParameters();
});

// Hoặc yêu cầu từng parameter riêng lẻ
List<String> importantParams = ['WPNAV_SPEED', 'RTL_ALT', 'LAND_SPEED'];
for (String param in importantParams) {
  api.requestParameter(param);
  await Future.delayed(Duration(milliseconds: 100));
}
```

#### 4. Lỗi parsing MAVLink
```dart
// Thêm error handling cho event stream
api.eventStream.listen(
  (event) {
    // Xử lý event bình thường
  },
  onError: (error) {
    print("MAVLink parsing error: $error");
    // Thử kết nối lại
    api.disconnect();
    Future.delayed(Duration(seconds: 2), () {
      api.connect(lastPort, baudRate: lastBaudRate);
    });
  },
);
```

### Debug Mode

Để bật debug mode, bạn có thể thêm logging:

```dart
class DebugMAVLinkAPI extends DroneMAVLinkAPI {
  @override
  void _processMAVLinkFrame(MavlinkFrame frm) {
    print("Received MAVLink message: ${frm.message.runtimeType}");
    super._processMAVLinkFrame(frm);
  }
}
```

---

## 📖 API Constants

### MAVLink Stream IDs
```dart
static const int MAV_DATA_STREAM_ALL = 0;
static const int MAV_DATA_STREAM_RAW_SENSORS = 1;
static const int MAV_DATA_STREAM_EXTENDED_STATUS = 2;
static const int MAV_DATA_STREAM_RC_CHANNELS = 3;
static const int MAV_DATA_STREAM_RAW_CONTROLLER = 4;
static const int MAV_DATA_STREAM_POSITION = 6;
static const int MAV_DATA_STREAM_EXTRA1 = 10;  // Attitude data
static const int MAV_DATA_STREAM_EXTRA2 = 11;  // VFR HUD data
static const int MAV_DATA_STREAM_EXTRA3 = 12;
```

### Common Flight Modes (ArduPilot)
```dart
const Map<int, String> ARDUPILOT_MODES = {
  0: 'STABILIZE',
  1: 'ACRO',
  2: 'ALT_HOLD',
  3: 'AUTO',
  4: 'GUIDED',
  5: 'LOITER',
  6: 'RTL',
  7: 'CIRCLE',
  8: 'POSITION',
  9: 'LAND',
  10: 'OF_LOITER',
  11: 'DRIFT',
  13: 'SPORT',
  14: 'FLIP',
  15: 'AUTOTUNE',
  16: 'POSHOLD',
  17: 'BRAKE',
  18: 'THROW',
  19: 'AVOID_ADSB',
  20: 'GUIDED_NOGPS',
  21: 'SMART_RTL',
  22: 'FLOWHOLD',
  23: 'FOLLOW',
  24: 'ZIGZAG',
  25: 'SYSTEMID',
  26: 'AUTOROTATE',
  27: 'AUTO_RTL',
};
```

---

## 🔗 Links và Resources

- [MAVLink Protocol Documentation](https://mavlink.io/)
- [ArduPilot Documentation](https://ardupilot.org/)
- [Flutter LibSerialPort](https://pub.dev/packages/flutter_libserialport)
- [Dart MAVLink](https://pub.dev/packages/dart_mavlink)

---

## 📝 License

MIT License - xem file LICENSE để biết thêm chi tiết.
