# Command Interface Documentation

## Overview

Command Interface module cung cấp khả năng gửi các lệnh điều khiển tới drone, bao gồm arm/disarm, thay đổi flight mode, và các lệnh điều khiển khác.

## Core Commands

### 1. Arm/Disarm Commands

#### `void sendArmCommand(bool arm)`

Gửi lệnh arm hoặc disarm tới drone.

```dart
final api = DroneMAVLinkAPI();

// Arm the drone
api.sendArmCommand(true);

// Disarm the drone
api.sendArmCommand(false);

// Check current armed status
bool isArmed = api.isArmed;
print('Drone is ${isArmed ? 'armed' : 'disarmed'}');
```

**Parameters:**

- `arm`: true để arm, false để disarm

**MAVLink Command:** MAV_CMD_COMPONENT_ARM_DISARM (400)

### 2. Flight Mode Commands

#### `void setFlightMode(int mode)`

Thay đổi flight mode của drone.

```dart
// Set different flight modes
api.setFlightMode(0);  // MANUAL
api.setFlightMode(2);  // STABILIZE
api.setFlightMode(9);  // AUTO
api.setFlightMode(10); // RTL (Return to Launch)
api.setFlightMode(11); // LOITER

// Check current flight mode
String currentMode = api.currentMode;
print('Current mode: $currentMode');
```

**Parameters:**

- `mode`: Flight mode number (varies by autopilot)

**MAVLink Message:** SET_MODE

## Flight Modes

### ArduPilot Flight Modes

```dart
class ArduPilotFlightModes {
  static const int MANUAL = 0;
  static const int CIRCLE = 1;
  static const int STABILIZE = 2;
  static const int TRAINING = 3;
  static const int ACRO = 4;
  static const int FBWA = 5;        // Fly By Wire A
  static const int FBWB = 6;        // Fly By Wire B
  static const int CRUISE = 7;
  static const int AUTOTUNE = 8;
  static const int AUTO = 9;
  static const int RTL = 10;        // Return to Launch
  static const int LOITER = 11;
  static const int TAKEOFF = 12;
  static const int AVOID_ADSB = 13;
  static const int GUIDED = 14;
  static const int INITIALIZING = 15;
  static const int QSTABILIZE = 16; // QuadPlane Stabilize
  static const int QHOVER = 18;     // QuadPlane Hover
  static const int QLOITER = 17;    // QuadPlane Loiter
  static const int QLAND = 19;      // QuadPlane Land
  static const int QRTL = 20;       // QuadPlane RTL
  static const int QAUTOTUNE = 21;  // QuadPlane AutoTune
  static const int QACRO = 22;      // QuadPlane Acro
}
```

### Mode Descriptions

- **MANUAL**: Full manual control
- **STABILIZE**: Self-leveling mode
- **AUTO**: Autonomous mission execution
- **RTL**: Return to launch point
- **LOITER**: Hold position
- **GUIDED**: Guided mode for external control
- **QSTABILIZE**: QuadPlane stabilize mode
- **QHOVER**: QuadPlane hover mode

## Command Classes

### 1. Flight Mode Manager

```dart
class FlightModeManager {
  final DroneMAVLinkAPI api;
  String _previousMode = 'Unknown';

  FlightModeManager(this.api) {
    _setupModeMonitoring();
  }

  void _setupModeMonitoring() {
    api.eventStream
      .where((event) => event.type == MAVLinkEventType.heartbeat)
      .listen((event) {
        String currentMode = event.data['mode'];

        if (currentMode != _previousMode) {
          _onModeChanged(_previousMode, currentMode);
          _previousMode = currentMode;
        }
      });
  }

  void _onModeChanged(String from, String to) {
    print('Flight mode changed: $from -> $to');
  }

  Future<bool> setModeWithConfirmation(int mode,
      {Duration timeout = const Duration(seconds: 5)}) async {

    String expectedMode = _getModeString(mode);
    api.setFlightMode(mode);

    // Wait for mode confirmation
    Completer<bool> completer = Completer<bool>();
    late StreamSubscription subscription;

    subscription = api.eventStream
      .where((event) => event.type == MAVLinkEventType.heartbeat)
      .listen((event) {
        String currentMode = event.data['mode'];

        if (currentMode == expectedMode) {
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

  String _getModeString(int mode) {
    switch (mode) {
      case ArduPilotFlightModes.MANUAL: return 'MANUAL';
      case ArduPilotFlightModes.STABILIZE: return 'STABILIZE';
      case ArduPilotFlightModes.AUTO: return 'AUTO';
      case ArduPilotFlightModes.RTL: return 'RTL';
      case ArduPilotFlightModes.LOITER: return 'LOITER';
      case ArduPilotFlightModes.GUIDED: return 'GUIDED';
      default: return 'UNKNOWN MODE ($mode)';
    }
  }

  bool canSwitchToMode(int mode) {
    // Check if it's safe to switch to the requested mode
    if (!api.isConnected) return false;

    switch (mode) {
      case ArduPilotFlightModes.AUTO:
        // AUTO mode requires mission loaded and GPS fix
        return api.gpsFixType.contains('3D') && api.totalWaypoints > 0;

      case ArduPilotFlightModes.RTL:
        // RTL requires GPS fix and home position set
        return api.gpsFixType.contains('3D') && api.homePosition.isNotEmpty;

      case ArduPilotFlightModes.LOITER:
        // LOITER requires GPS fix
        return api.gpsFixType.contains('3D');

      default:
        return true;
    }
  }
}
```

