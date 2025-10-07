import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:skylink/api/5G/services/mqtt_service.dart';

final MqttService _mqtt = Get.find<MqttService>();

class MqttDialog extends StatefulWidget {
  const MqttDialog({super.key});

  @override
  State<MqttDialog> createState() => _MqttDialogState();
}

class _MqttDialogState extends State<MqttDialog> {
  MqttServerClient? _client;
  final List<String> _logs = <String>[];
  bool _connecting = true;
  final TextEditingController _deviceController = TextEditingController(
    text: 'drone_1',
  );

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _mqtt.connect();
      await _mqtt.subscribeAllDevices();
      setState(() {
        _connecting = false;
      });
      _mqtt.listenMessages().listen((line) {
        setState(() {
          _logs.insert(0, line);
        });
      });
    } catch (e) {
      setState(() {
        _connecting = false;
        _logs.insert(0, '❌ Error: $e');
      });
    }
  }

  Future<void> _publishSample() async {
    final client = _client;
    if (client == null) return;
    final device = _deviceController.text.trim().isEmpty
        ? 'drone_1'
        : _deviceController.text.trim();
    await _mqtt.publishSample(deviceId: device);
    setState(() {
      _logs.insert(0, '📤 $device → (sample json)');
    });
  }

  @override
  void dispose() {
    _deviceController.dispose();
    _mqtt.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'MQTT Listener',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_connecting) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                const Text(
                  'Đang kết nối MQTT...',
                  style: TextStyle(color: Colors.black),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _deviceController,
                        decoration: const InputDecoration(
                          labelText: 'Device ID (ví dụ: drone_1)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _publishSample,
                      child: const Text('Publish mẫu'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Logs', style: TextStyle(color: Colors.black)),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      reverse: true,
                      itemCount: _logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            _logs[index],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.black,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
