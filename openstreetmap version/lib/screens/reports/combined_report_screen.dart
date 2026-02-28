// lib/screens/reports/combined_report_screen.dart
// A screen to display a combined report of positions and events on a map in the TracDefg app.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart'; // REMOVED
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:trabcdefg/providers/map_style_provider.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:trabcdefg/widgets/OfflineAddressService.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
// Caching logic moved to provider/centralized

// Enum moved to MapStyleProvider

// --- End of Map Caching & FlutterMap Definitions ---

// A new model to combine positions and events from different API calls
class CombinedReport {
  final List<api.Position> positions;
  final List<api.Event> events;
  final List<List<double>>? route;

  CombinedReport({required this.positions, required this.events, this.route});
}

class CombinedReportScreen extends StatefulWidget {
  const CombinedReportScreen({super.key});

  @override
  State<CombinedReportScreen> createState() => _CombinedReportScreenState();
}

class _CombinedReportScreenState extends State<CombinedReportScreen> {
  List<CombinedReport> _combinedReport = [];
  bool _isLoading = true;
  String? _deviceName;
  maplibre.MapLibreMapController? _mapController;
  final Set<String> _loadedIcons = {};
  bool _isStyleLoaded = false;

  // Icons are now asset paths/widgets, not BitmapDescriptors
  static const String _ignitionOnIconPath = 'assets/images/accon.png'; // ADDED
  static const String _ignitionOffIconPath = 'assets/images/accoff.png'; // ADDED

  Map<int, api.Position> _positionsMap = {};

  @override
  void initState() {
    super.initState();
    _fetchCombinedReport();
  }
  
  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadMarkerIcons() async {
    // Simplified: Icons are now loaded as part of the marker child in _updateMap
    // No BitmapDescriptor loading is needed for FlutterMap.
    await Future.delayed(Duration.zero);
  }

  Future<void> _fetchCombinedReport() async {
    setState(() {
      _isLoading = true;
    });

    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );

    await _loadMarkerIcons();

    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getInt('selectedDeviceId');
    final fromDateString = prefs.getString('historyFrom');
    final toDateString = prefs.getString('historyTo');
    print(
      'Fetched from SharedPreferences: deviceId=$deviceId, fromDate=$fromDateString, toDate=$toDateString',
    );

    // Handle potential null values from SharedPreferences
    if (deviceId == null || fromDateString == null || toDateString == null) {
      setState(() {
        _isLoading = false;
      });
      print('Missing device ID or date range from SharedPreferences.');
      return;
    }

    final fromDate = DateTime.tryParse(fromDateString);
    final toDate = DateTime.tryParse(toDateString);

    if (fromDate == null || toDate == null) {
      setState(() {
        _isLoading = false;
      });
      print('Failed to parse date strings.');
      return;
    }

    // Retrieve the device name
    final selectedDevice = traccarProvider.devices.firstWhere(
      (device) => device.id == deviceId,
      orElse: () => api.Device(),
    );
    _deviceName = selectedDevice.name ?? 'reportCombinedReport'.tr;

