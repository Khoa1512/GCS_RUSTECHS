import 'package:skylink/core/constant/app_image.dart';

class MapType {
  final String name;
  final String imagePath;
  final String urlTemplate;

  const MapType({
    required this.name,
    required this.imagePath,
    required this.urlTemplate,
  });
}

final List<MapType> mapTypes = [
  MapType(
    name: 'Satellite Map',
    imagePath: AppImage.satelliteMap,
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  ),
  MapType(
    name: 'Google Satellite',
    imagePath: AppImage.satelliteMap,
    urlTemplate: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
  ),
  MapType(
    name: 'Google Hybrid',
    imagePath: AppImage.satelliteMap, // Re-use satellite icon or add new one
    urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
  ),
  MapType(
    name: 'Gray Map',
    imagePath: AppImage.grayMap,
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
  ),
  MapType(
    name: 'Street Map',
    imagePath: AppImage.streetMap,
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
  ),
  MapType(
    name: 'Net Geo Map',
    imagePath: AppImage.natGeoMap,
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/NatGeo_World_Map/MapServer/tile/%7Bz%7D/%7By%7D/%7Bx%7D',
  ),
  MapType(
    name: 'Terrain Map',
    imagePath: AppImage.terrainMap,
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Terrain_Base/MapServer/tile/%7Bz%7D/%7By%7D/%7Bx%7D',
  ),

  MapType(
    name: 'Ocean Base Map',
    imagePath: AppImage.terrainMap,
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/Ocean/World_Ocean_Base/MapServer/tile/%7Bz%7D/%7By%7D/%7Bx%7D',
  ),
  MapType(
    name: 'Topo Map',
    imagePath: AppImage.terrainMap,
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
  ),
];
