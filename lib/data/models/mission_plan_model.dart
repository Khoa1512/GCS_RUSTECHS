import 'dart:math' as math;
import 'package:skylink/data/models/route_point_model.dart';

class UserMissionPlan {
  final String id;
  final String title;
  final String description;
  final List<RoutePoint> waypoints;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserMissionPlan({
    required this.id,
    required this.title,
    this.description = '',
    required this.waypoints,
    required this.createdAt,
    this.updatedAt,
  });

  // Calculate total distance between waypoints
  double get totalDistance {
    if (waypoints.length < 2) return 0.0;

    double totalDist = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      final point1 = waypoints[i];
      final point2 = waypoints[i + 1];

      final lat1 = double.parse(point1.latitude);
      final lon1 = double.parse(point1.longitude);
      final lat2 = double.parse(point2.latitude);
      final lon2 = double.parse(point2.longitude);

      // Haversine formula for distance calculation
      const earthRadius = 6371000; // meters
      final dLat = (lat2 - lat1) * (math.pi / 180);
      final dLon = (lon2 - lon1) * (math.pi / 180);

      final a =
          math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(lat1 * (math.pi / 180)) *
              math.cos(lat2 * (math.pi / 180)) *
              math.sin(dLon / 2) *
              math.sin(dLon / 2);

      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      final distance = earthRadius * c;

      totalDist += distance;
    }

    return totalDist;
  }

  // Calculate estimated flight time (assuming average speed)
  Duration get estimatedFlightTime {
    const avgSpeedMs = 15.0; // 15 m/s average speed
    final timeSeconds = totalDistance / avgSpeedMs;
    return Duration(seconds: timeSeconds.round());
  }

  // Get altitude statistics
  Map<String, double> get altitudeStats {
    if (waypoints.isEmpty) {
      return {'min': 0.0, 'max': 0.0, 'avg': 0.0};
    }

    final altitudes = waypoints.map((wp) => double.parse(wp.altitude)).toList();
    final minAlt = altitudes.reduce((a, b) => a < b ? a : b);
    final maxAlt = altitudes.reduce((a, b) => a > b ? a : b);
    final avgAlt = altitudes.reduce((a, b) => a + b) / altitudes.length;

    return {'min': minAlt, 'max': maxAlt, 'avg': avgAlt};
  }

  // Get waypoint count
  int get waypointCount => waypoints.length;

  // Get mission area bounds
  Map<String, double>? get missionBounds {
    if (waypoints.isEmpty) return null;

    final lats = waypoints.map((wp) => double.parse(wp.latitude)).toList();
    final lngs = waypoints.map((wp) => double.parse(wp.longitude)).toList();

    return {
      'north': lats.reduce((a, b) => a > b ? a : b),
      'south': lats.reduce((a, b) => a < b ? a : b),
      'east': lngs.reduce((a, b) => a > b ? a : b),
      'west': lngs.reduce((a, b) => a < b ? a : b),
    };
  }

  // Copy with method
  UserMissionPlan copyWith({
    String? id,
    String? title,
    String? description,
    List<RoutePoint>? waypoints,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserMissionPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      waypoints: waypoints ?? this.waypoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'waypoints': waypoints.map((wp) => wp.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // From JSON
  factory UserMissionPlan.fromJson(Map<String, dynamic> json) {
    return UserMissionPlan(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      waypoints: (json['waypoints'] as List)
          .map((wp) => RoutePoint.fromJson(wp))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }
}
