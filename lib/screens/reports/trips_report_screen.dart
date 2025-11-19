// lib/screens/reports/trips_report_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:get/get.dart';

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
    _fetchTripsReport();
  }

  Future<void> _loadMarkerIcons() async {
    // Load the start icon from assets/images/start.png
    final Uint8List startIconBytes = (await rootBundle.load('assets/images/start.png')).buffer.asUint8List();
    final ui.Codec startCodec = await ui.instantiateImageCodec(startIconBytes, targetWidth: 80);
    final ui.FrameInfo startFi = await startCodec.getNextFrame();
    _startIcon = await BitmapDescriptor.fromBytes(
      (await (await startCodec.getNextFrame()).image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List(),
    );

    // Load the end icon from assets/images/destination.png
    final Uint8List endIconBytes = (await rootBundle.load('assets/images/destination.png')).buffer.asUint8List();
    final ui.Codec endCodec = await ui.instantiateImageCodec(endIconBytes, targetWidth: 80);
    final ui.FrameInfo endFi = await endCodec.getNextFrame();
    _endIcon = await BitmapDescriptor.fromBytes(
      (await (await endCodec.getNextFrame()).image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List(),
    );
  }

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
              _createMarkersAndPolylines();
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

  void _createMarkersAndPolylines() {
    _markers.clear();
    _polylines.clear();
    for (var i = 0; i < _tripsReport.length; i++) {
      final trip = _tripsReport[i];
      final LatLng startPoint = LatLng(trip.startLat, trip.startLon);
      final LatLng endPoint = LatLng(trip.endLat, trip.endLon);

      _markers.add(
        Marker(
          markerId: MarkerId('start_$i'),
          position: startPoint,
          infoWindow: InfoWindow(
            title: '${'reportTrips'.tr} ${i + 1} ${'reportStartDate'.tr}',
            snippet: '${'positionDeviceTime'.tr}: ${DateFormat('yyyy-MM-dd HH:mm').format(trip.startTime.toLocal())}',
          ),
          icon: _startIcon,
        ),
      );

      _markers.add(
        Marker(
          markerId: MarkerId('end_$i'),
          position: endPoint,
          infoWindow: InfoWindow(
            title: '${'reportTrips'.tr} ${i + 1} ${'reportEndTime'.tr}',
            snippet: '${'positionDeviceTime'.tr}: ${DateFormat('yyyy-MM-dd HH:mm').format(trip.endTime.toLocal())}',
          ),
          icon: _endIcon,
        ),
      );

      _polylines.add(
        Polyline(
          polylineId: PolylineId('trip_route_$i'),
          points: [startPoint, endPoint],
          color: Colors.blue,
          width: 5,
        ),
      );
    }
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
    final controller = _controller.future.then((c) {
      c.showMarkerInfoWindow(markerId);
    });
  }

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
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_tripsReport.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${'reportTrips'.tr}: ${_deviceName ?? ''}')),
        body: Center(
          child: Text('No data available for the selected period.'.tr),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('${'reportTrips'.tr}: ${_deviceName ?? ''}')),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: Stack(
              children: [
                GoogleMap(
              mapType: _currentMapType,
              initialCameraPosition: _tripsReport.isNotEmpty
                  ? CameraPosition(
                      target: LatLng(_tripsReport.first.startLat, _tripsReport.first.startLon),
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _tripsReport.length,
              itemBuilder: (context, index) {
                final trip = _tripsReport[index];
                return GestureDetector(
                  onTap: () {
                    _animateToPosition(LatLng(trip.startLat, trip.startLon));
                    _showInfoWindowForMarker(MarkerId('start_$index'));
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
                            '${'reportTrips'.tr} ${index + 1}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Divider(),
                          ListTile(
                            title: Text('reportStartTime'.tr),
                            trailing: Text(DateFormat('yyyy-MM-dd HH:mm').format(trip.startTime.toLocal())),
                          ),
                          ListTile(
                            title: Text('reportEndTime'.tr),
                            trailing: Text(DateFormat('yyyy-MM-dd HH:mm').format(trip.endTime.toLocal())),
                          ),
                          ListTile(
                            title: Text('reportDuration'.tr),
                            trailing: Text(_formatDuration(trip.duration)),
                          ),
                          ListTile(
                            title: Text('sharedDistance'.tr),
                            trailing: Text(_formatDistance(trip.distance)),
                          ),
                          ListTile(
                            title: Text('reportAverageSpeed'.tr),
                            trailing: Text('${trip.averageSpeed.toStringAsFixed(2)} ${'sharedKmh'.tr}'),
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