import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import 'package:skylink/core/utils/geo_utils.dart';

class NoFlyZoneService {
  // Singleton pattern
  static final NoFlyZoneService _instance = NoFlyZoneService._internal();
  factory NoFlyZoneService() => _instance;
  NoFlyZoneService._internal();

  /// Loads and parses the no-fly zone JSON file in a background isolate.
  /// Returns a list of polygons, where each polygon is a list of LatLng points.
  Future<List<List<LatLng>>> loadNoFlyZones(String assetPath) async {
    try {
      // 1. Load string from assets (Main Isolate)
      final String jsonString = await rootBundle.loadString(assetPath);

      // 2. Parse in Background Isolate to avoid UI freeze
      final List<List<LatLng>> polygons = await Isolate.run(() {
        final rawPolygons = _parseGeoJson(jsonString);
        // Merge overlapping polygons to reduce draw calls and fix visual artifacts
        return GeoUtils.mergePolygons(rawPolygons);
      });

      return polygons;
    } catch (e) {
      print('Error loading no-fly zones: $e');
      return [];
    }
  }

  /// Pure function to parse GeoJSON string.
  /// Must be static or top-level to be used in Isolate.run (or capture no closure state).
  static List<List<LatLng>> _parseGeoJson(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final List<List<LatLng>> polygons = [];

    if (data.containsKey('features')) {
      final List<dynamic> features = data['features'];

      for (var feature in features) {
        final geometry = feature['geometry'];
        if (geometry != null && geometry['type'] == 'Polygon') {
          final List<dynamic> coordinates = geometry['coordinates'];

          // GeoJSON Polygons are List<List<List<double>>>: [Ring1, Ring2, ...]
          // Ring1 is the outer boundary. We typically only care about the outer boundary for simple visualization.
          if (coordinates.isNotEmpty) {
            final List<dynamic> outerRing = coordinates[0];
            final List<LatLng> polygonPoints = [];

            for (var point in outerRing) {
              // GeoJSON is [longitude, latitude]
              if (point is List && point.length >= 2) {
                final double lon = (point[0] as num).toDouble();
                final double lat = (point[1] as num).toDouble();
                polygonPoints.add(LatLng(lat, lon));
              }
            }

            if (polygonPoints.isNotEmpty) {
              polygons.add(polygonPoints);
            }
          }
        }
      }
    }
    return polygons;
  }
}
