import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:skylink/services/telemetry_service.dart';
import 'package:skylink/api/telemetry/mavlink_api.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RoutePage extends StatefulWidget {
  const RoutePage({super.key});

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  final TelemetryService _telemetry = TelemetryService();
  StreamSubscription? _mavSub;

  // Connection
  List<String> _ports = [];
  String _selectedPort = '';
  final TextEditingController _baudCtl = TextEditingController(text: '115200');
  bool get _connected => _telemetry.isConnected;

  // Mission state
  final List<PlanMissionItem> _items = [];
  int _dlReceived = 0;
  int _dlTotal = 0;
  int _ulSent = 0;
  int _ulTotal = 0;
  int? _currentSeq;
  String _status = '';
  int _nextToRequest = 0; // sequential mission item requests
  LatLng? _home; // EKF home position

  // Map state
  final MapController _mapController = MapController();
  LatLng _mapCenter = LatLng(0, 0);
  double _mapZoom = 2.0;

  // Upload source (paste content)
  final TextEditingController _pasteCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshPorts();
    _wireEvents();
  }

  void _wireEvents() {
    _mavSub?.cancel();
    _mavSub = _telemetry.mavlinkAPI.eventStream.listen((e) {
      switch (e.type) {
        case MAVLinkEventType.missionCount:
          setState(() {
            _items.clear();
            _dlTotal = (e.data as int);
            _dlReceived = 0;
          });
          // Sequentially request items, one at a time
          if (_dlTotal > 0) {
            _nextToRequest = 0;
            _telemetry.mavlinkAPI.requestMissionItem(_nextToRequest);
            _nextToRequest++;
          }
          break;
        case MAVLinkEventType.missionItem:
          final it = e.data as PlanMissionItem;
          setState(() {
            // ensure ordered insert/update
            final idx = it.seq;
            while (_items.length <= idx) {
              _items.add(
                PlanMissionItem(seq: _items.length, command: 0, frame: 0),
              );
            }
            _items[idx] = it;
            _dlReceived = _items
                .where(
                  (x) => x.command != 0 || x.x != 0 || x.y != 0 || x.z != 0,
                )
                .length;
          });
          // Request next item if any remaining
          if (_nextToRequest < _dlTotal) {
            _telemetry.mavlinkAPI.requestMissionItem(_nextToRequest);
            _nextToRequest++;
          }
          break;
        case MAVLinkEventType.missionDownloadProgress:
          setState(() {
            _dlReceived = e.data['received'] ?? _dlReceived;
            _dlTotal = e.data['total'] ?? _dlTotal;
          });
          break;
        case MAVLinkEventType.missionDownloadComplete:
          setState(() {});
          _fitMapToMission();
          break;
        case MAVLinkEventType.missionUploadProgress:
          setState(() {
            _ulSent = e.data['sent'] ?? _ulSent;
            _ulTotal = e.data['total'] ?? _ulTotal;
          });
          break;
        case MAVLinkEventType.missionUploadComplete:
          setState(() {
            _ulSent = _ulTotal;
            _status = 'Upload complete';
          });
          _fitMapToMission();
          break;
        case MAVLinkEventType.missionCurrent:
          setState(() {
            _currentSeq = e.data['seq'] as int?;
          });
          break;
        case MAVLinkEventType.missionAck:
          setState(() {
            _status = 'Mission ACK: ${e.data}';
          });
          break;
        case MAVLinkEventType.missionCleared:
          setState(() {
            _status = 'Mission cleared';
          });
          break;
        case MAVLinkEventType.homePosition:
          setState(() {
            final d = e.data as Map;
            _home = LatLng(
              (d['lat'] as num).toDouble(),
              (d['lon'] as num).toDouble(),
            );
          });
          break;
        default:
          break;
      }
    });
  }

  Future<void> _refreshPorts() async {
    setState(() {
      _ports = SerialPort.availablePorts;
      if (_ports.isNotEmpty &&
          (_selectedPort.isEmpty || !_ports.contains(_selectedPort))) {
        _selectedPort = _ports.first;
      }
    });
  }

  Future<void> _connect() async {
    if (_selectedPort.isEmpty) return;
    final baud = int.tryParse(_baudCtl.text.trim()) ?? 115200;
    final ok = await _telemetry.connect(_selectedPort, baudRate: baud);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect $_selectedPort')),
      );
    }
  }

  void _disconnect() {
    _telemetry.disconnect();
  }

  void _downloadMission() {
    setState(() {
      _items.clear();
      _dlReceived = 0;
      _dlTotal = 0;
    });
    _telemetry.mavlinkAPI.requestMissionList();
  }

  Future<void> _uploadPasted() async {
    final text = _pasteCtl.text.trim();
    if (text.isEmpty) return;
    MissionPlan plan;
    try {
      if (text.startsWith('{')) {
        plan = MissionPlan.fromQgcPlanJson(text);
      } else {
        plan = MissionPlan.fromArduPilotWaypoints(text);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Parse mission failed: $e')));
      return;
    }
    setState(() {
      _ulSent = 0;
      _ulTotal = plan.items.length;
    });
    _telemetry.mavlinkAPI.startMissionUpload(plan.items);
  }

  void _clearMission() {
    _telemetry.mavlinkAPI.clearMission();
  }

  void _setCurrent(int seq) {
    _telemetry.mavlinkAPI.setCurrentMissionItem(seq);
  }

  void _getHome() {
    _telemetry.mavlinkAPI.requestHomePosition();
  }

  Future<void> _saveAsPlan() async {
    if (_items.isEmpty) return;
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/mission_${DateTime.now().millisecondsSinceEpoch}.plan';
    final json = MissionPlan(items: _items).toQgcPlanJson();
    await File(path).writeAsString(json);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved: $path')));
    }
  }

  @override
  void dispose() {
    _mavSub?.cancel();
    _baudCtl.dispose();
    _pasteCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left: controls + status + table
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConnectCard(),
                  const SizedBox(height: 12),
                  _buildMissionControls(),
                  const SizedBox(height: 12),
                  if (_status.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        _status,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  Expanded(child: _buildMissionTable()),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right: map (fills available space)
            Expanded(flex: 3, child: _buildMap()),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    final points = _missionLatLngs();
    final markers = <Marker>[];
    // Determine home marker: prefer EKF home; fallback to first mission item if global
    LatLng? homePoint = _home;
    if (homePoint == null && _items.isNotEmpty && _isGlobal(_items.first)) {
      homePoint = LatLng(_items.first.x, _items.first.y);
    }
    if (homePoint != null) {
      markers.add(
        Marker(
          width: 40,
          height: 40,
          point: homePoint,
          child: const Icon(Icons.home, color: Colors.orangeAccent, size: 28),
        ),
      );
    }
    for (var i = 0; i < _items.length; i++) {
      final it = _items[i];
      if (!_isGlobal(it)) continue;
      final latlng = LatLng(it.x, it.y);
      final isCurrent = _currentSeq == it.seq;
      // If this is the first item and we're using it as home, don't render a waypoint marker on top of the home icon
      if (i == 0 && homePoint != null && latlng == homePoint) {
        continue;
      }
      markers.add(
        Marker(
          width: 36,
          height: 36,
          point: latlng,
          child: GestureDetector(
            onTap: () => _centerOn(latlng),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.place,
                  color: isCurrent ? Colors.redAccent : Colors.cyanAccent,
                  size: 28,
                ),
                Positioned(
                  bottom: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${it.seq}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter,
                initialZoom: _mapZoom,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  tileProvider: NetworkTileProvider(),
                ),
                if (points.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        color: Colors.cyanAccent,
                        strokeWidth: 3.0,
                      ),
                    ],
                  ),
                MarkerLayer(markers: markers),
              ],
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: _fitMapToMission,
                    child: const Text('Fit to Mission'),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: () {
                      final LatLng? hp =
                          _home ??
                          (_items.isNotEmpty && _isGlobal(_items.first)
                              ? LatLng(_items.first.x, _items.first.y)
                              : null);
                      if (hp != null) _centerOn(hp);
                    },
                    child: const Text('Center Home'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _centerOn(LatLng p) {
    _mapController.move(p, _mapZoom.clamp(12.0, 16.0));
  }

  void _fitMapToMission() {
    final pts = _missionLatLngs();
    if (pts.isEmpty) return;
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapCenter = center;
    // Simple heuristic zoom by span
    final span =
        (maxLat - minLat).abs().clamp(0.001, 180.0) +
        (maxLng - minLng).abs().clamp(0.001, 360.0);
    _mapZoom = span < 0.01
        ? 16
        : span < 0.1
        ? 14
        : span < 1
        ? 12
        : span < 5
        ? 10
        : span < 20
        ? 8
        : 4;
    _mapController.move(center, _mapZoom);
  }

  List<LatLng> _missionLatLngs() {
    return _items.where(_isGlobal).map((it) => LatLng(it.x, it.y)).toList();
  }

  bool _isGlobal(PlanMissionItem it) {
    final lat = it.x;
    final lon = it.y;
    return lat != 0.0 || lon != 0.0
        ? (lat.abs() <= 90 && lon.abs() <= 180)
        : false;
  }

  Widget _buildConnectCard() {
    return Card(
      color: Colors.grey.shade800,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedPort.isEmpty ? null : _selectedPort,
                items: _ports
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: _connected
                    ? null
                    : (v) => setState(() => _selectedPort = v ?? ''),
                decoration: const InputDecoration(
                  labelText: 'Port',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                dropdownColor: Colors.grey.shade900,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _baudCtl,
                enabled: !_connected,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Baud',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _connected ? _disconnect : _connect,
              child: Text(_connected ? 'Disconnect' : 'Connect'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _refreshPorts,
              child: const Text('Refresh'),
            ),
            const SizedBox(width: 12),
            Text(
              _connected ? 'Connected' : 'Disconnected',
              style: TextStyle(color: _connected ? Colors.green : Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionControls() {
    return Card(
      color: Colors.grey.shade800,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ElevatedButton(
                  onPressed: _connected ? _downloadMission : null,
                  child: const Text('Download'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _connected ? _clearMission : null,
                  child: const Text('Clear'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _connected ? _getHome : null,
                  child: const Text('Get Home'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _items.isNotEmpty ? _saveAsPlan : null,
                  child: const Text('Save .plan'),
                ),
                const SizedBox(width: 16),
                if (_dlTotal > 0)
                  Text(
                    'Download: $_dlReceived/$_dlTotal',
                    style: const TextStyle(color: Colors.white70),
                  ),
                const SizedBox(width: 16),
                if (_ulTotal > 0)
                  Text(
                    'Upload: $_ulSent/$_ulTotal',
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Paste .plan JSON or QGC WPL text, then Upload',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _pasteCtl,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: '{ ... } or QGC WPL 110...\t',
                hintStyle: TextStyle(color: Colors.white38),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: _connected ? _uploadPasted : null,
                child: const Text('Upload from pasted content'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Text(
                  'Mission Items',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                if (_currentSeq != null)
                  Text(
                    'Current: $_currentSeq',
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.black54),
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text(
                      'No items',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Colors.black26),
                    itemBuilder: (context, index) {
                      final it = _items[index];
                      final isHomeRow = index == 0 && _isGlobal(it);
                      return ListTile(
                        dense: true,
                        title: Text(
                          '${isHomeRow ? "[HOME] " : ""}#${it.seq}  CMD ${it.command}  FRAME ${it.frame}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'x=${it.x.toStringAsFixed(6)}, y=${it.y.toStringAsFixed(6)}, z=${it.z.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: _connected
                                  ? () => _setCurrent(it.seq)
                                  : null,
                              child: const Text('Set Current'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
