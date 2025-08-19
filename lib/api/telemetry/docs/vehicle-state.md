# Vehicle State Management Documentation

## Overview

Vehicle State Management module cung cấp khả năng theo dõi và truy cập thông tin trạng thái real-time của drone, bao gồm attitude, position, GPS, battery và các thông tin khác.

## State Categories

### 1. Connection State

```dart
// Connection status (tiện lợi)
bool isConnected = api.isConnected;

// Hoặc lắng nghe thay đổi:
api.eventStream
  .where((e) => e.type == MAVLinkEventType.connectionStateChanged)
  .listen((e) => print('State: ${e.data}'));
```

### 2. Flight Status

Sử dụng events để lấy mode/armed và các thông tin khác; nếu cần getter đồng bộ, hãy xây service cache.

```dart
String mode = 'Unknown';
bool armed = false;

final sub = api.eventStream
  .where((e) => e.type == MAVLinkEventType.heartbeat)
  .listen((e) {
    mode = e.data['mode'];
    armed = e.data['armed'];
  });
```

### 3. Attitude Data

```dart
double roll = 0, pitch = 0, yaw = 0;
api.eventStream
  .where((e) => e.type == MAVLinkEventType.attitude)
  .listen((e) {
    roll = (e.data['roll'] as num).toDouble();
    pitch = (e.data['pitch'] as num).toDouble();
    yaw = (e.data['yaw'] as num).toDouble();
  });
```

### 4. Speed Data

```dart
double groundSpeed = 0;
api.eventStream
  .where((e) => e.type == MAVLinkEventType.vfrHud)
  .listen((e) => groundSpeed = (e.data['groundspeed'] as num).toDouble());
```

### 5. Altitude Data

```dart
double altMSL = 0, altRelative = 0;
api.eventStream
  .where((e) => e.type == MAVLinkEventType.position)
  .listen((e) {
    altMSL = (e.data['altMSL'] as num?)?.toDouble() ?? 0;
    altRelative = (e.data['altRelative'] as num?)?.toDouble() ?? 0;
  });
```

### 6. GPS Data

```dart
String gpsFixType = 'No GPS';
int satellites = 0;
api.eventStream
  .where((e) => e.type == MAVLinkEventType.gpsInfo)
  .listen((e) {
    gpsFixType = e.data['fixType'];
    satellites = e.data['satellites'];
  });
```

### 7. Battery Data

```dart
int batteryPercent = 0;
api.eventStream
  .where((e) => e.type == MAVLinkEventType.batteryStatus)
  .listen((e) => batteryPercent = e.data['batteryPercent'] as int);
```

### 8. Parameters

```dart
// Parameters (Map cache trong API)
final Map<String, double> parameters = api.parameters;
```

## State Monitoring Classes

### 1. Vehicle State Monitor

```dart
class VehicleStateMonitor {
  final DroneMAVLinkAPI api;
  final StreamController<VehicleState> _stateController = 
      StreamController<VehicleState>.broadcast();
  
  late StreamSubscription _eventSubscription;
  VehicleState _currentState = VehicleState();
  
  Stream<VehicleState> get stateStream => _stateController.stream;
  VehicleState get currentState => _currentState;
  
  VehicleStateMonitor(this.api) {
    _setupStateMonitoring();
  }
  
  void _setupStateMonitoring() {
    _eventSubscription = api.eventStream.listen(_updateState);
  }
  
  void _updateState(MAVLinkEvent event) {
    bool stateChanged = false;
    
    switch (event.type) {
      case MAVLinkEventType.heartbeat:
        if (_currentState.flightMode != event.data['mode'] ||
            _currentState.isArmed != event.data['armed']) {
          _currentState = _currentState.copyWith(
            flightMode: event.data['mode'],
            isArmed: event.data['armed'],
          );
          stateChanged = true;
        }
        break;
        
      case MAVLinkEventType.attitude:
        _currentState = _currentState.copyWith(
          roll: event.data['roll'],
          pitch: event.data['pitch'],
          yaw: event.data['yaw'],
        );
        stateChanged = true;
        break;
        
      case MAVLinkEventType.position:
        _currentState = _currentState.copyWith(
          latitude: event.data['lat'],
          longitude: event.data['lon'],
          altitudeMSL: event.data['altMSL'],
          altitudeRelative: event.data['altRelative'],
          groundSpeed: event.data['groundSpeed'],
        );
        stateChanged = true;
        break;
        
      case MAVLinkEventType.gpsInfo:
        _currentState = _currentState.copyWith(
          gpsFixType: event.data['fixType'],
          satelliteCount: event.data['satellites'],
        );
        stateChanged = true;
        break;
        
      case MAVLinkEventType.batteryStatus:
        _currentState = _currentState.copyWith(
          batteryPercent: event.data['batteryPercent'],
          batteryVoltage: event.data['voltageBattery'],
        );
        stateChanged = true;
        break;
        
      case MAVLinkEventType.vfrHud:
        _currentState = _currentState.copyWith(
          airspeed: event.data['airspeed'],
          groundSpeed: event.data['groundspeed'],
          throttle: event.data['throttle'],
          climbRate: event.data['climb'],
        );
        stateChanged = true;
        break;
    }
    
    if (stateChanged) {
      _currentState = _currentState.copyWith(
        lastUpdated: DateTime.now(),
      );
      _stateController.add(_currentState);
    }
  }
  
  void dispose() {
    _eventSubscription.cancel();
    _stateController.close();
  }
}
```

