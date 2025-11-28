import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:skylink/presentation/widget/flight/drone_map_widget.dart';
import 'package:skylink/services/telemetry_service.dart';

void main() {
  runApp(const DroneMapSimulationApp());
}

class DroneMapSimulationApp extends StatelessWidget {
  const DroneMapSimulationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drone Map Simulation',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blue,
          secondary: Colors.orange,
        ),
      ),
      home: const SimulationScreen(),
    );
  }
}

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  final TelemetryService _telemetryService = TelemetryService();

  // Simulation State
  bool _isConnected = false;
  bool _isArmed = false;
  String _gpsFixType = 'No GPS';

  // Drone Position
  double _lat = 10.7302; // Default Home
  double _lon = 106.6988;
  double _alt = 0.0;
  double _yaw = 0.0;

  // Auto Flight
  Timer? _flightTimer;
  bool _isAutoFlying = false;
  double _flightAngle = 0.0;
  final double _flightRadius = 0.0005; // ~50m radius
  final double _centerLat = 10.7302;
  final double _centerLon = 106.6988;

  @override
  void initState() {
    super.initState();
    // Start simulation loop
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _updateSimulation();
    });
  }

  void _updateSimulation() {
    if (_isAutoFlying) {
      setState(() {
        _flightAngle += 0.05; // Speed
        if (_flightAngle > 2 * math.pi) _flightAngle -= 2 * math.pi;

        // Circular path
        _lat = _centerLat + _flightRadius * math.sin(_flightAngle);
        _lon = _centerLon + _flightRadius * math.cos(_flightAngle);

        // Yaw follows path (tangent)
        _yaw = (_flightAngle * 180 / math.pi) + 90;
        if (_yaw > 360) _yaw -= 360;

        // Altitude variation
        _alt = 20 + 5 * math.sin(_flightAngle * 2);
      });
    }

    // Send data to TelemetryService
    _telemetryService.simulateTelemetry({
      'connected': _isConnected,
      'gps_fix_type': _gpsFixType,
      'armed': _isArmed,
      'mode': _isArmed ? 'GUIDED' : 'STABILIZE',
      'gps_latitude': _lat,
      'gps_longitude': _lon,
      'gps_altitude': _alt,
      'yaw': _yaw,
      'roll': 0.0,
      'pitch': 0.0,
      'satellites': 12,
    });
  }

  void _toggleAutoFlight() {
    setState(() {
      _isAutoFlying = !_isAutoFlying;
      if (_isAutoFlying) {
        // Reset to circle start
        _lat = _centerLat;
        _lon = _centerLon + _flightRadius;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drone Map Visual Simulation')),
      body: Row(
        children: [
          // Left: Map
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const DroneMapWidget(),
            ),
          ),

          // Right: Controls
          Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xFF2C2C2C),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Telemetry Controls',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),

                  // Connection
                  SwitchListTile(
                    title: const Text('Connection'),
                    subtitle: Text(_isConnected ? 'Connected' : 'Disconnected'),
                    value: _isConnected,
                    onChanged: (val) => setState(() => _isConnected = val),
                  ),

                  // GPS Fix
                  const Text('GPS Fix Type:'),
                  DropdownButton<String>(
                    value: _gpsFixType,
                    isExpanded: true,
                    items:
                        ['No GPS', '2D Fix', '3D Fix', 'RTK Float', 'RTK Fixed']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                    onChanged: (val) => setState(() => _gpsFixType = val!),
                  ),
                  const SizedBox(height: 16),

                  // Arming
                  SwitchListTile(
                    title: const Text('Arming'),
                    subtitle: Text(_isArmed ? 'ARMED' : 'DISARMED'),
                    value: _isArmed,
                    activeColor: Colors.red,
                    onChanged: _isConnected
                        ? (val) => setState(() => _isArmed = val)
                        : null,
                  ),
                  const Divider(),

                  // Auto Flight
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _isConnected && _gpsFixType != 'No GPS'
                          ? _toggleAutoFlight
                          : null,
                      icon: Icon(_isAutoFlying ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        _isAutoFlying
                            ? 'Stop Auto Flight'
                            : 'Start Auto Flight',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isAutoFlying
                            ? Colors.red
                            : Colors.green,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Manual Controls
                  if (!_isAutoFlying) ...[
                    const Text('Manual Control'),
                    _buildSlider('Lat', _lat, 10.72, 10.74, (v) => _lat = v),
                    _buildSlider('Lon', _lon, 106.69, 106.71, (v) => _lon = v),
                    _buildSlider('Alt', _alt, 0, 100, (v) => _alt = v),
                    _buildSlider('Yaw', _yaw, 0, 360, (v) => _yaw = v),
                  ],

                  const Spacer(),
                  const Text(
                    'Instructions:\n'
                    '1. Connect\n'
                    '2. Set GPS to 3D/RTK\n'
                    '3. Arm (Sets Home Point)\n'
                    '4. Start Auto Flight or use Sliders\n'
                    '5. Disconnect to test Ghost Mode',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(6)}'),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: (val) {
            setState(() {
              onChanged(val);
            });
          },
        ),
      ],
    );
  }
}
