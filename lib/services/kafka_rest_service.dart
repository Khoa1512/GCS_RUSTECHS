import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Architecture: Flutter → Kafka REST API → Pi
class KafkaRestService extends ChangeNotifier {
  // Singleton pattern
  static final KafkaRestService _instance = KafkaRestService._internal();
  factory KafkaRestService() => _instance;
  KafkaRestService._internal();

  static String get _apiKey => dotenv.env['KAFKA_API_KEY'] ?? '';
  static String get _apiSecret => dotenv.env['KAFKA_API_SECRET'] ?? '';
  static String get _clusterId => dotenv.env['KAFKA_CLUSTER_ID'] ?? '';
  static String get _restUrl => dotenv.env['KAFKA_REST_URL'] ?? '';
  static String get _topic => dotenv.env['KAFKA_TOPIC'] ?? 'gimbal-command';

  // State
  bool _isConnected = false;
  String? _lastError;
  int _messagesSent = 0;

  // Getters
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;
  int get messagesSent => _messagesSent;

  /// Get Authorization header with base64 encoded API key
  String _getAuthHeader() {
    final credentials = '$_apiKey:$_apiSecret';
    final encoded = base64Encode(utf8.encode(credentials));
    return 'Basic $encoded';
  }

  /// Test connection to Kafka REST API
  Future<bool> testConnection() async {
    try {
      debugPrint('🔌 Testing Kafka REST API connection...');

      // Test by getting topic metadata
      final url = Uri.parse('$_restUrl/v3/clusters/$_clusterId/topics/$_topic');

      final response = await http
          .get(
            url,
            headers: {
              'Authorization': _getAuthHeader(),
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _isConnected = true;
        _lastError = null;
        // debugPrint('✅ Kafka REST API connected');
        // debugPrint('📋 Topic: $_topic exists');
        notifyListeners();
        return true;
      } else if (response.statusCode == 401) {
        _isConnected = false;
        // _lastError = 'Authentication failed';
        // debugPrint('❌ Kafka REST authentication failed');
      } else if (response.statusCode == 404) {
        _isConnected = false;
        // _lastError = 'Topic not found';
        // debugPrint('❌ Topic $_topic not found');
      } else {
        _isConnected = false;
        _lastError = 'HTTP ${response.statusCode}';
        // debugPrint('❌ Kafka REST connection failed: ${response.statusCode}');
      }

      notifyListeners();
      return false;
    } catch (e) {
      _lastError = e.toString();
      _isConnected = false;
      // debugPrint('❌ Kafka REST test error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Send message to Kafka topic via REST API
  Future<bool> _sendToKafka(Map<String, dynamic> message) async {
    try {
      // Confluent REST API v3 format
      final url = Uri.parse(
        '$_restUrl/v3/clusters/$_clusterId/topics/$_topic/records',
      );

      final payload = {
        'value': {'type': 'JSON', 'data': message},
      };

      debugPrint('📤 Posting to Kafka: ${message['action']}');

      final response = await http
          .post(
            url,
            headers: {
              'Authorization': _getAuthHeader(),
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        _messagesSent++;
        _isConnected = true;
        _lastError = null;
        // debugPrint('✅ Message sent to Kafka: ${message['action']}');
        notifyListeners();
        return true;
      } else if (response.statusCode == 401) {
        _lastError = 'Authentication failed';
        // debugPrint('❌ Kafka auth failed: ${response.body}');
      } else if (response.statusCode == 404) {
        _lastError = 'Topic not found';
        // debugPrint('❌ Topic not found: ${response.body}');
      } else {
        _lastError = 'HTTP ${response.statusCode}';
        // debugPrint(
        //   '❌ Kafka POST failed: ${response.statusCode} - ${response.body}',
        // );
      }

      notifyListeners();
      return false;
    } catch (e) {
      _lastError = e.toString();
      _isConnected = false;
      debugPrint('❌ Send to Kafka error: $e');
      notifyListeners();
      return false;
    }
  }

  // ==================== GIMBAL COMMAND METHODS ====================

  /// Send Lock command
  Future<bool> sendLockCommand() async {
    final command = {'action': 'lock'};
    // debugPrint('📤 Sending Lock command to Kafka');
    return await _sendToKafka(command);
  }

  /// Send Follow command
  Future<bool> sendFollowCommand() async {
    final command = {'action': 'follow'};
    // debugPrint('📤 Sending Follow command to Kafka');
    return await _sendToKafka(command);
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
    // debugPrint('📤 Sending Velocity command to Kafka: p=$pitch, y=$yaw');
    return await _sendToKafka(command);
  }

  /// Send Click to Aim command
  Future<bool> sendClickToAimCommand({required int x, required int y}) async {
    final command = {'action': 'click_to_aim', 'x': x, 'y': y};
    // debugPrint('📤 Sending Click to Aim command to Kafka: x=$x, y=$y');
    return await _sendToKafka(command);
  }

  /// Send PIP command
  Future<bool> sendPIPCommand({required int mode}) async {
    final command = {'action': 'pip', 'mode': mode};
    // debugPrint('📤 Sending PIP command to Kafka: mode=$mode');
    return await _sendToKafka(command);
  }

  /// Send OSD command
  Future<bool> sendOSDCommand({required bool show}) async {
    final command = {'action': 'osd', 'show': show};
    // debugPrint('📤 Sending OSD command to Kafka: show=$show');
    return await _sendToKafka(command);
  }

  /// Send Get Status command
  Future<bool> sendGetStatusCommand() async {
    final command = {'action': 'get_status'};
    debugPrint('📤 Sending Get Status command to Kafka');
    return await _sendToKafka(command);
  }

  /// Send Get Data command
  Future<bool> sendGetDataCommand({double timeout = 2.0}) async {
    final command = {'action': 'get_data', 'timeout': timeout};
    // debugPrint('📤 Sending Get Data command to Kafka');
    return await _sendToKafka(command);
  }

  /// Send Connect Gimbal command
  Future<bool> sendConnectCommand({
    required String ip,
    required int port,
  }) async {
    final command = {'action': 'connect', 'ip': ip, 'port': port};
    debugPrint('📤 Sending Connect command to Kafka: $ip:$port');
    return await _sendToKafka(command);
  }

  /// Send Disconnect Gimbal command
  Future<bool> sendDisconnectCommand() async {
    final command = {'action': 'disconnect'};
    // debugPrint('📤 Sending Disconnect command to Kafka');
    return await _sendToKafka(command);
  }

  /// Reset statistics
  void resetStats() {
    _messagesSent = 0;
    _lastError = null;
    notifyListeners();
    // debugPrint('📊 Kafka stats reset');
  }

  @override
  void dispose() {
    super.dispose();
  }
}
