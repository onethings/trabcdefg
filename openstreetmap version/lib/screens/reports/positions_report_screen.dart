// lib/screens/reports/positions_report_screen.dart
// Positions report with map view, route path, and position selection.
// Based on traccar-web PositionsReportPage (uses /api/positions + map).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/map_style_provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class PosItem {
  final int id;
  final int deviceId;
  final DateTime fixTime;
  final DateTime deviceTime;
  final DateTime serverTime;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
  final double course;
  final double accuracy;
  final String? address;
  final String? protocol;
  final bool valid;
  final Map<String, dynamic> attributes;

  PosItem({
    required this.id,
    required this.deviceId,
    required this.fixTime,
    required this.deviceTime,
    required this.serverTime,
    required this.latitude,
    required this.longitude,
    this.altitude = 0,
    this.speed = 0,
    this.course = 0,
    this.accuracy = 0,
    this.address,
    this.protocol,
    this.valid = false,
    this.attributes = const {},
  });

  factory PosItem.fromJson(Map<String, dynamic> json) {
    return PosItem(
      id: json['id'] as int,
      deviceId: json['deviceId'] as int,
      fixTime: DateTime.parse(json['fixTime'] as String),
      deviceTime: DateTime.parse(json['deviceTime'] as String),
      serverTime: DateTime.parse(json['serverTime'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0,
      speed: (json['speed'] as num?)?.toDouble() ?? 0,
      course: (json['course'] as num?)?.toDouble() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      address: json['address'] as String?,
      protocol: json['protocol'] as String?,
      valid: json['valid'] as bool? ?? false,
      attributes: json['attributes'] as Map<String, dynamic>? ?? {},
    );
  }
}

class PositionsReportScreen extends StatefulWidget {
  const PositionsReportScreen({super.key});

  @override
  State<PositionsReportScreen> createState() => _PositionsReportScreenState();
}

class _PositionsReportScreenState extends State<PositionsReportScreen> {
  List<PosItem> _items = [];
  bool _isLoading = true;
  String? _deviceName;
  PosItem? _selectedItem;

  maplibre.MapLibreMapController? _mapController;
  bool _mapReady = false;
  bool _showMap = true;

  @override
  void initState() {
    super.initState();
    _fetchPositions();
  }

  Future<void> _fetchPositions() async {
    setState(() => _isLoading = true);
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getInt('selectedDeviceId');
    final fromDateString = prefs.getString('historyFrom');
    final toDateString = prefs.getString('historyTo');
    if (deviceId == null || fromDateString == null || toDateString == null) {
      setState(() => _isLoading = false);
      return;
    }
    final fromDate = DateTime.tryParse(fromDateString);
    final toDate = DateTime.tryParse(toDateString);
    if (fromDate == null || toDate == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final queryParams = [api.QueryParam('from', fromDate.toIso8601String()), api.QueryParam('to', toDate.toIso8601String()), api.QueryParam('deviceId', deviceId.toString())];
      final response = await traccarProvider.apiClient.invokeAPI('/positions', 'GET', queryParams, null, {'Accept': 'application/json'}, {}, 'application/json');
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body) as List? ?? [];
        _items = data.map((e) => PosItem.fromJson(e as Map<String, dynamic>)).toList();
        final device = traccarProvider.devices.firstWhere((d) => d.id == deviceId, orElse: () => api.Device());
        _deviceName = device.name;
      }
    } catch (e) {
      debugPrint('Positions error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load positions.'.tr)));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onMapCreated(maplibre.MapLibreMapController c) {
    _mapController = c;
    _mapReady = true;
    _updateMap();
  }

  Future<void> _updateMap() async {
    if (!_mapReady || _mapController == null || _items.isEmpty) return;
    try {
      await _mapController!.clearLines();
      await _mapController!.clearCircles();

      // Route line
      final coords = _items.map((p) => maplibre.LatLng(p.latitude, p.longitude)).toList();
      if (coords.length >= 2) {
        await _mapController!.addLine(maplibre.LineOptions(geometry: coords, lineColor: "#1E88E5", lineWidth: 3.0));
      }
      // Selected position marker
      if (_selectedItem != null) {
        await _mapController!.addCircle(maplibre.CircleOptions(geometry: maplibre.LatLng(_selectedItem!.latitude, _selectedItem!.longitude), circleColor: "#E53935", circleRadius: 8));
        await _mapController!.animateCamera(maplibre.CameraUpdate.newCameraPosition(maplibre.CameraPosition(target: maplibre.LatLng(_selectedItem!.latitude, _selectedItem!.longitude), zoom: 15)));
      } else {
        // Fit all points
        final lats = _items.map((p) => p.latitude);
        final lngs = _items.map((p) => p.longitude);
        _mapController?.animateCamera(
          maplibre.CameraUpdate.newLatLngBounds(
            maplibre.LatLngBounds(southwest: maplibre.LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)), northeast: maplibre.LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b))),
            left: 40,
            right: 40,
            top: 40,
            bottom: 40,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final mapStyle = Provider.of<MapStyleProvider>(context).styleString;
    return Scaffold(
      appBar: AppBar(
        title: Text('${'reportPositions'.tr}: ${_deviceName ?? ''}'),
        actions: [IconButton(icon: Icon(_showMap ? Icons.list : Icons.map), tooltip: _showMap ? 'Show List' : 'Show Map', onPressed: () => setState(() => _showMap = !_showMap))],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(child: Text('sharedNoData'.tr))
          : Column(
              children: [
                if (_showMap)
                  SizedBox(
                    height: 250,
                    child: maplibre.MapLibreMap(
                      onMapCreated: _onMapCreated,
                      styleString: mapStyle,
                      initialCameraPosition: maplibre.CameraPosition(target: maplibre.LatLng(_items.first.latitude, _items.first.longitude), zoom: 12),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      final selected = _selectedItem?.id == item.id;
                      return Card(
                        elevation: selected ? 6 : 1,
                        color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          dense: true,
                          leading: Icon(item.valid ? Icons.location_on : Icons.location_off, color: item.valid ? Colors.green : Colors.red, size: 20),
                          title: Text(
                            DateFormat('yyyy-MM-dd HH:mm:ss').format(item.fixTime.toLocal()),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                          ),
                          subtitle: Text(
                            '${item.latitude.toStringAsFixed(4)}, ${item.longitude.toStringAsFixed(4)}  ${(item.speed * 1.852).toStringAsFixed(1)} km/h',
                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          trailing: Text('${item.course.toStringAsFixed(0)}°', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          onTap: () {
                            setState(() => _selectedItem = item);
                            _updateMap();
                          },
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
