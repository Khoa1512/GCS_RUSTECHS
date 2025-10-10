import 'dart:async';
import 'package:flutter/material.dart';
import 'package:skylink/services/multi_drone_service.dart';

class SimpleDualDroneWidget extends StatefulWidget {
  const SimpleDualDroneWidget({super.key});

  @override
  State<SimpleDualDroneWidget> createState() => _SimpleDualDroneWidgetState();
}

class _SimpleDualDroneWidgetState extends State<SimpleDualDroneWidget> {
  final MultiDroneService _multiDroneService = MultiDroneService();

  // State
  Map<String, bool> _connectionStates = {};
  Map<String, Map<String, dynamic>> _telemetryData = {};
  List<String> _availablePorts = [];

  // Controllers
  String? _selectedPort1;
  String? _selectedPort2;

  // Subscriptions
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _telemetrySubscription;

  @override
  void initState() {
    super.initState();
    _initializeService();
    _loadAvailablePorts();
  }

  void _initializeService() {
    // Listen to connection states
    _connectionSubscription = _multiDroneService.connectionStateStream.listen((
      states,
    ) {
      if (mounted) {
        setState(() {
          _connectionStates = states;
        });
      }
    });

    // Listen to telemetry data
    _telemetrySubscription = _multiDroneService.telemetryDataStream.listen((
      data,
    ) {
      if (mounted) {
        setState(() {
          _telemetryData = data;
        });
      }
    });
  }

  void _loadAvailablePorts() {
    final ports = _multiDroneService.getAvailablePorts();
    setState(() {
      _availablePorts = ports;
      if (ports.isNotEmpty && _selectedPort1 == null) {
        _selectedPort1 = ports.first;
      }
      if (ports.length > 1 && _selectedPort2 == null) {
        _selectedPort2 = ports[1];
      }
    });
  }

