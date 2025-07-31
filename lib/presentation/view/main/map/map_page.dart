import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/core/constant/map_type.dart';
import 'package:skylink/data/models/route_point_model.dart';
import 'package:skylink/presentation/widget/map/main_map.dart';
import 'package:skylink/presentation/widget/map/section/flight_log_section.dart';
import 'package:skylink/presentation/widget/map/section/map_type_section.dart';
import 'package:skylink/presentation/widget/map/section/route_point_table.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapType? selectedMapType;
  List<RoutePoint> routePoints = [];
  final MapController mapController = MapController();
  @override
  void initState() {
    super.initState();
    selectedMapType = mapTypes.first;
  }

  void handleMapTypeChange(MapType mapType) {
    setState(() {
      selectedMapType = mapType;
    });
  }

  void handleClearRoutePoints() {
    setState(() {
      routePoints = [];
    });
  }

  void addRoutePoint(LatLng latLng) {
    setState(() {
      routePoints.add(
        RoutePoint(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          order: routePoints.length + 1,
          latitude: latLng.latitude.toString(),
          longitude: latLng.longitude.toString(),
          altitude: "0",
        ),
      );
    });
  }

  void handleSearchLocation(LatLng location) {
    setState(() {
      // Optional: Add a marker or jump
    });
    // Notify map
    mapController.move(location, 16); // or use widget method
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MainMap(
          mapController: mapController,
          mapType: selectedMapType!,
          routePoints: routePoints,
          onTap: addRoutePoint,
        ),
        Positioned(
          top: 20,
          right: 20,
          child: Column(
            children: [
              MapTypeSection(mapTypes: mapTypes, onTap: handleMapTypeChange),
              const SizedBox(height: 20),
              const FlightLogSection(),
            ],
          ),
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: RoutePointTable(
            routePoints: routePoints,
            onClearTap: handleClearRoutePoints,
            onSearchLocation: handleSearchLocation,
          ),
        ),
      ],
    );
  }
}
