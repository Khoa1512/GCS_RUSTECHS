import 'package:flutter/material.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'package:skylink/core/constant/app_color.dart';
import 'dart:async';

class ConnectionDialog {
  static Future<void> show(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return const _ConnectionDialogWidget();
      },
    );
  }
}

class _ConnectionDialogWidget extends StatefulWidget {
  const _ConnectionDialogWidget();

  @override
  State<_ConnectionDialogWidget> createState() =>
      _ConnectionDialogWidgetState();
}

class _ConnectionDialogWidgetState extends State<_ConnectionDialogWidget> {
  final TelemetryService _telemetryService = TelemetryService();
  List<String> _availablePorts = [];
  String? _selectedPort;
  String? _connectedPort;
  int _baudRate = 115200;
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isWaitingForData = false;
  Timer? _progressTimer;
  double _progressValue = 0.0;
  StreamSubscription? _dataSubscription;

  final List<int> _baudRates = [9600, 57600, 115200, 230400, 460800, 921600];

  @override
  void initState() {
    super.initState();
    _isConnected = _telemetryService.isConnected;
    _loadAvailablePorts();
  }

  void _loadAvailablePorts() {
    setState(() {
      _availablePorts = _telemetryService.getAvailablePorts();
      if (_availablePorts.isNotEmpty && _selectedPort == null) {
        _selectedPort = _availablePorts.first;
      }
    });
  }

  Future<void> _connect() async {
    if (_selectedPort == null) {
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      // Check if port is still available before connecting
      final availablePorts = _telemetryService.getAvailablePorts();
      if (!availablePorts.contains(_selectedPort)) {
        throw Exception('Port no longer available');
      }

      bool success = await _telemetryService.connect(
        _selectedPort!,
        baudRate: _baudRate,
      );

      setState(() {
        _isConnecting = false;
        _isConnected = success;
        if (success) {
          _connectedPort = _selectedPort;
        } else {
          // print('Connection failed to $_selectedPort');
        }
      });

      if (success) {
        setState(() {
          _isConnecting = false;
          // Chưa set _isConnected = true ngay, đợi progress bar chạy hết
        });
        _showSnackBar('Port connected, waiting for data...', isError: false);
        _startProgressBar();
      } else {
        setState(() {
          _isConnecting = false;
          _isConnected = false;
        });
        _showSnackBar('Failed to connect to $_selectedPort', isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isConnected = false;
        });
        _showSnackBar('Connection error: $e', isError: true);
      }
    }
  }

  Future<void> _disconnect() async {
    _telemetryService.disconnect();

    if (mounted) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _connectedPort = null;
      });

      _showSnackBar('Disconnected', isError: false);
      Navigator.of(context).pop();
    }
  }

  void _startProgressBar() {
    // Hủy timer và subscription cũ nếu có
    _progressTimer?.cancel();
    _dataSubscription?.cancel();

    bool hasReceivedData = false;

    // Reset và bắt đầu chờ data
    setState(() {
      _isWaitingForData = true;
      _progressValue = 0.0;
    });

    // Bắt đầu timer để cập nhật thanh tiến trình
    // Tăng 0.1% mỗi 100ms -> full sau 10s (tăng từ 5s lên 10s)
    _progressTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          _progressValue += 0.01; // 1/100 để full sau 10s
          if (_progressValue > 1.0) _progressValue = 1.0;

          // Nếu đã chạy hết thanh tiến trình
          if (_progressValue >= 1.0) {
            _progressTimer?.cancel();
            _dataSubscription?.cancel();

            if (hasReceivedData) {
              setState(() {
                _isWaitingForData = false;
                _isConnected = true;
              });
              Navigator.of(context).pop();
            } else {
              _disconnect();
              _showSnackBar(
                'Connection timeout: No data received',
                isError: true,
              );
            }
          }
        });
      }
    });

    // Lắng nghe data stream
    _dataSubscription = _telemetryService.dataReceiveStream.listen((hasData) {
      if (hasData) {
        hasReceivedData = true;
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _dataSubscription?.cancel();
    super.dispose();
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.settings_input_antenna, color: AppColors.primaryColor),
          SizedBox(width: 8),
          Text(
            'Drone Connection',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isWaitingForData) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: _progressValue,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Waiting for data...',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],

            // Connection Status
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: _isWaitingForData
                    ? Colors.orange.withOpacity(0.2)
                    : _isConnected
                    ? Colors.green.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                border: Border.all(
                  color: _isWaitingForData
                      ? Colors.orange
                      : _isConnected
                      ? Colors.green
                      : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isWaitingForData
                        ? Icons.hourglass_empty
                        : _isConnected
                        ? Icons.check_circle
                        : Icons.error,
                    color: _isWaitingForData
                        ? Colors.orange
                        : _isConnected
                        ? Colors.green
                        : Colors.red,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _isWaitingForData
                        ? 'Connecting...'
                        : _isConnected
                        ? 'Connected'
                        : 'Disconnected',
                    style: TextStyle(
                      color: _isWaitingForData
                          ? Colors.orange
                          : _isConnected
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            if (!_isConnected) ...[
              SizedBox(height: 16),

              // Port Selection
              Text(
                'Serial Port:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade600),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPort,
                          hint: Text(
                            'Select Port',
                            style: TextStyle(color: Colors.grey),
                          ),
                          dropdownColor: Colors.grey.shade800,
                          items: _availablePorts.map((port) {
                            return DropdownMenuItem<String>(
                              value: port,
                              child: Text(
                                port,
                                style: TextStyle(color: Colors.white),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedPort = value;
                            });
                          },
                          padding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: AppColors.primaryColor),
                      onPressed: _loadAvailablePorts,
                      tooltip: 'Refresh Ports',
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Baud Rate Selection
              Text(
                'Baud Rate:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade600),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _baudRate,
                    dropdownColor: Colors.grey.shade800,
                    items: _baudRates.map((rate) {
                      return DropdownMenuItem<int>(
                        value: rate,
                        child: Text(
                          '$rate',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _baudRate = value!;
                      });
                    },
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    isExpanded: true,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),

        if (_isConnected)
          ElevatedButton(
            onPressed: () async {
              await _disconnect();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Disconnect'),
          )
        else if (_isWaitingForData)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: _progressValue,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              SizedBox(height: 8),
              Text(
                'Waiting for data...',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          )
        else
          ElevatedButton(
            onPressed: _isConnecting || _selectedPort == null ? null : _connect,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: _isConnecting
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Connecting...'),
                    ],
                  )
                : Text('Connect'),
          ),
      ],
    );
  }
}
