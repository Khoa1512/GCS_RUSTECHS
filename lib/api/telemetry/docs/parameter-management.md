# Parameter Management Documentation

## Overview

Parameter Management module cung cấp khả năng đọc, ghi và quản lý các tham số cấu hình của drone. Module này hỗ trợ cả việc lấy tất cả tham số cũng như làm việc với từng tham số cụ thể.

## Core Functionality

### Parameter Operations

#### 1. Request All Parameters

```dart
void requestAllParameters()
```

Yêu cầu tất cả tham số từ drone. Đây là operation bất đồng bộ sẽ trigger events khi nhận được dữ liệu.

```dart
final api = DroneMAVLinkAPI();

// Request all parameters
api.requestAllParameters();

// Listen for individual parameter events
api.eventStream
  .where((event) => event.type == MAVLinkEventType.parameterReceived)
  .listen((event) {
    String paramName = event.data['id'];
    double paramValue = event.data['value'];
    print('Parameter $paramName: $paramValue');
  });

// Listen for completion event
api.eventStream
  .where((event) => event.type == MAVLinkEventType.allParametersReceived)
  .listen((event) {
    Map<String, double> allParams = event.data;
    print('Received ${allParams.length} parameters');
  });
```

#### 2. Request Specific Parameter

```dart
void requestParameter(String paramName)
```

Yêu cầu một tham số cụ thể theo tên.

```dart
// Request a specific parameter
api.requestParameter('ARMING_CHECK');

// Listen for the response
api.eventStream
  .where((event) => event.type == MAVLinkEventType.parameterReceived)
  .where((event) => event.data['id'] == 'ARMING_CHECK')
  .listen((event) {
    double value = event.data['value'];
    print('ARMING_CHECK value: $value');
  });
```

#### 3. Set Parameter Value

```dart
void setParameter(String paramName, double value)
```

Thiết lập giá trị cho một tham số.

```dart
// Set a parameter value
api.setParameter('WPNAV_SPEED', 500.0);

// The drone will send back the updated parameter value
// Listen for confirmation
api.eventStream
  .where((event) => event.type == MAVLinkEventType.parameterReceived)
  .where((event) => event.data['id'] == 'WPNAV_SPEED')
  .listen((event) {
    double newValue = event.data['value'];
    print('WPNAV_SPEED updated to: $newValue');
  });
```

### Parameter Access

#### Direct Access

```dart
// Get all parameters as a map
Map<String, double> allParams = api.parameters;

// Get specific parameter value
double? armingCheck = api.parameters['ARMING_CHECK'];
if (armingCheck != null) {
  print('Arming check value: $armingCheck');
} else {
  print('ARMING_CHECK parameter not available');
}
```

## Parameter Events

### Parameter Received Event

```dart
{
  'id': String,           // Parameter name (e.g., "ARMING_CHECK")
  'value': double,        // Parameter value
  'type': String,         // Parameter type (e.g., "float", "int32_t")
  'index': int,           // Parameter index in the list
  'count': int            // Total number of parameters
}
```

### All Parameters Received Event

```dart
Map<String, double>       // Map containing all parameters
```

## Common Parameters

### ArduPilot Parameters

#### Flight Control Parameters

```dart
// Arming check configuration
'ARMING_CHECK' -> 1.0     // Enable all arming checks

// Failsafe parameters
'FS_GCS_ENABLE' -> 1.0    // Enable GCS failsafe
'FS_THR_ENABLE' -> 1.0    // Enable throttle failsafe
'FS_THR_VALUE' -> 975.0   // Throttle failsafe PWM value

// Navigation parameters
'WPNAV_SPEED' -> 500.0    // Waypoint navigation speed (cm/s)
'WPNAV_RADIUS' -> 200.0   // Waypoint radius (cm)
'WPNAV_SPEED_UP' -> 250.0 // Ascent speed (cm/s)
'WPNAV_SPEED_DN' -> 150.0 // Descent speed (cm/s)
```

