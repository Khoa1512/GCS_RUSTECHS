import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'package:skylink/api/telemetry/mavlink/events.dart';
import 'dart:async';

class ParamsPage extends StatefulWidget {
  const ParamsPage({super.key});

  @override
  State<ParamsPage> createState() => _ParamsPageState();
}

class _ParamsPageState extends State<ParamsPage> {
  final TelemetryService _telemetryService = TelemetryService();
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _mavlinkSubscription;

  Map<String, double> get _parameters =>
      _telemetryService.mavlinkAPI.parameters;
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String? _selectedParameter;
  final TextEditingController _searchController = TextEditingController();

  // Parameter categories for sidebar
  final List<String> _categories = [
    'All',
    'ARMING',
    'ACRO',
    'AHRS',
    'BATT',
    'COMPASS',
    'EK2',
    'EK3',
    'FENCE',
    'GPS',
    'INS',
    'LAND',
    'LOG',
    'LOITER',
    'MISSION',
    'PILOT',
    'RC',
    'RTL',
    'SERVO',
    'STABILIZE',
    'WPNAV',
  ];

  // Track modified parameters
  final Set<String> _modifiedParameters = {};

  // Loading progress
  int _receivedCount = 0;
  int _totalCount = 0;
  double get _loadingProgress =>
      _totalCount > 0 ? _receivedCount / _totalCount : 0.0;
  @override
  void initState() {
    super.initState();
    _listenToConnection();
    _listenToMavlinkEvents();
    if (_telemetryService.isConnected) {
      _loadParameters();
    }
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _mavlinkSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToConnection() {
    _connectionSubscription = _telemetryService.connectionStream.listen((
      isConnected,
    ) {
      if (isConnected) {
        _loadParameters();
      } else {
        setState(() {
          // Clear all parameter-related data when disconnected
          _telemetryService.mavlinkAPI.parameters.clear();
          _modifiedParameters.clear();
          _receivedCount = 0;
          _totalCount = 0;
          _isLoading = false;
          _selectedParameter = null;
        });
      }
    });
  }

  void _listenToMavlinkEvents() {
    _mavlinkSubscription = _telemetryService.mavlinkAPI.eventStream.listen((
      event,
    ) {
      if (event.type == MAVLinkEventType.parameterReceived) {
        final index = event.data['index'] as int;
        final count = event.data['count'] as int;

        setState(() {
          _receivedCount = index + 1;
          _totalCount = count;
        });
      } else if (event.type == MAVLinkEventType.allParametersReceived) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _loadParameters() {
    if (!_telemetryService.isConnected) return;

    setState(() {
      _isLoading = true;
      _receivedCount = 0;
      _totalCount = 0;
    });

    // Request all parameters from vehicle
    _telemetryService.mavlinkAPI.requestAllParameters();
  }

  List<MapEntry<String, double>> get _filteredParameters {
    final paramList = _parameters.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    var filtered = paramList;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (param) =>
                param.key.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    // Filter by category
    if (_selectedCategory != 'All') {
      filtered = filtered
          .where((param) => param.key.startsWith(_selectedCategory))
          .toList();
    }

    return filtered;
  }

  void _setParameter(String paramName, double value) {
    if (!_telemetryService.isConnected) return;
    _telemetryService.mavlinkAPI.setParameter(paramName, value);

    // Track modified parameters
    setState(() {
      _modifiedParameters.add(paramName);
    });
  }

  Widget _buildParameterTable() {
    final filteredParams = _filteredParameters;

    if (_isLoading && _parameters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Loading parameters...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'This may take a few minutes for ArduPilot vehicles',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_parameters.isEmpty) {
      if (!_telemetryService.isConnected) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.link_off, size: 80, color: Colors.grey.shade600),
              SizedBox(height: 16),
              Text(
                'Not Connected',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Connect to vehicle to view and edit parameters',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      } else {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber,
                size: 80,
                color: Colors.orange.shade400,
              ),
              SizedBox(height: 16),
              Text(
                'No Parameters Received',
                style: TextStyle(
                  color: Colors.orange.shade400,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try refreshing to load parameters from vehicle',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadParameters,
                icon: Icon(Icons.refresh),
                label: Text('Refresh Parameters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                ),
              ),
            ],
          ),
        );
      }
    }

    return Column(
      children: [
        // Table Header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade700,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade600, width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              // Status Column
              SizedBox(
                width: 40,
                child: Icon(Icons.edit, color: Colors.grey.shade500, size: 16),
              ),
              Container(width: 1, height: 24, color: Colors.grey.shade600),

              // Command Column
              Expanded(
                flex: 4,
                child: Text(
                  'Command',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(width: 1, height: 24, color: Colors.grey.shade600),

              // Value Column
              Expanded(
                flex: 2,
                child: Text(
                  'Value',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(width: 1, height: 24, color: Colors.grey.shade600),

              // Units Column
              Expanded(
                flex: 1,
                child: Text(
                  'Units',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(width: 1, height: 24, color: Colors.grey.shade600),

              // Description Column
              Expanded(
                flex: 6,
                child: Text(
                  'Description',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        // Table Rows
        Expanded(
          child: ListView.builder(
            itemCount: filteredParams.length,
            itemBuilder: (context, index) {
              final param = filteredParams[index];
              final isEvenRow = index % 2 == 0;
              final isSelected = param.key == _selectedParameter;
              final isModified = _modifiedParameters.contains(param.key);

              return _buildParameterRow(
                param,
                isEvenRow,
                isSelected,
                isModified,
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatParameterValue(double value) {
    // Handle common precision issues
    if (value.abs() < 1e-10) return '0';

    // Check if it's close to an integer
    if ((value - value.round()).abs() < 1e-10) {
      return value.round().toString();
    }

    // For decimal values, use smart formatting
    String str = value.toString();

    // Remove trailing zeros after decimal point
    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'0*$'), '');
      str = str.replaceAll(RegExp(r'\.$'), '');
    }

    // Limit to reasonable precision for display
    if (str.contains('.')) {
      List<String> parts = str.split('.');
      if (parts[1].length > 6) {
        return value
            .toStringAsFixed(6)
            .replaceAll(RegExp(r'0*$'), '')
            .replaceAll(RegExp(r'\.$'), '');
      }
    }

    return str;
  }

  Widget _buildParameterRow(
    MapEntry<String, double> param,
    bool isEvenRow,
    bool isSelected,
    bool isModified,
  ) {
    final controller = TextEditingController(
      text: _formatParameterValue(param.value),
    );

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.blue.shade700.withOpacity(0.4)
            : (isEvenRow
                  ? Colors.grey.shade800
                  : Colors.grey.shade700.withOpacity(0.8)),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade700, width: 0.5),
          left: isSelected
              ? BorderSide(color: Colors.blue.shade400, width: 3)
              : BorderSide.none,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.blue.shade400.withOpacity(0.2),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedParameter = param.key;
            });
          },
          hoverColor: Colors.grey.shade600.withOpacity(0.3),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // Status Indicator Column
                SizedBox(
                  width: 40,
                  child: Center(
                    child: isModified
                        ? Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade400,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 12,
                            ),
                          )
                        : SizedBox.shrink(),
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.grey.shade600),

                // Command Column
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: SelectableText(
                      param.key,
                      style: TextStyle(
                        color: isModified
                            ? Colors.orange.shade300
                            : Colors.blue.shade300,
                        fontFamily: 'monospace',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.grey.shade600),

                // Value Column (Editable)
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isModified
                              ? Colors.orange.shade400
                              : Colors.grey.shade600,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: controller,
                        style: TextStyle(
                          color: isModified
                              ? Colors.orange.shade300
                              : Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: InputBorder.none,
                          filled: true,
                          fillColor: Colors.grey.shade900,
                          hoverColor: Colors.grey.shade800,
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(
                              color: Colors.blue.shade400,
                              width: 2,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.-]')),
                        ],
                        onSubmitted: (value) {
                          final newValue = double.tryParse(value);
                          if (newValue != null && newValue != param.value) {
                            _setParameter(param.key, newValue);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${param.key} updated to $newValue',
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.green.shade600,
                                duration: Duration(seconds: 3),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.grey.shade600),

                // Units Column
                Expanded(
                  flex: 1,
                  child: Text(
                    _getParameterUnit(param.key),
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.grey.shade600),

                // Description Column
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      _getParameterDescription(param.key),
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParameterDetailsPanel() {
    if (_selectedParameter == null) return SizedBox.shrink();

    final paramValue = _parameters[_selectedParameter!];
    final isModified = _modifiedParameters.contains(_selectedParameter!);

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        border: Border(left: BorderSide(color: Colors.grey.shade700, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade600, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade300, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Parameter Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedParameter = null;
                    });
                  },
                  icon: Icon(Icons.close, color: Colors.grey.shade400),
                  iconSize: 20,
                ),
              ],
            ),
          ),

          // Parameter Info
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parameter Name
                  Text(
                    'Parameter Name',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  SelectableText(
                    _selectedParameter!,
                    style: TextStyle(
                      color: isModified
                          ? Colors.orange.shade300
                          : Colors.blue.shade300,
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 16),

                  // Current Value
                  Text(
                    'Current Value',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    paramValue != null
                        ? _formatParameterValue(paramValue)
                        : 'N/A',
                    style: TextStyle(
                      color: isModified ? Colors.orange.shade300 : Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 8),

                  // Units
                  Text(
                    'Units: ${_getParameterUnit(_selectedParameter!)}',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),

                  SizedBox(height: 16),

                  // Status
                  if (isModified)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade600.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange.shade400),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit,
                            color: Colors.orange.shade400,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Modified',
                            style: TextStyle(
                              color: Colors.orange.shade400,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 16),

                  // Description
                  Text(
                    'Description',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _getParameterDescription(_selectedParameter!),
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),

                  SizedBox(height: 16),

                  // Quick Actions
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),

                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: _selectedParameter!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Parameter name copied to clipboard'),
                        ),
                      );
                    },
                    icon: Icon(Icons.copy, size: 16),
                    label: Text('Copy Name'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),

                  SizedBox(height: 8),

                  ElevatedButton.icon(
                    onPressed: () {
                      final valueText = paramValue != null
                          ? _formatParameterValue(paramValue)
                          : '';
                      Clipboard.setData(ClipboardData(text: valueText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Parameter value copied to clipboard'),
                        ),
                      );
                    },
                    icon: Icon(Icons.copy, size: 16),
                    label: Text('Copy Value'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      foregroundColor: Colors.white,
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

  String _getParameterUnit(String paramName) {
    // Common ArduPilot parameter units
    if (paramName.contains('RATE') || paramName.contains('TURN')) {
      return 'deg/s';
    }
    if (paramName.contains('ANGLE') || paramName.contains('TRIM')) return 'deg';
    if (paramName.contains('SPEED') || paramName.contains('VEL')) return 'm/s';
    if (paramName.contains('ALT') || paramName.contains('HEIGHT')) return 'm';
    if (paramName.contains('DIST') || paramName.contains('RADIUS')) return 'm';
    if (paramName.contains('TIME') || paramName.contains('TIMEOUT')) return 's';
    if (paramName.contains('VOLT') || paramName.contains('BATT')) return 'V';
    if (paramName.contains('CURR') || paramName.contains('AMP')) return 'A';
    if (paramName.contains('FREQ') || paramName.contains('HZ')) return 'Hz';
    if (paramName.contains('PWM') || paramName.contains('SERVO')) return 'pwm';
    if (paramName.contains('GAIN') ||
        paramName.contains('P_') ||
        paramName.contains('I_') ||
        paramName.contains('D_')) {
      return '';
    }
    return '';
  }

  String _getParameterDescription(String paramName) {
    // Common ArduPilot parameter descriptions
    final descriptions = {
      'ARMING_CHECK': 'Arming check bitmask',
      'BATT_MONITOR': 'Battery monitoring',
      'COMPASS_USE': 'Use compass for navigation',
      'GPS_TYPE': 'GPS receiver type',
      'RC1_MIN': 'RC channel 1 minimum',
      'RC1_MAX': 'RC channel 1 maximum',
      'SERVO1_FUNCTION': 'Servo 1 function',
      'FLTMODE1': 'Flight mode 1',
      'WPNAV_SPEED': 'Waypoint navigation speed',
      'PILOT_SPEED_UP': 'Pilot maximum climb rate',
    };

    // Check for exact match first
    if (descriptions.containsKey(paramName)) {
      return descriptions[paramName]!;
    }

    // Check for partial matches
    for (final key in descriptions.keys) {
      if (paramName.startsWith(key.split('_')[0])) {
        return descriptions[key]!;
      }
    }

    // Generic descriptions based on parameter prefix
    if (paramName.startsWith('ARMING_')) return 'Arming safety check parameter';
    if (paramName.startsWith('BATT_')) return 'Battery monitoring parameter';
    if (paramName.startsWith('COMPASS_')) {
      return 'Compass configuration parameter';
    }
    if (paramName.startsWith('GPS_')) return 'GPS receiver parameter';
    if (paramName.startsWith('RC')) return 'Radio control channel parameter';
    if (paramName.startsWith('SERVO')) return 'Servo output parameter';
    if (paramName.startsWith('FLTMODE')) return 'Flight mode configuration';
    if (paramName.startsWith('WPNAV_')) return 'Waypoint navigation parameter';
    if (paramName.startsWith('PILOT_')) return 'Pilot input parameter';
    if (paramName.startsWith('ACRO_')) return 'Acrobatic mode parameter';
    if (paramName.startsWith('STAB_')) return 'Stabilize mode parameter';
    if (paramName.startsWith('LOITER_')) return 'Loiter mode parameter';
    if (paramName.startsWith('RTL_')) return 'Return to launch parameter';
    if (paramName.startsWith('LAND_')) return 'Landing parameter';
    if (paramName.startsWith('FENCE_')) return 'Geofence parameter';
    if (paramName.startsWith('FAILSAFE_')) return 'Failsafe parameter';

    return 'Vehicle configuration parameter';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: Row(
        children: [
          // Sidebar với Categories
          _buildSidebar(),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Header với Toolbar
                _buildHeader(),

                // Connection Status
                if (!_telemetryService.isConnected) _buildConnectionStatus(),

                // Search và Filters
                _buildSearchAndFilters(),

                // Parameters Table
                Expanded(
                  child: Row(
                    children: [
                      // Parameter Table
                      Expanded(flex: 3, child: _buildParameterTable()),

                      // Parameter Details Panel
                      if (_selectedParameter != null)
                        SizedBox(
                          width: 350,
                          child: _buildParameterDetailsPanel(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        border: Border(
          right: BorderSide(color: Colors.grey.shade700, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Sidebar Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade600, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.category, color: Colors.blue.shade300, size: 20),
                SizedBox(width: 8),
                Text(
                  'Categories',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // Category List
          Expanded(
            child: _telemetryService.isConnected
                ? ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = category == _selectedCategory;
                      final count = category == 'All'
                          ? _parameters.length
                          : _parameters.keys
                                .where((key) => key.startsWith(category))
                                .length;

                      return Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCategory = category;
                                _selectedParameter = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            hoverColor: Colors.grey.shade600.withOpacity(0.3),
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue.shade700.withOpacity(0.4)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.blue.shade400,
                                        width: 1.5,
                                      )
                                    : Border.all(color: Colors.transparent),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.blue.shade400
                                              .withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.blue.shade200
                                            : Colors.grey.shade300,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        fontSize: 13.5,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                  if (count > 0)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.blue.shade600
                                            : Colors.grey.shade700,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        count.toString(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.link_off,
                          size: 40,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Disconnected',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Connect to view\ncategories',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),

          // Sidebar Footer với Statistics
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              border: Border(
                top: BorderSide(color: Colors.grey.shade600, width: 1),
              ),
            ),
            child: Column(
              children: [
                _buildStatItem('Total Parameters', _parameters.length),
                SizedBox(height: 8),
                _buildStatItem('Modified', _modifiedParameters.length),
                SizedBox(height: 8),
                _buildStatItem('Filtered', _filteredParameters.length),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            color: Colors.blue.shade300,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.settings, color: Colors.white, size: 28),
          SizedBox(width: 12),
          Text(
            'Vehicle Parameters',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 16),

          // Quick Action Buttons
          _buildQuickActionButton(
            icon: Icons.save,
            label: 'Save to File',
            onPressed: () {
              // TODO: Implement save to file
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Save functionality coming soon')),
              );
            },
          ),
          SizedBox(width: 8),
          _buildQuickActionButton(
            icon: Icons.upload_file,
            label: 'Load from File',
            onPressed: () {
              // TODO: Implement load from file
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Load functionality coming soon')),
              );
            },
          ),
          SizedBox(width: 8),
          _buildQuickActionButton(
            icon: Icons.compare_arrows,
            label: 'Compare',
            onPressed: () {
              // TODO: Implement parameter comparison
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Compare functionality coming soon')),
              );
            },
          ),

          Spacer(),

          // Loading Progress
          if (_isLoading)
            Row(
              children: [
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Loading: $_receivedCount / $_totalCount',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _loadingProgress,
                        backgroundColor: Colors.grey.shade600,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
              ],
            ),

          // Refresh Button
          if (_telemetryService.isConnected)
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _loadParameters,
              icon: Icon(Icons.refresh),
              label: Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: label,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey.shade300,
          side: BorderSide(color: Colors.grey.shade600),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      color: Colors.red.shade700,
      child: Text(
        'Not connected to vehicle. Please connect to view parameters.',
        style: TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    if (!_telemetryService.isConnected) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade700, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Search Box
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search parameters... (e.g., ARMING, RC, SERVO)',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade800,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade600),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue.shade400),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              style: TextStyle(color: Colors.white),
            ),
          ),

          SizedBox(width: 16),

          // Filter Options
          if (_modifiedParameters.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                  // Show only modified parameters
                });
              },
              icon: Icon(Icons.edit, size: 16),
              label: Text('Modified (${_modifiedParameters.length})'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade400,
                side: BorderSide(color: Colors.orange.shade400),
              ),
            ),

          SizedBox(width: 8),

          // Clear Filters
          if (_searchQuery.isNotEmpty || _selectedCategory != 'All')
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _selectedCategory = 'All';
                  _searchController.clear();
                });
              },
              icon: Icon(Icons.clear, size: 16),
              label: Text('Clear Filters'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade400,
              ),
            ),
        ],
      ),
    );
  }
}
