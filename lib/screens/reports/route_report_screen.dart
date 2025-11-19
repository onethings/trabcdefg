// lib/screens/reports/route_report_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:get/get.dart';

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
      outdated: (json['outdated'] ?? false) as bool, // Handle null
      valid: (json['valid'] ?? false) as bool, // Handle null
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
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  late BitmapDescriptor _startIcon;
  late BitmapDescriptor _endIcon;
  MapType _currentMapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _fetchRouteReport();
  }

  Future<void> _loadMarkerIcons() async {
    final Uint8List startIconBytes = (await rootBundle.load('assets/images/start.png')).buffer.asUint8List();
    _startIcon = await BitmapDescriptor.fromBytes(startIconBytes);

    final Uint8List endIconBytes = (await rootBundle.load('assets/images/destination.png')).buffer.asUint8List();
    _endIcon = await BitmapDescriptor.fromBytes(endIconBytes);
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
      final path = '/reports/route';
      final headerParams = {'Accept': 'application/json'};

      // final http.Response response = await apiClient.invokeAPI(
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
              _createMarkersAndPolylines();
            }
          }
        } else {
          print('Warning: Expected JSON, but received content type: $contentType');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load route report. The server returned a file instead of JSON.'.tr)),
          );
        }
      }
    } catch (e) {
      print('Error fetching route report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load route report.'.tr)),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _createMarkersAndPolylines() {
    _markers.clear();
    _polylines.clear();

    if (_routeReport.isEmpty) return;

    final List<LatLng> polylinePoints = _routeReport
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route_path'),
        points: polylinePoints,
        color: Colors.blue,
        width: 5,
      ),
    );

    // Add start marker
    final startPoint = _routeReport.first;
    _markers.add(
      Marker(
        markerId: MarkerId('start_${startPoint.id}'),
        position: LatLng(startPoint.latitude, startPoint.longitude),
        infoWindow: InfoWindow(
          title: 'Start'.tr,
          snippet: '${'positionDeviceTime'.tr}: ${DateFormat('yyyy-MM-dd HH:mm').format(startPoint.deviceTime.toLocal())}',
        ),
        icon: _startIcon,
      ),
    );

    // Add end marker
    final endPoint = _routeReport.last;
    _markers.add(
      Marker(
        markerId: MarkerId('end_${endPoint.id}'),
        position: LatLng(endPoint.latitude, endPoint.longitude),
        infoWindow: InfoWindow(
          title: 'End'.tr,
          snippet: '${'positionDeviceTime'.tr}: ${DateFormat('yyyy-MM-dd HH:mm').format(endPoint.deviceTime.toLocal())}',
        ),
        icon: _endIcon,
      ),
    );
  }

  Future<void> _animateToPosition(LatLng position) async {
    final controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 16,
        ),
      ),
    );
  }

  void _showInfoWindowForMarker(MarkerId markerId) {
    _controller.future.then((c) {
      c.showMarkerInfoWindow(markerId);
    });
  }

  String _formatSpeed(double speed) {
    return '${speed.toStringAsFixed(2)} ${'sharedKmh'.tr}';
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime.toLocal());
  }

  Future<void> _exportToCsv() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Storage permission is required to save the file.'.tr)),
      );
      return;
    }

    if (_routeReport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No data to export.'.tr)),
      );
      return;
    }

    final csvHeader =
        'id,deviceId,deviceTime,latitude,longitude,speed,address,protocol,serverTime,fixTime,outdated,valid,altitude,course,accuracy,network,attributes\n';
    final csvRows = _routeReport.map((position) {
      final attributesJson = json.encode(position.attributes);
      return '${position.id},${position.deviceId},"${_formatDateTime(position.deviceTime)}",${position.latitude},${position.longitude},${position.speed},"${position.address ?? ''}",${position.protocol},"${_formatDateTime(position.serverTime)}","${_formatDateTime(position.fixTime)}",${position.outdated},${position.valid},${position.altitude},${position.course},${position.accuracy},${position.network ?? ''},"$attributesJson"';
    }).join('\n');

    final csvContent = csvHeader + csvRows;
    final directory = await getExternalStorageDirectory();
    final fileName = 'route_report_${_deviceName ?? 'vehicle'}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File('${directory!.path}/$fileName');

    try {
      await file.writeAsString(csvContent);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Report exported to'.tr} ${file.path}')),
      );
    } catch (e) {
      print('Error exporting CSV: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export report.'.tr)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${'reportReplay'.tr}: ${_deviceName ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToCsv,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  flex: 1,
                  child: Stack(
              children: [
                GoogleMap(
                    mapType: _currentMapType,
                    initialCameraPosition: _routeReport.isNotEmpty
                        ? CameraPosition(
                            target: LatLng(_routeReport.first.latitude, _routeReport.first.longitude),
                            zoom: 14,
                          )
                        : const CameraPosition(
                            target: LatLng(21.9162, 95.9560), // Mandalay, Myanmar
                            zoom: 14,
                          ),
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                    },
                    markers: _markers,
                    polylines: _polylines,
                  ),
                   Positioned(
                  top: 10,
                  right: 10,
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: () {
                      setState(() {
                        _currentMapType = _currentMapType == MapType.normal
                            ? MapType.satellite
                            : MapType.normal;
                      });
                    },
                    child: Icon(
                      _currentMapType == MapType.normal
                          ? Icons.satellite_alt
                          : Icons.map,
                    ),
                  ),
                ),
              ],
            ),
                ),
                Expanded(
                  flex: 1,
                  child: _routeReport.isEmpty
                      ? Center(child: Text('No route data available for the selected period.'.tr))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _routeReport.length,
                          itemBuilder: (context, index) {
                            final position = _routeReport[index];
                            return GestureDetector(
                              onTap: () {
                                _animateToPosition(LatLng(position.latitude, position.longitude));
                              },
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
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const Divider(),
                                      ListTile(
                                        title: Text('positionDeviceTime'.tr),
                                        trailing: Text(_formatDateTime(position.deviceTime)),
                                      ),
                                      ListTile(
                                        title: Text('positionSpeed'.tr),
                                        trailing: Text(_formatSpeed(position.speed)),
                                      ),
                                      if (position.address != null)
                                        ListTile(
                                          title: Text('positionAddress'.tr),
                                          trailing: Text(position.address!),
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