#### Flight Mode Parameters

```dart
// Flight mode configuration
'FLTMODE1' -> 0.0         // Stabilize
'FLTMODE2' -> 2.0         // AltHold  
'FLTMODE3' -> 3.0         // Auto
'FLTMODE4' -> 4.0         // Guided
'FLTMODE5' -> 5.0         // Loiter
'FLTMODE6' -> 6.0         // RTL
```

#### Tuning Parameters

```dart
// PID tuning parameters
'RATE_RLL_P' -> 0.135     // Roll rate P gain
'RATE_RLL_I' -> 0.135     // Roll rate I gain
'RATE_RLL_D' -> 0.004     // Roll rate D gain

'RATE_PIT_P' -> 0.135     // Pitch rate P gain
'RATE_PIT_I' -> 0.135     // Pitch rate I gain
'RATE_PIT_D' -> 0.004     // Pitch rate D gain

'RATE_YAW_P' -> 0.270     // Yaw rate P gain
'RATE_YAW_I' -> 0.027     // Yaw rate I gain
'RATE_YAW_D' -> 0.000     // Yaw rate D gain
```

## Parameter Management Classes

### 1. Parameter Cache Manager

```dart
class ParameterCacheManager {
  final DroneMAVLinkAPI api;
  final Map<String, double> _parameterCache = {};
  final Map<String, DateTime> _lastUpdated = {};
  
  ParameterCacheManager(this.api) {
    _setupParameterListener();
  }
  
  void _setupParameterListener() {
    api.eventStream
      .where((event) => event.type == MAVLinkEventType.parameterReceived)
      .listen((event) {
        String paramName = event.data['id'];
        double paramValue = event.data['value'];
        
        _parameterCache[paramName] = paramValue;
        _lastUpdated[paramName] = DateTime.now();
      });
  }
  
  double? getParameter(String name) {
    return _parameterCache[name];
  }
  
  bool hasParameter(String name) {
    return _parameterCache.containsKey(name);
  }
  
  DateTime? getLastUpdated(String name) {
    return _lastUpdated[name];
  }
  
  Map<String, double> getAllParameters() {
    return Map.from(_parameterCache);
  }
  
  List<String> getParameterNames() {
    return _parameterCache.keys.toList();
  }
  
  void clearCache() {
    _parameterCache.clear();
    _lastUpdated.clear();
  }
}
```

### 2. Parameter Validator

```dart
class ParameterValidator {
  static const Map<String, ParameterLimits> _parameterLimits = {
    'WPNAV_SPEED': ParameterLimits(min: 20.0, max: 2000.0),
    'WPNAV_RADIUS': ParameterLimits(min: 10.0, max: 1000.0),
    'ARMING_CHECK': ParameterLimits(min: 0.0, max: 1.0),
    'RATE_RLL_P': ParameterLimits(min: 0.01, max: 0.5),
    'RATE_PIT_P': ParameterLimits(min: 0.01, max: 0.5),
    'RATE_YAW_P': ParameterLimits(min: 0.01, max: 0.8),
  };
  
  static ValidationResult validateParameter(String name, double value) {
    if (!_parameterLimits.containsKey(name)) {
      return ValidationResult(true, 'Parameter $name is not validated');
    }
    
    ParameterLimits limits = _parameterLimits[name]!;
    
    if (value < limits.min) {
      return ValidationResult(false, 
        'Value $value is below minimum ${limits.min} for $name');
    }
    
    if (value > limits.max) {
      return ValidationResult(false, 
        'Value $value is above maximum ${limits.max} for $name');
    }
    
    return ValidationResult(true, 'Valid');
  }
  
  static List<String> getCriticalParameters() {
    return [
      'ARMING_CHECK',
      'FS_GCS_ENABLE',
      'FS_THR_ENABLE',
      'WPNAV_SPEED',
      'RATE_RLL_P',
      'RATE_PIT_P',
      'RATE_YAW_P',
    ];
  }
}

class ParameterLimits {
  final double min;
  final double max;
  
  const ParameterLimits({required this.min, required this.max});
}

class ValidationResult {
  final bool isValid;
  final String message;
  
  const ValidationResult(this.isValid, this.message);
}
```

