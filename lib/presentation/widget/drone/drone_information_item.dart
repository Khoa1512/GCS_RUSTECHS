import 'package:flutter/material.dart';
import 'package:skylink/data/model/drone_information_mode.dart';
import 'package:skylink/presentation/widget/custom/custom_dotted_corner_border.dart';

class DroneInformationItem extends StatefulWidget {
  final DroneInformationModel droneInformation;
  const DroneInformationItem({super.key, required this.droneInformation});
  @override
  State<DroneInformationItem> createState() => _DroneInformationItemState();
}

class _DroneInformationItemState extends State<DroneInformationItem>
    with TickerProviderStateMixin {
  late AnimationController _takeoffController;
  late Animation<double> _liftAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _takeoffController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _liftAnimation = Tween<double>(begin: 0.0, end: -10.0).animate(
      CurvedAnimation(parent: _takeoffController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _takeoffController, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.02).animate(
      CurvedAnimation(parent: _takeoffController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _takeoffController.dispose();
    super.dispose();
  }

  void _startTakeoff() {
    _takeoffController.forward();
  }

  void _stopTakeoff() {
    _takeoffController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.droneInformation.name,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              SizedBox(height: 10),
              Text(widget.droneInformation.description),
            ],
          ),
          const Spacer(),
          MouseRegion(
            onEnter: (_) {
              setState(() => _isHovered = true);
              _startTakeoff();
            },
            onExit: (_) {
              setState(() => _isHovered = false);
              _stopTakeoff();
            },
            child: Container(
              padding: EdgeInsets.all(20),
              child: AnimatedBuilder(
                animation: _takeoffController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _liftAnimation.value),
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Transform.rotate(
                        angle: _rotationAnimation.value,
                        child: CustomPaint(
                          painter: DottedBorderPainter(),
                          child: Container(
                            height: 100,
                            width: 150,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: _isHovered
                                  ? [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: Image.asset(
                                widget.droneInformation.image,
                                height: 100,
                                width: 150,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