### 2. Arm/Disarm Manager

```dart
class ArmDisarmManager {
  final DroneMAVLinkAPI api;
  bool _isArming = false;
  bool _isDisarming = false;

  ArmDisarmManager(this.api);

  Future<bool> armWithPrecheck({Duration timeout = const Duration(seconds: 10)}) async {
    if (_isArming) return false;

    // Perform pre-arm checks
    ArmingCheckResult checkResult = await performPreArmChecks();

    if (!checkResult.canArm) {
      print('Pre-arm check failed: ${checkResult.reason}');
      return false;
    }

    _isArming = true;

    try {
      api.sendArmCommand(true);

      // Wait for arming confirmation
      bool armed = await _waitForArmingState(true, timeout: timeout);

      if (armed) {
        print('Drone armed successfully');
      } else {
        print('Arming timed out');
      }

      return armed;
    } finally {
      _isArming = false;
    }
  }

  Future<bool> disarmWithConfirmation({Duration timeout = const Duration(seconds: 5)}) async {
    if (_isDisarming) return false;

    _isDisarming = true;

    try {
      api.sendArmCommand(false);

      // Wait for disarming confirmation
      bool disarmed = await _waitForArmingState(false, timeout: timeout);

      if (disarmed) {
        print('Drone disarmed successfully');
      } else {
        print('Disarming timed out');
      }

      return disarmed;
    } finally {
      _isDisarming = false;
    }
  }

  Future<bool> _waitForArmingState(bool expectedState,
      {Duration timeout = const Duration(seconds: 5)}) async {

    Completer<bool> completer = Completer<bool>();
    late StreamSubscription subscription;

    subscription = api.eventStream
      .where((event) => event.type == MAVLinkEventType.heartbeat)
      .listen((event) {
        bool armed = event.data['armed'];

        if (armed == expectedState) {
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

  Future<ArmingCheckResult> performPreArmChecks() async {
    // Check connection
    if (!api.isConnected) {
      return ArmingCheckResult(false, 'Not connected to drone');
    }

    // Check if already armed
    if (api.isArmed) {
      return ArmingCheckResult(false, 'Drone is already armed');
    }

    // Check GPS fix
    if (!api.gpsFixType.contains('3D')) {
      return ArmingCheckResult(false, 'GPS fix required (current: ${api.gpsFixType})');
    }

    // Check satellite count
    if (api.satellites < 6) {
      return ArmingCheckResult(false, 'Insufficient satellites (${api.satellites}/6)');
    }

    // Check battery level
    if (api.batteryPercent < 20) {
      return ArmingCheckResult(false, 'Low battery (${api.batteryPercent}%)');
    }

    // Check flight mode
    String mode = api.currentMode;
    if (mode == 'INITIALIZING' || mode == 'Unknown') {
      return ArmingCheckResult(false, 'Invalid flight mode: $mode');
    }

    return ArmingCheckResult(true, 'Pre-arm checks passed');
  }
}

class ArmingCheckResult {
  final bool canArm;
  final String reason;

  const ArmingCheckResult(this.canArm, this.reason);
}
```

### 3. Command Queue Manager