### 3. Parameter Backup Manager

```dart
class ParameterBackupManager {
  final DroneMAVLinkAPI api;
  final String backupDirectory;
  
  ParameterBackupManager(this.api, this.backupDirectory);
  
  Future<void> backupParameters() async {
    Map<String, double> parameters = api.parameters;
    
    if (parameters.isEmpty) {
      throw Exception('No parameters available to backup');
    }
    
    String timestamp = DateTime.now().toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    
    String filename = 'parameters_backup_$timestamp.json';
    String filepath = '$backupDirectory/$filename';
    
    Map<String, dynamic> backup = {
      'timestamp': DateTime.now().toIso8601String(),
      'parameter_count': parameters.length,
      'parameters': parameters,
    };
    
    File file = File(filepath);
    await file.writeAsString(jsonEncode(backup));
    
    print('Parameters backed up to: $filepath');
  }
  
  Future<Map<String, double>> restoreParameters(String backupPath) async {
    File file = File(backupPath);
    
    if (!await file.exists()) {
      throw Exception('Backup file not found: $backupPath');
    }
    
    String content = await file.readAsString();
    Map<String, dynamic> backup = jsonDecode(content);
    
    Map<String, double> parameters = Map<String, double>.from(
        backup['parameters']);
    
    print('Loaded ${parameters.length} parameters from backup');
    return parameters;
  }
  
  Future<void> applyBackup(String backupPath) async {
    Map<String, double> parameters = await restoreParameters(backupPath);
    
    for (String paramName in parameters.keys) {
      double value = parameters[paramName]!;
      
      // Validate parameter before setting
      ValidationResult validation = ParameterValidator.validateParameter(
          paramName, value);
      
      if (validation.isValid) {
        api.setParameter(paramName, value);
        await Future.delayed(Duration(milliseconds: 100)); // Rate limiting
      } else {
        print('Skipping invalid parameter $paramName: ${validation.message}');
      }
    }
    
    print('Backup restoration completed');
  }
  
  Future<List<String>> listBackups() async {
    Directory dir = Directory(backupDirectory);
    
    if (!await dir.exists()) {
      return [];
    }
    
    List<FileSystemEntity> files = await dir.list().toList();
    
    return files
        .where((file) => file.path.endsWith('.json'))
        .map((file) => basename(file.path))
        .toList();
  }
}
```

## Advanced Parameter Operations

### 1. Parameter Synchronization

```dart
class ParameterSynchronizer {
  final DroneMAVLinkAPI api;
  final Map<String, double> _pendingChanges = {};
  bool _isSyncing = false;
  
  ParameterSynchronizer(this.api);
  
  void queueParameterChange(String name, double value) {
    _pendingChanges[name] = value;
  }
  
  Future<void> synchronizeAll() async {
    if (_isSyncing || _pendingChanges.isEmpty) return;
    
    _isSyncing = true;
    
    try {
      for (String paramName in _pendingChanges.keys) {
        double value = _pendingChanges[paramName]!;
        
        // Validate parameter
        ValidationResult validation = ParameterValidator.validateParameter(
            paramName, value);
        
        if (!validation.isValid) {
          print('Skipping invalid parameter $paramName: ${validation.message}');
          continue;
        }
        
        // Set parameter
        api.setParameter(paramName, value);
        
        // Wait for confirmation
        bool confirmed = await _waitForParameterConfirmation(paramName, value);
        
        if (confirmed) {
          print('Parameter $paramName synchronized successfully');
        } else {
          print('Failed to synchronize parameter $paramName');
        }
        
        // Rate limiting
        await Future.delayed(Duration(milliseconds: 200));
      }
    } finally {
      _pendingChanges.clear();
      _isSyncing = false;
    }
  }
  
  Future<bool> _waitForParameterConfirmation(String paramName, double expectedValue,
      {Duration timeout = const Duration(seconds: 5)}) async {
    
    Completer<bool> completer = Completer<bool>();
    late StreamSubscription subscription;
    
    subscription = api.eventStream
      .where((event) => event.type == MAVLinkEventType.parameterReceived)
      .where((event) => event.data['id'] == paramName)
      .listen((event) {
        double receivedValue = event.data['value'];
        
        if ((receivedValue - expectedValue).abs() < 0.001) {
          if (!completer.isCompleted) {
            completer.complete(true);
            subscription.cancel();
          }
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

### 2. Parameter Group Manager

```dart
class ParameterGroupManager {
  final DroneMAVLinkAPI api;
  
