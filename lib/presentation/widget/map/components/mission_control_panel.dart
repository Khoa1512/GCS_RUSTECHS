import 'package:flutter/material.dart';

class MissionControlPanel extends StatelessWidget {
  final VoidCallback? onReadMission;
  final VoidCallback? onSendMission;
  final VoidCallback? onImportMission;
  final VoidCallback? onExportMission;
  final bool isConnected;
  final int waypointCount;

  const MissionControlPanel({
    super.key,
    this.onReadMission,
    this.onSendMission,
    this.onImportMission,
    this.onExportMission,
    this.isConnected = false,
    this.waypointCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.flight_takeoff,
                  color: Colors.teal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Mission Control',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConnected ? Icons.wifi : Icons.wifi_off,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isConnected ? 'Connected' : 'Disconnected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Mission Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.route, color: Colors.white60, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Current Mission:',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  waypointCount == 0
                      ? 'No waypoints'
                      : '$waypointCount waypoint${waypointCount > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Column(
            children: [
              // Flight Controller Actions
              const Text(
                'Flight Controller',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: 'Read',
                      icon: Icons.download,
                      color: Colors.blue,
                      onPressed: onReadMission,
                      enabled: isConnected,
                      tooltip: 'Download mission from flight controller',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      label: 'Send',
                      icon: Icons.upload,
                      color: Colors.orange,
                      onPressed: onSendMission,
                      enabled: isConnected && waypointCount > 0,
                      tooltip: 'Upload mission to flight controller',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // File Operations
              const Text(
                'File Operations',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: 'Import',
                      icon: Icons.file_open,
                      color: Colors.green,
                      onPressed: onImportMission,
                      tooltip: 'Import mission from file',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      label: 'Export',
                      icon: Icons.save,
                      color: Colors.purple,
                      onPressed: onExportMission,
                      enabled: waypointCount > 0,
                      tooltip: 'Export mission to file',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
    bool enabled = true,
    String? tooltip,
  }) {
    final isEnabled = enabled && onPressed != null;

    Widget button = Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: isEnabled
            ? LinearGradient(
                colors: [
                  color.withValues(alpha: 0.8),
                  color.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isEnabled ? null : const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEnabled ? color.withValues(alpha: 0.3) : Colors.white10,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isEnabled ? Colors.white : Colors.white30,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isEnabled ? Colors.white : Colors.white30,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }

    return button;
  }
}
