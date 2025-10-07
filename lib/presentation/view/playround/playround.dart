import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skylink/presentation/widget/connection/mqtt_dialog.dart';
import 'package:skylink/services/connection_manager.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'package:skylink/api/5G/services/mqtt_service.dart';

class PlayroundPage extends StatefulWidget {
  const PlayroundPage({super.key});

  @override
  State<PlayroundPage> createState() => _PlayroundPageState();
}

class _PlayroundPageState extends State<PlayroundPage> {
  late ConnectionManager connectionManager;
  late TelemetryService telemetryService;
  late MqttService mqttService;

  List<String> debugLogs = [];
  ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Get services with error handling
    try {
      connectionManager = Get.find<ConnectionManager>();
      telemetryService = Get.find<TelemetryService>();
      mqttService = Get.find<MqttService>();

      // Listen to telemetry data for debugging
      telemetryService.telemetryStream.listen((data) {
        addDebugLog('🔥 Telemetry Update: ${data.length} fields');
        data.forEach((key, value) {
          addDebugLog('   $key: $value');
        });
      });

      addDebugLog('✅ Services initialized successfully');
    } catch (e) {
      addDebugLog('❌ Error initializing services: $e');
      // Initialize services manually if they don't exist
      _initializeServicesManually();
    }
  }

  void _initializeServicesManually() {
    addDebugLog('🔧 Manually initializing services...');
    try {
      // Put services if they don't exist
      if (!Get.isRegistered<MqttService>()) {
        Get.put(MqttService(), permanent: true);
        addDebugLog('📦 Created MqttService');
      }
      if (!Get.isRegistered<TelemetryService>()) {
        Get.put(TelemetryService(), permanent: true);
        addDebugLog('📦 Created TelemetryService');
      }
      if (!Get.isRegistered<ConnectionManager>()) {
        Get.put(ConnectionManager(), permanent: true);
        addDebugLog('📦 Created ConnectionManager');
      }

      // Get services again
      connectionManager = Get.find<ConnectionManager>();
      telemetryService = Get.find<TelemetryService>();
      mqttService = Get.find<MqttService>();

      // Listen to telemetry data
      telemetryService.telemetryStream.listen((data) {
        addDebugLog('🔥 Telemetry Update: ${data.length} fields');
        if (data.isNotEmpty) {
          data.entries.take(5).forEach((entry) {
            addDebugLog('   ${entry.key}: ${entry.value}');
          });
        }
      });

      // Listen to MQTT connection status
      addDebugLog('🔗 Setting up MQTT listeners...');

      // Check MQTT connection status
      addDebugLog('📡 MQTT Connected: ${mqttService.isConnected}');
      addDebugLog(
        '🔌 Connection Manager State: ${connectionManager.currentConnectionType.name}',
      );

      addDebugLog('✅ Manual service initialization completed');
    } catch (e) {
      addDebugLog('❌ Manual initialization failed: $e');
    }
  }

  void addDebugLog(String log) {
    setState(() {
      debugLogs.add('${DateTime.now().toString().substring(11, 19)} - $log');
      if (debugLogs.length > 100) {
        debugLogs.removeAt(0); // Keep only last 100 logs
      }
    });

    // Auto scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MQTT Test Playground'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                debugLogs.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Control buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const MqttDialog(),
                          );
                        },
                        label: const Text("MQTT Settings"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GetBuilder<ConnectionManager>(
                        init: Get.isRegistered<ConnectionManager>()
                            ? null
                            : ConnectionManager(),
                        builder: (manager) {
                          return ElevatedButton.icon(
                            icon: Icon(
                              manager.currentConnectionType ==
                                      ConnectionType.mqtt
                                  ? Icons.wifi
                                  : Icons.wifi_off,
                            ),
                            onPressed: () async {
                              try {
                                addDebugLog(
                                  '🔲 Current state: ${manager.currentConnectionType.name}',
                                );
                                addDebugLog(
                                  '📡 MQTT connected: ${mqttService.isConnected}',
                                );

                                if (manager.currentConnectionType ==
                                    ConnectionType.mqtt) {
                                  addDebugLog('🔌 Switching away from MQTT...');
                                  await manager.switchTo(ConnectionType.none);
                                  addDebugLog('✅ Switched to NONE');
                                } else {
                                  addDebugLog('🔌 Switching to MQTT...');
                                  await manager.switchTo(ConnectionType.mqtt);
                                  addDebugLog('✅ Switched to MQTT');

                                  // Wait a bit and check connection
                                  await Future.delayed(Duration(seconds: 2));
                                  addDebugLog(
                                    '📡 MQTT connected after switch: ${mqttService.isConnected}',
                                  );

                                  // Test direct MQTT listening
                                  addDebugLog(
                                    '🎧 Setting up direct MQTT listener...',
                                  );
                                  mqttService.listenMessages().listen((
                                    message,
                                  ) {
                                    addDebugLog('📨 MQTT Message: $message');
                                  });

                                  mqttService.listenTelemetryData().listen((
                                    data,
                                  ) {
                                    addDebugLog(
                                      '📊 MQTT Telemetry Data: ${data.keys.length} keys',
                                    );
                                    addDebugLog(
                                      '📋 Keys: ${data.keys.take(5).join(", ")}',
                                    );
                                  });
                                }
                              } catch (e) {
                                addDebugLog('❌ Connection error: $e');
                              }
                            },
                            label: Text(
                              manager.currentConnectionType ==
                                      ConnectionType.mqtt
                                  ? "Disconnect"
                                  : "Connect MQTT",
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  manager.currentConnectionType ==
                                      ConnectionType.mqtt
                                  ? Colors.red
                                  : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Test buttons row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.bug_report),
                        onPressed: () async {
                          addDebugLog('🧪 === MANUAL MQTT TEST ===');
                          try {
                            addDebugLog(
                              '📡 MQTT Service Connected: ${mqttService.isConnected}',
                            );

                            if (!mqttService.isConnected) {
                              addDebugLog('🔌 Connecting to MQTT manually...');
                              await mqttService.connect();
                              addDebugLog(
                                '✅ MQTT connected: ${mqttService.isConnected}',
                              );
                            }

                            addDebugLog('🎧 Testing MQTT streams...');

                            // Test message stream
                            mqttService
                                .listenMessages()
                                .take(5)
                                .listen(
                                  (message) =>
                                      addDebugLog('📨 Raw Message: $message'),
                                  onError: (e) =>
                                      addDebugLog('❌ Message Stream Error: $e'),
                                  onDone: () =>
                                      addDebugLog('✅ Message stream test done'),
                                );

                            // Test telemetry stream
                            mqttService
                                .listenTelemetryData()
                                .take(3)
                                .listen(
                                  (data) => addDebugLog(
                                    '📊 Telemetry Keys: ${data.keys.toList()}',
                                  ),
                                  onError: (e) => addDebugLog(
                                    '❌ Telemetry Stream Error: $e',
                                  ),
                                  onDone: () => addDebugLog(
                                    '✅ Telemetry stream test done',
                                  ),
                                );
                          } catch (e) {
                            addDebugLog('❌ Manual test error: $e');
                          }
                        },
                        label: const Text("Test MQTT"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          addDebugLog('🔄 === STATUS CHECK ===');
                          addDebugLog(
                            '📡 MQTT Connected: ${mqttService.isConnected}',
                          );
                          addDebugLog(
                            '🔌 Connection Type: ${connectionManager.currentConnectionType.name}',
                          );
                          addDebugLog(
                            '📊 Telemetry Data Count: ${telemetryService.currentTelemetry.length}',
                          );
                          addDebugLog('======================');
                        },
                        label: const Text("Status"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GetBuilder<ConnectionManager>(
                  init: Get.isRegistered<ConnectionManager>()
                      ? null
                      : ConnectionManager(),
                  builder: (manager) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Icon(
                              manager.currentConnectionType ==
                                      ConnectionType.mqtt
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              color:
                                  manager.currentConnectionType ==
                                      ConnectionType.mqtt
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Status: ${manager.currentConnectionType.name.toUpperCase()}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    manager.currentConnectionType ==
                                        ConnectionType.mqtt
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Debug logs
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.grey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔍 Debug Console (${debugLogs.length} logs)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(color: Colors.grey),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: debugLogs.length,
                      itemBuilder: (context, index) {
                        final log = debugLogs[index];
                        Color textColor = Colors.white;

                        // Color coding for different log types
                        if (log.contains('❌') || log.contains('💥')) {
                          textColor = Colors.red;
                        } else if (log.contains('✅') || log.contains('📤')) {
                          textColor = Colors.green;
                        } else if (log.contains('🔍') || log.contains('📥')) {
                          textColor = Colors.blue;
                        } else if (log.contains('⚠️')) {
                          textColor = Colors.orange;
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.0),
                          child: Text(
                            log,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