  static const Map<String, List<String>> _parameterGroups = {
    'navigation': [
      'WPNAV_SPEED',
      'WPNAV_RADIUS',
      'WPNAV_SPEED_UP',
      'WPNAV_SPEED_DN',
      'WPNAV_ACCEL',
    ],
    'failsafe': [
      'FS_GCS_ENABLE',
      'FS_THR_ENABLE',
      'FS_THR_VALUE',
      'FS_BATT_ENABLE',
      'FS_BATT_VOLTAGE',
    ],
    'tuning_roll': [
      'RATE_RLL_P',
      'RATE_RLL_I',
      'RATE_RLL_D',
      'ATC_RAT_RLL_P',
      'ATC_RAT_RLL_I',
      'ATC_RAT_RLL_D',
    ],
    'tuning_pitch': [
      'RATE_PIT_P',
      'RATE_PIT_I',
      'RATE_PIT_D',
      'ATC_RAT_PIT_P',
      'ATC_RAT_PIT_I',
      'ATC_RAT_PIT_D',
    ],
    'tuning_yaw': [
      'RATE_YAW_P',
      'RATE_YAW_I',
      'RATE_YAW_D',
      'ATC_RAT_YAW_P',
      'ATC_RAT_YAW_I',
      'ATC_RAT_YAW_D',
    ],
  };
  
  ParameterGroupManager(this.api);
  
  List<String> getGroupNames() {
    return _parameterGroups.keys.toList();
  }
  
  List<String> getParametersInGroup(String groupName) {
    return _parameterGroups[groupName] ?? [];
  }
  
  Map<String, double> getGroupParameters(String groupName) {
    List<String> paramNames = getParametersInGroup(groupName);
    Map<String, double> groupParams = {};
    
    for (String paramName in paramNames) {
      double? value = api.parameters[paramName];
      if (value != null) {
        groupParams[paramName] = value;
      }
    }
    
    return groupParams;
  }
  
  void requestGroup(String groupName) {
    List<String> paramNames = getParametersInGroup(groupName);
    
    for (String paramName in paramNames) {
      api.requestParameter(paramName);
    }
  }
  
  Future<void> setGroupParameters(String groupName, Map<String, double> values) async {
    List<String> paramNames = getParametersInGroup(groupName);
    
    for (String paramName in paramNames) {
      if (values.containsKey(paramName)) {
        double value = values[paramName]!;
        
        // Validate parameter
        ValidationResult validation = ParameterValidator.validateParameter(
            paramName, value);
        
        if (validation.isValid) {
          api.setParameter(paramName, value);
          await Future.delayed(Duration(milliseconds: 100));
        } else {
          print('Invalid parameter $paramName: ${validation.message}');
        }
      }
    }
  }
}
```

## Usage Examples

### Basic Parameter Operations

```dart
class BasicParameterExample {
  final DroneMAVLinkAPI api = DroneMAVLinkAPI();
  
