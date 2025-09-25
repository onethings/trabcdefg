// lib/screens/reports/stops_report_screen.dart

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

class StopReport {
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
  final int positionId;
  final double latitude;
  final double longitude;
  final String? address;
  final int duration;
  final int engineHours;

  StopReport({
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
    required this.positionId,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.duration,
    required this.engineHours,
  });

  factory StopReport.fromJson(Map<String, dynamic> json) {
    return StopReport(
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
      positionId: json['positionId'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      duration: json['duration'] as int,
      engineHours: json['engineHours'] as int,
    );
  }
}

class StopsReportScreen extends StatefulWidget {
  const StopsReportScreen({super.key});

  @override
  State<StopsReportScreen> createState() => _StopsReportScreenState();
}

class _StopsReportScreenState extends State<StopsReportScreen> {
  List<StopReport> _stopsReport = [];
  bool _isLoading = true;
  String? _deviceName;
  MapType _currentMapType = MapType.normal;
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};
  late BitmapDescriptor _parkingIcon;
  static const CameraPosition _defaultLocation = CameraPosition(
    target: LatLng(21.9162, 95.9560), // Mandalay, Myanmar
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _fetchStopsReport();
  }

  Future<void> _loadMarkerIcons() async {
    final Uint8List iconBytes = (await rootBundle.load('assets/images/parking.png')).buffer.asUint8List();
    final ui.Codec codec = await ui.instantiateImageCodec(iconBytes, targetWidth: 80);
    final ui.FrameInfo fi = await codec.getNextFrame();
    _parkingIcon = await BitmapDescriptor.fromBytes(
      (await (await codec.getNextFrame()).image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List(),
    );
  }


  Future<void> _fetchStopsReport() async {
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
      final path = '/reports/stops';
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
            _stopsReport = decodedData
                .map((e) => StopReport.fromJson(e as Map<String, dynamic>))
                .toList();
            if (_stopsReport.isNotEmpty) {
              _deviceName = _stopsReport.first.deviceName;
              _createMarkers();
            }
          }
        } else {
          print('Warning: Expected JSON, but received content type: $contentType');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load stops report. The server returned a file instead of JSON. Please check the Traccar server settings for reports.'.tr)),
          );
        }
      }
    } catch (e) {
      print('Error fetching stops report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load stops report.'.tr)),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _createMarkers() {
    _markers.clear();
    for (var i = 0; i < _stopsReport.length; i++) {
      final stop = _stopsReport[i];
      _markers.add(
        Marker(
          markerId: MarkerId('stop_$i'),
          position: LatLng(stop.latitude, stop.longitude),
          infoWindow: InfoWindow(
            title: '${'reportStops'.tr} ${i + 1}',
            snippet: '${'reportDuration'.tr}: ${_formatDuration(stop.duration)}\n'
                     '${'reportStartDate'.tr}: ${DateFormat('yyyy-MM-dd HH:mm').format(stop.startTime.toLocal())}',
          ),
          icon: _parkingIcon,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_stopsReport.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${'reportStops'.tr} ${_deviceName ?? ''}')),
        body: Center(
          child: Text('No data available for the selected period.'.tr),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('${'reportStops'.tr} ${_deviceName ?? ''}')),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: Stack(
              children: [GoogleMap(
              mapType: _currentMapType,
              initialCameraPosition: _stopsReport.isNotEmpty
                  ? CameraPosition(
                      target: LatLng(_stopsReport.first.latitude, _stopsReport.first.longitude),
                      zoom: 14,
                    )
                  : _defaultLocation,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
              markers: _markers,
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
              itemCount: _stopsReport.length,
              itemBuilder: (context, index) {
                final stop = _stopsReport[index];
                return GestureDetector(
                  onTap: () {
                    _animateToPosition(LatLng(stop.latitude, stop.longitude));
                    _showInfoWindowForMarker(MarkerId('stop_$index'));
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
                            '${'reportStops'.tr} ${index + 1}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Divider(),
                          ListTile(
                            title: Text('reportStartDate'.tr),
                            trailing: Text(DateFormat('yyyy-MM-dd HH:mm').format(stop.startTime.toLocal())),
                          ),
                          ListTile(
                            title: Text('reportEndTime'.tr),
                            trailing: Text(DateFormat('yyyy-MM-dd HH:mm').format(stop.endTime.toLocal())),
                          ),
                          ListTile(
                            title: Text('reportDuration'.tr),
                            trailing: Text(_formatDuration(stop.duration)),
                          ),
                          ListTile(
                            title: Text('positionAddress'.tr),
                            trailing: Text(stop.address ?? 'Address not available'.tr),
                          ),
                          ListTile(
                            title: Text('reportEngineHours'.tr),
                            trailing: Text(_formatDuration(stop.engineHours)),
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