### 2. Vehicle State Data Class

```dart
class VehicleState {
  // Connection
  final bool isConnected;
  
  // Flight status
  final String flightMode;
  final bool isArmed;
  final int currentWaypoint;
  final int totalWaypoints;
  
  // Position
  final double? latitude;
  final double? longitude;
  final double? altitudeMSL;
  final double? altitudeRelative;
  
  // Attitude
  final double? roll;
  final double? pitch;
  final double? yaw;
  
  // Speed
  final double? airspeed;
  final double? groundSpeed;
  final double? climbRate;
  
  // GPS
  final String gpsFixType;
  final int satelliteCount;
  
  // Battery
  final int batteryPercent;
  final double? batteryVoltage;
  
  // System
  final int? throttle;
  final DateTime lastUpdated;
  
  const VehicleState({
    this.isConnected = false,
    this.flightMode = 'Unknown',
    this.isArmed = false,
    this.currentWaypoint = -1,
    this.totalWaypoints = -1,
    this.latitude,
    this.longitude,
    this.altitudeMSL,
    this.altitudeRelative,
    this.roll,
    this.pitch,
    this.yaw,
    this.airspeed,
    this.groundSpeed,
    this.climbRate,
    this.gpsFixType = 'No GPS',
    this.satelliteCount = 0,
    this.batteryPercent = 0,
    this.batteryVoltage,
    this.throttle,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? const Duration().inMicroseconds == 0 
           ? DateTime.now() 
           : lastUpdated;
  
  VehicleState copyWith({
    bool? isConnected,
    String? flightMode,
    bool? isArmed,
    int? currentWaypoint,
    int? totalWaypoints,
    double? latitude,
    double? longitude,
    double? altitudeMSL,
    double? altitudeRelative,
    double? roll,
    double? pitch,
    double? yaw,
    double? airspeed,
    double? groundSpeed,
    double? climbRate,
    String? gpsFixType,
    int? satelliteCount,
    int? batteryPercent,
    double? batteryVoltage,
    int? throttle,
    DateTime? lastUpdated,
  }) {
    return VehicleState(
      isConnected: isConnected ?? this.isConnected,
      flightMode: flightMode ?? this.flightMode,
      isArmed: isArmed ?? this.isArmed,
      currentWaypoint: currentWaypoint ?? this.currentWaypoint,
      totalWaypoints: totalWaypoints ?? this.totalWaypoints,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitudeMSL: altitudeMSL ?? this.altitudeMSL,
      altitudeRelative: altitudeRelative ?? this.altitudeRelative,
      roll: roll ?? this.roll,
      pitch: pitch ?? this.pitch,
      yaw: yaw ?? this.yaw,
      airspeed: airspeed ?? this.airspeed,
      groundSpeed: groundSpeed ?? this.groundSpeed,
      climbRate: climbRate ?? this.climbRate,
      gpsFixType: gpsFixType ?? this.gpsFixType,
      satelliteCount: satelliteCount ?? this.satelliteCount,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      throttle: throttle ?? this.throttle,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
  
  // Convenience getters
  bool get hasGPSFix => gpsFixType.contains('3D') || gpsFixType.contains('RTK');
  bool get isReadyToArm => hasGPSFix && satelliteCount >= 6 && batteryPercent > 20;
  bool get isFlying => isArmed && (altitudeRelative ?? 0) > 1.0;
  
  String get statusSummary {
    List<String> status = [];
    
    if (!isConnected) status.add('Disconnected');
    if (isArmed) status.add('Armed');
    status.add(flightMode);
    status.add('$batteryPercent%');
    status.add(gpsFixType);
    
    return status.join(' | ');
  }
  
  @override
  String toString() {
    return 'VehicleState(${statusSummary})';
  }
}
```

