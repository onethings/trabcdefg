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
import 'package:http/http.dart' as http;
// import 'package:google_maps_flutter/google_maps_flutter.dart'; // REMOVED
import 'package:flutter_map/flutter_map.dart'; // ADDED
import 'package:latlong2/latlong.dart'; // FIXED: Un-aliased import
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart'; // ADDED
import 'dart:typed_data'; // ADDED
import 'package:flutter/foundation.dart'; // ADDED for DiagnosticsProperty

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
  // final Completer<GoogleMapController> _controller = Completer(); // REMOVED
  late MapController _mapController; // ADDED
  final List<Marker> _markers = []; // Changed to FlutterMap Marker list
  final List<Polyline> _polylines = []; // Changed to FlutterMap Polyline list
  // late BitmapDescriptor _startIcon; // REMOVED
  // late BitmapDescriptor _endIcon; // REMOVED
  AppMapType _currentMapType = AppMapType.openStreetMap; // Changed to AppMapType

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

    _fetchTripsReport();
  }

  @override
  void dispose() {
    _httpClient.close(); // Dispose HTTP client
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
      // Changed to latlong2 LatLng (un-aliased)
      final LatLng startPoint = LatLng(trip.startLat, trip.startLon);
      final LatLng endPoint = LatLng(trip.endLat, trip.endLon);

      // FlutterMap Marker for Start Point
      _markers.add(
        Marker(
          point: startPoint,
          width: 30.0,
          height: 30.0,
          child: Image.asset(
            'assets/images/start.png',
            fit: BoxFit.contain,
          ),
        ),
      );

      // FlutterMap Marker for End Point
      _markers.add(
        Marker(
          point: endPoint,
          width: 30.0,
          height: 30.0,
          child: Image.asset(
            'assets/images/destination.png',
            fit: BoxFit.contain,
          ),
        ),
      );

      // FlutterMap Polyline
      _polylines.add(
        Polyline(
          points: [startPoint, endPoint],
          color: Colors.blue,
          strokeWidth: 5.0,
        ),
      );
    }
  }

  Future<void> _animateToPosition(LatLng position) async {
    // Uses FlutterMap's move method
    _mapController.move(
      position,
      16,
    );
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    // Check for cache initialization
    if (!_isCacheInitialized) { 
       return Scaffold(
        appBar: AppBar(title: Text('Loading Map...'.tr)),
        body: const Center(child: Text('Initializing Map Assets...')),
      );
    }

    if (_tripsReport.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${'reportTrips'.tr}: ${_deviceName ?? ''}')),
        body: Center(
          child: Text('No data available for the selected period.'.tr),
        ),
      );
    }
    
    // Determine the map's initial center (latlong2 LatLng)
    final LatLng initialCenter = _tripsReport.isNotEmpty
        ? LatLng(_tripsReport.first.startLat, _tripsReport.first.startLon)
        : const LatLng(21.9162, 95.9560); // Mandalay, Myanmar

    return Scaffold(
      appBar: AppBar(title: Text('${'reportTrips'.tr}: ${_deviceName ?? ''}')),
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
              itemCount: _tripsReport.length,
              itemBuilder: (context, index) {
                final trip = _tripsReport[index];
                return GestureDetector(
                  onTap: () {
                    // Animate to start position
                    _animateToPosition(LatLng(trip.startLat, trip.startLon));
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