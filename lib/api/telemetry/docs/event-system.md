# Event System Documentation

## Overview

Hệ thống Event của MAVLink API được thiết kế theo pattern Observer, cho phép các component khác lắng nghe và phản ứng với các sự kiện từ drone một cách bất đồng bộ.

## Event Types

### MAVLinkEventType Enum

```dart
enum MAVLinkEventType {
  heartbeat,               // Heartbeat message từ drone
  attitude,                // Dữ liệu góc nghiêng (roll, pitch, yaw)
  position,                // Vị trí GPS và altitude
  statusText,              // Tin nhắn trạng thái từ drone
  batteryStatus,           // Thông tin pin và điện áp
  gpsInfo,                 // Thông tin GPS chi tiết
  vfrHud,                  // Dữ liệu VFR HUD (tốc độ, độ cao)
  parameterReceived,       // Một tham số đã được nhận
  allParametersReceived,   // Tất cả tham số đã được nhận
  connectionStateChanged,  // Thay đổi trạng thái kết nối
}
```

## Event Data Structures

### 1. Heartbeat Event

```dart
{
  'mode': String,              // Flight mode (e.g., "STABILIZE", "AUTO")
  'armed': bool,               // Trạng thái arm của drone
  'type': String,              // Loại drone (e.g., "Quadrotor", "VTOL")
  'autopilot': String,         // Loại autopilot (e.g., "ArduPilot", "PX4")
  'baseMode': int,             // Base mode flags
  'customMode': int,           // Custom mode number
  'systemStatus': String,      // System status (e.g., "Active", "Standby")
  'mavlinkVersion': int        // MAVLink protocol version
}
```

### 2. Attitude Event

```dart
{
  'roll': double,              // Góc roll (độ)
  'pitch': double,             // Góc pitch (độ)
  'yaw': double,               // Góc yaw (độ)
  'rollSpeed': double,         // Tốc độ roll (độ/giây)
  'pitchSpeed': double,        // Tốc độ pitch (độ/giây)
  'yawSpeed': double           // Tốc độ yaw (độ/giây)
}
```

### 3. Position Event

```dart
{
  'lat': double,               // Latitude (độ)
  'lon': double,               // Longitude (độ)
  'altMSL': double,            // Altitude MSL (mét)
  'altRelative': double,       // Altitude relative (mét)
  'vx': double,                // North velocity (m/s)
  'vy': double,                // East velocity (m/s)
  'vz': double,                // Down velocity (m/s)
  'heading': double,           // Heading (độ)
  'groundSpeed': double        // Ground speed (m/s)
}
```

### 4. GPS Info Event

```dart
{
  'fixType': String,           // GPS fix type ("No GPS", "3D Fix", "RTK Fixed", etc.)
  'satellites': int,           // Số vệ tinh nhìn thấy
  'lat': double,               // Latitude (độ)
  'lon': double,               // Longitude (độ)
  'alt': double,               // Altitude (mét)
  'eph': double,               // Horizontal accuracy (mét)
  'epv': double,               // Vertical accuracy (mét)
  'vel': double,               // Speed (m/s)
  'cog': double                // Course over ground (độ)
}
```

### 5. Battery Status Event

```dart
{
  'batteryPercent': int,       // Phần trăm pin còn lại
  'voltageBattery': double,    // Điện áp pin (volts)
  'currentBattery': double,    // Dòng điện (amps)
  'cpuLoad': double,           // CPU load (%)
  'commDropRate': int,         // Communication drop rate
  'errorsComm': int,           // Communication errors
  'sensorHealth': int          // Sensor health flags
}
```

### 6. VFR HUD Event

```dart
{
  'airspeed': double,          // Airspeed (m/s)
  'groundspeed': double,       // Groundspeed (m/s)
  'heading': int,              // Heading (độ)
  'throttle': int,             // Throttle (%)
  'alt': double,               // Altitude (mét)
  'climb': double              // Climb rate (m/s)
}
```

### 7. Status Text Event

