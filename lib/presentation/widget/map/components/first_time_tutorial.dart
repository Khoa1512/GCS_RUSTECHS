import 'package:flutter/material.dart';

class FirstTimeTutorial extends StatefulWidget {
  final Widget child;
  final List<TutorialStep> steps;
  final bool showOnFirstLoad;

  const FirstTimeTutorial({
    super.key,
    required this.child,
    required this.steps,
    this.showOnFirstLoad = false,
  });

  @override
  State<FirstTimeTutorial> createState() => _FirstTimeTutorialState();
}

class _FirstTimeTutorialState extends State<FirstTimeTutorial> {
  bool showTutorial = false;
  int currentStep = 0;

  @override
  void initState() {
    super.initState();
    if (widget.showOnFirstLoad) {
      _showTutorial();
    }
  }

  void _showTutorial() {
    // Show tutorial after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          showTutorial = true;
        });
      }
    });
  }

  void _completeTutorial() {
    setState(() {
      showTutorial = false;
    });
  }

  void _nextStep() {
    if (currentStep < widget.steps.length - 1) {
      setState(() {
        currentStep++;
      });
    } else {
      _completeTutorial();
    }
  }

  void _skipTutorial() {
    _completeTutorial();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (showTutorial)
          Positioned.fill(
            child: Material(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.teal.withOpacity(0.3)),
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
                              Icons.flight_takeoff,
                              color: Colors.teal,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Welcome to Mission Planning!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Current step content
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              widget.steps[currentStep].icon,
                              color: Colors.teal,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.steps[currentStep].title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.steps[currentStep].description,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Progress indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.steps.length,
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
                          TextButton(
                            onPressed: _skipTutorial,
                            child: const Text(
                              'Bỏ qua',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),

                          ElevatedButton(
                            onPressed: _nextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              currentStep < widget.steps.length - 1
                                  ? 'Tiếp theo'
                                  : 'Bắt đầu',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class TutorialStep {
  final String title;
  final String description;
  final IconData icon;

  TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}
