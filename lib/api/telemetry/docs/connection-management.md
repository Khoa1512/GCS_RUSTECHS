# Connection Management Documentation

## Overview

Connection Management module chịu trách nhiệm quản lý kết nối serial giữa ground station và drone, bao gồm việc khởi tạo, duy trì, và đóng kết nối.

## Connection States

### MAVLinkConnectionState Enum

```dart
enum MAVLinkConnectionState {
  disconnected,    // Không có kết nối
  connecting,      // Đang thực hiện kết nối
  connected,       // Kết nối thành công
  error,          // Có lỗi xảy ra
}
```

## Core Methods

### 1. Port Discovery

Hệ thống Flutter có thể liệt kê cổng qua thư viện flutter_libserialport nếu bạn cần tự triển khai. API hiện tại không cung cấp wrapper `getAvailablePorts()`.

### 2. Connection Establishment

#### `Future<void> connect(String port, {int? baudRate})`

Khởi tạo kết nối tới drone qua cổng serial được chỉ định.

```dart
await api.connect('COM3', baudRate: 115200);
```

**Parameters:**

- `port`: Tên cổng serial (required)
- `baudRate`: Tốc độ baud (optional, default: 115200)

**Returns:**

- `Future<void>`

**Connection Process:**

1. Configure serial port settings (baud, bits, parity, stop bits)
2. Open serial connection
3. Start reading stream and feed parser
4. Emit connection state change event

### 3. Connection Termination

#### `void disconnect()`

Đóng kết nối hiện tại và dọn dẹp resources.

```dart
api.disconnect();
print('Disconnected from drone');
```

**Process:**

1. Cancel data reader subscription
2. Close serial port
3. Emit disconnection event

## Connection Configuration

### Serial Port Settings

Khi kết nối, API cấu hình serial như sau (tự động): 115200 (mặc định), 8N1.

## Connection Monitoring

### 1. Connection State Events

```dart
api.eventStream
  .where((event) => event.type == MAVLinkEventType.connectionStateChanged)
  .listen((event) {
    MAVLinkConnectionState state = event.data;
    
    switch (state) {
      case MAVLinkConnectionState.connecting:
        print('Connecting to drone...');
        break;
      case MAVLinkConnectionState.connected:
        print('Connected to drone');
        _onConnected();
        break;
      case MAVLinkConnectionState.disconnected:
        print('Disconnected from drone');
        _onDisconnected();
        break;
      case MAVLinkConnectionState.error:
        print('Connection error');
        _onConnectionError();
        break;
    }
  });
```

### 2. Connection Status Check

```dart
// Check if currently connected
bool isConnected = api.isConnected;

// Get connection state in real-time
String status = api.isConnected ? 'Connected' : 'Disconnected';
print('Current status: $status');
```

## Error Handling

### Common Connection Errors

1. **Port Not Available**

```dart
Future<bool> connectWithValidation(String port) async {
  List<String> availablePorts = api.getAvailablePorts();
  
  if (!availablePorts.contains(port)) {
    print('Error: Port $port is not available');
    print('Available ports: $availablePorts');
    return false;
  }
  
  return await api.connect(port);
}
```

1. **Port Already in Use**

```dart
Future<bool> connectWithRetry(String port, {int maxRetries = 3}) async {
  for (int i = 0; i < maxRetries; i++) {
    bool success = await api.connect(port);
    if (success) return true;
    
    print('Connection attempt ${i + 1} failed, retrying...');
    await Future.delayed(Duration(seconds: 2));
  }
  
  print('Failed to connect after $maxRetries attempts');
  return false;
}
```

1. **Connection Timeout**

```dart
Future<bool> connectWithTimeout(String port, {Duration timeout = const Duration(seconds: 10)}) async {
  Completer<bool> completer = Completer<bool>();
  
  // Start connection
  api.connect(port).then((success) {
    if (!completer.isCompleted) {
      completer.complete(success);
    }
  });
  
  // Set timeout
  Timer(timeout, () {
    if (!completer.isCompleted) {
      api.disconnect();
      completer.complete(false);
    }
  });
  
  return completer.future;
}
```

## Advanced Connection Management

### 1. Auto-Reconnection

