import 'package:flutter/material.dart';
import 'package:skylink/data/models/mission_plan_model.dart';

class PlanManagerWidget extends StatefulWidget {
  final List<UserMissionPlan> plans;
  final UserMissionPlan? selectedPlan;
  final Function(String title, String description) onCreatePlan;
  final Function(UserMissionPlan plan) onSelectPlan;
  final Function(UserMissionPlan plan) onEditPlan;
  final Function(UserMissionPlan plan) onDeletePlan;
  final VoidCallback onCreateNewPlan;

  const PlanManagerWidget({
    super.key,
    required this.plans,
    this.selectedPlan,
    required this.onCreatePlan,
    required this.onSelectPlan,
    required this.onEditPlan,
    required this.onDeletePlan,
    required this.onCreateNewPlan,
  });

  @override
  State<PlanManagerWidget> createState() => _PlanManagerWidgetState();
}

class _PlanManagerWidgetState extends State<PlanManagerWidget> {
  void _showDeleteConfirmation(UserMissionPlan plan) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: const Text(
            'Delete Mission Plan',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete "${plan.title}"?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onDeletePlan(plan);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade800, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade800, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Mission Plans',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.plans.length} plans',
                    style: const TextStyle(
                      color: Colors.teal,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Create New Plan Button
          Container(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                onPressed: widget.onCreateNewPlan,
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Create New Plan',
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),

          // Plans List
          Expanded(
            child: widget.plans.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, color: Colors.grey, size: 32),
                        SizedBox(height: 8),
                        Text(
                          'No plans created yet',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.plans.length,
                    itemBuilder: (context, index) {
                      final plan = widget.plans[index];
                      final isSelected = widget.selectedPlan?.id == plan.id;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.teal.withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: isSelected
                              ? Border.all(color: Colors.teal, width: 1)
                              : null,
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.flight_takeoff,
                              color: Colors.teal,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            plan.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${plan.waypointCount} waypoints • ${(plan.totalDistance / 1000).toStringAsFixed(1)}km',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => widget.onEditPlan(plan),
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                  size: 16,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              IconButton(
                                onPressed: () => _showDeleteConfirmation(plan),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 16,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          onTap: () => widget.onSelectPlan(plan),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
