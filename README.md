# VTOL FE (Flutter Frontend)

Flutter frontend for the VTOL GCS. This app provides telemetry, control, and UI components for interacting with VTOL drones.

## Telemetry / MAVLink API

The MAVLink API has been refactored into a modular architecture by EventType. Start here:

- lib/api/telemetry/README.md — Modular MAVLink documentation
- lib/api/telemetry/mavlink_api.dart — Barrel export preserving legacy imports
- lib/api/telemetry/mavlink/ — Core modules and handlers

Quick import:

```dart
import 'package:vtol_fe/api/telemetry/mavlink_api.dart';
```

See the telemetry README for connection, events, parameters, and commands.

## Development

- Flutter: 3.x+
- Dart: 3.x+

Run the app as usual with Flutter tooling. Follow the telemetry docs for serial/MAVLink specifics.
