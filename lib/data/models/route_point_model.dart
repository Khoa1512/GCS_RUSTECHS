class RoutePoint {
  final String id;
  final int order;
  final String latitude;
  final String longitude;
  final String altitude;

  RoutePoint({
    required this.id,
    required this.order,
    required this.latitude,
    required this.longitude,
    required this.altitude,
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
