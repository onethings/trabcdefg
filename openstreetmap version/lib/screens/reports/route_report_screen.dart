// lib/screens/reports/route_report_screen.dart //Replay report
// A screen to display route report on a map in the TracDefg app.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/map_style_provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/widgets/offline_address_service.dart';

class RouteReport {
  final int id;
  final int deviceId;
  final String protocol;
  final DateTime serverTime;
  final DateTime deviceTime;
  final DateTime fixTime;
  final bool outdated;
  final bool valid;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;
  final double course;
  final String? address;
  final double accuracy;
  final String? network;
  final Map<String, dynamic> attributes;

  RouteReport({
    required this.id,
    required this.deviceId,
    required this.protocol,
    required this.serverTime,
    required this.deviceTime,
    required this.fixTime,
    required this.outdated,
    required this.valid,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.course,
    this.address,
    required this.accuracy,
    this.network,
    required this.attributes,
  });

  factory RouteReport.fromJson(Map<String, dynamic> json) {
    return RouteReport(
      id: json['id'] as int,
      deviceId: json['deviceId'] as int,
      protocol: json['protocol'] as String,
      serverTime: DateTime.parse(json['serverTime'] as String),
      deviceTime: DateTime.parse(json['deviceTime'] as String),
      fixTime: DateTime.parse(json['fixTime'] as String),
      outdated: (json['outdated'] ?? false) as bool,
      valid: (json['valid'] ?? false) as bool,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      course: (json['course'] as num).toDouble(),
      address: json['address'] as String?,
      accuracy: (json['accuracy'] as num).toDouble(),
      network: json['network'] as String?,
      attributes: json['attributes'] as Map<String, dynamic>,
    );
  }
}

class RouteReportScreen extends StatefulWidget {
  const RouteReportScreen({super.key});

  @override
  State<RouteReportScreen> createState() => _RouteReportScreenState();
}

class _RouteReportScreenState extends State<RouteReportScreen> {
  List<RouteReport> _routeReport = [];
  bool _isLoading = true;
  String? _deviceName;
  maplibre.MapLibreMapController? _mapController;
  final Set<String> _loadedIcons = {};
  bool _isStyleLoaded = false;
  final http.Client _httpClient = http.Client();

  @override
  void initState() {
    super.initState();
    _fetchRouteReport();
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  Future<void> _fetchRouteReport() async {
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
    debugPrint(
      'Fetched from SharedPreferences: deviceId=$deviceId, fromDate=$fromDateString, toDate=$toDateString',
    );

    if (deviceId == null || fromDateString == null || toDateString == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      debugPrint('Missing device ID or date range from SharedPreferences.');
      return;
    }

    final fromDate = DateTime.tryParse(fromDateString);
    final toDate = DateTime.tryParse(toDateString);

    if (fromDate == null || toDate == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      debugPrint('Failed to parse date strings.');
      return;
    }

    try {
      final apiClient = traccarProvider.apiClient;
      final queryParams = [
        api.QueryParam('from', fromDate.toIso8601String()),
        api.QueryParam('to', toDate.toIso8601String()),
        api.QueryParam('deviceId', deviceId.toString()),
      ];
      final path = '/reports/route';
      final headerParams = {'Accept': 'application/json'};

      final response = await apiClient.invokeAPI(
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
            _routeReport = decodedData
                .map((e) => RouteReport.fromJson(e as Map<String, dynamic>))
                .toList();

            if (_routeReport.isNotEmpty) {
              final device = traccarProvider.devices.firstWhere(
                (d) => d.id == _routeReport.first.deviceId,
                orElse: () => api.Device(),
              );
              _deviceName = device.name;
              _createMapElements();
            }
          }
        } else {
          debugPrint(
            'Warning: Expected JSON, but received content type: $contentType',
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to load route report. The server returned a file instead of JSON.'
                    .tr,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching route report: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load route report.'.tr)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onStyleLoaded() async {
    _isStyleLoaded = true;
    if (_routeReport.isNotEmpty) {
      _createMapElements();
    }
  }

  Future<void> _createMapElements() async {
    if (_mapController == null || !_isStyleLoaded || _routeReport.isEmpty) {
      return;
    }

    await _mapController!.clearSymbols();
    await _mapController!.clearLines();

    final points = _routeReport
        .map((p) => maplibre.LatLng(p.latitude, p.longitude))
        .toList();

    if (points.isNotEmpty) {
      await _mapController!.addLine(
        maplibre.LineOptions(
          geometry: points,
          lineColor: "#0000FF",
          lineWidth: 4.0,
        ),
      );

      await _addMarker(points.first, "start_pin", "assets/images/start.png");
      await _addMarker(points.last, "end_pin", "assets/images/destination.png");

      _zoomToFit(points);
    }
  }

  Future<void> _addMarker(
    maplibre.LatLng point,
    String iconId,
    String assetPath,
  ) async {
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
        left: 50,
        right: 50,
        top: 50,
        bottom: 50,
      ),
    );
  }

  void _animateToPosition(maplibre.LatLng position) {
    _mapController?.animateCamera(maplibre.CameraUpdate.newLatLng(position));
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime.toLocal());
  }

