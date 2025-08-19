import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:skylink/api/telemetry/mavlink_api.dart';

/// Simple MAVLink API Demo
/// Ví dụ đơn giản để test kết nối và nhận dữ liệu từ drone
void main() {
  runApp(SimpleMAVLinkDemo());
}

class SimpleMAVLinkDemo extends StatelessWidget {
  const SimpleMAVLinkDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple MAVLink Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MAVLinkSimpleTest(),
    );
  }
}

class MAVLinkSimpleTest extends StatefulWidget {
  const MAVLinkSimpleTest({super.key});

  @override
  _MAVLinkSimpleTestState createState() => _MAVLinkSimpleTestState();
}

class _MAVLinkSimpleTestState extends State<MAVLinkSimpleTest> {
  late DroneMAVLinkAPI _api;
  late StreamSubscription _eventSubscription;

  bool _isConnected = false;
  String _selectedPort = '';
  List<String> _availablePorts = [];

  // Basic telemetry data
  String _flightMode = 'Unknown';
  bool _isArmed = false;
  double _roll = 0.0;
  double _pitch = 0.0;
  double _yaw = 0.0;
  int _batteryPercent = 0;
  String _lastMessage = '';

  @override
  void initState() {
    super.initState();
    _initAPI();
  }

  void _initAPI() {
    _api = DroneMAVLinkAPI();

    // Listen to MAVLink events
    _eventSubscription = _api.eventStream.listen((event) {
      if (!mounted) return;

      setState(() {
        switch (event.type) {
          case MAVLinkEventType.connectionStateChanged:
            _isConnected = event.data == MAVLinkConnectionState.connected;
            _lastMessage = 'Connection state: ${event.data}';
            break;

          case MAVLinkEventType.heartbeat:
            _flightMode = event.data['mode'] ?? 'Unknown';
            _isArmed = event.data['armed'] ?? false;
            _lastMessage = 'Heartbeat: Mode=$_flightMode, Armed=$_isArmed';
            break;

          case MAVLinkEventType.attitude:
            _roll = event.data['roll'] ?? 0.0;
            _pitch = event.data['pitch'] ?? 0.0;
            _yaw = event.data['yaw'] ?? 0.0;
            _lastMessage =
                'Attitude: R=${_roll.toStringAsFixed(1)}°, P=${_pitch.toStringAsFixed(1)}°, Y=${_yaw.toStringAsFixed(1)}°';
            break;

          case MAVLinkEventType.batteryStatus:
            _batteryPercent = event.data['batteryPercent'] ?? 0;
            _lastMessage = 'Battery: $_batteryPercent%';
            break;

          case MAVLinkEventType.statusText:
            String text = event.data['text'] ?? '';
            _lastMessage = 'Status: $text';
            break;

          default:
            _lastMessage = 'Event: ${event.type}';
            break;
        }
      });
    });

    // Get available ports
    _refreshPorts();
  }

  void _refreshPorts() {
    setState(() {
  _availablePorts = SerialPort.availablePorts;
      if (_availablePorts.isNotEmpty && _selectedPort.isEmpty) {
        _selectedPort = _availablePorts.first;
      }
    });
  }

  Future<void> _connect() async {
    if (_selectedPort.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select a port')));
      return;
    }

    setState(() {
      _lastMessage = 'Connecting to $_selectedPort...';
    });

  // Try common baud rates (adjust as needed)
  List<int> baudRates = [115200, 57600, 38400, 9600];
    bool connected = false;

    for (int baudRate in baudRates) {
      setState(() {
        _lastMessage = 'Trying $_selectedPort at $baudRate baud...';
      });

      await _api.connect(_selectedPort, baudRate: baudRate);

      if (_api.isConnected) {
        setState(() {
          _isConnected = true;
          _lastMessage = 'Connected to $_selectedPort at $baudRate baud!';
        });
        // Request standard data streams
        _api.requestAllDataStreams();
        connected = true;
        break;
      } else {
        setState(() {
          _lastMessage = 'Failed at $baudRate baud, trying next...';
        });
        // Small delay between attempts
        await Future.delayed(Duration(milliseconds: 500));
      }
    }

    if (!connected) {
      setState(() {
        _lastMessage = 'Failed to connect to $_selectedPort at all baud rates';
      });
    }
  }

  void _disconnect() {
    _api.disconnect();
    setState(() {
      _lastMessage = 'Disconnected';
    });
  }

  void _armDisarm() {
    if (!_isConnected) return;

    _api.sendArmCommand(!_isArmed);
    setState(() {
      _lastMessage = _isArmed ? 'Disarm command sent' : 'Arm command sent';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Simple MAVLink Demo'),
        backgroundColor: _isConnected ? Colors.green : Colors.red,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Connection',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),

                    // Port selection
                    DropdownButton<String>(
                      value: _selectedPort.isEmpty ? null : _selectedPort,
                      hint: Text('Select Port'),
                      isExpanded: true,
                      items: _availablePorts.map((port) {
                        return DropdownMenuItem<String>(
                          value: port,
                          child: Text(port),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPort = value ?? '';
                        });
                      },
                    ),

                    SizedBox(height: 10),

                    // Connection buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isConnected ? _disconnect : _connect,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isConnected
                                  ? Colors.red
                                  : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              _isConnected ? 'Disconnect' : 'Connect',
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _refreshPorts,
                            child: Text('Refresh Ports'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Status Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),

                    _buildStatusRow(
                      'Connection',
                      _isConnected ? 'CONNECTED' : 'DISCONNECTED',
                      _isConnected ? Colors.green : Colors.red,
                    ),
                    _buildStatusRow('Flight Mode', _flightMode, Colors.blue),
                    _buildStatusRow(
                      'Armed',
                      _isArmed ? 'YES' : 'NO',
                      _isArmed ? Colors.red : Colors.green,
                    ),
                    _buildStatusRow(
                      'Battery',
                      '$_batteryPercent%',
                      _batteryPercent > 30 ? Colors.green : Colors.red,
                    ),
                    _buildStatusRow(
                      'Roll',
                      '${_roll.toStringAsFixed(1)}°',
                      Colors.orange,
                    ),
                    _buildStatusRow(
                      'Pitch',
                      '${_pitch.toStringAsFixed(1)}°',
                      Colors.orange,
                    ),
                    _buildStatusRow(
                      'Yaw',
                      '${_yaw.toStringAsFixed(1)}°',
                      Colors.orange,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Control Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Basic Controls',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),

                    ElevatedButton(
                      onPressed: _isConnected ? _armDisarm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isArmed ? Colors.green : Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 40),
                      ),
                      child: Text(_isArmed ? 'DISARM' : 'ARM'),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Last Message Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Message',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      _lastMessage.isEmpty ? 'No messages yet' : _lastMessage,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    _api.dispose();
    super.dispose();
  }
}
