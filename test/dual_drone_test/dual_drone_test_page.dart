import 'package:flutter/material.dart';
import 'simple_dual_drone_widget.dart';

class DualDroneTestPage extends StatelessWidget {
  const DualDroneTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dual Drone Connection Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Test kết nối 2 Flight Controller',
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 16),
            SimpleDualDroneWidget(),
          ],
        ),
      ),
    );
  }
}
