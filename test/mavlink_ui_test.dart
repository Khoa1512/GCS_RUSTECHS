import 'package:flutter/material.dart';
import 'dart:async';
import 'package:skylink/api/telemetry/mavlink_api.dart';

void main() {
  runApp(MAVLinkTestApp());
}

class MAVLinkTestApp extends StatelessWidget {
  const MAVLinkTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MAVLink API Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MAVLinkDashboard(),
    );
  }
}

class MAVLinkDashboard extends StatefulWidget {
  const MAVLinkDashboard({super.key});

  @override
  _MAVLinkDashboardState createState() => _MAVLinkDashboardState();
}

class _MAVLinkDashboardState extends State<MAVLinkDashboard> {
  late DroneMAVLinkAPI _api;
  late StreamSubscription _eventSubscription;

  // Connection state
  bool _isConnected = false;
  String _selectedPort = '';
  List<String> _availablePorts = [];

  // Vehicle state
  String _flightMode = 'Unknown';
  bool _isArmed = false;
  String _gpsFixType = 'No GPS';
  int _satellites = 0;
  int _batteryPercent = 0;
  double _batteryVoltage = 0.0;

  // Attitude data
  double _roll = 0.0;
  double _pitch = 0.0;
  double _yaw = 0.0;

  // Position data
  double _latitude = 0.0;
  double _longitude = 0.0;
  double _altitudeMSL = 0.0;
  double _altitudeRelative = 0.0;

  // Speed data
  double _airspeed = 0.0;
  double _groundspeed = 0.0;

  // Status messages
  final List<String> _statusMessages = [];

