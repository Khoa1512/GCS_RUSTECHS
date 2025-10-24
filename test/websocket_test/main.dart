import 'package:flutter/material.dart';
import 'package:skylink/presentation/view/test/websocket_test_page.dart';

void main() {
  runApp(WebSocketTestApp());
}

class WebSocketTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebSocket Telemetry Test',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: WebSocketTestPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