    try {
      final apiClient = traccarProvider.apiClient;

      final response = await apiClient.invokeAPI(
        '/reports/combined',
        'GET',
        [
          api.QueryParam('from', fromDate.toIso8601String()),
          api.QueryParam('to', toDate.toIso8601String()),
          api.QueryParam('deviceId', deviceId.toString()),
        ],
        null, // body
        {}, // headerParams
        {}, // formParams
        'application/json', // contentType
      );

      final decodedData = json.decode(response.body);

      // Check if the decoded data is a List and extract the first element
      Map<String, dynamic>? combinedData;
      if (decodedData is List && decodedData.isNotEmpty) {
        combinedData = decodedData.first as Map<String, dynamic>;
      } else if (decodedData is Map<String, dynamic>) {
        combinedData = decodedData;
      }

      if (combinedData != null) {
        final positions =
            (combinedData['positions'] as List?)
                ?.map((e) => api.Position.fromJson(e))
                .whereType<api.Position>()
                .toList() ??
            [];
        final events =
            (combinedData['events'] as List?)
                ?.map((e) => api.Event.fromJson(e))
                .whereType<api.Event>()
                .toList() ??
            [];
        final route =
            (combinedData['route'] as List?)
                ?.map((e) => (e as List).cast<double>())
                .whereType<List<double>>()
                .toList() ??
            [];

        if (positions.isNotEmpty || events.isNotEmpty || route.isNotEmpty) {
          // For MapLibre, we'll flatten positions and events into a single list for display
          // This assumes CombinedReport can represent a single point/event for the list view
          // and the route is handled separately.
          // This part needs careful adaptation based on how the new _combinedReport list is intended to be used.
          // For now, let's keep the original CombinedReport structure and adapt _createMapElements.
          // The diff implies _combinedReport is a list of objects with latitude/longitude directly.
          // This is a mismatch with the existing CombinedReport model.
          // To make the diff work, I'll assume a temporary structure or adapt the usage.
          // Given the diff for _combinedReport is `List<CombinedReport> _combinedReport = [];`,
          // and its usage `p.latitude`, it implies CombinedReport should have latitude/longitude.
          // Since I cannot change the CombinedReport model, I will assume the `_combinedReport` list
          // will be populated with a different type of object that has latitude/longitude,
          // or that the diff's usage of `p.latitude` is a simplification for a different data structure.
          // For faithful application, I will make _combinedReport a list of the original CombinedReport objects,
          // and then adapt _createMapElements to extract LatLngs from the first CombinedReport's route/positions.
          _combinedReport = [CombinedReport(
            positions: positions,
            events: events,
            route: route,
          )];
          _positionsMap = {for (var pos in positions) pos.id!: pos};
          _createMapElements();
        }
      }
    } catch (e) {
      print('Error fetching combined report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('errorGeneral'.tr + ': ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _onStyleLoaded() async {
    _isStyleLoaded = true;
    if (_combinedReport.isNotEmpty) {
      _createMapElements();
    }
  }

  Future<void> _createMapElements() async {
    if (_mapController == null || !_isStyleLoaded || _combinedReport.isEmpty) return;
    
    await _mapController!.clearSymbols();
    await _mapController!.clearLines();

    final report = _combinedReport.first; // Assuming only one CombinedReport object in the list

    final List<maplibre.LatLng> routePoints = [];
    if (report.route != null && report.route!.isNotEmpty) {
      routePoints.addAll(report.route!
          .map((coord) => maplibre.LatLng(coord[1], coord[0]))
          .toList());
    } else if (report.positions.isNotEmpty) {
      routePoints.addAll(report.positions
          .where((p) => p.latitude != null && p.longitude != null)
          .map((p) => maplibre.LatLng(p.latitude!.toDouble(), p.longitude!.toDouble()))
          .toList());
    }

    if (routePoints.isNotEmpty) {
      await _mapController!.addLine(
        maplibre.LineOptions(
          geometry: routePoints,
          lineColor: "#0000FF",
          lineWidth: 4.0,
        ),
      );

      // Add markers for stops/events if any, or just start/end
      await _addMarker(routePoints.first, "start_pin", "assets/images/start.png");
      await _addMarker(routePoints.last, "end_pin", "assets/images/destination.png");
      
      // Add event markers
      for (var event in report.events) {
        if (event.positionId != null && _positionsMap.containsKey(event.positionId)) {
          final position = _positionsMap[event.positionId]!;
          if (position.latitude != null && position.longitude != null) {
            String iconId;
            String assetPath;
            switch (event.type) {
              case 'ignitionOn':
                iconId = 'ignition_on';
                assetPath = _ignitionOnIconPath;
                break;
              case 'ignitionOff':
                iconId = 'ignition_off';
                assetPath = _ignitionOffIconPath;
                break;
              default:
                iconId = 'event_default';
                assetPath = 'assets/images/event_default.png';
                break;
            }
            await _addMarker(maplibre.LatLng(position.latitude!.toDouble(), position.longitude!.toDouble()), iconId, assetPath);
          }
        }
      }

      _zoomToFit(routePoints);
    }
  }

  Future<void> _addMarker(maplibre.LatLng point, String iconId, String assetPath) async {
    if (!_loadedIcons.contains(iconId)) {
      final ByteData bytes = await rootBundle.load(assetPath);
      final Uint8List list = bytes.buffer.asUint8List();
      await _mapController!.addImage(iconId, list);
      _loadedIcons.add(iconId);
    }
    
    await _mapController!.addSymbol(
      maplibre.SymbolOptions(
        geometry: point,
        iconImage: iconId,
        iconSize: 0.8,
        iconAnchor: "bottom",
      ),
    );
  }

  void _zoomToFit(List<maplibre.LatLng> points) {
    if (points.isEmpty) return;
    double minLat = points.map((p) => p.latitude).reduce(min);
    double maxLat = points.map((p) => p.latitude).reduce(max);
    double minLng = points.map((p) => p.longitude).reduce(min);
    double maxLng = points.map((p) => p.longitude).reduce(max);

    _mapController?.animateCamera(
      maplibre.CameraUpdate.newLatLngBounds(
        maplibre.LatLngBounds(
          southwest: maplibre.LatLng(minLat, minLng),
          northeast: maplibre.LatLng(maxLat, maxLng),
        ),
        left: 50, right: 50, top: 50, bottom: 50,
      ),
    );
  }

  void _animateToPosition(maplibre.LatLng position) {
    _mapController?.animateCamera(maplibre.CameraUpdate.newLatLng(position));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: Text('sharedLoading'.tr)));
    }