  Future<void> _connectDrone1() async {
    if (_selectedPort1 == null) {
      _showSnackBar('Please select port for Drone 1');
      return;
    }

    _showLoadingDialog('Connecting Drone 1...');

    try {
      final success = await _multiDroneService.addDrone(
        'drone_1',
        _selectedPort1!,
      );
      Navigator.of(context).pop(); // Close loading dialog

      if (success) {
        _showSnackBar('Drone 1 connected successfully');
      } else {
        _showSnackBar('Failed to connect Drone 1');
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showSnackBar('Error connecting Drone 1: $e');
    }
  }

  Future<void> _connectDrone2() async {
    if (_selectedPort2 == null) {
      _showSnackBar('Please select port for Drone 2');
      return;
    }

    if (_selectedPort2 == _selectedPort1) {
      _showSnackBar('Please select different ports for each drone');
      return;
    }

    _showLoadingDialog('Connecting Drone 2...');

    try {
      final success = await _multiDroneService.addDrone(
        'drone_2',
        _selectedPort2!,
      );
      Navigator.of(context).pop(); // Close loading dialog

      if (success) {
        _showSnackBar('Drone 2 connected successfully');
      } else {
        _showSnackBar('Failed to connect Drone 2');
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showSnackBar('Error connecting Drone 2: $e');
    }
  }

  Future<void> _disconnectDrone1() async {
    await _multiDroneService.removeDrone('drone_1');
    _showSnackBar('Drone 1 disconnected');
  }

  Future<void> _disconnectDrone2() async {
    await _multiDroneService.removeDrone('drone_2');
    _showSnackBar('Drone 2 disconnected');
  }

  Future<void> _connectBothDrones() async {
    if (_selectedPort1 == null || _selectedPort2 == null) {
      _showSnackBar('Please select ports for both drones');
      return;
    }

    if (_selectedPort1 == _selectedPort2) {
      _showSnackBar('Please select different ports for each drone');
      return;
    }

    _showLoadingDialog('Connecting both drones...');

    try {
      // Connect drone 1
      final success1 = await _multiDroneService.addDrone(
        'drone_1',
        _selectedPort1!,
      );

      // Connect drone 2
      final success2 = await _multiDroneService.addDrone(
        'drone_2',
        _selectedPort2!,
      );

      Navigator.of(context).pop(); // Close loading dialog

      if (success1 && success2) {
        _showSnackBar('Both drones connected successfully');
      } else if (success1) {
        _showSnackBar('Only Drone 1 connected');
      } else if (success2) {
        _showSnackBar('Only Drone 2 connected');
      } else {
        _showSnackBar('Failed to connect both drones');
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showSnackBar('Error connecting drones: $e');
    }
  }

  Future<void> _disconnectAll() async {
    await _multiDroneService.disconnectAllOptimized();
    _showSnackBar('All drones disconnected');
  }

  Future<void> _armAll() async {
    await _multiDroneService.sendCommandToAllParallel('arm');
    _showSnackBar('Arm command sent to all drones');
  }

  Future<void> _disarmAll() async {
    await _multiDroneService.sendCommandToAllParallel('disarm');
    _showSnackBar('Disarm command sent to all drones');
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.flight, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Dual Drone Connection Test',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadAvailablePorts,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh ports',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status
            _buildStatusSection(),
            const SizedBox(height: 16),

            // Port selection
            _buildPortSelection(),
            const SizedBox(height: 16),

            // Individual drone controls
            _buildIndividualControls(),
            const SizedBox(height: 16),

            // Batch controls
            _buildBatchControls(),
            const SizedBox(height: 16),

            // Telemetry display
            _buildTelemetryDisplay(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    final connectedCount = _connectionStates.values
        .where((connected) => connected)
        .length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connected Drones: $connectedCount / 2'),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildDroneStatus(
                'Drone 1',
                _connectionStates['drone_1'] ?? false,
              ),
              const SizedBox(width: 16),
              _buildDroneStatus(
                'Drone 2',
                _connectionStates['drone_2'] ?? false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDroneStatus(String name, bool connected) {
    return Row(
      children: [
        Icon(
          connected ? Icons.flight : Icons.flight_takeoff_outlined,
          color: connected ? Colors.green : Colors.grey,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '$name: ${connected ? "Connected" : "Disconnected"}',
          style: TextStyle(
            color: connected ? Colors.green : Colors.grey,
            fontWeight: connected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildPortSelection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Port Selection',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedPort1,
                  decoration: const InputDecoration(
                    labelText: 'Drone 1 Port',
                    border: OutlineInputBorder(),
                  ),
                  items: _availablePorts.map((port) {
                    return DropdownMenuItem(value: port, child: Text(port));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPort1 = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedPort2,
                  decoration: const InputDecoration(
                    labelText: 'Drone 2 Port',
                    border: OutlineInputBorder(),
                  ),
                  items: _availablePorts.map((port) {
                    return DropdownMenuItem(value: port, child: Text(port));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPort2 = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualControls() {
    final drone1Connected = _connectionStates['drone_1'] ?? false;
    final drone2Connected = _connectionStates['drone_2'] ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Individual Controls',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Drone 1 controls
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Drone 1',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: drone1Connected ? null : _connectDrone1,
                      child: const Text('Connect'),
                    ),
                    const SizedBox(height: 4),
                    ElevatedButton(
                      onPressed: drone1Connected ? _disconnectDrone1 : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Drone 2 controls
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Drone 2',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: drone2Connected ? null : _connectDrone2,
                      child: const Text('Connect'),
                    ),
                    const SizedBox(height: 4),
                    ElevatedButton(
                      onPressed: drone2Connected ? _disconnectDrone2 : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatchControls() {
    final hasConnectedDrones = _connectionStates.values.any(
      (connected) => connected,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Batch Controls',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: _connectBothDrones,
                child: const Text('Connect Both'),
              ),
              ElevatedButton(
                onPressed: hasConnectedDrones ? _disconnectAll : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Disconnect All'),
              ),
              ElevatedButton(
                onPressed: hasConnectedDrones ? _armAll : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Arm All'),
              ),
              ElevatedButton(
                onPressed: hasConnectedDrones ? _disarmAll : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Disarm All'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryDisplay() {
    if (_telemetryData.isEmpty) {
      return const Text('No telemetry data available');
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Telemetry Data',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._telemetryData.entries.map((entry) {
            final droneId = entry.key;
            final data = entry.value;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      droneId.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Battery: ${(data['battery'] ?? 0.0).toStringAsFixed(1)}%',
                    ),
                    Text('Armed: ${data['armed'] == 1.0 ? "Yes" : "No"}'),
                    Text(
                      'Altitude: ${(data['gps_altitude'] ?? 0.0).toStringAsFixed(1)}m',
                    ),
                    Text(
                      'Speed: ${(data['groundspeed'] ?? 0.0).toStringAsFixed(1)} m/s',
                    ),
                    const SizedBox(height: 4),
                    Text('Yaw: ${(data['yaw'] ?? 0.0).toStringAsFixed(1)}°'),
                    Text('Roll: ${(data['roll'] ?? 0.0).toStringAsFixed(1)}°'),
                    Text(
                      'Pitch: ${(data['pitch'] ?? 0.0).toStringAsFixed(1)}°',
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _telemetrySubscription?.cancel();
    super.dispose();
  }
}
