// lib/screens/reports/stops_report_screen.dart
// A screen to display stops report on a map in the TracDefg app.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
// import 'package:google_maps_flutter/google_maps_flutter.dart'; // REMOVED: Google Maps
import 'package:flutter_map/flutter_map.dart'; // ADDED: FlutterMap for OpenStreetMap
import 'package:latlong2/latlong.dart'; // FIXED: Un-aliased import for LatLng
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart'; // ADDED: Hive Caching
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

class CachedNetworkImageProvider
    extends ImageProvider<CachedNetworkImageProvider> {
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
        throw Exception(
          'Failed to load tile from network: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}

class _HiveTileProvider extends TileProvider {
  final _TileCacheService cacheService;
  final http.Client httpClient;

  _HiveTileProvider({required this.cacheService, required this.httpClient});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      cacheService: cacheService,
      httpClient: httpClient,
    );
  }
}

enum AppMapType { openStreetMap, satellite }

// --- End of Map Caching & FlutterMap Imports/Definitions ---

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
  // final Completer<GoogleMapController> _controller = Completer(); // REMOVED
  late MapController _mapController; // ADDED
  final List<Marker> _markers = []; // Changed to FlutterMap Marker list
  // late BitmapDescriptor _stopIcon; // REMOVED

  AppMapType _currentMapType =
      AppMapType.openStreetMap; // Changed to AppMapType

  // Caching variables (ADDED)
  final _TileCacheService _cacheService = _TileCacheService();
  final http.Client _httpClient = http.Client();
  late _HiveTileProvider _tileProvider;
  bool _isCacheInitialized = false;

  // Tile URLs (ADDED)
  static const String _osmUrlTemplate =
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _satelliteUrlTemplate =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const List<String> _osmSubdomains = ['a', 'b', 'c'];

  @override
  void initState() {
    super.initState();
    // _loadMarkerIcons(); // Not needed for FlutterMap
    _mapController = MapController(); // Initialized MapController

    // Initialize cache service and then the tile provider
    _cacheService.init().then((_) {
      _tileProvider = _HiveTileProvider(
        cacheService: _cacheService,
        httpClient: _httpClient,
      );
      if (mounted) {
        setState(() {
          _isCacheInitialized = true;
        });
      }
    });

    _fetchStopsReport();
  }

  @override
  void dispose() {
    _httpClient.close(); // Dispose HTTP client
    super.dispose();
  }

  // Future<void> _loadMarkerIcons() async { ... } // REMOVED: Replaced by Marker widgets

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
      // LatLng from latlong2 (un-aliased)
      final LatLng stopPoint = LatLng(stop.latitude, stop.longitude);

      // FlutterMap Marker for Stop Point
      _markers.add(
        Marker(
          point: stopPoint,
          width: 30.0,
          height: 30.0,
          child: Image.asset(
            'assets/images/parking.png', // Assuming you have a stop icon
            fit: BoxFit.contain,
          ),
        ),
      );
    }
  }

  Future<void> _animateToPosition(LatLng position) async {
    // Uses FlutterMap's move method
    _mapController.move(position, 16);
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Check for cache initialization
    if (!_isCacheInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text('Loading Map...'.tr)),
        body: const Center(child: Text('Initializing Map Assets...')),
      );
    }

    if (_stopsReport.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${'reportStops'.tr}: ${_deviceName ?? ''}'),
        ),
        body: Center(
          child: Text('No data available for the selected period.'.tr),
        ),
      );
    }

    // Determine the map's initial center (LatLng from latlong2)
    final LatLng initialCenter = _stopsReport.isNotEmpty
        ? LatLng(_stopsReport.first.latitude, _stopsReport.first.longitude)
        : const LatLng(21.9162, 95.9560); // Mandalay, Myanmar

    return Scaffold(
      appBar: AppBar(title: Text('${'reportStops'.tr}: ${_deviceName ?? ''}')),
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
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
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
                        _currentMapType =
                            _currentMapType == AppMapType.openStreetMap
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
              itemCount: _stopsReport.length,
              itemBuilder: (context, index) {
                final stop = _stopsReport[index];
                return GestureDetector(
                  onTap: () {
                    // Animate to stop position
                    _animateToPosition(LatLng(stop.latitude, stop.longitude));
                    // Removed Google Maps specific showInfoWindowForMarker
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
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            title: Text('reportStartDate'.tr),
                            trailing: Text(
                              DateFormat(
                                'yyyy-MM-dd HH:mm',
                              ).format(stop.startTime.toLocal()),
                            ),
                          ),
                          ListTile(
                            title: Text('reportEndTime'.tr),
                            trailing: Text(
                              DateFormat(
                                'yyyy-MM-dd HH:mm',
                              ).format(stop.endTime.toLocal()),
                            ),
                          ),
                          ListTile(
                            title: Text('reportDuration'.tr),
                            trailing: Text(_formatDuration(stop.duration)),
                          ),
                          ListTile(
                            title: Text('positionAddress'.tr),
                            trailing: Text(
                              stop.address ?? 'Address not available'.tr,
                            ),
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