```dart
class CommandQueueManager {
  final DroneMAVLinkAPI api;
  final Queue<DroneCommand> _commandQueue = Queue<DroneCommand>();
  bool _isProcessing = false;

  CommandQueueManager(this.api);

  void queueCommand(DroneCommand command) {
    _commandQueue.add(command);
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessing || _commandQueue.isEmpty) return;

    _isProcessing = true;

    while (_commandQueue.isNotEmpty) {
      DroneCommand command = _commandQueue.removeFirst();

      try {
        await _executeCommand(command);
        await Future.delayed(Duration(milliseconds: 500)); // Rate limiting
      } catch (e) {
        print('Error executing command ${command.type}: $e');
      }
    }

    _isProcessing = false;
  }

  Future<void> _executeCommand(DroneCommand command) async {
    switch (command.type) {
      case CommandType.arm:
        api.sendArmCommand(true);
        break;
      case CommandType.disarm:
        api.sendArmCommand(false);
        break;
      case CommandType.setMode:
        api.setFlightMode(command.parameter as int);
        break;
      case CommandType.setParameter:
        var params = command.parameter as Map<String, dynamic>;
        api.setParameter(params['name'], params['value']);
        break;
    }
  }

  void clearQueue() {
    _commandQueue.clear();
  }

  int get queueLength => _commandQueue.length;
}

class DroneCommand {
  final CommandType type;
  final dynamic parameter;
  final DateTime timestamp;

  DroneCommand(this.type, {this.parameter}) : timestamp = DateTime.now();
}

enum CommandType {
  arm,
  disarm,
  setMode,
  setParameter,
}
```

## Advanced Command Operations

### 1. Command Sequences

```dart
class CommandSequence {
  final List<DroneCommand> _commands = [];

  void addCommand(CommandType type, {dynamic parameter}) {
    _commands.add(DroneCommand(type, parameter: parameter));
  }

  void addArm() {
    addCommand(CommandType.arm);
  }

  void addDisarm() {
    addCommand(CommandType.disarm);
  }

  void addModeChange(int mode) {
    addCommand(CommandType.setMode, parameter: mode);
  }

  void addParameterSet(String name, double value) {
    addCommand(CommandType.setParameter,
        parameter: {'name': name, 'value': value});
  }

  Future<void> execute(DroneMAVLinkAPI api,
      {Duration delayBetweenCommands = const Duration(seconds: 1)}) async {

    for (DroneCommand command in _commands) {
      switch (command.type) {
        case CommandType.arm:
          api.sendArmCommand(true);
          break;
        case CommandType.disarm:
          api.sendArmCommand(false);
          break;
        case CommandType.setMode:
          api.setFlightMode(command.parameter as int);
          break;
        case CommandType.setParameter:
          var params = command.parameter as Map<String, dynamic>;
          api.setParameter(params['name'], params['value']);
          break;
      }

      await Future.delayed(delayBetweenCommands);
    }
  }
}
```

### 2. Pre-flight Sequence

```dart
class PreflightSequence {
  final DroneMAVLinkAPI api;
  final FlightModeManager modeManager;
  final ArmDisarmManager armManager;

  PreflightSequence(this.api, this.modeManager, this.armManager);

  Future<bool> executePreflightSequence() async {
    print('Starting preflight sequence...');

    // Step 1: Check connection
    if (!api.isConnected) {
      print('❌ Not connected to drone');
      return false;
    }
    print('✅ Connected to drone');

    // Step 2: Request parameters
    print('📡 Requesting parameters...');
    api.requestAllParameters();
    await _waitForParameters();
    print('✅ Parameters received');

    // Step 3: Check GPS
    if (!api.gpsFixType.contains('3D')) {
      print('❌ Waiting for GPS fix...');
      bool gpsReady = await _waitForGPSFix();
      if (!gpsReady) {
        print('❌ GPS fix timeout');
        return false;
      }
    }
    print('✅ GPS fix obtained');

    // Step 4: Set stabilize mode
    print('🛫 Setting STABILIZE mode...');
    bool modeSet = await modeManager.setModeWithConfirmation(
        ArduPilotFlightModes.STABILIZE);
    if (!modeSet) {
      print('❌ Failed to set STABILIZE mode');
      return false;
    }
    print('✅ STABILIZE mode set');

    // Step 5: Perform pre-arm checks
    print('🔍 Performing pre-arm checks...');
    ArmingCheckResult checkResult = await armManager.performPreArmChecks();
    if (!checkResult.canArm) {
      print('❌ Pre-arm check failed: ${checkResult.reason}');
      return false;
    }
    print('✅ Pre-arm checks passed');

    print('🎉 Preflight sequence completed successfully');
    return true;
  }

  Future<void> _waitForParameters() async {
    Completer<void> completer = Completer<void>();

    api.eventStream
      .where((event) => event.type == MAVLinkEventType.allParametersReceived)
      .listen((event) {
        completer.complete();
      });

    return completer.future.timeout(Duration(seconds: 30));
  }

  Future<bool> _waitForGPSFix({Duration timeout = const Duration(minutes: 2)}) async {
    if (api.gpsFixType.contains('3D')) return true;

    Completer<bool> completer = Completer<bool>();
    late StreamSubscription subscription;

    subscription = api.eventStream
      .where((event) => event.type == MAVLinkEventType.gpsInfo)
      .listen((event) {
        String fixType = event.data['fixType'];

        if (fixType.contains('3D')) {
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

## Usage Examples

### Basic Commands

```dart
class BasicCommandExample {
  final DroneMAVLinkAPI api = DroneMAVLinkAPI();