  String _formatSpeed(double speed) {
    return '${(speed * 1.852).toStringAsFixed(2)} ${'sharedKmh'.tr}';
  }

  Future<void> _exportToCsv() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Storage permission is required to save the file.'.tr),
        ),
      );
      return;
    }

    if (_routeReport.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No data to export.'.tr)));
      return;
    }

    final csvHeader =
        'id,deviceId,deviceTime,latitude,longitude,speed,address,protocol,serverTime,fixTime,outdated,valid,altitude,course,accuracy,network,attributes\n';
    final csvRows = _routeReport
        .map((position) {
          final attributesJson = json.encode(position.attributes);
          return '${position.id},${position.deviceId},"${_formatDateTime(position.deviceTime)}",${position.latitude},${position.longitude},${position.speed},"${position.address ?? ''}",${position.protocol},"${_formatDateTime(position.serverTime)}","${_formatDateTime(position.fixTime)}",${position.outdated},${position.valid},${position.altitude},${position.course},${position.accuracy},${position.network ?? ''},"$attributesJson"';
        })
        .join('\n');

    final csvContent = csvHeader + csvRows;
    final directory = await getExternalStorageDirectory();
    final fileName =
        'route_report_${_deviceName ?? 'vehicle'}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File('${directory!.path}/$fileName');

    try {
      await file.writeAsString(csvContent);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Report exported to'.tr} ${file.path}')),
      );
    } catch (e) {
      debugPrint('Error exporting CSV: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to export report.'.tr)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: Text('sharedLoading'.tr)));
    }

    if (_routeReport.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_deviceName ?? 'reportReplay'.tr)),
        body: Center(child: Text('sharedNoData'.tr)),
      );
    }

    final mapProvider = Provider.of<MapStyleProvider>(context);
    final initialCenter = _routeReport.isNotEmpty
        ? maplibre.LatLng(
            _routeReport.first.latitude,
            _routeReport.first.longitude,
          )
        : const maplibre.LatLng(21.9162, 95.9560);

    return Scaffold(
      appBar: AppBar(
        title: Text('${'reportReplay'.tr}: ${_deviceName ?? ''}'),
        actions: [
          IconButton(icon: const Icon(Icons.download), onPressed: _exportToCsv),
        ],
      ),
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
                      mapProvider.isSatelliteMode
                          ? Icons.map
                          : Icons.satellite_alt,
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
              itemCount: _routeReport.length,
              itemBuilder: (context, index) {
                final position = _routeReport[index];
                return GestureDetector(
                  onTap: () => _animateToPosition(
                    maplibre.LatLng(position.latitude, position.longitude),
                  ),
                  child: Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 16.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${'reportPositions'.tr} ${index + 1}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            title: Text('positionDeviceTime'.tr),
                            trailing: Text(
                              _formatDateTime(position.deviceTime),
                            ),
                          ),
                          ListTile(
                            title: Text('positionSpeed'.tr),
                            trailing: Text(_formatSpeed(position.speed)),
                          ),
                          ListTile(
                            title: Text('positionAddress'.tr),
                            trailing: FutureBuilder<String>(
                              future:
                                  position.address != null &&
                                      position.address!.isNotEmpty
                                  ? Future.value(position.address)
                                  : OfflineAddressService.getAddress(
                                      position.latitude,
                                      position.longitude,
                                    ),
                              builder: (context, snapshot) {
                                return Text(snapshot.data ?? '...');
                              },
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
}
