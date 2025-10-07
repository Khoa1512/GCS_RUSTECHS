import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _subscription;

  String get _token => dotenv.env['MQTT_TOKEN'] ?? '';
  String get _host => dotenv.env['MQTT_HOST'] ?? 'mqtt1.eoh.io';
  int get _port => int.tryParse(dotenv.env['MQTT_PORT'] ?? '1883') ?? 1883;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  Future<void> connect() async {
    if (isConnected) return;

    final String clientId =
        'flutter_client_${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttServerClient(_host, clientId)
      ..port = _port
      ..logging(on: false)
      ..keepAlivePeriod = 30
      ..connectTimeoutPeriod = 5000
      ..onConnected = () => debugPrint('MQTT connected for 10ms real-time');

    client.onDisconnected = () => debugPrint('MQTT disconnected');

    if (_token.isEmpty) {
      throw Exception('Missing TOKEN in .env. Please set TOKEN=...');
    }

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(_token, _token)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    client.connectionMessage = connMess;

    try {
      await client.connect();
    } on Exception {
      client.disconnect();
      rethrow;
    }

    final status = client.connectionStatus;
    if (status == null || status.state != MqttConnectionState.connected) {
      final code = status?.returnCode;
      client.disconnect();
      throw Exception('MQTT connect failed: ${code ?? 'unknown'}');
    }
    _client = client;
  }

  String topicAllDevices() => 'eoh/chip/$_token/config/+/value';
  String topicForDevice(String deviceId) =>
      'eoh/chip/$_token/config/$deviceId/value';
  String topicOnlineStatus() => 'eoh/chip/$_token/is_online';

  Future<void> subscribeAllDevices() async {
    if (!isConnected) await connect();

    _client!.subscribe(topicAllDevices(), MqttQos.atMostOnce);
    _client!.subscribe(topicOnlineStatus(), MqttQos.atMostOnce);
  }

  Stream<String> listenMessages() {
    final controller = StreamController<String>.broadcast();
    _subscription?.cancel();
    _subscription = _client?.updates?.listen((events) {
      final MqttPublishMessage msg = events.first.payload as MqttPublishMessage;
      final String topic = events.first.topic;
      final String payload = MqttPublishPayload.bytesToStringAsString(
        msg.payload.message,
      );

      final parts = topic.split('/');
      String configInfo = '';
      if (parts.length >= 4 && parts[parts.length - 2] != '+') {
        final configId = parts[parts.length - 2];
        configInfo = ' [Config ID: $configId]';
      }

      controller.add('📥 $topic$configInfo → $payload');
    });
    return controller.stream;
  }

  Stream<Map<String, dynamic>> listenTelemetryData() {
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    _subscription?.cancel();
    _subscription = _client?.updates?.listen((events) {
      final MqttPublishMessage msg = events.first.payload as MqttPublishMessage;
      final String topic = events.first.topic;

      try {
        String? decodedPayload;
        try {
          decodedPayload = utf8.decode(msg.payload.message);
        } catch (e) {
          decodedPayload = MqttPublishPayload.bytesToStringAsString(
            msg.payload.message,
          );
        }

        final data = jsonDecode(decodedPayload);
        if (data is Map<String, dynamic>) {
          data['_mqtt_topic'] = topic;
          data['_mqtt_timestamp'] = DateTime.now().millisecondsSinceEpoch;
          controller.add(data);
        }
      } catch (e) {
        debugPrint('Failed to parse MQTT JSON: $e');
      }
    });
    return controller.stream;
  }

  Future<void> publishSample({required String deviceId}) async {
    if (!isConnected) await connect();
    final pubTopic = topicForDevice(deviceId);
    final builder = MqttClientPayloadBuilder()
      ..addString(
        jsonEncode({
          'temp': 25.5,
          'humidity': 60,
          'status': 'OK',
          'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        }),
      );
    _client!.publishMessage(pubTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    _client?.disconnect();
    _client = null;
  }
}