  Future<void> demonstrateParameterOperations() async {
    // Connect to drone first
  await api.connect('COM3');
  if (!api.isConnected) return;
    
    // Request all parameters
    api.requestAllParameters();
    
    // Wait for parameters to be received
    await _waitForParameters();
    
    // Get a specific parameter
    double? armingCheck = api.parameters['ARMING_CHECK'];
    print('Current ARMING_CHECK value: $armingCheck');
    
    // Set a parameter
    api.setParameter('WPNAV_SPEED', 500.0);
    
    // Request a specific parameter
    api.requestParameter('WPNAV_RADIUS');
  }
  
  Future<void> _waitForParameters() async {
    Completer<void> completer = Completer<void>();
    
    api.eventStream
      .where((event) => event.type == MAVLinkEventType.allParametersReceived)
      .listen((event) {
        completer.complete();
      });
    
    return completer.future;
  }
}
```

### Advanced Parameter Management

```dart
class AdvancedParameterExample {
  final DroneMAVLinkAPI api = DroneMAVLinkAPI();
  late ParameterCacheManager cacheManager;
  late ParameterBackupManager backupManager;
  late ParameterGroupManager groupManager;
  
  void initialize() {
    cacheManager = ParameterCacheManager(api);
    backupManager = ParameterBackupManager(api, '/path/to/backups');
    groupManager = ParameterGroupManager(api);
  }
  
  Future<void> performParameterMaintenance() async {
    // Connect and get parameters
  await api.connect('COM3');
  if (!api.isConnected) return;
    api.requestAllParameters();
    
    // Wait for parameters
    await _waitForAllParameters();
    
    // Backup current parameters
    await backupManager.backupParameters();
    
    // Work with parameter groups
    Map<String, double> navParams = groupManager.getGroupParameters('navigation');
    print('Navigation parameters: $navParams');
    
    // Validate critical parameters
    List<String> criticalParams = ParameterValidator.getCriticalParameters();
    for (String paramName in criticalParams) {
      double? value = api.parameters[paramName];
      if (value != null) {
        ValidationResult result = ParameterValidator.validateParameter(
            paramName, value);
        
        if (!result.isValid) {
          print('WARNING: ${result.message}');
        }
      }
    }
  }
  
  Future<void> _waitForAllParameters() async {
    Completer<void> completer = Completer<void>();
    
    api.eventStream
      .where((event) => event.type == MAVLinkEventType.allParametersReceived)
      .listen((event) {
        completer.complete();
      });
    
    return completer.future;
  }
}
```

## Best Practices

### 1. Parameter Validation

```dart
// Always validate parameters before setting
ValidationResult validation = ParameterValidator.validateParameter(
    'WPNAV_SPEED', 500.0);

if (validation.isValid) {
  api.setParameter('WPNAV_SPEED', 500.0);
} else {
  print('Invalid parameter: ${validation.message}');
}
```

### 2. Rate Limiting

```dart
// Don't set parameters too quickly
for (String paramName in parameterList) {
  api.setParameter(paramName, values[paramName]);
  await Future.delayed(Duration(milliseconds: 100));
}
```

### 3. Backup Before Changes

```dart
// Always backup before making changes
await backupManager.backupParameters();

// Make changes
api.setParameter('RATE_RLL_P', 0.15);

// Verify changes
await Future.delayed(Duration(seconds: 2));
double? newValue = api.parameters['RATE_RLL_P'];
print('New value: $newValue');
```

### 4. Error Handling

```dart
try {
  api.setParameter('INVALID_PARAM', 100.0);
} catch (e) {
  print('Error setting parameter: $e');
}

// Check if parameter exists before using
if (api.parameters.containsKey('WPNAV_SPEED')) {
  double speed = api.parameters['WPNAV_SPEED']!;
  // Use speed value
} else {
  print('WPNAV_SPEED parameter not available');
}
```