  // Parameters
  Map<String, double> _parameters = {};
  bool _parametersLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeAPI();
  }

  void _initializeAPI() {
    _api = DroneMAVLinkAPI();

    // Listen to all MAVLink events
    _eventSubscription = _api.eventStream.listen(_handleMAVLinkEvent);

    // Get available ports
    _refreshPorts();
  }

  void _refreshPorts() {
    setState(() {
      _availablePorts = _api.getAvailablePorts();
      if (_availablePorts.isNotEmpty && _selectedPort.isEmpty) {
        _selectedPort = _availablePorts.first;
      }
    });
  }

  void _handleMAVLinkEvent(MAVLinkEvent event) {
    if (!mounted) return;

    setState(() {
      switch (event.type) {
        case MAVLinkEventType.connectionStateChanged:
          _isConnected = event.data == MAVLinkConnectionState.connected;
          break;

        case MAVLinkEventType.heartbeat:
          _flightMode = event.data['mode'] ?? 'Unknown';
          _isArmed = event.data['armed'] ?? false;
          break;

        case MAVLinkEventType.attitude:
          _roll = event.data['roll'] ?? 0.0;
          _pitch = event.data['pitch'] ?? 0.0;
          _yaw = event.data['yaw'] ?? 0.0;
          break;

        case MAVLinkEventType.position:
          _latitude = event.data['lat'] ?? 0.0;
          _longitude = event.data['lon'] ?? 0.0;
          _altitudeMSL = event.data['altMSL'] ?? 0.0;
          _altitudeRelative = event.data['altRelative'] ?? 0.0;
          break;

        case MAVLinkEventType.gpsInfo:
          _gpsFixType = event.data['fixType'] ?? 'No GPS';
          _satellites = event.data['satellites'] ?? 0;
          break;

        case MAVLinkEventType.batteryStatus:
          _batteryPercent = event.data['batteryPercent'] ?? 0;
          _batteryVoltage = event.data['voltageBattery'] ?? 0.0;
          break;

        case MAVLinkEventType.vfrHud:
          _airspeed = event.data['airspeed'] ?? 0.0;
          _groundspeed = event.data['groundspeed'] ?? 0.0;
          break;

        case MAVLinkEventType.statusText:
          String severity = event.data['severity'] ?? 'Info';
          String text = event.data['text'] ?? '';
          _addStatusMessage('[$severity] $text');
          break;

        case MAVLinkEventType.allParametersReceived:
          _parameters = Map<String, double>.from(event.data);
          _parametersLoaded = true;
          _addStatusMessage('Received ${_parameters.length} parameters');
          break;

        case MAVLinkEventType.parameterReceived:
          String paramName = event.data['id'] ?? '';
          double paramValue = event.data['value'] ?? 0.0;
          _parameters[paramName] = paramValue;
          break;
      }
    });
  }

  void _addStatusMessage(String message) {
    _statusMessages.insert(0, '${DateTime.now().toLocal().toString().substring(11, 19)}: $message');
    if (_statusMessages.length > 50) {
      _statusMessages.removeLast();
    }
  }

  Future<void> _connect() async {
    if (_selectedPort.isEmpty) {
      _showSnackBar('Please select a port');
      return;
    }

    _addStatusMessage('Connecting to $_selectedPort...');
    bool success = await _api.connect(_selectedPort, baudRate: 115200);

    if (success) {
      _addStatusMessage('Connected successfully');
      // Request parameters after connection
      Future.delayed(Duration(seconds: 2), () {
        _api.requestAllParameters();
      });
    } else {
      _addStatusMessage('Connection failed');
    }
  }

  void _disconnect() {
    _api.disconnect();
    _addStatusMessage('Disconnected');
  }

  void _armDrone() {
    if (!_isConnected) {
      _showSnackBar('Not connected to drone');
      return;
    }

    _api.sendArmCommand(true);
    _addStatusMessage('Arming command sent');
  }

  void _disarmDrone() {
    if (!_isConnected) {
      _showSnackBar('Not connected to drone');
      return;
    }

    _api.sendArmCommand(false);
    _addStatusMessage('Disarming command sent');
  }

  void _setFlightMode(int mode, String modeName) {
    if (!_isConnected) {
      _showSnackBar('Not connected to drone');
      return;
    }

    _api.setFlightMode(mode);
    _addStatusMessage('Set flight mode to $modeName');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MAVLink API Test Dashboard'),
        backgroundColor: _isConnected ? Colors.green : Colors.red,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshPorts,
            tooltip: 'Refresh Ports',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection Panel
            _buildConnectionPanel(),

            SizedBox(height: 16),

            // Main content
            Expanded(
              child: Row(
                children: [
                  // Left column - Vehicle Status
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        _buildVehicleStatusPanel(),
                        SizedBox(height: 16),
                        _buildAttitudePanel(),
                        SizedBox(height: 16),
                        _buildPositionPanel(),
                      ],
                    ),
                  ),

                  SizedBox(width: 16),

                  // Right column - Controls and Messages
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildControlPanel(),
                        SizedBox(height: 16),
                        _buildParametersPanel(),
                        SizedBox(height: 16),
                        _buildStatusMessagesPanel(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionPanel() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedPort.isEmpty ? null : _selectedPort,
                    hint: Text('Select Port'),
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
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isConnected ? _disconnect : _connect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isConnected ? Colors.red : Colors.green,
                  ),
                  child: Text(_isConnected ? 'Disconnect' : 'Connect'),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _isConnected ? Icons.link : Icons.link_off,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  _isConnected ? 'Connected to $_selectedPort' : 'Disconnected',
                  style: TextStyle(
                    color: _isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleStatusPanel() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vehicle Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildStatusRow('Flight Mode', _flightMode, _getFlightModeColor()),
            _buildStatusRow('Armed', _isArmed ? 'YES' : 'NO', _isArmed ? Colors.red : Colors.green),
            _buildStatusRow('GPS Fix', _gpsFixType, _getGPSColor()),
            _buildStatusRow('Satellites', '$_satellites', _getSatelliteColor()),
            _buildBatteryRow(),
            _buildSpeedRow(),
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
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryRow() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Battery', style: TextStyle(fontWeight: FontWeight.w500)),
          Row(
            children: [
              Icon(
                Icons.battery_full,
                color: _getBatteryColor(),
                size: 20,
              ),
              SizedBox(width: 4),
              Text(
                '$_batteryPercent% (${_batteryVoltage.toStringAsFixed(1)}V)',
                style: TextStyle(
                  color: _getBatteryColor(),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedRow() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Speed', style: TextStyle(fontWeight: FontWeight.w500)),
          Text(
            'Air: ${_airspeed.toStringAsFixed(1)} m/s | Ground: ${_groundspeed.toStringAsFixed(1)} m/s',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAttitudePanel() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attitude',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttitudeIndicator('Roll', _roll, Colors.red),
                _buildAttitudeIndicator('Pitch', _pitch, Colors.green),
                _buildAttitudeIndicator('Yaw', _yaw, Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttitudeIndicator(String label, double angle, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
        SizedBox(height: 8),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(40),
          ),
          child: Center(
            child: Text(
              '${angle.toStringAsFixed(1)}°',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPositionPanel() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Position',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildStatusRow('Latitude', _latitude.toStringAsFixed(6), Colors.black),
            _buildStatusRow('Longitude', _longitude.toStringAsFixed(6), Colors.black),
            _buildStatusRow('Altitude MSL', '${_altitudeMSL.toStringAsFixed(1)} m', Colors.black),
            _buildStatusRow('Altitude Relative', '${_altitudeRelative.toStringAsFixed(1)} m', Colors.black),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // Arm/Disarm buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnected && !_isArmed ? _armDrone : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('ARM'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnected && _isArmed ? _disarmDrone : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('DISARM'),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Flight mode buttons
            Text('Flight Modes:', style: TextStyle(fontWeight: FontWeight.w500)),
            SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildModeButton('STABILIZE', 2),
                _buildModeButton('AUTO', 9),
                _buildModeButton('RTL', 10),
                _buildModeButton('LOITER', 11),
                _buildModeButton('GUIDED', 14),
              ],
            ),

            SizedBox(height: 16),

            // Parameter request button
            ElevatedButton(
              onPressed: _isConnected ? () => _api.requestAllParameters() : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('Request Parameters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String modeName, int modeNumber) {
    bool isCurrentMode = _flightMode == modeName;

    return ElevatedButton(
      onPressed: _isConnected ? () => _setFlightMode(modeNumber, modeName) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isCurrentMode ? Colors.orange : Colors.grey,
        foregroundColor: Colors.white,
      ),
      child: Text(modeName),
    );
  }

  Widget _buildParametersPanel() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Parameters',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_parameters.length} loaded',
                  style: TextStyle(
                    color: _parametersLoaded ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            if (_parameters.isNotEmpty) ...[
              SizedBox(
                height: 150,
                child: ListView.builder(
                  itemCount: _parameters.length,
                  itemBuilder: (context, index) {
                    String key = _parameters.keys.elementAt(index);
                    double value = _parameters[key]!;

                    return ListTile(
                      dense: true,
                      title: Text(key, style: TextStyle(fontSize: 12)),
                      trailing: Text(
                        value.toStringAsFixed(2),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              Center(
                child: Text(
                  'No parameters loaded',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMessagesPanel() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status Messages',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _statusMessages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _statusMessages[index],
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getFlightModeColor() {
    switch (_flightMode) {
      case 'STABILIZE':
        return Colors.green;
      case 'AUTO':
        return Colors.blue;
      case 'RTL':
        return Colors.orange;
      case 'LOITER':
        return Colors.purple;
      case 'GUIDED':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Color _getGPSColor() {
    if (_gpsFixType.contains('3D') || _gpsFixType.contains('RTK')) {
      return Colors.green;
    } else if (_gpsFixType.contains('2D')) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Color _getSatelliteColor() {
    if (_satellites >= 8) return Colors.green;
    if (_satellites >= 6) return Colors.orange;
    return Colors.red;
  }

  Color _getBatteryColor() {
    if (_batteryPercent > 50) return Colors.green;
    if (_batteryPercent > 25) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    _api.dispose();
    super.dispose();
  }
}