### 3. State Change Detector

```dart
class StateChangeDetector {
  final VehicleStateMonitor monitor;
  final Map<String, dynamic> _previousValues = {};
  final StreamController<StateChange> _changeController = 
      StreamController<StateChange>.broadcast();
  
  Stream<StateChange> get changeStream => _changeController.stream;
  
  StateChangeDetector(this.monitor) {
    monitor.stateStream.listen(_detectChanges);
  }
  
  void _detectChanges(VehicleState newState) {
    // Check flight mode changes
    if (_previousValues['flightMode'] != newState.flightMode) {
      _emitChange('flightMode', _previousValues['flightMode'], newState.flightMode);
      _previousValues['flightMode'] = newState.flightMode;
    }
    
    // Check armed status changes
    if (_previousValues['isArmed'] != newState.isArmed) {
      _emitChange('isArmed', _previousValues['isArmed'], newState.isArmed);
      _previousValues['isArmed'] = newState.isArmed;
    }
    
    // Check GPS fix changes
    if (_previousValues['gpsFixType'] != newState.gpsFixType) {
      _emitChange('gpsFixType', _previousValues['gpsFixType'], newState.gpsFixType);
      _previousValues['gpsFixType'] = newState.gpsFixType;
    }
    
    // Check battery level changes (only significant changes)
    int? prevBattery = _previousValues['batteryPercent'];
    if (prevBattery == null || (newState.batteryPercent - prevBattery).abs() >= 5) {
      _emitChange('batteryPercent', prevBattery, newState.batteryPercent);
      _previousValues['batteryPercent'] = newState.batteryPercent;
    }
  }
  
  void _emitChange(String property, dynamic oldValue, dynamic newValue) {
    _changeController.add(StateChange(
      property: property,
      oldValue: oldValue,
      newValue: newValue,
      timestamp: DateTime.now(),
    ));
  }
  
  void dispose() {
    _changeController.close();
  }
}

class StateChange {
  final String property;
  final dynamic oldValue;
  final dynamic newValue;
  final DateTime timestamp;
  
  const StateChange({
    required this.property,
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
  });
  
  @override
  String toString() {
    return '$property: $oldValue -> $newValue (${timestamp.toIso8601String()})';
  }
}
```

### 4. Alert System

```dart
class VehicleAlertSystem {
  final VehicleStateMonitor monitor;
  final StreamController<VehicleAlert> _alertController = 
      StreamController<VehicleAlert>.broadcast();
  
  Stream<VehicleAlert> get alertStream => _alertController.stream;
  
  VehicleAlertSystem(this.monitor) {
    monitor.stateStream.listen(_checkAlerts);
  }
  
  void _checkAlerts(VehicleState state) {
    // Low battery alert
    if (state.batteryPercent <= 15) {
      _emitAlert(AlertLevel.critical, 'Low battery: ${state.batteryPercent}%');
    } else if (state.batteryPercent <= 25) {
      _emitAlert(AlertLevel.warning, 'Battery low: ${state.batteryPercent}%');
    }
    
    // GPS alerts
    if (!state.hasGPSFix && state.isArmed) {
      _emitAlert(AlertLevel.critical, 'GPS fix lost while armed');
    } else if (state.satelliteCount < 6) {
      _emitAlert(AlertLevel.warning, 'Low satellite count: ${state.satelliteCount}');
    }
    
    // Attitude alerts
    if (state.roll != null && state.roll!.abs() > 45) {
      _emitAlert(AlertLevel.warning, 'High roll angle: ${state.roll!.toStringAsFixed(1)}°');
    }
    
    if (state.pitch != null && state.pitch!.abs() > 30) {
      _emitAlert(AlertLevel.warning, 'High pitch angle: ${state.pitch!.toStringAsFixed(1)}°');
    }
    
    // Speed alerts
    if (state.groundSpeed != null && state.groundSpeed! > 20) {
      _emitAlert(AlertLevel.info, 'High ground speed: ${state.groundSpeed!.toStringAsFixed(1)} m/s');
    }
  }
  
  void _emitAlert(AlertLevel level, String message) {
    _alertController.add(VehicleAlert(
      level: level,
      message: message,
      timestamp: DateTime.now(),
    ));
  }
  
  void dispose() {
    _alertController.close();
  }
}

enum AlertLevel {
  info,
  warning, 
  critical
}

class VehicleAlert {
  final AlertLevel level;
  final String message;
  final DateTime timestamp;
  
  const VehicleAlert({
    required this.level,
    required this.message,
    required this.timestamp,
  });
  
  @override
  String toString() {
    return '${level.name.toUpperCase()}: $message (${timestamp.toIso8601String()})';
  }
}
```