```dart
{
  'severity': String,          // Severity level ("Info", "Warning", "Error", etc.)
  'text': String               // Status message text
}
```

### 8. Parameter Events

```dart
// Parameter Received Event
{
  'id': String,                // Parameter name
  'value': double,             // Parameter value
  'type': String,              // Parameter type
  'index': int,                // Parameter index
  'count': int                 // Total parameter count
}

// All Parameters Received Event
Map<String, double>            // Map of all parameters
```

### 9. Connection State Changed Event

```dart
MAVLinkConnectionState enum:
- disconnected
- connected
- connecting
- error
```

## Usage Examples

### Basic Event Listening

```dart
class DroneEventHandler {
  late StreamSubscription _subscription;
  
  void startListening(DroneMAVLinkAPI api) {
    _subscription = api.eventStream.listen(_handleEvent);
  }
  
  void _handleEvent(MAVLinkEvent event) {
    print('Event: ${event.type} at ${event.timestamp}');
    print('Data: ${event.data}');
  }
  
  void stopListening() {
    _subscription.cancel();
  }
}
```

### Filtered Event Listening

```dart
class AttitudeMonitor {
  late StreamSubscription _attitudeSubscription;
  
  void startMonitoring(DroneMAVLinkAPI api) {
    // Chỉ lắng nghe attitude events
    _attitudeSubscription = api.eventStream
      .where((event) => event.type == MAVLinkEventType.attitude)
      .listen(_handleAttitude);
  }
  
  void _handleAttitude(MAVLinkEvent event) {
    final data = event.data;
    double roll = data['roll'];
    double pitch = data['pitch'];
    double yaw = data['yaw'];
    
    print('Attitude: R=${roll.toStringAsFixed(1)}° '
          'P=${pitch.toStringAsFixed(1)}° '
          'Y=${yaw.toStringAsFixed(1)}°');
  }
}
```

### Multiple Event Types

```dart
class DroneDataLogger {
  late StreamSubscription _subscription;
  List<String> _logs = [];
  
  void startLogging(DroneMAVLinkAPI api) {
    _subscription = api.eventStream
      .where((event) => [
        MAVLinkEventType.attitude,
        MAVLinkEventType.position,
        MAVLinkEventType.gpsInfo,
        MAVLinkEventType.batteryStatus
      ].contains(event.type))
      .listen(_logEvent);
  }
  
  void _logEvent(MAVLinkEvent event) {
    String logEntry = '${event.timestamp}: ${event.type} - ${event.data}';
    _logs.add(logEntry);
    
    // Save to file periodically
    if (_logs.length % 100 == 0) {
      _saveLogsToFile();
    }
  }
  
  void _saveLogsToFile() {
    // Implementation for saving logs
  }
}
```

### Event-Driven UI Updates

```dart
class DroneStatusWidget extends StatefulWidget {
  final DroneMAVLinkAPI api;
  
  const DroneStatusWidget({required this.api});
  
  @override
  _DroneStatusWidgetState createState() => _DroneStatusWidgetState();
}

class _DroneStatusWidgetState extends State<DroneStatusWidget> {
  late StreamSubscription _subscription;
  
  String _connectionStatus = 'Disconnected';
  String _flightMode = 'Unknown';
  bool _isArmed = false;
  int _batteryPercent = 0;
  
  @override
  void initState() {
    super.initState();
    _subscription = widget.api.eventStream.listen(_updateUI);
  }
  
  void _updateUI(MAVLinkEvent event) {
    if (!mounted) return;
    
    setState(() {
      switch (event.type) {
        case MAVLinkEventType.connectionStateChanged:
          _connectionStatus = event.data.toString();
          break;
        case MAVLinkEventType.heartbeat:
          _flightMode = event.data['mode'];
          _isArmed = event.data['armed'];
          break;
        case MAVLinkEventType.batteryStatus:
          _batteryPercent = event.data['batteryPercent'];
          break;
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Status: $_connectionStatus'),
        Text('Mode: $_flightMode'),
        Text('Armed: $_isArmed'),
        Text('Battery: $_batteryPercent%'),
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

## Best Practices

### 1. Memory Management

```dart
class EventHandler {
  StreamSubscription? _subscription;
  
