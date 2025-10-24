import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

class WebSocketTelemetryService {
  static final WebSocketTelemetryService _instance =
      WebSocketTelemetryService._internal();
  factory WebSocketTelemetryService() => _instance;
  WebSocketTelemetryService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  // Stream controllers
  final _dataController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _statsController = StreamController<Map<String, dynamic>>.broadcast();

  // Connection state
  bool _isConnected = false;
  String? _serverUrl;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  // Getters
  bool get isConnected => _isConnected;
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get statsStream => _statsController.stream;

  /// Connect to WebSocket server
  Future<void> connect(String serverUrl) async {


    _serverUrl = serverUrl;

    try {
      _channel = IOWebSocketChannel.connect(
        Uri.parse(serverUrl),
        pingInterval: Duration(seconds: 30),
      );

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionController.add(true);

      // Start ping timer
      _startPingTimer();

    } catch (e) {
      print('❌ Failed to connect to WebSocket server: $e');
      _handleConnectionError();
    }
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);

      switch (data['type']) {
        case 'connection_established':
          _sendPing(); // Send initial ping
          break;

        case 'telemetry_update':
          // Forward telemetry data to listeners
          _dataController.add(data);
          break;

        case 'pong':
          if (data.containsKey('server_stats')) {
            _statsController.add(data['server_stats']);
          }
          break;

        case 'server_stats':
          _statsController.add(data['data']);
          break;

        case 'error':
          break;

        default:
          break;
      }
    } catch (e) {
      print('❌ Error parsing WebSocket message: $e');
    }
  }

  /// Handle WebSocket errors
  void _handleError(error) {
    _handleConnectionError();
  }

  /// Handle WebSocket disconnect
  void _handleDisconnect() {
    _handleConnectionError();
  }

  /// Handle connection errors and attempt reconnection
  void _handleConnectionError() {
    _isConnected = false;
    _connectionController.add(false);
    _stopPingTimer();

    if (_reconnectAttempts < _maxReconnectAttempts && _serverUrl != null) {
      _reconnectAttempts++;
      final delay = Duration(seconds: _reconnectAttempts * 2);


      _reconnectTimer = Timer(delay, () {
        if (_serverUrl != null) {
          connect(_serverUrl!);
        }
      });
    } else {
      print('💀 Max reconnection attempts reached or no server URL');
    }
  }

  /// Start ping timer to keep connection alive
  void _startPingTimer() {
    _pingTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_isConnected) {
        _sendPing();
      }
    });
  }

  /// Stop ping timer
  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Send ping to server
  void _sendPing() {
    if (_isConnected && _channel != null) {
      final pingMessage = {
        'action': 'ping',
        'timestamp': DateTime.now().toIso8601String(),
      };

      try {
        _channel!.sink.add(jsonEncode(pingMessage));
      } catch (e) {
        print('❌ Failed to send ping: $e');
      }
    }
  }

  /// Request latest data from server
  void requestLatestData() {
    if (_isConnected && _channel != null) {
      final request = {
        'action': 'get_latest',
        'timestamp': DateTime.now().toIso8601String(),
      };

      try {
        _channel!.sink.add(jsonEncode(request));
      } catch (e) {
        print('❌ Failed to request latest data: $e');
      }
    }
  }

  /// Request server statistics
  void requestServerStats() {
    if (_isConnected && _channel != null) {
      final request = {
        'action': 'get_stats',
        'timestamp': DateTime.now().toIso8601String(),
      };

      try {
        _channel!.sink.add(jsonEncode(request));
      } catch (e) {
        print('❌ Failed to request server stats: $e');
      }
    }
  }

  /// Disconnect from WebSocket server
  void disconnect() {
    _stopPingTimer();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();

    _isConnected = false;
    _reconnectAttempts = 0;
    _serverUrl = null;

    _connectionController.add(false);
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _dataController.close();
    _connectionController.close();
    _statsController.close();
  }
}