## Usage Examples

### Basic State Monitoring

```dart
class BasicStateExample {
  final DroneMAVLinkAPI api = DroneMAVLinkAPI();
  late VehicleStateMonitor stateMonitor;
  
  void initialize() {
    stateMonitor = VehicleStateMonitor(api);
    
    // Listen to state changes
    stateMonitor.stateStream.listen((state) {
      print('Vehicle state: ${state.statusSummary}');
      
      // Access specific state properties
      if (state.hasGPSFix) {
        print('Position: ${state.latitude}, ${state.longitude}');
        print('Altitude: ${state.altitudeRelative}m');
      }
      
      if (state.isArmed) {
        print('Attitude: R=${state.roll}° P=${state.pitch}° Y=${state.yaw}°');
        print('Speed: ${state.groundSpeed} m/s');
      }
    });
  }
  
  void checkReadiness() {
    VehicleState state = stateMonitor.currentState;
    
    if (state.isReadyToArm) {
      print('✅ Vehicle is ready to arm');
    } else {
      print('❌ Vehicle not ready:');
      if (!state.hasGPSFix) print('  - No GPS fix');
      if (state.satelliteCount < 6) print('  - Insufficient satellites');
      if (state.batteryPercent <= 20) print('  - Low battery');
    }
  }
}
```

### Advanced State Management

```dart
class AdvancedStateExample {
  final DroneMAVLinkAPI api = DroneMAVLinkAPI();
  late VehicleStateMonitor stateMonitor;
  late StateChangeDetector changeDetector;
  late VehicleAlertSystem alertSystem;
  
  void initialize() {
    stateMonitor = VehicleStateMonitor(api);
    changeDetector = StateChangeDetector(stateMonitor);
    alertSystem = VehicleAlertSystem(stateMonitor);
    
    // Monitor state changes
    changeDetector.changeStream.listen((change) {
      print('State change: $change');
      
      if (change.property == 'flightMode') {
        _handleModeChange(change.oldValue, change.newValue);
      } else if (change.property == 'isArmed') {
        _handleArmingChange(change.newValue);
      }
    });
    
    // Monitor alerts
    alertSystem.alertStream.listen((alert) {
      _handleAlert(alert);
    });
  }
  
  void _handleModeChange(String? oldMode, String newMode) {
    print('Flight mode changed: $oldMode -> $newMode');
    
    if (newMode == 'RTL') {
      print('🏠 Drone is returning to launch');
    } else if (newMode == 'AUTO') {
      print('🤖 Drone entered autonomous mode');
    }
  }
  
  void _handleArmingChange(bool isArmed) {
    if (isArmed) {
      print('🚁 Drone ARMED - ready for flight');
    } else {
      print('🛬 Drone DISARMED - safe');
    }
  }
  
  void _handleAlert(VehicleAlert alert) {
    switch (alert.level) {
      case AlertLevel.critical:
        print('🚨 CRITICAL: ${alert.message}');
        // Take immediate action
        break;
      case AlertLevel.warning:
        print('⚠️ WARNING: ${alert.message}');
        // Log warning
        break;
      case AlertLevel.info:
        print('ℹ️ INFO: ${alert.message}');
        break;
    }
  }
  
  void dispose() {
    stateMonitor.dispose();
    changeDetector.dispose();
    alertSystem.dispose();
  }
}
```

### UI Integration

