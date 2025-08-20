# MAVLink API (Modular) Documentation

<!-- markdownlint-disable MD051 -->

`DroneMAVLinkAPI` là API chính để giao tiếp MAVLink qua serial. Kể từ bản này, API đã được refactor theo kiến trúc module:

- Barrel export: `mavlink_api.dart` tiếp tục export các module bên trong để tương thích import cũ.
- Sự kiện tách theo EventType, mỗi loại có handler riêng trong `mavlink/handlers/*`.
- Core routing/serial/parse nằm ở `mavlink/mavlink_core.dart`.

## 📋 Mục lục

1. [Cấu trúc API](#cau-truc-api)
2. [Event System](#event-system-modular)
3. [Connection Management](#connection-management-mavlink_coredart)
4. [Data Streams](#data-streams-mavlink_coredart)
5. [Parameter Management](#parameter-management-mavlink_coredart--handlersparams_handlerdart)
6. [Command Sending](#command-sending-mavlink_coredart)
7. [Vehicle State](#vehicle-state-exposed-via-events-stateful-props-optional)
8. [Usage Examples](#usage-examples)
9. [UI Example & Testing](#ui-example--testing)
10. [Error Handling](#error-handling)

## 🚀 Quick Start

```dart
import 'package:vtol_fe/api/telemetry/mavlink_api.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

// Tạo instance API
final api = DroneMAVLinkAPI();

// Liệt kê cổng serial (API không cung cấp getAvailablePorts)
final ports = SerialPort.availablePorts;
print('Available ports: $ports');

// Kết nối (trả về Future<void>)
await api.connect('COM3', baudRate: 115200);

// Xác nhận trạng thái kết nối
if (!api.isConnected) {
  print('Failed to connect');
  return;
}

// (Tùy chọn) yêu cầu các data streams/parameters sau khi kết nối
api.requestAllDataStreams();
api.requestAllParameters();

// Lắng nghe events
final sub = api.eventStream.listen((event) {
  switch (event.type) {
    case MAVLinkEventType.attitude:
      print('Roll: ${event.data['roll']}°');
      break;
    case MAVLinkEventType.gpsInfo:
      print('GPS: ${event.data['fixType']}, Sats: ${event.data['satellites']}');
      break;
    default:
      break;
  }
});

// Dọn dẹp
sub.cancel();
api.dispose();
```

## 🏗️ Cấu trúc API

### Class Hierarchy

```text
DroneMAVLinkAPI
├── Connection Management
├── Event System
├── Data Streams
├── Parameter Management
├── Command Interface
└── Vehicle State
```

### Core Components (Modules)

#### 1. MAVLink Event System (mavlink/events.dart)

- **MAVLinkEventType**: Enum định nghĩa các loại sự kiện
- **MAVLinkEvent**: Class đại diện cho một sự kiện MAVLink
- **`Stream<MAVLinkEvent>`**: Stream để lắng nghe các sự kiện

#### 2. Connection State Management (mavlink/mavlink_core.dart)

- **MAVLinkConnectionState**: Enum trạng thái kết nối
- **Serial Port Management**: Quản lý kết nối serial
- **Auto-reconnection**: Tự động kết nối lại khi mất kết nối

---

## 🎯 Event System (modular)

### Event Types (mavlink/events.dart)

```dart
enum MAVLinkEventType {
  heartbeat,              // Heartbeat từ drone
  attitude,               // Dữ liệu góc nghiêng (roll, pitch, yaw)
  position,               // Vị trí GPS và altitude
  statusText,             // Tin nhắn trạng thái từ drone
  batteryStatus,          // Thông tin pin
  gpsInfo,                // Thông tin GPS chi tiết
  vfrHud,                 // Dữ liệu VFR HUD (tốc độ, độ cao)
  parameterReceived,      // Tham số nhận được
  allParametersReceived,  // Tất cả tham số đã nhận
  sysStatus,              // SysStatus (raw)
  commandAck,             // Command ACK (raw)
  connectionStateChanged, // Thay đổi trạng thái kết nối
}
```

### Event Data Structure (mapped in handlers)

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

## 🔌 Connection Management (mavlink_core.dart)

### Available Methods

#### `Future<void> connect(String port, {int? baudRate})`

Kết nối tới cổng serial được chỉ định. Sau khi `await`, hãy kiểm tra `api.isConnected` hoặc lắng nghe event `connectionStateChanged` để xác nhận.

```dart
await api.connect('COM3', baudRate: 57600);
if (api.isConnected) {
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

## 📡 Data Streams (mavlink_core.dart)

### Stream Types

Có thể yêu cầu các luồng dữ liệu tiêu chuẩn sau khi kết nối:

- **MAV_DATA_STREAM_ALL**: Tất cả dữ liệu (4Hz)
- **MAV_DATA_STREAM_EXTRA1**: Dữ liệu attitude (10Hz)
- **MAV_DATA_STREAM_EXTRA2**: Dữ liệu VFR HUD (5Hz)
- **MAV_DATA_STREAM_POSITION**: Dữ liệu vị trí (3Hz)
- **MAV_DATA_STREAM_EXTENDED_STATUS**: Trạng thái mở rộng (2Hz)

### Stream Request

```dart
// Yêu cầu tất cả luồng dữ liệu
api.requestAllDataStreams();
```

---

## ⚙️ Parameter Management (mavlink_core.dart + handlers/params_handler.dart)

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

## 🎮 Command Sending (mavlink_core.dart)

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

## 📊 Vehicle State (consume via events)

Thay vì gọi các getter đồng bộ, hãy lắng nghe `eventStream` và (tuỳ chọn) xây dựng một service để cache trạng thái.

Ví dụ service tối giản cache dữ liệu:

```dart
class TelemetryCache {
  final DroneMAVLinkAPI api;
  final Map<String, double> data = {};
  String mode = 'Unknown';
  bool armed = false;
  late final StreamSubscription sub;

  TelemetryCache(this.api) {
    sub = api.eventStream.listen((e) {
      switch (e.type) {
        case MAVLinkEventType.heartbeat:
          mode = e.data['mode'];
          armed = e.data['armed'];
          break;
        case MAVLinkEventType.attitude:
          data['roll'] = (e.data['roll'] as num?)?.toDouble() ?? 0;
          data['pitch'] = (e.data['pitch'] as num?)?.toDouble() ?? 0;
          data['yaw'] = (e.data['yaw'] as num?)?.toDouble() ?? 0;
          break;
        case MAVLinkEventType.vfrHud:
          data['groundspeed'] = (e.data['groundspeed'] as num?)?.toDouble() ?? 0;
          data['alt'] = (e.data['alt'] as num?)?.toDouble() ?? 0;
          break;
        default:
          break;
      }
    });
  }

  void dispose() => sub.cancel();
}
```

---

## 🧭 Mission Protocol (quick start)

DroneMAVLinkAPI hỗ trợ MAVLink Mission Protocol đầy đủ (download, upload, clear, set-current) và tương thích cả MISSION_ITEM_INT lẫn legacy MISSION_ITEM.

### API chính

- Download danh sách mission (sequential):
  - `requestMissionList()` để nhận `missionCount`
  - Sau đó gọi tuần tự `requestMissionItem(seq)` cho từng `seq = 0..count-1`
- Upload mission:
  - Chuẩn bị `List<PlanMissionItem>` (xem MissionPlan)
  - Gọi `startMissionUpload(items)`; autopilot sẽ yêu cầu từng item và API tự trả lời
- Khác:
  - `clearMission()` xóa toàn bộ mission trên vehicle
  - `setCurrentMissionItem(seq)` đặt current waypoint
  - `requestHomePosition()` yêu cầu EKF Home (HOME_POSITION/GPS_GLOBAL_ORIGIN)

### Sự kiện liên quan (eventStream)

- `missionCount` (int): tổng số items
- `missionItem` (PlanMissionItem): item nhận được (INT hoặc legacy)
- `missionDownloadProgress` ({received,total}) và `missionDownloadComplete`
- `missionUploadProgress` ({sent,total}) và `missionUploadComplete`
- `missionCurrent` ({seq,total,missionMode}) và `missionItemReached` (seq)
- `missionAck` (type) và `missionCleared`
- `homePosition` ({lat,lon,alt,source})

### Ví dụ: Download mission hiện tại (sequential)

```dart
final api = DroneMAVLinkAPI();
int _total = 0;
int _next = 0;
final List<PlanMissionItem> items = [];

final sub = api.eventStream.listen((e) {
  switch (e.type) {
    case MAVLinkEventType.missionCount:
      _total = e.data as int;
      items.clear();
      _next = 0;
      if (_total > 0) api.requestMissionItem(_next++);
      break;
    case MAVLinkEventType.missionItem:
      final it = e.data as PlanMissionItem;
      while (items.length <= it.seq) {
        items.add(PlanMissionItem(seq: items.length, command: 0, frame: 0));
      }
      items[it.seq] = it;
      if (_next < _total) api.requestMissionItem(_next++);
      break;
    case MAVLinkEventType.missionDownloadComplete:
      print('Downloaded ${items.length} items');
      break;
    default:
      break;
  }
});

api.requestMissionList();
```

### Ví dụ: Upload mission từ QGC .plan hoặc QGC WPL 110

```dart
import 'package:vtol_fe/api/telemetry/mavlink_api.dart';

Future<void> uploadFromText(DroneMAVLinkAPI api, String text) async {
  MissionPlan plan;
  if (text.trim().startsWith('{')) {
    plan = MissionPlan.fromQgcPlanJson(text);
  } else {
    plan = MissionPlan.fromArduPilotWaypoints(text);
  }
  api.startMissionUpload(plan.items);
}
```

#### Ghi chú

- Xuất .plan sẽ tự suy luận `plannedHomePosition` từ item đầu nếu là toạ độ toàn cục hợp lệ.
- Khi autopilot yêu cầu legacy MISSION_ITEM, API sẽ tự động phản hồi dạng float để tương thích.

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
    await api.connect(port);
    if (!api.isConnected) {
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
  await api.connect(_lastPort);
  if (!api.isConnected) {
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
print('Available ports: ${SerialPort.availablePorts}');
```

---

## 📖 API Reference Summary

### Constructor

- `DroneMAVLinkAPI()`: Tạo instance mới

### Connection Methods

- `connect(String port, {int? baudRate})`: Kết nối (trả về `Future<void>`)
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

### State Access

- Trạng thái nên được lấy từ `eventStream` (xem các module docs). `isConnected` là thuộc tính tiện lợi; các dữ liệu còn lại nhận qua events hoặc service cache.

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
- **[Mission Protocol](./docs/mission-protocol.md)** - Quy trình download/upload/clear/current và các sự kiện liên quan
- **[Mission File Formats](./docs/mission-file-formats.md)** - QGC .plan và QGC WPL 110 (import/export, mapping trường)

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
