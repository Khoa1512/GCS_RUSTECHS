import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:skylink/core/constant/map_type.dart';
import 'package:skylink/presentation/widget/swarm/swarm_control_panel_new.dart';

class SwarmPage extends StatefulWidget {
  const SwarmPage({super.key});

  @override
  State<SwarmPage> createState() => _SwarmPageState();
}

class _SwarmPageState extends State<SwarmPage> {
  MapType? selectedMapType;
  final MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    selectedMapType = mapTypes.first;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Cột trái chiếm 70% width - chứa map
        Expanded(
          flex: 70,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: Color(0xFF2A2A2A)),
            child: Column(
              children: [
                // Map Area
                Expanded(
                  child: Container(
                    margin: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: const LatLng(
                          10.823099,
                          106.629662,
                        ),
                        initialZoom: 16,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: selectedMapType?.urlTemplate ??
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.rustech.skylink',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Cột phải chiếm 30% width - hiển thị thông tin drone
        Expanded(
          flex: 30,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              border: Border(
                left: BorderSide(color: Colors.grey.shade800, width: 1),
              ),
            ),
            child: const SwarmControlPanel(),
          ),
        ),
      ],
    );
  }
}