```dart
class VehicleStatusWidget extends StatefulWidget {
  final DroneMAVLinkAPI api;
  
  const VehicleStatusWidget({required this.api});
  
  @override
  _VehicleStatusWidgetState createState() => _VehicleStatusWidgetState();
}

class _VehicleStatusWidgetState extends State<VehicleStatusWidget> {
  late VehicleStateMonitor _stateMonitor;
  VehicleState _currentState = VehicleState();
  
  @override
  void initState() {
    super.initState();
    _stateMonitor = VehicleStateMonitor(widget.api);
    
    _stateMonitor.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection Status
            Row(
              children: [
                Icon(
                  _currentState.isConnected ? Icons.link : Icons.link_off,
                  color: _currentState.isConnected ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text(_currentState.isConnected ? 'Connected' : 'Disconnected'),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Flight Status
            _buildStatusRow('Mode', _currentState.flightMode),
            _buildStatusRow('Armed', _currentState.isArmed ? 'Yes' : 'No'),
            
            SizedBox(height: 16),
            
            // Position Data
            if (_currentState.latitude != null && _currentState.longitude != null)
              _buildStatusRow('Position', 
                  '${_currentState.latitude!.toStringAsFixed(6)}, '
                  '${_currentState.longitude!.toStringAsFixed(6)}'),
            
            if (_currentState.altitudeRelative != null)
              _buildStatusRow('Altitude', 
                  '${_currentState.altitudeRelative!.toStringAsFixed(1)} m'),
            
            SizedBox(height: 16),
            
            // Attitude Data
            if (_currentState.roll != null)
              _buildAttitudeIndicator(),
            
            SizedBox(height: 16),
            
            // GPS Status
            Row(
              children: [
                Icon(
                  _currentState.hasGPSFix ? Icons.gps_fixed : Icons.gps_not_fixed,
                  color: _currentState.hasGPSFix ? Colors.green : Colors.orange,
                ),
                SizedBox(width: 8),
                Text('${_currentState.gpsFixType} (${_currentState.satelliteCount} sats)'),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Battery Status
            Row(
              children: [
                Icon(
                  Icons.battery_full,
                  color: _getBatteryColor(_currentState.batteryPercent),
                ),
                SizedBox(width: 8),
                Text('${_currentState.batteryPercent}%'),
                if (_currentState.batteryVoltage != null)
                  Text(' (${_currentState.batteryVoltage!.toStringAsFixed(1)}V)'),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
  
  Widget _buildAttitudeIndicator() {
    return Column(
      children: [
        Text('Attitude', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildAngleIndicator('Roll', _currentState.roll, Colors.red),
            _buildAngleIndicator('Pitch', _currentState.pitch, Colors.green),
            _buildAngleIndicator('Yaw', _currentState.yaw, Colors.blue),
          ],
        ),
      ],
    );
  }
  
  Widget _buildAngleIndicator(String label, double? angle, Color color) {
    String angleText = angle != null ? '${angle.toStringAsFixed(1)}°' : '--';
    
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12)),
        Text(angleText, style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        )),
      ],
    );
  }
  
  Color _getBatteryColor(int percent) {
    if (percent > 50) return Colors.green;
    if (percent > 25) return Colors.orange;
    return Colors.red;
  }
  
  @override
  void dispose() {
    _stateMonitor.dispose();
    super.dispose();
  }
}
```

## Best Practices

### 1. Regular State Updates

```dart
// Ensure state is updated regularly
Timer.periodic(Duration(seconds: 1), (_) {
  VehicleState state = stateMonitor.currentState;
  
  // Check if state is stale
  if (DateTime.now().difference(state.lastUpdated).inSeconds > 5) {
    print('Warning: Vehicle state is stale');
  }
});
```

### 2. State Validation

```dart
bool isStateValid(VehicleState state) {
  // Check for reasonable values
  if (state.roll != null && state.roll!.abs() > 180) return false;
  if (state.pitch != null && state.pitch!.abs() > 90) return false;
  if (state.batteryPercent < 0 || state.batteryPercent > 100) return false;
  
  return true;
}
```

### 3. Efficient State Updates

```dart
// Only update UI when necessary
VehicleState? _lastUIState;

stateMonitor.stateStream.listen((state) {
  // Only update UI for significant changes
  if (_shouldUpdateUI(state, _lastUIState)) {
    setState(() {
      _currentState = state;
    });
    _lastUIState = state;
  }
});

bool _shouldUpdateUI(VehicleState newState, VehicleState? oldState) {
  if (oldState == null) return true;
  
  // Check for significant changes
  if (newState.flightMode != oldState.flightMode) return true;
  if (newState.isArmed != oldState.isArmed) return true;
  if ((newState.batteryPercent - oldState.batteryPercent).abs() >= 1) return true;
  
  return false;
}
```

### 4. State Persistence

```dart
class StatePersistence {
  static const String _stateKey = 'last_vehicle_state';
  
  static Future<void> saveState(VehicleState state) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String stateJson = jsonEncode(state.toMap());
    await prefs.setString(_stateKey, stateJson);
  }
  
  static Future<VehicleState?> loadState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? stateJson = prefs.getString(_stateKey);
    
    if (stateJson != null) {
      Map<String, dynamic> stateMap = jsonDecode(stateJson);
      return VehicleState.fromMap(stateMap);
    }
    
    return null;
  }
}
```