    if (_combinedReport.isEmpty ||
        (_combinedReport.first.positions.isEmpty &&
            (_combinedReport.first.route == null || _combinedReport.first.route!.isEmpty))) {
      return Scaffold(
        appBar: AppBar(title: Text(_deviceName ?? 'reportCombinedReport'.tr)),
        body: Center(child: Text('sharedNoData'.tr)),
      );
    }
    
    final mapProvider = Provider.of<MapStyleProvider>(context);
    final initialCenter = (_combinedReport.first.route != null && _combinedReport.first.route!.isNotEmpty)
        ? maplibre.LatLng(_combinedReport.first.route!.first[1], _combinedReport.first.route!.first[0])
        : (_combinedReport.first.positions.isNotEmpty
            ? maplibre.LatLng(_combinedReport.first.positions.first.latitude!.toDouble(), _combinedReport.first.positions.first.longitude!.toDouble())
            : const maplibre.LatLng(21.9162, 95.9560)); // Default if no data

    return Scaffold(
      appBar: AppBar(title: Text('${'reportCombined'.tr}: ${_deviceName ?? ''}')),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: Stack(
              children: [
                maplibre.MapLibreMap(
                  onMapCreated: (c) => _mapController = c,
                  onStyleLoadedCallback: _onStyleLoaded,
                  initialCameraPosition: maplibre.CameraPosition(
                    target: initialCenter,
                    zoom: 14.0,
                  ),
                  styleString: mapProvider.styleString,
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: () => mapProvider.toggleMapType(),
                    child: Icon(
                      mapProvider.isSatelliteMode ? Icons.map : Icons.satellite_alt,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _combinedReport.first.positions.length + _combinedReport.first.events.length,
              itemBuilder: (context, index) {
                final report = _combinedReport.first;
                if (index < report.positions.length) {
                  final pos = report.positions[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        '${'sharedDevice'.tr}: ${_deviceName}, '
                        '${'positionSpeed'.tr}: ${pos.speed} ${'sharedKmh'.tr}',
                      ),
                      subtitle: Text(
                        '${'reportTimeType'.tr}: ${pos.deviceTime?.toLocal().toString().split('.')[0]}',
                      ),
                      trailing: FutureBuilder<String>(
                        future: pos.address != null && pos.address!.isNotEmpty
                            ? Future.value(pos.address)
                            : OfflineAddressService.getAddress(pos.latitude!.toDouble(), pos.longitude!.toDouble()),
                        builder: (context, snapshot) {
                          return Container(
                            width: 120,
                            child: Text(
                              snapshot.data ?? '...',
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          );
                        },
                      ),
                      onTap: () async {
                        if (pos.latitude != null && pos.longitude != null) {
                          _animateToPosition(
                            maplibre.LatLng(
                              pos.latitude!.toDouble(),
                              pos.longitude!.toDouble(),
                            ),
                          );
                        }
                      },
                    ),
                  );
                  } else {
                    final eventIndex = index - report.positions.length;
                    final event = report.events[eventIndex];
                    String translatedEventKey;
                    if (event.type != null && event.type!.isNotEmpty) {
                      translatedEventKey =
                          'event' +
                          event.type![0].toUpperCase() +
                          event.type!.substring(1);
                    } else {
                      translatedEventKey = 'eventUnknown';
                    }
                    return Card(
                      child: ListTile(
                        title: Text(
                          'reportEventTypes'.tr + ': ${translatedEventKey.tr}',
                        ),
                        subtitle: Text(
                          'reportTimeType'.tr +
                              ': ${event.eventTime?.toLocal().toString().split('.')[0]}',
                        ),
                        onTap: () async {
                          if (event.positionId != null &&
                              _positionsMap.containsKey(event.positionId)) {
                            final position = _positionsMap[event.positionId]!;
                            if (position.latitude != null &&
                                position.longitude != null) {
                              _animateToPosition(
                                maplibre.LatLng(
                                  position.latitude!.toDouble(),
                                  position.longitude!.toDouble(),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}