```dart
class AutoReconnectManager {
  final DroneMAVLinkAPI api;
  Timer? _reconnectTimer;
  String? _lastPort;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  
  AutoReconnectManager(this.api) {
    _setupConnectionMonitoring();
  }
  
  void _setupConnectionMonitoring() {
    api.eventStream
      .where((event) => event.type == MAVLinkEventType.connectionStateChanged)
      .listen((event) {
        MAVLinkConnectionState state = event.data;
        
        if (state == MAVLinkConnectionState.disconnected && _lastPort != null) {
          _startReconnection();
        } else if (state == MAVLinkConnectionState.connected) {
          _reconnectAttempts = 0;
          _reconnectTimer?.cancel();
        }
      });
  }
  
  Future<bool> connect(String port) async {
    _lastPort = port;
    _reconnectAttempts = 0;
    return await api.connect(port);
  }
  
  void _startReconnection() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      print('Max reconnection attempts reached');
      return;
    }
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: 5), () async {
      _reconnectAttempts++;
      print('Reconnection attempt $_reconnectAttempts/$maxReconnectAttempts');
      
      bool success = await api.connect(_lastPort!);
      if (!success) {
        _startReconnection();
      }
    });
  }
  
  void dispose() {
    _reconnectTimer?.cancel();
  }
}
```

### 2. Connection Health Monitoring

```dart
class ConnectionHealthMonitor {
  final DroneMAVLinkAPI api;
  DateTime? _lastHeartbeat;
  Timer? _healthCheckTimer;
  
  ConnectionHealthMonitor(this.api) {
    _setupHealthMonitoring();
  }
  
  void _setupHealthMonitoring() {
    // Monitor heartbeat messages
    api.eventStream
      .where((event) => event.type == MAVLinkEventType.heartbeat)
      .listen((event) {
        _lastHeartbeat = DateTime.now();
      });
    
    // Check connection health every 5 seconds
    _healthCheckTimer = Timer.periodic(Duration(seconds: 5), (_) {
      _checkConnectionHealth();
    });
  }
  
  void _checkConnectionHealth() {
    if (!api.isConnected) return;
    
    if (_lastHeartbeat == null) {
      print('Warning: No heartbeat received yet');
      return;
    }
    
    Duration timeSinceLastHeartbeat = DateTime.now().difference(_lastHeartbeat!);
    
    if (timeSinceLastHeartbeat.inSeconds > 10) {
      print('Warning: No heartbeat for ${timeSinceLastHeartbeat.inSeconds} seconds');
      print('Connection may be unstable');
    }
  }
  
  bool get isHealthy {
    if (!api.isConnected || _lastHeartbeat == null) return false;
    
    Duration timeSinceLastHeartbeat = DateTime.now().difference(_lastHeartbeat!);
    return timeSinceLastHeartbeat.inSeconds < 10;
  }
  
  void dispose() {
    _healthCheckTimer?.cancel();
  }
}
```

### 3. Multi-Port Connection Manager

```dart
class MultiPortConnectionManager {
  final DroneMAVLinkAPI api;
  List<String> _preferredPorts = [];
  
  MultiPortConnectionManager(this.api);
  
  void setPreferredPorts(List<String> ports) {
    _preferredPorts = ports;
  }
  
  Future<bool> connectToAnyAvailable() async {
    List<String> availablePorts = api.getAvailablePorts();
    
    // Try preferred ports first
    for (String port in _preferredPorts) {
      if (availablePorts.contains(port)) {
        print('Trying preferred port: $port');
        bool success = await api.connect(port);
        if (success) {
          print('Connected to preferred port: $port');
          return true;
        }
      }
    }
    
    // Try any other available ports
    for (String port in availablePorts) {
      if (!_preferredPorts.contains(port)) {
        print('Trying port: $port');
        bool success = await api.connect(port);
        if (success) {
          print('Connected to port: $port');
          return true;
        }
      }
    }
    
    print('Failed to connect to any available port');
    return false;
  }
  
  Future<List<String>> scanForDroneConnections() async {
    List<String> droneConnections = [];
    List<String> availablePorts = api.getAvailablePorts();
    
    for (String port in availablePorts) {
      print('Scanning port: $port');
      
      bool connected = await api.connect(port);
      if (connected) {
        // Wait for heartbeat to confirm it's a drone
        bool isHeartbeatReceived = await _waitForHeartbeat();
        
        if (isHeartbeatReceived) {
          droneConnections.add(port);
          print('Drone found on port: $port');
        }
        
        api.disconnect();
        await Future.delayed(Duration(milliseconds: 500));
      }
    }
    
    return droneConnections;
  }
  
  Future<bool> _waitForHeartbeat({Duration timeout = const Duration(seconds: 5)}) async {
    Completer<bool> completer = Completer<bool>();
    late StreamSubscription subscription;
    
    subscription = api.eventStream
      .where((event) => event.type == MAVLinkEventType.heartbeat)
      .listen((event) {
        if (!completer.isCompleted) {
          completer.complete(true);
          subscription.cancel();
        }
      });
    
    Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(false);
        subscription.cancel();
      }
    });
    
    return completer.future;
  }
}
```