  void startListening(DroneMAVLinkAPI api) {
    // Cancel existing subscription before creating new one
    _subscription?.cancel();
    _subscription = api.eventStream.listen(_handleEvent);
  }
  
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
```

### 2. Error Handling

```dart
void _handleEvent(MAVLinkEvent event) {
  try {
    switch (event.type) {
      case MAVLinkEventType.attitude:
        _processAttitude(event.data);
        break;
      // ... other cases
    }
  } catch (e) {
    print('Error handling event ${event.type}: $e');
  }
}

void _processAttitude(Map<String, dynamic> data) {
  // Validate data before using
  if (data['roll'] != null && data['roll'] is double) {
    double roll = data['roll'];
    // Use roll value safely
  }
}
```

### 3. Event Filtering and Throttling

```dart
class ThrottledEventHandler {
  late StreamSubscription _subscription;
  
  void startListening(DroneMAVLinkAPI api) {
    _subscription = api.eventStream
      .where((event) => event.type == MAVLinkEventType.attitude)
      .distinct((prev, next) => 
        // Only process if roll/pitch changed significantly
        (prev.data['roll'] - next.data['roll']).abs() < 0.1 &&
        (prev.data['pitch'] - next.data['pitch']).abs() < 0.1)
      .listen(_handleAttitude);
  }
}
```

### 4. Event Buffering

```dart
class BufferedEventHandler {
  final List<MAVLinkEvent> _eventBuffer = [];
  Timer? _processTimer;
  
  void startListening(DroneMAVLinkAPI api) {
    api.eventStream.listen(_bufferEvent);
    
    // Process buffered events every 100ms
    _processTimer = Timer.periodic(
      Duration(milliseconds: 100),
      (_) => _processBufferedEvents()
    );
  }
  
  void _bufferEvent(MAVLinkEvent event) {
    _eventBuffer.add(event);
    
    // Limit buffer size
    if (_eventBuffer.length > 1000) {
      _eventBuffer.removeAt(0);
    }
  }
  
  void _processBufferedEvents() {
    if (_eventBuffer.isEmpty) return;
    
    // Process all buffered events
    for (var event in _eventBuffer) {
      _processEvent(event);
    }
    _eventBuffer.clear();
  }
  
  void dispose() {
    _processTimer?.cancel();
  }
}
```

## Advanced Usage

### Custom Event Filters

```dart
extension MAVLinkEventFilters on Stream<MAVLinkEvent> {
  Stream<MAVLinkEvent> onlyWhenConnected(DroneMAVLinkAPI api) {
    return where((_) => api.isConnected);
  }
  
  Stream<MAVLinkEvent> onlyWhenArmed(DroneMAVLinkAPI api) {
    return where((_) => api.isArmed);
  }
  
  Stream<MAVLinkEvent> batteryLevelChanges() {
    return where((event) => event.type == MAVLinkEventType.batteryStatus)
           .distinct((prev, next) => 
             prev.data['batteryPercent'] == next.data['batteryPercent']);
  }
}

// Usage
api.eventStream
  .onlyWhenConnected(api)
  .onlyWhenArmed(api)
  .batteryLevelChanges()
  .listen((event) {
    print('Battery level changed while connected and armed: ${event.data}');
  });
```

### Event Composition

```dart
class CompositeEventHandler {
  late StreamSubscription _subscription;
  
  void startListening(DroneMAVLinkAPI api) {
    // Combine multiple event streams
    final attitudeStream = api.eventStream
      .where((event) => event.type == MAVLinkEventType.attitude);
    
    final positionStream = api.eventStream
      .where((event) => event.type == MAVLinkEventType.position);
    
    // Merge streams and listen
    _subscription = Rx.merge([attitudeStream, positionStream])
      .listen(_handleNavigationData);
  }
  
  void _handleNavigationData(MAVLinkEvent event) {
    // Handle combined attitude and position data
  }
}
```
