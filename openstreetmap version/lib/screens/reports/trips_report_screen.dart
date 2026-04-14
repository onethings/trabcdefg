// lib/screens/reports/trips_report_screen.dart
// A screen to display trips report in the TracDefg app.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:trabcdefg/providers/map_style_provider.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:trabcdefg/widgets/OfflineAddressService.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
// Enum and Tile Provider removed as they are no longer needed with native MapLibre caching.

// Enum moved to provider

// --- End of Map Caching & FlutterMap Imports/Definitions ---


class TripReport {
  final int deviceId;
  final String deviceName;
  final double distance;
  final double averageSpeed;
  final double maxSpeed;
  final double spentFuel;
  final double startOdometer;
  final double endOdometer;
  final DateTime startTime;
  final DateTime endTime;
  final int startPositionId;
  final int endPositionId;
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  final String? startAddress;
  final String? endAddress;
  final int duration;
  final String? driverUniqueId;
  final String? driverName;

  TripReport({
    required this.deviceId,
    required this.deviceName,
    required this.distance,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.spentFuel,
    required this.startOdometer,
    required this.endOdometer,
    required this.startTime,
    required this.endTime,
    required this.startPositionId,
    required this.endPositionId,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    this.startAddress,
    this.endAddress,
    required this.duration,
    this.driverUniqueId,
    this.driverName,
  });

  factory TripReport.fromJson(Map<String, dynamic> json) {
    return TripReport(
      deviceId: json['deviceId'] as int,
      deviceName: json['deviceName'] as String,
      distance: (json['distance'] as num).toDouble(),
      averageSpeed: (json['averageSpeed'] as num).toDouble(),
      maxSpeed: (json['maxSpeed'] as num).toDouble(),
      spentFuel: (json['spentFuel'] as num).toDouble(),
      startOdometer: (json['startOdometer'] as num).toDouble(),
      endOdometer: (json['endOdometer'] as num).toDouble(),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      startPositionId: json['startPositionId'] as int,
      endPositionId: json['endPositionId'] as int,
      startLat: (json['startLat'] as num).toDouble(),
      startLon: (json['startLon'] as num).toDouble(),
      endLat: (json['endLat'] as num).toDouble(),
      endLon: (json['endLon'] as num).toDouble(),
      startAddress: json['startAddress'] as String?,
      endAddress: json['endAddress'] as String?,
      duration: json['duration'] as int,
      driverUniqueId: json['driverUniqueId'] as String?,
      driverName: json['driverName'] as String?,
    );
  }
}

class TripsReportScreen extends StatefulWidget {
  const TripsReportScreen({super.key});

  @override
  State<TripsReportScreen> createState() => _TripsReportScreenState();
}

class _TripsReportScreenState extends State<TripsReportScreen> {
  List<TripReport> _tripsReport = [];
  bool _isLoading = true;
  String? _deviceName;
  maplibre.MapLibreMapController? _mapController;
  final Set<String> _loadedIcons = {};
  bool _isStyleLoaded = false;
// Constants for manual tile URLs removed as we use MapStyleProvider now.


  @override
  void initState() {
    super.initState();
    _fetchTripsReport();
  }

  @override
  void dispose() {
    super.dispose();
  }


  Future<void> _loadMarkerIcons() async {
    // Replaced complex Google Maps BitmapDescriptor logic with a simple no-op 
    // as FlutterMap Markers use Widgets directly.
    await Future.value();
  }

  // ... (TripReport parsing and _fetchTripsReport logic remain mostly the same) ...
Future<void> _fetchTripsReport() async {
    setState(() {
      _isLoading = true;
    });

    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );

    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getInt('selectedDeviceId');
    final fromDateString = prefs.getString('historyFrom');
    final toDateString = prefs.getString('historyTo');
    print('Fetched from SharedPreferences: deviceId=$deviceId, fromDate=$fromDateString, toDate=$toDateString');

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