  Future<void> demonstrateBasicCommands() async {
    // Connect to drone
    await api.connect('COM3');

    // Set stabilize mode
    api.setFlightMode(ArduPilotFlightModes.STABILIZE);
    await Future.delayed(Duration(seconds: 2));

    // Arm the drone
    api.sendArmCommand(true);
    await Future.delayed(Duration(seconds: 2));

    // Check if armed
    if (api.isArmed) {
      print('Drone is armed and ready');
    }

    // Change to auto mode
    api.setFlightMode(ArduPilotFlightModes.AUTO);
    await Future.delayed(Duration(seconds: 2));

    // Later... disarm the drone
    api.sendArmCommand(false);
  }
}
```

### Advanced Command Management

```dart
class AdvancedCommandExample {
  final DroneMAVLinkAPI api = DroneMAVLinkAPI();
  late FlightModeManager modeManager;
  late ArmDisarmManager armManager;
  late CommandQueueManager commandQueue;

  void initialize() {
    modeManager = FlightModeManager(api);
    armManager = ArmDisarmManager(api);
    commandQueue = CommandQueueManager(api);
  }

  Future<void> performSafeArming() async {
    await api.connect('COM3');

    // Perform safe arming with checks
    bool armed = await armManager.armWithPrecheck();

    if (armed) {
      print('Drone armed successfully with all checks passed');
    } else {
      print('Arming failed - check drone status');
    }
  }

  void queueFlightSequence() {
    // Queue a sequence of commands
    commandQueue.queueCommand(DroneCommand(CommandType.setMode,
        parameter: ArduPilotFlightModes.STABILIZE));

    commandQueue.queueCommand(DroneCommand(CommandType.arm));

    commandQueue.queueCommand(DroneCommand(CommandType.setMode,
        parameter: ArduPilotFlightModes.AUTO));
  }

  Future<void> executePreflightChecklist() async {
    PreflightSequence preflight = PreflightSequence(api, modeManager, armManager);

    bool ready = await preflight.executePreflightSequence();

    if (ready) {
      print('Drone is ready for flight');
      // Proceed with mission
    } else {
      print('Preflight checks failed');
    }
  }
}
```

## Best Practices

### 1. Always Check State Before Commands

```dart
// Check connection before sending commands
if (!api.isConnected) {
  print('Cannot send command: not connected');
  return;
}

// Check current state before arming
if (api.isArmed) {
  print('Drone is already armed');
  return;
}
```

### 2. Use Confirmation for Critical Commands

```dart
// Wait for arming confirmation
api.sendArmCommand(true);

bool armed = await _waitForArmingConfirmation();
if (armed) {
  print('Arming confirmed');
} else {
  print('Arming failed or timed out');
}
```

### 3. Implement Safety Checks

```dart
// Implement safety checks before arming
ArmingCheckResult checks = await performPreArmChecks();

if (!checks.canArm) {
  print('Safety check failed: ${checks.reason}');
  return;
}

api.sendArmCommand(true);
```

### 4. Rate Limit Commands

```dart
// Don't send commands too quickly
api.setFlightMode(ArduPilotFlightModes.STABILIZE);
await Future.delayed(Duration(milliseconds: 500));

api.sendArmCommand(true);
await Future.delayed(Duration(milliseconds: 500));
```

### 5. Handle Command Failures

```dart
try {
  bool modeSet = await modeManager.setModeWithConfirmation(
      ArduPilotFlightModes.AUTO, timeout: Duration(seconds: 10));

  if (!modeSet) {
    print('Mode change timed out');
    // Handle failure - maybe retry or abort
  }
} catch (e) {
  print('Error changing mode: $e');
}
```
