// lib/screens/reports/combined_report_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'package:get/get.dart';

class CombinedReportScreen extends StatefulWidget {
  const CombinedReportScreen({super.key});

  @override
  State<CombinedReportScreen> createState() => _CombinedReportScreenState();
}

// A new model to combine positions and events from different API calls
class CombinedReport {
  final List<api.Position> positions;
  final List<api.Event> events;
  final List<List<double>>? route;

  CombinedReport({required this.positions, required this.events, this.route});
}

class _CombinedReportScreenState extends State<CombinedReportScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  CombinedReport? _combinedReport;
  bool _isLoading = true;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  String? _deviceName;

  late BitmapDescriptor _ignitionOnIcon;
  late BitmapDescriptor _ignitionOffIcon;

  Map<int, api.Position> _positionsMap = {};
  MapType _currentMapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    _fetchCombinedReport();
  }

  Future<void> _loadMarkerIcons() async {
    _ignitionOnIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(),
      'assets/images/accon.png',
    );
    _ignitionOffIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(),
      'assets/images/accoff.png',
    );
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
          _combinedReport = CombinedReport(
            positions: positions,
            events: events,
            route: route,
          );
          _updateMap();
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

  void _updateMap() {
    if (_combinedReport == null) {
      return;
    }

    // Clear previous markers and polylines
    _polylines.clear();
    _markers.clear();

    // Draw route polyline
    if (_combinedReport!.route != null && _combinedReport!.route!.isNotEmpty) {
      final List<LatLng> routePoints = _combinedReport!.route!
          .map((coord) => LatLng(coord[1], coord[0]))
          .toList();

      if (routePoints.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route_polyline'),
            points: routePoints,
            color: Colors.blue,
            width: 4,
          ),
        );

        // Add start and end markers
        _markers.add(
          Marker(
            markerId: const MarkerId('start_marker'),
            position: routePoints.first,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          ),
        );

        _markers.add(
          Marker(
            markerId: const MarkerId('end_marker'),
            position: routePoints.last,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        );
      }
    }

    // Populate positions map for quick lookup
    _positionsMap = {for (var pos in _combinedReport!.positions) pos.id!: pos};

    // Add event markers
    for (var event in _combinedReport!.events) {
      if (event.positionId != null &&
          _positionsMap.containsKey(event.positionId)) {
        final position = _positionsMap[event.positionId]!;
        if (position.latitude != null && position.longitude != null) {
          BitmapDescriptor eventIcon;
          switch (event.type) {
            case 'ignitionOn':
              eventIcon = _ignitionOnIcon;
              break;
            case 'ignitionOff':
              eventIcon = _ignitionOffIcon;
              break;
            default:
              eventIcon = BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueYellow,
              );
              break;
          }

          String translatedEventKey;
          if (event.type != null && event.type!.isNotEmpty) {
            translatedEventKey =
                'event' +
                event.type![0].toUpperCase() +
                event.type!.substring(1);
          } else {
            translatedEventKey = 'eventUnknown';
          }

          _markers.add(
            Marker(
              markerId: MarkerId('event_marker_${event.id}'),
              position: LatLng(
                position.latitude!.toDouble(),
                position.longitude!.toDouble(),
              ),
              icon: eventIcon,
              infoWindow: InfoWindow(
                title: 'reportEvents'.tr + ': ${translatedEventKey.tr}',
                snippet:
                    'reportTimeType'.tr +
                    ': ${event.eventTime?.toLocal().toString().split('.')[0]}',
              ),
            ),
          );
        }
      }
    }

    setState(() {});
  }

  Future<void> _showInfoWindowForMarker(MarkerId markerId) async {
    final controller = await _controller.future;
    controller.showMarkerInfoWindow(markerId);
  }

  Future<void> _animateToPosition(LatLng latLng) async {
    final controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: 15)),
    );
  }

  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: Text('sharedLoading'.tr)));
    }

    if (_combinedReport == null ||
        (_combinedReport!.positions.isEmpty &&
            _combinedReport!.route!.isEmpty)) {
      return Scaffold(
        appBar: AppBar(title: Text(_deviceName ?? 'reportCombinedReport'.tr)),
        body: Center(child: Text('sharedNoData'.tr)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_deviceName ?? 'reportCombinedReport'.tr)),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                GoogleMap(
                  mapType: _currentMapType,
                  initialCameraPosition: CameraPosition(
                    target: _polylines.isNotEmpty
                        ? _polylines.first.points.first
                        : const LatLng(0, 0),
                    zoom: 13,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                  polylines: _polylines,
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
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Text(
                  'reportPositions'.tr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ..._combinedReport!.positions
                    .map(
                      (pos) => ListTile(
                        title: Text(
                          'sharedDevice'.tr +
                              ': ${_deviceName}, ' +
                              'positionSpeed'.tr +
                              ': ${pos.speed} ' +
                              'sharedKmh'.tr,
                        ),
                        subtitle: Text(
                          'reportTimeType'.tr +
                              ': ${pos.deviceTime?.toLocal().toString().split('.')[0]}',
                        ),
                        onTap: () async {
                          if (pos.latitude != null && pos.longitude != null) {
                            await _animateToPosition(
                              LatLng(
                                pos.latitude!.toDouble(),
                                pos.longitude!.toDouble(),
                              ),
                            );

                            // Add a temporary marker for the tapped position
                            final tempMarkerId = MarkerId(
                              'temp_marker_${pos.id}',
                            );
                            _markers.add(
                              Marker(
                                markerId: tempMarkerId,
                                position: LatLng(
                                  pos.latitude!.toDouble(),
                                  pos.longitude!.toDouble(),
                                ),
                                infoWindow: InfoWindow(
                                  title: 'reportPosition'.tr,
                                  snippet:
                                      'reportTimeType'.tr +
                                      ': ${pos.deviceTime?.toLocal().toString().split('.')[0]}',
                                ),
                              ),
                            );

                            // Immediately show the info window and remove the temporary marker after a delay
                            await _showInfoWindowForMarker(tempMarkerId);
                            Future.delayed(const Duration(seconds: 3), () {
                              setState(() {
                                _markers.removeWhere(
                                  (m) => m.markerId == tempMarkerId,
                                );
                              });
                            });
                          }
                        },
                      ),
                    )
                    .toList(),
                const Divider(),
                Text(
                  'reportEvents'.tr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ..._combinedReport!.events.map((event) {
                  String translatedEventKey;
                  if (event.type != null && event.type!.isNotEmpty) {
                    translatedEventKey =
                        'event' +
                        event.type![0].toUpperCase() +
                        event.type!.substring(1);
                  } else {
                    translatedEventKey = 'eventUnknown';
                  }
                  return ListTile(
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
                          await _animateToPosition(
                            LatLng(
                              position.latitude!.toDouble(),
                              position.longitude!.toDouble(),
                            ),
                          );
                          _showInfoWindowForMarker(
                            MarkerId('event_marker_${event.id}'),
                          );
                        }
                      }
                    },
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
