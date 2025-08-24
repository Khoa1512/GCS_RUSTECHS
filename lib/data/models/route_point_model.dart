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
}

final List<RoutePoint> routePoints = [
  RoutePoint(
    id: '1',
    order: 1,
    latitude: '10.8231',
    longitude: '106.6297',
    altitude: '100',
  ),
  RoutePoint(
    id: '2',
    order: 2,
    latitude: '10.8231',
    longitude: '106.6297',
    altitude: '100',
  ),
  RoutePoint(
    id: '3',
    order: 3,
    latitude: '10.8231',
    longitude: '106.6297',
    altitude: '100',
  ),
];
