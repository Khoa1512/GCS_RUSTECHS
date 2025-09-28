import 'package:flutter/material.dart';

class MissionTutorialOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final GlobalKey targetKey;

  const MissionTutorialOverlay({
    super.key,
    required this.onClose,
    required this.targetKey,
  });

  @override
  State<MissionTutorialOverlay> createState() => _MissionTutorialOverlayState();
}

class _MissionTutorialOverlayState extends State<MissionTutorialOverlay>
    with TickerProviderStateMixin {
  int currentStep = 0;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<TutorialStep> tutorialSteps = [
    TutorialStep(
      title: 'Chào mừng đến với Mission Planning!',
      description:
          'Hướng dẫn này sẽ giúp bạn tạo và quản lý mission bay một cách dễ dàng.',
      targetArea: null,
      showArrow: false,
    ),
    TutorialStep(
      title: 'Thêm Waypoint đầu tiên',
      description:
          'Nhấp vào nút "Add WP" hoặc click trực tiếp lên bản đồ để thêm điểm bay.',
      targetArea: Rect.fromLTWH(10, 580, 80, 40),
      showArrow: true,
      arrowDirection: ArrowDirection.up,
    ),
    TutorialStep(
      title: 'Chỉnh sửa Waypoint',
      description:
          'Click vào waypoint để chỉnh sửa độ cao, tốc độ và các thông số khác.',
      targetArea: null,
      showArrow: false,
    ),
    TutorialStep(
      title: 'Orbit - Bay vòng tròn',
      description:
          'Sử dụng chức năng Orbit để tạo đường bay vòng tròn quanh một điểm.',
      targetArea: Rect.fromLTWH(10, 620, 80, 40),
      showArrow: true,
      arrowDirection: ArrowDirection.up,
    ),
    TutorialStep(
      title: 'Survey - Khảo sát khu vực',
      description:
          'Chức năng Survey giúp tạo đường bay zigzag để chụp ảnh toàn bộ khu vực.',
      targetArea: Rect.fromLTWH(100, 650, 80, 40),
      showArrow: true,
      arrowDirection: ArrowDirection.up,
    ),
    TutorialStep(
      title: 'Kiểm tra Mission',
      description:
          'Xem thông tin tổng quan: số waypoint, khoảng cách, thời gian bay ước tính.',
      targetArea: null,
      showArrow: false,
    ),
    TutorialStep(
      title: 'Gửi Mission lên Flight Controller',
      description:
          'Sau khi hoàn tất, nhấn "Read Mission" để gửi mission lên máy bay.',
      targetArea: null,
      showArrow: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (currentStep < tutorialSteps.length - 1) {
      setState(() {
        currentStep++;
      });
      _slideController.reset();
      _slideController.forward();
    } else {
      _closeTutorial();
    }
  }

  void _previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
      _slideController.reset();
      _slideController.forward();
    }
  }

  void _closeTutorial() {
    _fadeController.reverse().then((_) {
      widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = tutorialSteps[currentStep];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.black.withOpacity(0.7),
        child: Stack(
          children: [
            // Background tap to close
            GestureDetector(
              onTap: _closeTutorial,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent,
              ),
            ),

            // Highlight target area if specified
            if (step.targetArea != null)
              Positioned(
                left: step.targetArea!.left,
                top: step.targetArea!.top,
                child: Container(
                  width: step.targetArea!.width,
                  height: step.targetArea!.height,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.teal, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),

            // Arrow pointing to target
            if (step.showArrow && step.targetArea != null) _buildArrow(step),

            // Tutorial content
            Center(
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.teal.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.help_outline,
                              color: Colors.teal,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              step.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _closeTutorial,
                            icon: const Icon(Icons.close, color: Colors.grey),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Content
                      Text(
                        step.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Progress indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          tutorialSteps.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index == currentStep
                                  ? Colors.teal
                                  : Colors.grey.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Navigation buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (currentStep > 0)
                            TextButton(
                              onPressed: _previousStep,
                              child: const Text(
                                'Quay lại',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          else
                            const SizedBox(),

                          ElevatedButton(
                            onPressed: _nextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              currentStep < tutorialSteps.length - 1
                                  ? 'Tiếp theo'
                                  : 'Hoàn thành',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrow(TutorialStep step) {
    if (step.targetArea == null) return const SizedBox();

    double arrowX = step.targetArea!.center.dx;
    double arrowY = step.targetArea!.top - 20;

    switch (step.arrowDirection) {
      case ArrowDirection.up:
        arrowY = step.targetArea!.top - 20;
        break;
      case ArrowDirection.down:
        arrowY = step.targetArea!.bottom + 20;
        break;
      case ArrowDirection.left:
        arrowX = step.targetArea!.left - 20;
        arrowY = step.targetArea!.center.dy;
        break;
      case ArrowDirection.right:
        arrowX = step.targetArea!.right + 20;
        arrowY = step.targetArea!.center.dy;
        break;
    }

    return Positioned(
      left: arrowX - 12,
      top: arrowY - 12,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.teal,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          _getArrowIcon(step.arrowDirection),
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  IconData _getArrowIcon(ArrowDirection direction) {
    switch (direction) {
      case ArrowDirection.up:
        return Icons.keyboard_arrow_up;
      case ArrowDirection.down:
        return Icons.keyboard_arrow_down;
      case ArrowDirection.left:
        return Icons.keyboard_arrow_left;
      case ArrowDirection.right:
        return Icons.keyboard_arrow_right;
    }
  }
}

class TutorialStep {
  final String title;
  final String description;
  final Rect? targetArea;
  final bool showArrow;
  final ArrowDirection arrowDirection;

  TutorialStep({
    required this.title,
    required this.description,
    this.targetArea,
    this.showArrow = false,
    this.arrowDirection = ArrowDirection.up,
  });
}

enum ArrowDirection { up, down, left, right }
