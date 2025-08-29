import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:skylink/presentation/widget/flight/compass_heading_tape.dart';
import 'package:skylink/services/telemetry_service.dart';

class PrimaryFlightDisplay extends StatefulWidget {
  // Remove static parameters - now using real-time telemetry
  const PrimaryFlightDisplay({super.key});

  @override
  State<PrimaryFlightDisplay> createState() => _PrimaryFlightDisplayState();
}

class _PrimaryFlightDisplayState extends State<PrimaryFlightDisplay>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pitchAnimation;
  late Animation<double> _rollAnimation;

  final TelemetryService _telemetryService = TelemetryService();

  // Current telemetry values for animations
  double _currentPitch = 0.0;
  double _currentRoll = 0.0;

  // Debouncing for mode and armed status
  String _lastFlightMode = '';
  bool _lastArmedState = false;
  DateTime? _lastModeChange;
  DateTime? _lastArmedChange;
  static const Duration _debounceDelay = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 100), // Faster for real-time feel
      vsync: this,
    );

    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pitchAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _rollAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  void _updateAnimations(double newPitch, double newRoll) {
    // Only animate if there's significant change (reduce jitter)
    double pitchDiff = (newPitch - _currentPitch).abs();
    double rollDiff = (newRoll - _currentRoll).abs();

    if (pitchDiff < 0.5 && rollDiff < 0.5) return; // Skip small changes

    _pitchAnimation = Tween<double>(begin: _currentPitch, end: newPitch)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOut, // Faster curve
          ),
        );

    _rollAnimation = Tween<double>(begin: _currentRoll, end: newRoll).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _currentPitch = newPitch;
    _currentRoll = newRoll;

    _animationController.reset();
    _animationController.forward();
  }

  // Debounced mode and armed status checking
  bool _shouldUpdateMode(String newMode) {
    if (newMode == _lastFlightMode) return false;

    DateTime now = DateTime.now();
    if (_lastModeChange != null &&
        now.difference(_lastModeChange!) < _debounceDelay) {
      return false;
    }

    _lastFlightMode = newMode;
    _lastModeChange = now;
    return true;
  }

  bool _shouldUpdateArmedStatus(bool newArmedState) {
    if (newArmedState == _lastArmedState) return false;

    DateTime now = DateTime.now();
    if (_lastArmedChange != null &&
        now.difference(_lastArmedChange!) < _debounceDelay) {
      return false;
    }

    _lastArmedState = newArmedState;
    _lastArmedChange = now;
    return true;
  }

  // Improved armed status detection with hysteresis
  bool _getStableArmedStatus(double armedValue) {
    // Use hysteresis to prevent jitter: 0.3/0.7 instead of 0.5
    if (_lastArmedState) {
      return armedValue > 0.3; // Stay armed until clearly disarmed
    } else {
      return armedValue > 0.7; // Need clear signal to arm
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getCardinalDirection(double heading) {
    // Chuyển đổi heading thành hướng chính xác
    if (heading >= 337.5 || heading < 22.5) return 'N';
    if (heading >= 22.5 && heading < 67.5) return 'NE';
    if (heading >= 67.5 && heading < 112.5) return 'E';
    if (heading >= 112.5 && heading < 157.5) return 'SE';
    if (heading >= 157.5 && heading < 202.5) return 'S';
    if (heading >= 202.5 && heading < 247.5) return 'SW';
    if (heading >= 247.5 && heading < 292.5) return 'W';
    if (heading >= 292.5 && heading < 337.5) return 'NW';
    return 'N';
  }

  // Get flight mode colors based on the mode type
  List<Color> _getFlightModeColors(String flightMode, bool isArmed) {
    // Safety modes - Red
    if (['RTL', 'LAND', 'QLAND', 'EMERGENCY'].contains(flightMode)) {
      return [Color(0xFFE53935), Color(0xFFB71C1C)];
    }

    // Autonomous modes - Blue
    if ([
      'AUTO',
      'GUIDED',
      'TAKEOFF',
      'LOITER',
      'QLOITER',
      'QRTL',
    ].contains(flightMode)) {
      return [Color(0xFF1976D2), Color(0xFF0D47A1)];
    }

    // Manual/Stabilized modes - Green when armed, Orange when disarmed
    if ([
      'MANUAL',
      'STABILIZE',
      'ACRO',
      'QSTABILIZE',
      'QACRO',
      'QHOVER',
    ].contains(flightMode)) {
      return isArmed
          ? [Color(0xFF4CAF50), Color(0xFF2E7D32)]
          : [Color(0xFFFF9800), Color(0xFFE65100)];
    }

    // Assisted modes - Purple
    if ([
      'FBWA',
      'FBWB',
      'CRUISE',
      'AUTOTUNE',
      'QAUTOTUNE',
      'CIRCLE',
    ].contains(flightMode)) {
      return [Color(0xFF7B1FA2), Color(0xFF4A148C)];
    }

    // Unknown or training modes - Gray
    return [Color(0xFF757575), Color(0xFF424242)];
  }

  // Get single flight mode color for shadow
  Color _getFlightModeColor(String flightMode, bool isArmed) {
    if (['RTL', 'LAND', 'QLAND', 'EMERGENCY'].contains(flightMode)) {
      return Colors.red;
    }
    if ([
      'AUTO',
      'GUIDED',
      'TAKEOFF',
      'LOITER',
      'QLOITER',
      'QRTL',
    ].contains(flightMode)) {
      return Colors.blue;
    }
    if ([
      'MANUAL',
      'STABILIZE',
      'ACRO',
      'QSTABILIZE',
      'QACRO',
      'QHOVER',
    ].contains(flightMode)) {
      return isArmed ? Colors.green : Colors.orange;
    }
    if ([
      'FBWA',
      'FBWB',
      'CRUISE',
      'AUTOTUNE',
      'QAUTOTUNE',
      'CIRCLE',
    ].contains(flightMode)) {
      return Colors.purple;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1419), Color(0xFF1A1F2B), Color(0xFF0F1419)],
        ),
        border: Border.all(color: Color(0xFF2A3441), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0xFF0A7C8C).withOpacity(0.1),
            blurRadius: 30,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with connection status
          _buildHeader(),
          // Fixed height compass heading tape
          SizedBox(
            height: 50,
            child: StreamBuilder<Map<String, double>>(
              stream: _telemetryService.telemetryStream,
              builder: (context, snapshot) {
                final telemetryData = snapshot.data ?? {};
                // Only use stabilized compass_heading
                final compassHeading = telemetryData['compass_heading'] ?? 0.0;

                return CompassHeadingTape(
                  heading: compassHeading < 0
                      ? compassHeading + 360
                      : compassHeading,
                  height: 50,
                );
              },
            ),
          ),
          // Attitude indicator takes remaining space
          Expanded(
            child: StreamBuilder<Map<String, double>>(
              stream: _telemetryService.telemetryStream,
              builder: (context, snapshot) {
                final telemetryData = snapshot.data ?? {};
                final isConnected = _telemetryService.isConnected;

                // Extract telemetry values with improved stability
                final pitch = telemetryData['pitch'] ?? 0.0;
                final roll = telemetryData['roll'] ?? 0.0;
                final yaw = telemetryData['yaw'] ?? 0.0;
                // Only use stabilized compass_heading
                final compassHeading = telemetryData['compass_heading'] ?? 0.0;
                final altitude = telemetryData['altitude_rel'] ?? 0.0;
                final speed = telemetryData['groundspeed'] ?? 0.0;
                final armedValue = telemetryData['armed'] ?? 0.0;

                // Use stable armed status detection
                final isArmed = _getStableArmedStatus(armedValue);
                final currentMode = _telemetryService.currentMode;

                // Update animations only when data changes significantly
                if (snapshot.hasData) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _updateAnimations(pitch, roll);
                  });
                }

                return Padding(
                  padding: EdgeInsets.all(16),
                  child: _buildAttitudeIndicator(
                    pitch,
                    roll,
                    yaw,
                    altitude,
                    speed,
                    isArmed,
                    isConnected,
                    compassHeading,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<bool>(
      stream: _telemetryService.connectionStream,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? false;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E2936), Color(0xFF2A3441)],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            border: Border(
              bottom: BorderSide(color: Color(0xFF0A7C8C), width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.flight, color: Color(0xFF0A7C8C), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Primary Flight Display',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              StreamBuilder<Map<String, double>>(
                stream: _telemetryService.telemetryStream,
                builder: (context, snapshot) {
                  final telemetryData = snapshot.data ?? {};
                  final armedValue = telemetryData['armed'] ?? 0.0;
                  final isArmed = _getStableArmedStatus(armedValue);
                  final flightMode = _telemetryService.currentMode;

                  // Only rebuild if mode or armed status actually changed
                  if (!_shouldUpdateMode(flightMode) &&
                      !_shouldUpdateArmedStatus(isArmed)) {
                    // Return cached widget or previous state
                  }

                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isConnected
                            ? _getFlightModeColors(flightMode, isArmed)
                            : [Color(0xFFE53935), Color(0xFFB71C1C)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isConnected
                                      ? _getFlightModeColor(flightMode, isArmed)
                                      : Colors.red)
                                  .withOpacity(0.3),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isConnected ? Icons.flight : Icons.signal_wifi_off,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          isConnected
                              ? flightMode.toUpperCase()
                              : 'DISCONNECTED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttitudeIndicator(
    double pitch,
    double roll,
    double yaw,
    double altitude,
    double speed,
    bool isArmed,
    bool isConnected,
    double compassHeading,
  ) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xFF1A1F2B), Color(0xFF0F1419)],
            ),
            border: Border.all(color: Color(0xFF2A3441), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Main attitude display
              CustomPaint(
                size: Size.infinite,
                painter: AttitudeIndicatorPainter(
                  pitch: _pitchAnimation.value,
                  roll: _rollAnimation.value,
                  heading: yaw, // Use yaw for attitude indicator
                ),
              ),
              // Flight data overlay - left side with real-time data
              Positioned(
                left: 20,
                top: 20,
                child: _buildFlightDataOverlay(
                  altitude,
                  speed,
                  compassHeading,
                  isConnected,
                ),
              ),
              // ARM status - bottom right corner for prominence and no overlap
              Positioned(
                right: 20,
                bottom: 20,
                child: _buildArmStatusItem(isConnected, isArmed),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFlightDataOverlay(
    double altitude,
    double speed,
    double compassHeading,
    bool isConnected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Altitude
        _buildDataItem(
          'ALT',
          '${altitude.toStringAsFixed(1)}m',
          isConnected ? Color(0xFF00BCD4) : Colors.grey,
          Icons.height,
        ),
        SizedBox(height: 12),
        // Speed
        _buildDataItem(
          'SPD',
          '${speed.toStringAsFixed(1)}m/s',
          isConnected ? Color(0xFF4CAF50) : Colors.grey,
          Icons.speed,
        ),
        SizedBox(height: 12),
        // Heading - use compassHeading for consistency with compass tape
        _buildDataItem(
          'HDG',
          '${_getCardinalDirection(compassHeading)} ${compassHeading.toStringAsFixed(0)}°',
          isConnected ? Color(0xFFFF9800) : Colors.grey,
          Icons.explore,
        ),
      ],
    );
  }

  Widget _buildDataItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  // Prominent ARM status display for safety
  Widget _buildArmStatusItem(bool isConnected, bool isArmed) {
    // Only show ARM status when connected, otherwise don't show anything
    if (!isConnected) {
      return SizedBox.shrink(); // Hidden when not connected
    }

    // Connected - show ARM status
    Color statusColor = isArmed ? Colors.red : Colors.green;
    Color backgroundColor = isArmed
        ? Colors.red.withOpacity(0.2)
        : Colors.green.withOpacity(0.2);
    String statusText = isArmed ? 'ARMED' : 'DISARMED';
    IconData statusIcon = isArmed ? Icons.warning : Icons.shield;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.4),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          if (isArmed) ...[
            SizedBox(width: 6),
            // Slower blinking for less distraction
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                // Slower blinking with longer on-time
                double blinkValue =
                    (DateTime.now().millisecondsSinceEpoch / 800) % 2;
                double opacity = blinkValue < 1.5 ? 1.0 : 0.3;

                return Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.6),
                          blurRadius: 4,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// Removed PitchScalePainter class completely

// Giữ nguyên AttitudeIndicatorPainter như cũ nhưng bỏ heading display
class AttitudeIndicatorPainter extends CustomPainter {
  final double pitch;
  final double roll;
  final double heading;

  AttitudeIndicatorPainter({
    required this.pitch,
    required this.roll,
    required this.heading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        math.min(size.width, size.height) / 2 -
        50; // More space for pitch scale

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Clip to circle
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );

    // Draw artificial horizon
    _drawArtificialHorizon(canvas, radius);

    // Draw pitch ladder
    _drawPitchLadder(canvas, radius);

    canvas.restore();
    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Draw roll indicator
    _drawRollIndicator(canvas, radius);

    // Draw aircraft symbol (always on top)
    _drawAircraftSymbol(canvas);

    canvas.restore();
  }

  void _drawArtificialHorizon(Canvas canvas, double radius) {
    canvas.save();
    canvas.rotate(roll * math.pi / 180);

    // Calculate horizon line position based on pitch
    final horizonOffset = (pitch / 90) * radius * 2;

    // Sky gradient
    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF1E88E5), // Bright blue
        Color(0xFF42A5F5), // Medium blue
        Color(0xFF90CAF9), // Light blue
      ],
    );

    // Ground gradient
    final groundGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF8D6E63), // Brown
        Color(0xFF6D4C41), // Dark brown
        Color(0xFF3E2723), // Very dark brown
      ],
    );

    // Draw sky
    final skyRect = Rect.fromLTRB(
      -radius * 2,
      -radius * 2,
      radius * 2,
      horizonOffset,
    );
    final skyPaint = Paint()..shader = skyGradient.createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    // Draw ground
    final groundRect = Rect.fromLTRB(
      -radius * 2,
      horizonOffset,
      radius * 2,
      radius * 2,
    );
    final groundPaint = Paint()
      ..shader = groundGradient.createShader(groundRect);
    canvas.drawRect(groundRect, groundPaint);

    // Draw horizon line with glow effect
    final horizonPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    // Draw glow first
    canvas.drawLine(
      Offset(-radius * 2, horizonOffset),
      Offset(radius * 2, horizonOffset),
      glowPaint,
    );

    // Draw main line
    canvas.drawLine(
      Offset(-radius * 2, horizonOffset),
      Offset(radius * 2, horizonOffset),
      horizonPaint,
    );

    canvas.restore();
  }

  void _drawPitchLadder(Canvas canvas, double radius) {
    canvas.save();
    canvas.rotate(roll * math.pi / 180);

    final textPaint = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Draw pitch lines every 5 degrees, with numbers only on 10-degree intervals
    for (int angle = -30; angle <= 30; angle += 5) {
      if (angle == 0) continue; // Skip horizon line

      final y = -(angle + pitch) / 90 * radius * 3.0; // Much wider spacing
      if (y.abs() > radius * 1.5) continue; // Allow more extension

      bool isMajor = angle % 10 == 0; // Major lines every 10° (with numbers)

      // Different line lengths for major and minor
      final lineLength = isMajor
          ? 50.0
          : 30.0; // Long for major, short for minor
      final strokeWidth = isMajor ? 2.0 : 1.5;

      // Draw pitch line with color coding
      final paint = Paint()
        ..color = angle > 0 ? Color(0xFF4CAF50) : Color(0xFFFF5722)
        ..strokeWidth = strokeWidth;

      canvas.drawLine(
        Offset(-lineLength / 2, y),
        Offset(lineLength / 2, y),
        paint,
      );

      // Draw angle labels ONLY on major lines (every 10°)
      if (isMajor) {
        String label = angle > 0 ? '+$angle' : '$angle';

        textPaint.text = TextSpan(
          text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1)),
            ],
          ),
        );
        textPaint.layout();

        // Draw label only on LEFT side
        textPaint.paint(canvas, Offset(-lineLength / 2 - 30, y - 8));
      }
    }

    canvas.restore();
  }

  void _drawAircraftSymbol(Canvas canvas) {
    // Aircraft symbol with glow effect
    final aircraftPaint = Paint()
      ..color = Color(0xFFFFEB3B)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = Color(0xFFFFEB3B).withOpacity(0.3)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw glow first
    canvas.drawLine(Offset(-40, 0), Offset(-12, 0), glowPaint);
    canvas.drawLine(Offset(12, 0), Offset(40, 0), glowPaint);
    canvas.drawLine(Offset(0, -20), Offset(0, -8), glowPaint);

    // Draw main aircraft symbol
    canvas.drawLine(Offset(-40, 0), Offset(-12, 0), aircraftPaint);
    canvas.drawLine(Offset(12, 0), Offset(40, 0), aircraftPaint);
    canvas.drawLine(Offset(0, -20), Offset(0, -8), aircraftPaint);

    // Center dot with glow
    canvas.drawCircle(
      Offset.zero,
      6,
      Paint()
        ..color = Color(0xFFFFEB3B).withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset.zero,
      4,
      Paint()
        ..color = Color(0xFFFFEB3B)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawRollIndicator(Canvas canvas, double radius) {
    final rollRadius = radius + 15;

    // Define roll angles with different mark types
    final rollAngles = [
      {'angle': -60, 'major': true},
      {'angle': -45, 'major': true},
      {'angle': -30, 'major': true},
      {'angle': -20, 'major': false},
      {'angle': -10, 'major': false},
      {'angle': 0, 'major': true},
      {'angle': 10, 'major': false},
      {'angle': 20, 'major': false},
      {'angle': 30, 'major': true},
      {'angle': 45, 'major': true},
      {'angle': 60, 'major': true},
    ];

    for (var rollData in rollAngles) {
      int angle = rollData['angle'] as int;
      bool isMajor = rollData['major'] as bool;

      final tickAngle = angle * math.pi / 180;

      // Different sizes for major and minor marks
      final innerRadius = rollRadius - (angle == 0 ? 15 : (isMajor ? 12 : 8));
      final outerRadius = rollRadius + 5;
      final strokeWidth = isMajor ? 2.0 : 1.0;

      final innerPoint = Offset(
        innerRadius * math.sin(tickAngle),
        -innerRadius * math.cos(tickAngle),
      );
      final outerPoint = Offset(
        outerRadius * math.sin(tickAngle),
        -outerRadius * math.cos(tickAngle),
      );

      final paint = Paint()
        ..color = Colors.white
        ..strokeWidth = strokeWidth;

      canvas.drawLine(innerPoint, outerPoint, paint);

      // Draw angle numbers only for major marks (except 0°)
      if (isMajor && angle != 0) {
        final textPaint = TextPainter(
          text: TextSpan(
            text: angle.abs().toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: angle.abs() >= 30 ? 12 : 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPaint.layout();

        final textPoint = Offset(
          (rollRadius + 20) * math.sin(tickAngle) - textPaint.width / 2,
          -(rollRadius + 20) * math.cos(tickAngle) - textPaint.height / 2,
        );
        textPaint.paint(canvas, textPoint);
      }
    }

    // Draw roll indicator triangle
    canvas.save();
    canvas.rotate(roll * math.pi / 180);

    final trianglePaint = Paint()
      ..color = Color(0xFFFF5722)
      ..style = PaintingStyle.fill;

    final trianglePath = Path();
    trianglePath.moveTo(0, -rollRadius - 12);
    trianglePath.lineTo(-10, -rollRadius + 8);
    trianglePath.lineTo(10, -rollRadius + 8);
    trianglePath.close();

    canvas.drawPath(trianglePath, trianglePaint);

    // Add glow to triangle
    final glowTrianglePaint = Paint()
      ..color = Color(0xFFFF5722).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final glowTrianglePath = Path();
    glowTrianglePath.moveTo(0, -rollRadius - 15);
    glowTrianglePath.lineTo(-12, -rollRadius + 10);
    glowTrianglePath.lineTo(12, -rollRadius + 10);
    glowTrianglePath.close();

    canvas.drawPath(glowTrianglePath, glowTrianglePaint);
    canvas.drawPath(trianglePath, trianglePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(AttitudeIndicatorPainter oldDelegate) {
    return oldDelegate.pitch != pitch ||
        oldDelegate.roll != roll ||
        oldDelegate.heading != heading;
  }
}