## Usage Examples

### Basic Connection

```dart
class SimpleConnectionExample {
  final DroneMAVLinkAPI api = DroneMAVLinkAPI();
  
  Future<void> connectToDrone() async {
    // Get available ports
    List<String> ports = api.getAvailablePorts();
    if (ports.isEmpty) {
      print('No serial ports available');
      return;
    }
    
    // Try to connect to first available port
    String port = ports.first;
    print('Connecting to $port...');
    
    bool success = await api.connect(port, baudRate: 115200);
    if (success) {
      print('Connected successfully');
    } else {
      print('Connection failed');
    }
  }
}
```

### Advanced Connection with Monitoring

```dart
class AdvancedConnectionExample {
  final DroneMAVLinkAPI api = DroneMAVLinkAPI();
  late AutoReconnectManager reconnectManager;
  late ConnectionHealthMonitor healthMonitor;
  late StreamSubscription connectionSubscription;
  
  void initialize() {
    reconnectManager = AutoReconnectManager(api);
    healthMonitor = ConnectionHealthMonitor(api);
    
    connectionSubscription = api.eventStream
      .where((event) => event.type == MAVLinkEventType.connectionStateChanged)
      .listen(_handleConnectionStateChange);
  }
  
  void _handleConnectionStateChange(MAVLinkEvent event) {
    MAVLinkConnectionState state = event.data;
    print('Connection state changed: $state');
    
    // Update UI or perform actions based on connection state
  }
  
  Future<void> connectWithAutoReconnect(String port) async {
    bool success = await reconnectManager.connect(port);
    if (success) {
      print('Connected with auto-reconnect enabled');
    } else {
      print('Initial connection failed');
    }
  }
  
  void dispose() {
    connectionSubscription.cancel();
    reconnectManager.dispose();
    healthMonitor.dispose();
    api.dispose();
  }
}
```

## Best Practices

### 1. Always Check Port Availability

```dart
Future<bool> safeConnect(String port) async {
  List<String> availablePorts = api.getAvailablePorts();
  
  if (!availablePorts.contains(port)) {
    print('Port $port is not available');
    return false;
  }
  
  return await api.connect(port);
}
```

### 2. Handle Connection State Changes

```dart
void setupConnectionStateHandling() {
  api.eventStream
    .where((event) => event.type == MAVLinkEventType.connectionStateChanged)
    .listen((event) {
      switch (event.data) {
        case MAVLinkConnectionState.connected:
          // Enable UI controls, start telemetry display
          break;
        case MAVLinkConnectionState.disconnected:
          // Disable UI controls, show disconnected status
          break;
        case MAVLinkConnectionState.error:
          // Show error message, attempt reconnection
          break;
      }
    });
}
```

### 3. Proper Resource Cleanup

```dart
@override
void dispose() {
  api.disconnect();  // Always disconnect before disposing
  api.dispose();     // Clean up all resources
  super.dispose();
}
```

### 4. Connection Timeout Implementation

```dart
Future<bool> connectWithTimeout(String port, 
    {Duration timeout = const Duration(seconds: 10)}) async {
  
  return await Future.any([
    api.connect(port),
    Future.delayed(timeout, () => false)
  ]);
}
```
