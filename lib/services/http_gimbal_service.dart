import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// HTTP service để gửi gimbal commands qua HTTP bridge
/// Architecture: Flutter → HTTP → Python Bridge → Kafka → Pi
class HttpGimbalService extends ChangeNotifier {
  // Singleton pattern
  static final HttpGimbalService _instance = HttpGimbalService._internal();
  factory HttpGimbalService() => _instance;
  HttpGimbalService._internal();

  // HTTP Bridge configuration
  String _bridgeUrl = 'http://192.168.50.114:8888';
  bool _isConnected = false;
  String? _lastError;
  int _messagesSent = 0;

  // Getters
  bool get isConnected => _isConnected;
  String get bridgeUrl => _bridgeUrl;
  String? get lastError => _lastError;
  int get messagesSent => _messagesSent;

  /// Configure HTTP bridge URL
  void configure({required String bridgeUrl}) {
    _bridgeUrl = bridgeUrl;
    debugPrint('✅ HTTP Bridge configured: $_bridgeUrl');
    notifyListeners();
  }

  /// Test connection to bridge
  Future<bool> testConnection() async {
    try {
      debugPrint('🔌 Testing HTTP bridge connection...');

      final response = await http
          .get(Uri.parse('$_bridgeUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _isConnected = true;
        _lastError = null;
        debugPrint('✅ HTTP bridge connected');
        notifyListeners();
        return true;
      } else {
        _isConnected = false;
        _lastError = 'HTTP ${response.statusCode}';
        debugPrint('❌ HTTP bridge connection failed');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      _isConnected = false;
      debugPrint('❌ HTTP bridge test error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Send command to bridge
  Future<bool> _sendCommand(Map<String, dynamic> command) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_bridgeUrl/gimbal/command'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(command),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          _messagesSent++;
          _isConnected = true;
          _lastError = null;
          debugPrint('✅ Command sent: ${command['action']}');
          notifyListeners();
          return true;
        }
      }

      _lastError = 'HTTP ${response.statusCode}';
      debugPrint('❌ Command failed: $_lastError');
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = e.toString();
      _isConnected = false;
      debugPrint('❌ Send command error: $e');
      notifyListeners();
      return false;
    }
  }

  // ==================== GIMBAL COMMAND METHODS ====================

  /// Send Lock command
  Future<bool> sendLockCommand() async {
    final command = {'action': 'lock'};
    debugPrint('📤 Sending Lock command via HTTP');
    return await _sendCommand(command);
  }

  /// Send Follow command
  Future<bool> sendFollowCommand() async {
    final command = {'action': 'follow'};
    debugPrint('📤 Sending Follow command via HTTP');
    return await _sendCommand(command);
  }

  /// Send Velocity command
  Future<bool> sendVelocityCommand({
    required String mode,
    double roll = 0,
    double pitch = 0,
    double yaw = 0,
  }) async {
    final command = {
      'action': 'velocity',
      'mode': mode,
      'roll': roll,
      'pitch': pitch,
      'yaw': yaw,
    };
    debugPrint('📤 Sending Velocity command via HTTP: p=$pitch, y=$yaw');
    return await _sendCommand(command);
  }

  /// Send Click to Aim command
  Future<bool> sendClickToAimCommand({required int x, required int y}) async {
    final command = {'action': 'click_to_aim', 'x': x, 'y': y};
    debugPrint('📤 Sending Click to Aim command via HTTP: x=$x, y=$y');
    return await _sendCommand(command);
  }

  /// Send PIP command
  Future<bool> sendPIPCommand({required int mode}) async {
    final command = {'action': 'pip', 'mode': mode};
    debugPrint('📤 Sending PIP command via HTTP: mode=$mode');
    return await _sendCommand(command);
  }

  /// Send OSD command
  Future<bool> sendOSDCommand({required bool show}) async {
    final command = {'action': 'osd', 'show': show};
    debugPrint('📤 Sending OSD command via HTTP: show=$show');
    return await _sendCommand(command);
  }

  /// Send Get Status command
  Future<bool> sendGetStatusCommand() async {
    final command = {'action': 'get_status'};
    debugPrint('📤 Sending Get Status command via HTTP');
    return await _sendCommand(command);
  }

  /// Send Get Data command
  Future<bool> sendGetDataCommand({double timeout = 2.0}) async {
    final command = {'action': 'get_data', 'timeout': timeout};
    debugPrint('📤 Sending Get Data command via HTTP');
    return await _sendCommand(command);
  }

  /// Send Connect Gimbal command
  Future<bool> sendConnectCommand({
    required String ip,
    required int port,
  }) async {
    final command = {'action': 'connect', 'ip': ip, 'port': port};
    debugPrint('📤 Sending Connect command via HTTP: $ip:$port');
    return await _sendCommand(command);
  }

  /// Send Disconnect Gimbal command
  Future<bool> sendDisconnectCommand() async {
    final command = {'action': 'disconnect'};
    debugPrint('📤 Sending Disconnect command via HTTP');
    return await _sendCommand(command);
  }

  /// Reset statistics
  void resetStats() {
    _messagesSent = 0;
    _lastError = null;
    notifyListeners();
    debugPrint('📊 HTTP stats reset');
  }

  @override
  void dispose() {
    super.dispose();
  }
}
