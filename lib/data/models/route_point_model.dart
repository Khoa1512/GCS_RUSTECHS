class RoutePoint {
  final String id;
  final int order;
  final String latitude;
  final String longitude;
  final String altitude;
  final int command; // MAV_CMD number
  final Map<String, dynamic>?
  commandParams; // Additional parameters for specific commands

  RoutePoint({
    required this.id,
    required this.order,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    this.command = 16, // Default to MAV_CMD_NAV_WAYPOINT
    this.commandParams,
  });

  // Add copyWith method
  RoutePoint copyWith({
    String? id,
    int? order,
    String? latitude,
    String? longitude,
    String? altitude,
    int? command,
    Map<String, dynamic>? commandParams,
  }) {
    return RoutePoint(
      id: id ?? this.id,
      order: order ?? this.order,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      command: command ?? this.command,
      commandParams: commandParams ?? this.commandParams,
    );
  }

  // Add toJson method for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order': order,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'command': command,
      'commandParams': commandParams,
    };
  }

  // Add fromJson method for deserialization
  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      id: json['id'] as String,
      order: json['order'] as int,
      latitude: json['latitude'] as String,
      longitude: json['longitude'] as String,
      altitude: json['altitude'] as String,
      command: json['command'] as int? ?? 16,
      commandParams: json['commandParams'] as Map<String, dynamic>?,
    );
  }
}
