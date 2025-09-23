import 'dart:async';
import 'package:flutter/material.dart';
import 'package:skylink/services/multi_drone_service.dart';

class MultiDroneWidget extends StatefulWidget {
  const MultiDroneWidget({super.key});

  @override
  State<MultiDroneWidget> createState() => _MultiDroneWidgetState();
}

class _MultiDroneWidgetState extends State<MultiDroneWidget> {
  final MultiDroneService _multiDroneService = MultiDroneService();

  // State
  Map<String, bool> _connectionStates = {};
  Map<String, Map<String, dynamic>> _telemetryData = {};
  List<String> _availablePorts = [];

  // Dynamic drone ports - can add/remove as needed
  final List<String?> _selectedPorts = [null, null]; // Start with 2 slots
  final int _maxDrones = 8; // Maximum number of drones supported

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
      // Auto-assign first few ports if available
      for (int i = 0; i < ports.length && i < _selectedPorts.length; i++) {
        if (_selectedPorts[i] == null) {
          _selectedPorts[i] = ports[i];
        }
      }
    });
  }

  // Add new drone slot
  void _addDroneSlot() {
    if (_selectedPorts.length < _maxDrones) {
      setState(() {
        _selectedPorts.add(null);
      });
    }
  }

  // Remove drone slot
  void _removeDroneSlot(int index) {
    if (_selectedPorts.length > 1) {
      final droneId = 'drone_${index + 1}';
      _multiDroneService.removeDrone(droneId);
      setState(() {
        _selectedPorts.removeAt(index);
      });
    }
  }

  Future<void> _connectDrone(int index) async {
    if (_selectedPorts[index] == null) {
      _showSnackBar('Please select port for Drone ${index + 1}');
      return;
    }

    // Check for duplicate ports
    for (int i = 0; i < _selectedPorts.length; i++) {
      if (i != index && _selectedPorts[i] == _selectedPorts[index]) {
        _showSnackBar('Port already in use by another drone');
        return;
      }
    }

    _showLoadingDialog('Connecting Drone ${index + 1}...');

    try {
      final success = await _multiDroneService.addDrone(
        'drone_${index + 1}',
        _selectedPorts[index]!,
      );
      Navigator.of(context).pop(); // Close loading dialog

      if (success) {
        _showSnackBar('Drone ${index + 1} connected successfully');
      } else {
        _showSnackBar('Failed to connect Drone ${index + 1}');
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showSnackBar('Error connecting Drone ${index + 1}: $e');
    }
  }

  Future<void> _disconnectDrone(int index) async {
    final droneId = 'drone_${index + 1}';
    await _multiDroneService.removeDrone(droneId);
    _showSnackBar('Drone ${index + 1} disconnected');
  }

  Future<void> _connectAllDrones() async {
    // Validate all ports selected and unique
    final selectedNonNullPorts = _selectedPorts
        .where((port) => port != null)
        .toList();
    if (selectedNonNullPorts.isEmpty) {
      _showSnackBar('Please select at least one port');
      return;
    }

    if (selectedNonNullPorts.length != selectedNonNullPorts.toSet().length) {
      _showSnackBar('Please select unique ports for each drone');
      return;
    }

    _showLoadingDialog('Connecting all drones...');

    try {
      final futures = <Future>[];
      for (int i = 0; i < _selectedPorts.length; i++) {
        if (_selectedPorts[i] != null) {
          futures.add(
            _multiDroneService.addDrone('drone_${i + 1}', _selectedPorts[i]!),
          );
        }
      }

      final results = await Future.wait(futures);
      Navigator.of(context).pop();

      final successCount = results.where((success) => success == true).length;
      _showSnackBar(
        'Connected $successCount/${results.length} drones successfully',
      );
    } catch (e) {
      Navigator.of(context).pop();
      _showSnackBar('Error connecting drones: $e');
    }
  }

  Future<void> _disconnectAllDrones() async {
    await _multiDroneService.disconnectAll();
    _showSnackBar('All drones disconnected');
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _telemetrySubscription?.cancel();
    super.dispose();
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Multi-Drone Control (${_selectedPorts.length} Drones)'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _addDroneSlot,
            icon: Icon(Icons.add),
            tooltip: 'Add Drone Slot',
          ),
          IconButton(
            onPressed: _loadAvailablePorts,
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh Ports',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.shade100, Colors.grey.shade300],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              _buildControlPanel(),
              SizedBox(height: 16),
              Expanded(child: _buildDronesList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Control Panel',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _connectAllDrones,
                    icon: Icon(Icons.connect_without_contact),
                    label: Text('Connect All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _disconnectAllDrones,
                    icon: Icon(Icons.power_off),
                    label: Text('Disconnect All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Available Ports: ${_availablePorts.length}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDronesList() {
    return ListView.builder(
      itemCount: _selectedPorts.length,
      itemBuilder: (context, index) {
        return _buildDroneCard(index);
      },
    );
  }

  Widget _buildDroneCard(int index) {
    final droneId = 'drone_${index + 1}';
    final isConnected = _connectionStates[droneId] ?? false;
    final telemetry = _telemetryData[droneId] ?? {};

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.memory,
                  color: isConnected ? Colors.green : Colors.grey,
                ),
                SizedBox(width: 8),
                Text(
                  'Drone ${index + 1}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                if (_selectedPorts.length > 1)
                  IconButton(
                    onPressed: () => _removeDroneSlot(index),
                    icon: Icon(Icons.remove_circle, color: Colors.red),
                    tooltip: 'Remove Drone',
                  ),
              ],
            ),
            SizedBox(height: 12),

            // Port Selection
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedPorts[index],
                    decoration: InputDecoration(
                      labelText: 'Port',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: _availablePorts.map((port) {
                      return DropdownMenuItem(value: port, child: Text(port));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPorts[index] = value;
                      });
                    },
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: isConnected
                      ? () => _disconnectDrone(index)
                      : () => _connectDrone(index),
                  icon: Icon(
                    isConnected
                        ? Icons.power_off
                        : Icons.connect_without_contact,
                  ),
                  label: Text(isConnected ? 'Disconnect' : 'Connect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Connection Status
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isConnected
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isConnected ? Colors.green : Colors.red,
                ),
              ),
              child: Text(
                isConnected ? 'Connected' : 'Disconnected',
                style: TextStyle(
                  color: isConnected
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            if (isConnected) ...[
              SizedBox(height: 12),
              _buildTelemetrySection(telemetry),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetrySection(Map<String, dynamic> data) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Telemetry Data', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildTelemetryItem(
                'Battery',
                '${(data['battery'] ?? 0.0).toStringAsFixed(1)}%',
              ),
              _buildTelemetryItem('Armed', data['armed'] == 1.0 ? "Yes" : "No"),
              _buildTelemetryItem(
                'Altitude',
                '${(data['gps_altitude'] ?? 0.0).toStringAsFixed(1)}m',
              ),
              _buildTelemetryItem(
                'Speed',
                '${(data['groundspeed'] ?? 0.0).toStringAsFixed(1)} m/s',
              ),
              _buildTelemetryItem(
                'Yaw',
                '${(data['yaw'] ?? 0.0).toStringAsFixed(1)}°',
              ),
              _buildTelemetryItem(
                'Roll',
                '${(data['roll'] ?? 0.0).toStringAsFixed(1)}°',
              ),
              _buildTelemetryItem(
                'Pitch',
                '${(data['pitch'] ?? 0.0).toStringAsFixed(1)}°',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryItem(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
