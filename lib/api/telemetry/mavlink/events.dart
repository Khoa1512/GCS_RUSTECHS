/// Core event definitions shared across the MAVLink API modules
enum MAVLinkEventType {
  heartbeat,
  attitude,
  position,
  statusText,
  batteryStatus,
  gpsInfo,
  vfrHud,
  parameterReceived,
  allParametersReceived,
  sysStatus,
  commandAck,
  connectionStateChanged,
  // Mission protocol events
  missionCount,
  missionItem,
  missionCurrent,
  missionItemReached,
  missionAck,
  missionUploadProgress,
  missionUploadComplete,
  missionDownloadProgress,
  missionDownloadComplete,
  missionCleared,
  // Home position
  homePosition,
}

/// Connection state of the MAVLink connection
enum MAVLinkConnectionState { disconnected, connected, connecting, error }

/// A class representing a MAVLink message event
class MAVLinkEvent {
  final MAVLinkEventType type;
  final dynamic data;
  final DateTime timestamp;

  MAVLinkEvent(this.type, this.data) : timestamp = DateTime.now();
}
