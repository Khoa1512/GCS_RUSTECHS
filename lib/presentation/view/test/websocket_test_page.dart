import 'package:flutter/material.dart';
import 'dart:async';
import '../../../api/5G/websocket.dart';

/// Test UI for WebSocket telemetry connection
class WebSocketTestPage extends StatefulWidget {
  const WebSocketTestPage({Key? key}) : super(key: key);

  @override
  State<WebSocketTestPage> createState() => _WebSocketTestPageState();
}

class _WebSocketTestPageState extends State<WebSocketTestPage> {
  final WebSocketTelemetryService _wsService = WebSocketTelemetryService();
  final TextEditingController _urlController = TextEditingController();

  bool _isConnected = false;
  List<Map<String, dynamic>> _receivedMessages = [];
  Map<String, dynamic>? _serverStats;
  StreamSubscription? _dataSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _statsSubscription;

  @override
  void initState() {
    super.initState();
    _urlController.text = 'ws://localhost:8765'; // Default server URL
    _setupListeners();
  }

  void _setupListeners() {
    // Connection status listener
    _connectionSubscription = _wsService.connectionStream.listen((connected) {
      setState(() {
        _isConnected = connected;
      });

      if (connected) {
        _addLogMessage('✅ Connected to WebSocket server');
      } else {
        _addLogMessage('❌ Disconnected from WebSocket server');
      }
    });

    // Data stream listener
    _dataSubscription = _wsService.dataStream.listen((data) {
      _addLogMessage('📡 Data received: ${data['type']}');

      if (data['type'] == 'telemetry_update') {
        _addTelemetryMessage(data);
      }
    });

    // Stats stream listener
    _statsSubscription = _wsService.statsStream.listen((stats) {
      setState(() {
        _serverStats = stats;
      });
      _addLogMessage('📊 Server stats updated');
    });
  }

  void _addLogMessage(String message) {
    final logEntry = {
      'type': 'log',
      'message': message,
      'timestamp': DateTime.now(),
    };

    setState(() {
      _receivedMessages.insert(0, logEntry);
      if (_receivedMessages.length > 100) {
        _receivedMessages.removeLast();
      }
    });
  }

  void _addTelemetryMessage(Map<String, dynamic> data) {
    setState(() {
      _receivedMessages.insert(0, data);
      if (_receivedMessages.length > 100) {
        _receivedMessages.removeLast();
      }
    });
  }

  void _connect() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('Please enter WebSocket URL', isError: true);
      return;
    }

    _wsService.connect(url);
    _addLogMessage('🔌 Attempting to connect to: $url');
  }

  void _disconnect() {
    _wsService.disconnect();
    _addLogMessage('🔌 Disconnecting...');
  }

  void _requestLatestData() {
    _wsService.requestLatestData();
    _addLogMessage('📡 Requesting latest data...');
  }

  void _requestServerStats() {
    _wsService.requestServerStats();
    _addLogMessage('📊 Requesting server stats...');
  }

  void _clearMessages() {
    setState(() {
      _receivedMessages.clear();
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WebSocket Telemetry Test'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.clear_all),
            onPressed: _clearMessages,
            tooltip: 'Clear messages',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Connection section
            _buildConnectionSection(),
            SizedBox(height: 16),

            // Server stats section
            if (_serverStats != null) _buildServerStatsSection(),

            // Messages section
            Expanded(child: _buildMessagesSection()),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WebSocket Connection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),

            // URL input
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'WebSocket Server URL',
                hintText: 'ws://localhost:8765',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              enabled: !_isConnected,
            ),
            SizedBox(height: 12),

            // Connection status and buttons
            Row(
              children: [
                // Status indicator
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  _isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
                Spacer(),

                // Connect/Disconnect button
                ElevatedButton(
                  onPressed: _isConnected ? _disconnect : _connect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isConnected ? Colors.red : Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_isConnected ? 'Disconnect' : 'Connect'),
                ),
              ],
            ),

            // Action buttons
            if (_isConnected) ...[
              SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _requestLatestData,
                    icon: Icon(Icons.refresh),
                    label: Text('Get Latest Data'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _requestServerStats,
                    icon: Icon(Icons.analytics),
                    label: Text('Get Stats'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServerStatsSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Server Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Uptime',
                    '${(_serverStats!['uptime_seconds'] ?? 0).toStringAsFixed(0)}s',
                    Icons.timer,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Messages',
                    '${_serverStats!['messages_received'] ?? 0}',
                    Icons.message,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Clients',
                    '${_serverStats!['clients_connected'] ?? 0}',
                    Icons.people,
                  ),
                ),
              ],
            ),

            if (_serverStats!['topics'] != null) ...[
              SizedBox(height: 8),
              Text(
                'Topics: ${(_serverStats!['topics'] as List).join(', ')}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildMessagesSection() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text(
                  'Messages & Telemetry Data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Text(
                  '${_receivedMessages.length} messages',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          Expanded(
            child: _receivedMessages.isEmpty
                ? Center(
                    child: Text(
                      'No messages received yet.\nConnect to WebSocket server to see data.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: _receivedMessages.length,
                    itemBuilder: (context, index) {
                      final message = _receivedMessages[index];
                      return _buildMessageTile(message);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(Map<String, dynamic> message) {
    final isLogMessage = message['type'] == 'log';
    final timestamp = message['timestamp'] is DateTime
        ? message['timestamp'] as DateTime
        : DateTime.tryParse(message['timestamp'] ?? '') ?? DateTime.now();

    if (isLogMessage) {
      // Log message - hiển thị đơn giản
      return ListTile(
        dense: true,
        leading: Icon(Icons.info, size: 16, color: Colors.blue),
        title: Text(
          message['message'] ?? 'Unknown log message',
          style: TextStyle(fontSize: 13),
        ),
        subtitle: Text(
          _formatTime(timestamp),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      );
    } else {
      // Telemetry message - hiển thị JSON data
      return Card(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.sensors, size: 16, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Drone: ${message['drone_id'] ?? 'Unknown'}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Spacer(),
                  Text(
                    _formatTime(timestamp),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              SizedBox(height: 8),

              // Topic
              Text(
                'Topic: ${message['topic'] ?? 'Unknown'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              SizedBox(height: 8),

              // JSON Data
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  _formatJsonPretty(message['data']),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  String _formatJsonPretty(dynamic data) {
    try {
      if (data == null) return 'null';

      if (data is Map) {
        // Format map as pretty JSON
        final buffer = StringBuffer();
        buffer.writeln('{');

        final entries = data.entries.toList();
        for (int i = 0; i < entries.length; i++) {
          final entry = entries[i];
          buffer.write('  "${entry.key}": ');

          if (entry.value is String) {
            buffer.write('"${entry.value}"');
          } else if (entry.value is num) {
            buffer.write('${entry.value}');
          } else if (entry.value is bool) {
            buffer.write('${entry.value}');
          } else if (entry.value == null) {
            buffer.write('null');
          } else {
            buffer.write('"${entry.value}"');
          }

          if (i < entries.length - 1) {
            buffer.write(',');
          }
          buffer.writeln();
        }

        buffer.write('}');
        return buffer.toString();
      }

      return data.toString();
    } catch (e) {
      return 'Error formatting data: $e';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    _statsSubscription?.cancel();
    _urlController.dispose();
    super.dispose();
  }
}
