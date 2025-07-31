# MAVLink API Documentation

`DroneMAVLinkAPI` là một lớp API chính để giao tiếp với drone thông qua giao thức MAVLink qua kết nối serial. API này cung cấp một interface đơn giản để kết nối, nhận dữ liệu telemetry, và điều khiển drone.

## 📋 Mục lục

1. [Cấu trúc API](#cấu-trúc-api)
2. [Event System](#event-system)
3. [Connection Management](#connection-management)
4. [Data Streams](#data-streams)
5. [Parameter Management](#parameter-management)
6. [Command Sending](#command-sending)
7. [Vehicle State](#vehicle-state)
8. [Usage Examples](#usage-examples)
9. [UI Example & Testing](#ui-example--testing)
10. [Error Handling](#error-handling)

## 🚀 Quick Start

```dart
import 'package:vtol_fe/api/telemetry/mavlink_api.dart';

// Tạo instance API
final api = DroneMAVLinkAPI();

// Kết nối
bool success = await api.connect('COM3', baudRate: 115200);

// Lắng nghe events
api.eventStream.listen((event) {
  switch (event.type) {
    case MAVLinkEventType.attitude:
      print('Roll: ${event.data['roll']}°');
      break;
    case MAVLinkEventType.gpsInfo:
      print('GPS: ${event.data['fixType']}, Sats: ${event.data['satellites']}');
      break;
  }
});

// Dọn dẹp
api.dispose();
```

## 🏗️ Cấu trúc API

### Class Hierarchy

```
DroneMAVLinkAPI
├── Connection Management
├── Event System
├── Data Streams
├── Parameter Management
├── Command Interface
└── Vehicle State
```

### Core Components

#### 1. MAVLink Event System

- **MAVLinkEventType**: Enum định nghĩa các loại sự kiện
- **MAVLinkEvent**: Class đại diện cho một sự kiện MAVLink
- **Stream<MAVLinkEvent>**: Stream để lắng nghe các sự kiện

#### 2. Connection State Management

- **MAVLinkConnectionState**: Enum trạng thái kết nối
- **Serial Port Management**: Quản lý kết nối serial
- **Auto-reconnection**: Tự động kết nối lại khi mất kết nối

---

## 🎯 Event System

### Event Types

```dart
enum MAVLinkEventType {
  heartbeat,           // Heartbeat từ drone
  attitude,            // Dữ liệu góc nghiêng (roll, pitch, yaw)
  position,            // Vị trí GPS và altitude
  statusText,          // Tin nhắn trạng thái từ drone
  batteryStatus,       // Thông tin pin
  gpsInfo,            // Thông tin GPS chi tiết
  vfrHud,             // Dữ liệu VFR HUD (tốc độ, độ cao)
  parameterReceived,   // Tham số nhận được
  allParametersReceived, // Tất cả tham số đã nhận
  connectionStateChanged, // Thay đổi trạng thái kết nối
}
```

### Event Data Structure

Mỗi event chứa:

- **type**: Loại sự kiện
- **data**: Dữ liệu sự kiện (Map<String, dynamic>)
- **timestamp**: Thời gian xảy ra sự kiện

### Listening to Events

```dart
// Tạo instance API
final api = DroneMAVLinkAPI();

// Lắng nghe tất cả events
api.eventStream.listen((MAVLinkEvent event) {
  switch (event.type) {
    case MAVLinkEventType.heartbeat:
      print('Heartbeat: ${event.data}');
      break;
    case MAVLinkEventType.attitude:
      print('Attitude: Roll=${event.data['roll']}, Pitch=${event.data['pitch']}');
      break;
    // ... other events
  }
});

// Lắng nghe event cụ thể
api.eventStream
  .where((event) => event.type == MAVLinkEventType.gpsInfo)
  .listen((event) {
    print('GPS Fix: ${event.data['fixType']}');
    print('Satellites: ${event.data['satellites']}');
  });
```

---

## 🔌 Connection Management

### Available Methods

#### `List<String> getAvailablePorts()`

Lấy danh sách các cổng serial khả dụng.

```dart
List<String> ports = api.getAvailablePorts();
print('Available ports: $ports');
```

#### `Future<bool> connect(String port, {int? baudRate})`

Kết nối tới cổng serial được chỉ định.

**Parameters:**

- `port`: Tên cổng serial (VD: "COM3", "/dev/ttyUSB0")
- `baudRate`: Tốc độ baud (mặc định: 115200)

**Returns:** `true` nếu kết nối thành công, `false` nếu thất bại.

```dart
bool connected = await api.connect('COM3', baudRate: 57600);
if (connected) {
  print('Connected successfully');
} else {
  print('Connection failed');
}
```

#### `void disconnect()`

Ngắt kết nối khỏi cổng serial.

```dart
api.disconnect();
```

### Connection States

```dart
enum MAVLinkConnectionState {
  disconnected,  // Chưa kết nối
  connected,     // Đã kết nối
  connecting,    // Đang kết nối
  error,         // Lỗi kết nối
}
```

---

## 📡 Data Streams

### Stream Types

API tự động yêu cầu các luồng dữ liệu sau khi kết nối:

- **MAV_DATA_STREAM_ALL**: Tất cả dữ liệu (4Hz)
- **MAV_DATA_STREAM_EXTRA1**: Dữ liệu attitude (10Hz)
- **MAV_DATA_STREAM_EXTRA2**: Dữ liệu VFR HUD (5Hz)
- **MAV_DATA_STREAM_POSITION**: Dữ liệu vị trí (3Hz)
- **MAV_DATA_STREAM_EXTENDED_STATUS**: Trạng thái mở rộng (2Hz)

### Manual Stream Request

```dart
// Yêu cầu tất cả luồng dữ liệu
api.requestAllDataStreams();
```

---

## ⚙️ Parameter Management

### Reading Parameters

#### `void requestAllParameters()`

Yêu cầu tất cả tham số từ drone.

```dart
api.requestAllParameters();

// Lắng nghe khi nhận được tất cả tham số
api.eventStream
  .where((event) => event.type == MAVLinkEventType.allParametersReceived)
  .listen((event) {
    Map<String, double> parameters = event.data;
    print('Received ${parameters.length} parameters');
  });
```

#### `void requestParameter(String paramName)`

Yêu cầu một tham số cụ thể.

```dart
api.requestParameter('ARMING_CHECK');

api.eventStream
  .where((event) => event.type == MAVLinkEventType.parameterReceived)
  .listen((event) {
    print('Parameter ${event.data['id']}: ${event.data['value']}');
  });
```

### Writing Parameters

#### `void setParameter(String paramName, double value)`

Thiết lập giá trị cho một tham số.

```dart
// Thiết lập tham số ARMING_CHECK
api.setParameter('ARMING_CHECK', 1.0);
```

### Accessing Parameters

```dart
// Lấy tất cả tham số đã nhận
Map<String, double> allParams = api.parameters;

// Lấy giá trị tham số cụ thể
double? armingCheck = api.parameters['ARMING_CHECK'];
```

---

## 🎮 Command Sending

### Arm/Disarm Commands

#### `void sendArmCommand(bool arm)`

Gửi lệnh arm/disarm tới drone.

```dart
// Arm drone
api.sendArmCommand(true);

// Disarm drone
api.sendArmCommand(false);
```

### Flight Mode Commands

#### `void setFlightMode(int mode)`

Thay đổi flight mode của drone.

```dart
// Các flight mode phổ biến cho ArduPilot:
// 0: MANUAL, 2: STABILIZE, 9: AUTO, 10: RTL, 11: LOITER
api.setFlightMode(2); // STABILIZE mode
```

---

## 📊 Vehicle State

### Real-time State Properties

API cung cấp các thuộc tính chỉ đọc để truy cập trạng thái hiện tại:

#### Connection State

```dart
bool isConnected = api.isConnected;
```

#### Flight Status

```dart
String currentMode = api.currentMode;      // Flight mode hiện tại
bool isArmed = api.isArmed;               // Trạng thái arm
```

#### Attitude Data

```dart
double roll = api.roll;        // Góc roll (độ)
double pitch = api.pitch;      // Góc pitch (độ)  
double yaw = api.yaw;          // Góc yaw (độ)
```

#### Speed Data

```dart
double airSpeed = api.airSpeed;       // Tốc độ không khí (m/s)
double groundSpeed = api.groundSpeed; // Tốc độ mặt đất (m/s)
```

#### Altitude Data

```dart
double altMSL = api.altitudeMSL;           // Độ cao so với mực nước biển
double altRelative = api.altitudeRelative; // Độ cao tương đối
```

#### GPS Data

```dart
String gpsFixType = api.gpsFixType; // Loại GPS fix
int satellites = api.satellites;    // Số vệ tinh
```

#### Battery Data

```dart
int batteryPercent = api.batteryPercent; // Phần trăm pin
```

#### Mission Data

```dart
int currentWaypoint = api.currentWaypoint; // Waypoint hiện tại
int totalWaypoints = api.totalWaypoints;   // Tổng số waypoint
```

#### System Status

```dart
Map<String, double> homePosition = api.homePosition; // Vị trí home
String ekfStatus = api.ekfStatus;                    // Trạng thái EKF
```

---

## 💡 Usage Examples

### Complete Connection Example

```dart
import 'package:vtol_fe/api/telemetry/mavlink_api.dart';

class DroneController {
  late DroneMAVLinkAPI api;
  StreamSubscription? _subscription;

  void initialize() {
    api = DroneMAVLinkAPI();
    
    // Lắng nghe events
    _subscription = api.eventStream.listen(_handleMAVLinkEvent);
  }

  void _handleMAVLinkEvent(MAVLinkEvent event) {
    switch (event.type) {
      case MAVLinkEventType.connectionStateChanged:
        _handleConnectionState(event.data);
        break;
      case MAVLinkEventType.heartbeat:
        _handleHeartbeat(event.data);
        break;
      case MAVLinkEventType.attitude:
        _handleAttitude(event.data);
        break;
      case MAVLinkEventType.gpsInfo:
        _handleGPS(event.data);
        break;
      // ... other events
    }
  }

  void _handleConnectionState(MAVLinkConnectionState state) {
    switch (state) {
      case MAVLinkConnectionState.connected:
        print('Drone connected');
        // Yêu cầu tham số khi kết nối
        api.requestAllParameters();
        break;
      case MAVLinkConnectionState.disconnected:
        print('Drone disconnected');
        break;
      case MAVLinkConnectionState.error:
        print('Connection error');
        break;
    }
  }

  void _handleHeartbeat(Map<String, dynamic> data) {
    print('Mode: ${data['mode']}, Armed: ${data['armed']}');
  }

  void _handleAttitude(Map<String, dynamic> data) {
    print('Roll: ${data['roll']?.toStringAsFixed(1)}°');
    print('Pitch: ${data['pitch']?.toStringAsFixed(1)}°');
    print('Yaw: ${data['yaw']?.toStringAsFixed(1)}°');
  }

  void _handleGPS(Map<String, dynamic> data) {
    print('GPS: ${data['fixType']}, Sats: ${data['satellites']}');
    print('Position: ${data['lat']}, ${data['lon']}');
  }

  Future<void> connectToDrone(String port) async {
    bool connected = await api.connect(port);
    if (!connected) {
      print('Failed to connect to drone');
    }
  }

  void armDrone() {
    if (api.isConnected) {
      api.sendArmCommand(true);
    }
  }

  void disarmDrone() {
    if (api.isConnected) {
      api.sendArmCommand(false);
    }
  }

  void setStabilizeMode() {
    if (api.isConnected) {
      api.setFlightMode(2); // STABILIZE
    }
  }

  void dispose() {
    _subscription?.cancel();
    api.dispose();
  }
}
```

### UI Integration Example

```dart
class DroneStatusWidget extends StatefulWidget {
  final DroneMAVLinkAPI api;

  const DroneStatusWidget({Key? key, required this.api}) : super(key: key);

  @override
  _DroneStatusWidgetState createState() => _DroneStatusWidgetState();
}

class _DroneStatusWidgetState extends State<DroneStatusWidget> {
  late StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.api.eventStream.listen(_updateUI);
  }

  void _updateUI(MAVLinkEvent event) {
    if (mounted) {
      setState(() {
        // UI sẽ tự động cập nhật khi setState được gọi
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Connection Status
        Text('Connected: ${widget.api.isConnected}'),
        
        // Flight Status
        Text('Mode: ${widget.api.currentMode}'),
        Text('Armed: ${widget.api.isArmed}'),
        
        // Attitude
        Text('Roll: ${widget.api.roll.toStringAsFixed(1)}°'),
        Text('Pitch: ${widget.api.pitch.toStringAsFixed(1)}°'),
        Text('Yaw: ${widget.api.yaw.toStringAsFixed(1)}°'),
        
        // GPS
        Text('GPS: ${widget.api.gpsFixType}'),
        Text('Satellites: ${widget.api.satellites}'),
        
        // Battery
        Text('Battery: ${widget.api.batteryPercent}%'),
        
        // Controls
        ElevatedButton(
          onPressed: widget.api.isConnected && !widget.api.isArmed
              ? () => widget.api.sendArmCommand(true)
              : null,
          child: Text('Arm'),
        ),
        ElevatedButton(
          onPressed: widget.api.isConnected && widget.api.isArmed
              ? () => widget.api.sendArmCommand(false)
              : null,
          child: Text('Disarm'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
```

---

## ⚠️ Error Handling

### Connection Errors

API xử lý lỗi kết nối một cách tự động:

```dart
api.eventStream
  .where((event) => event.type == MAVLinkEventType.connectionStateChanged)
  .listen((event) {
    if (event.data == MAVLinkConnectionState.error) {
      print('Connection error occurred');
      // Thực hiện retry logic
      _retryConnection();
    }
  });

void _retryConnection() async {
  await Future.delayed(Duration(seconds: 5));
  bool reconnected = await api.connect(_lastPort);
  if (!reconnected) {
    // Retry again or notify user
  }
}
```

### Data Validation

```dart
void _handleAttitude(Map<String, dynamic> data) {
  // Kiểm tra dữ liệu hợp lệ
  if (data['roll'] != null && data['roll'].isFinite) {
    double roll = data['roll'];
    // Sử dụng dữ liệu roll
  }
}
```

### Timeout Handling

```dart
Timer? _parameterTimeout;

void requestParametersWithTimeout() {
  api.requestAllParameters();
  
  // Thiết lập timeout
  _parameterTimeout = Timer(Duration(seconds: 30), () {
    print('Parameter request timed out');
    // Handle timeout
  });
  
  // Hủy timeout khi nhận được tất cả tham số
  api.eventStream
    .where((event) => event.type == MAVLinkEventType.allParametersReceived)
    .listen((event) {
      _parameterTimeout?.cancel();
    });
}
```

---

## 🏆 Best Practices

### 1. Resource Management

```dart
@override
void dispose() {
  // Luôn gọi dispose khi không còn sử dụng
  api.dispose();
  super.dispose();
}
```

### 2. Event Filtering

```dart
// Sử dụng where() để lọc events cần thiết
api.eventStream
  .where((event) => event.type == MAVLinkEventType.attitude)
  .listen((event) {
    // Chỉ xử lý attitude events
  });
```

### 3. Connection State Management

```dart
// Luôn kiểm tra trạng thái kết nối trước khi gửi commands
if (api.isConnected) {
  api.sendArmCommand(true);
} else {
  print('Cannot send command: not connected');
}
```

### 4. Parameter Safety

```dart
// Kiểm tra tham số tồn tại trước khi sử dụng
double? armingCheck = api.parameters['ARMING_CHECK'];
if (armingCheck != null) {
  print('Arming check value: $armingCheck');
} else {
  print('Arming check parameter not available');
}
```

---

## 🔧 Troubleshooting

### Common Issues

1. **Connection Failed**
   - Kiểm tra cổng serial đúng
   - Kiểm tra baud rate
   - Đảm bảo không có ứng dụng khác đang sử dụng cổng

2. **No Data Received**
   - Kiểm tra kết nối vật lý
   - Đảm bảo drone đang phát MAVLink messages
   - Kiểm tra baud rate khớp với drone

3. **Parameter Request Timeout**
   - Drone có thể đang bận
   - Thử yêu cầu lại sau một khoảng thời gian
   - Kiểm tra kết nối ổn định

4. **Commands Not Working**
   - Đảm bảo drone ở trạng thái phù hợp
   - Kiểm tra system ID và component ID
   - Một số commands yêu cầu drone đã arm hoặc chưa arm

### Debug Tips

```dart
// Bật debug để xem tất cả events
api.eventStream.listen((event) {
  print('Event: ${event.type}, Data: ${event.data}');
});

// Kiểm tra trạng thái kết nối
print('Connected: ${api.isConnected}');
print('Available ports: ${api.getAvailablePorts()}');
```

---

## 📖 API Reference Summary

### Constructor

- `DroneMAVLinkAPI()`: Tạo instance mới

### Connection Methods

- `getAvailablePorts()`: Lấy danh sách cổng
- `connect(String port, {int? baudRate})`: Kết nối
- `disconnect()`: Ngắt kết nối

### Data Stream Methods

- `requestAllDataStreams()`: Yêu cầu tất cả luồng dữ liệu

### Parameter Methods

- `requestAllParameters()`: Yêu cầu tất cả tham số
- `requestParameter(String name)`: Yêu cầu tham số cụ thể
- `setParameter(String name, double value)`: Thiết lập tham số

### Command Methods

- `sendArmCommand(bool arm)`: Arm/disarm
- `setFlightMode(int mode)`: Thay đổi flight mode

### State Properties

- `isConnected`, `currentMode`, `isArmed`
- `roll`, `pitch`, `yaw`
- `airSpeed`, `groundSpeed`
- `altitudeMSL`, `altitudeRelative`
- `gpsFixType`, `satellites`
- `batteryPercent`
- `parameters`

### Cleanup

- `dispose()`: Giải phóng resources

## 📖 Detailed Documentation

Tài liệu được chia thành các module riêng biệt để dễ quản lý và tham khảo:

### Core Modules
- **[Event System](./docs/event-system.md)** - Hệ thống sự kiện và data structures
- **[Connection Management](./docs/connection-management.md)** - Quản lý kết nối serial
- **[Parameter Management](./docs/parameter-management.md)** - Đọc/ghi parameters
- **[Command Interface](./docs/command-interface.md)** - Gửi lệnh điều khiển
- **[Vehicle State](./docs/vehicle-state.md)** - Quản lý trạng thái drone

### Quick Reference
- **Event Types**: 10+ loại sự kiện khác nhau
- **Connection States**: 4 trạng thái kết nối
- **Commands**: Arm/disarm, flight modes, parameters
- **State Properties**: 20+ thuộc tính trạng thái real-time
- **Error Handling**: Comprehensive error management

## 🎯 UI Example & Testing

Tham khảo file `test/mavlink_ui_test.dart` để xem ví dụ đầy đủ về cách sử dụng API trong một ứng dụng Flutter thực tế.

### Chạy UI Test Dashboard

```bash
# Di chuyển vào thư mục dự án
cd vtol_fe

# Chạy ví dụ UI test
flutter run test/mavlink_ui_test.dart
```

### Tính năng của UI Test Dashboard

- **Connection Panel**: Chọn cổng COM và kết nối/ngắt kết nối
- **Vehicle Status**: Hiển thị flight mode, trạng thái armed, GPS, pin
- **Attitude Display**: Roll, Pitch, Yaw với giao diện trực quan
- **Position Info**: Vị trí GPS và độ cao
- **Control Panel**: Arm/Disarm, thay đổi flight mode
- **Parameter Management**: Xem và quản lý parameters
- **Status Messages**: Log real-time từ drone

### UI Test Features

```dart
// Kết nối và ngắt kết nối
await _api.connect(_selectedPort, baudRate: 115200);
_api.disconnect();

// Điều khiển drone
_api.sendArmCommand(true);  // Arm
_api.sendArmCommand(false); // Disarm
_api.setFlightMode(9);      // AUTO mode

// Request parameters
_api.requestAllParameters();

// Listen tất cả events
_api.eventStream.listen(_handleMAVLinkEvent);
```

## 🚨 Important Notes

1. **Thread Safety**: API sử dụng StreamController.broadcast() để đảm bảo thread-safe
2. **Resource Management**: Luôn gọi `dispose()` khi không sử dụng
3. **Error Handling**: Implement proper error handling cho production
4. **Performance**: Event stream có thể có tần suất cao, filter theo nhu cầu
5. **Rate Limiting**: Không gửi commands quá nhanh (khuyến nghị 100ms giữa các lệnh)

## 📝 License

MIT License - Xem file LICENSE để biết chi tiết.
