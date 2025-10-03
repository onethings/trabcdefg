// lib/screens/reports/route_report_screen.dart //Replay report

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart'; // REMOVED
import 'package:flutter_map/flutter_map.dart'; // ADDED
import 'package:latlong2/latlong.dart'; // FIXED: Un-aliased import for LatLng
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http; // ADDED
import 'package:hive/hive.dart'; // ADDED
import 'dart:typed_data'; // ADDED
import 'package:flutter/foundation.dart'; // ADDED

// --- Tile Caching Implementation using Hive (Copied from map_screen.dart) ---

class _TileCacheService {
  late Box<Uint8List> _tileBox;
  static const String boxName = 'mapTilesCache';

  Future<void> init() async {
    _tileBox = await Hive.openBox<Uint8List>(boxName);
  }

  String _generateKey(String url) {
    return url.hashCode.toString();
  }

  Future<Uint8List?> getTile(String url) async {
    return _tileBox.get(_generateKey(url));
  }

  Future<void> saveTile(String url, Uint8List tileData) async {
    await _tileBox.put(_generateKey(url), tileData);
  }
}

class CachedNetworkImageProvider extends ImageProvider<CachedNetworkImageProvider> {
  final String url;
  final _TileCacheService cacheService;
  final http.Client httpClient;

  CachedNetworkImageProvider(
    this.url, {
    required this.cacheService,
    required this.httpClient,
  });

  @override
  ImageStreamCompleter loadImage(
    CachedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<CachedNetworkImageProvider>('Original key', key),
      ],
    );
  }

  @override
  Future<CachedNetworkImageProvider> obtainKey(
    ImageConfiguration configuration, 
  ) {
    return Future<CachedNetworkImageProvider>.value(this);
  }

  Future<ui.Codec> _loadAsync(
    CachedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    assert(key == this);

    final cachedData = await cacheService.getTile(url);

    if (cachedData != null) {
      return decode(await ui.ImmutableBuffer.fromUint8List(cachedData)); 
    }

    try {
      final response = await httpClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        
        await cacheService.saveTile(url, bytes);

        return decode(await ui.ImmutableBuffer.fromUint8List(bytes)); 
      } else {
        throw Exception('Failed to load tile from network: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}

class _HiveTileProvider extends TileProvider {
  final _TileCacheService cacheService;
  final http.Client httpClient;

  _HiveTileProvider({
    required this.cacheService,
    required this.httpClient,
  });

  @override
  ImageProvider getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      cacheService: cacheService,
      httpClient: httpClient,
    );
  }
}

enum AppMapType {
  openStreetMap,
  satellite,
}

// --- End of Map Caching & FlutterMap Imports/Definitions ---

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
      outdated: (json['outdated'] ?? false) as bool, // FIX applied
      valid: (json['valid'] ?? false) as bool,      // FIX applied
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
  late MapController _mapController; 
  final List<Polyline> _polylines = []; 
  final List<Marker> _markers = []; 

  AppMapType _currentMapType = AppMapType.openStreetMap; 
  
  // Caching variables
  final _TileCacheService _cacheService = _TileCacheService();
  final http.Client _httpClient = http.Client();
  late _HiveTileProvider _tileProvider;
  bool _isCacheInitialized = false;

  // Tile URLs
  static const String _osmUrlTemplate = 
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _satelliteUrlTemplate = 
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const List<String> _osmSubdomains = ['a', 'b', 'c'];


  @override
  void initState() {
    super.initState();
    _mapController = MapController(); 
    
    // Initialize cache service and then the tile provider
    _cacheService.init().then((_) {
      if (mounted) { // CHECK 1: Ensure widget is mounted before setting state/variables
        _tileProvider = _HiveTileProvider(
          cacheService: _cacheService,
          httpClient: _httpClient,
        );
        setState(() {
          _isCacheInitialized = true;
        });
      }
    });

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
    _polylines.clear();
    _markers.clear();
    
    if (_routeReport.isEmpty) return;

    final List<LatLng> polylinePoints = _routeReport.map((p) => LatLng(p.latitude, p.longitude)).toList();
    
    // Polyline
    _polylines.add(
      Polyline(
        points: polylinePoints,
        color: Colors.blue,
        strokeWidth: 5.0,
      ),
    );

    // Start Marker
    final start = _routeReport.first;
    _markers.add(
      Marker(
        point: LatLng(start.latitude, start.longitude),
        width: 30.0,
        height: 30.0,
        child: Image.asset(
          'assets/images/start.png',
          fit: BoxFit.contain,
        ),
      ),
    );

    // End Marker
    final end = _routeReport.last;
    _markers.add(
      Marker(
        point: LatLng(end.latitude, end.longitude),
        width: 30.0,
        height: 30.0,
        child: Image.asset(
          'assets/images/destination.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Future<void> _animateToPosition(LatLng position) async {
    // No need for a mounted check here since _mapController.move is synchronous
    // but the position itself should be safe if the call originated from the
    // currently built widget tree (e.g., from onTap in the ListView).
    _mapController.move(
      position,
      16,
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime.toLocal());
  }

  String _formatSpeed(double speed) {
    return '${(speed * 1.852).toStringAsFixed(2)} ${'sharedKmh'.tr}';
  }
  
  // Future<void> _exportToKML() async { ... } 
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (!_isCacheInitialized) { 
       return Scaffold(
        appBar: AppBar(title: Text('Loading Map...'.tr)),
        body: const Center(child: Text('Initializing Map Assets...')),
      );
    }

    if (_routeReport.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('reportReplay'.tr+': ${_deviceName ?? ''}')),
        body: Center(
          child: Text('No data available for the selected period.'.tr),
        ),
      );
    }
    
    final LatLng initialCenter = _routeReport.isNotEmpty
        ? LatLng(_routeReport.first.latitude, _routeReport.first.longitude)
        : const LatLng(21.9162, 95.9560); 

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
      body: Column(
              children: [
                Expanded(
                  flex: 1,
                  child: Stack(
                    children: [
                      // REPLACED GoogleMap with FlutterMap
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: initialCenter,
                          initialZoom: 14.0,
                          interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                        ),
                        children: [
                          // Tile Layer: Conditional based on map type (OSM/Satellite)
                          TileLayer(
                            urlTemplate: _currentMapType == AppMapType.openStreetMap
                                ? _osmUrlTemplate
                                : _satelliteUrlTemplate,
                            subdomains: _currentMapType == AppMapType.openStreetMap
                                ? _osmSubdomains
                                : const [],
                            userAgentPackageName: 'com.trabcdefg.app',
                            tileProvider: _tileProvider, // Hive Caching
                          ),
                          // Polyline Layer
                          PolylineLayer(polylines: _polylines),
                          // Marker Layer
                          MarkerLayer(markers: _markers),
                        ],
                      ),
                      // Map Type Toggle Button
                      Positioned(
                        top: 10,
                        right: 10,
                        child: FloatingActionButton(
                          mini: true,
                          onPressed: () {
                            setState(() {
                              _currentMapType = _currentMapType == AppMapType.openStreetMap
                                  ? AppMapType.satellite
                                  : AppMapType.openStreetMap;
                            });
                          },
                          child: Icon(
                            _currentMapType == AppMapType.openStreetMap
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
                          itemCount: _routeReport.length,
                          itemBuilder: (context, index) {
                            final position = _routeReport[index];
                            return GestureDetector(
                              onTap: () {
                                // Animate to the selected position
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
                                          trailing: Text(position.address! as String),
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