    try {
      final apiClient = traccarProvider.apiClient;
      final queryParams = [
          api.QueryParam('from', fromDate.toIso8601String()),
          api.QueryParam('to', toDate.toIso8601String()),
          api.QueryParam('deviceId', deviceId.toString()),
      ];
      final path = '/reports/trips';
      final headerParams = {'Accept': 'application/json'};

      final http.Response response = await apiClient.invokeAPI(
        path,
        'GET',
        queryParams,
        null, // body
        headerParams, // headerParams
        {}, // formParams
        'application/json', // contentType
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final contentType = response.headers['content-type'];
        if (contentType != null && contentType.contains('application/json')) {
          final decodedData = json.decode(response.body);

          if (decodedData is List && decodedData.isNotEmpty) {
            _tripsReport = decodedData
                .map((e) => TripReport.fromJson(e as Map<String, dynamic>))
                .toList();
            if (_tripsReport.isNotEmpty) {
              _deviceName = _tripsReport.first.deviceName;
              _createMapElements();
            }
          }
        } else {
          print('Warning: Expected JSON, but received content type: $contentType');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load trips report. The server returned a file instead of JSON. Please check the Traccar server settings for reports.'.tr)),
          );
        }
      }
    } catch (e) {
      print('Error fetching trips report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load trips report.'.tr)),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _onStyleLoaded() async {
    _isStyleLoaded = true;
    if (_tripsReport.isNotEmpty) {
      _createMapElements();
    }
  }

  Future<void> _createMapElements() async {
    if (_mapController == null || !_isStyleLoaded || _tripsReport.isEmpty) return;
    
    await _mapController!.clearSymbols();
    await _mapController!.clearLines();

    final List<maplibre.LatLng> allPoints = [];

    for (var i = 0; i < _tripsReport.length; i++) {
        final trip = _tripsReport[i];
        final start = maplibre.LatLng(trip.startLat, trip.startLon);
        final end = maplibre.LatLng(trip.endLat, trip.endLon);
        
        allPoints.add(start);
        allPoints.add(end);

        await _mapController!.addLine(
          maplibre.LineOptions(
            geometry: [start, end],
            lineColor: Theme.of(context).colorScheme.primary.toHex(),
            lineWidth: 4.0,
          ),
        );

        await _addMarker(start, "start_$i", "assets/images/start.png");
        await _addMarker(end, "end_$i", "assets/images/destination.png");
    }

    if (allPoints.isNotEmpty) {
      _zoomToFit(allPoints);
    }
  }

  Future<void> _addMarker(maplibre.LatLng point, String iconId, String assetPath) async {
    // For simplicity, using a generic iconId if multiple markers share the same asset
    final baseIconId = assetPath.contains("start") ? "start_pin" : "end_pin";
    if (!_loadedIcons.contains(baseIconId)) {
      final ByteData bytes = await rootBundle.load(assetPath);
      final Uint8List list = bytes.buffer.asUint8List();
      await _mapController!.addImage(baseIconId, list);
      _loadedIcons.add(baseIconId);
    }
    
    await _mapController!.addSymbol(
      maplibre.SymbolOptions(
        geometry: point,
        iconImage: baseIconId,
        iconSize: 0.6,
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

  // void _showInfoWindowForMarker(MarkerId markerId) { // REMOVED as it's a Google Maps API call
  //   final controller = _controller.future.then((c) {
  //     c.showMarkerInfoWindow(markerId);
  //   });
  // }
  
  // Helper functions (e.g., _formatDuration, _formatDistance) remain the same

  String _formatDuration(int milliseconds) {
    int seconds = (milliseconds / 1000).round();
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} ${'sharedKm'.tr}';
    }
    return '${meters.toStringAsFixed(2)} ${'sharedMeters'.tr}';
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (_tripsReport.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_deviceName ?? 'reportTrips'.tr)),
        body: Center(child: Text('sharedNoData'.tr)),
      );
    }

    final mapProvider = Provider.of<MapStyleProvider>(context);
    final initialCenter = _tripsReport.isNotEmpty
        ? maplibre.LatLng(_tripsReport.first.startLat, _tripsReport.first.startLon)
        : const maplibre.LatLng(21.9162, 95.9560);

    return Scaffold(
      appBar: AppBar(title: Text('${'reportTrips'.tr}: ${_deviceName ?? ''}')),
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
                  styleString: mapProvider.getStyle(Theme.of(context).brightness),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: FloatingActionButton(
                    heroTag: "btn_style_trip",
                    mini: true,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    onPressed: () => mapProvider.toggleMapType(),
                    child: Icon(
                      mapProvider.isSatelliteMode ? Icons.map : Icons.satellite_alt,
                      color: Theme.of(context).colorScheme.onSurface,
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
              itemCount: _tripsReport.length,
              itemBuilder: (context, index) {
                final trip = _tripsReport[index];
                return GestureDetector(
                  onTap: () => _animateToPosition(maplibre.LatLng(trip.startLat, trip.startLon)),
                  child: Card(
// ... Card content (retaining existing style)
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 16.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${'reportTrips'.tr} ${index + 1}',
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const Divider(),
                          _buildTripDetailRow('reportStartTime'.tr, DateFormat('yyyy-MM-dd HH:mm').format(trip.startTime.toLocal())),
                          _buildTripDetailRow('reportEndTime'.tr, DateFormat('yyyy-MM-dd HH:mm').format(trip.endTime.toLocal())),
                          _buildTripDetailRow('reportDuration'.tr, _formatDuration(trip.duration)),
                          _buildTripDetailRow('sharedDistance'.tr, _formatDistance(trip.distance)),
                          _buildTripDetailRow('reportAverageSpeed'.tr, '${trip.averageSpeed.toStringAsFixed(2)} ${'sharedKmh'.tr}'),
                          ListTile(
                            title: Text(
                              'reportStartAddress'.tr,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            subtitle: FutureBuilder<String>(
                              future: trip.startAddress != null && trip.startAddress!.isNotEmpty
                                  ? Future.value(trip.startAddress)
                                  : OfflineAddressService.getAddress(trip.startLat, trip.startLon),
                              builder: (context, snapshot) => Text(
                                snapshot.data ?? '...',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              ),
                            ),
                          ),
                          ListTile(
                            title: Text(
                              'reportEndAddress'.tr,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            subtitle: FutureBuilder<String>(
                              future: trip.endAddress != null && trip.endAddress!.isNotEmpty
                                  ? Future.value(trip.endAddress)
                                  : OfflineAddressService.getAddress(trip.endLat, trip.endLon),
                              builder: (context, snapshot) => Text(
                                snapshot.data ?? '...',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripDetailRow(String title, String value) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

extension ColorToHex on Color {
  String toHex() => '#${value.toRadixString(16).padLeft(8, '0').substring(2)}';
}