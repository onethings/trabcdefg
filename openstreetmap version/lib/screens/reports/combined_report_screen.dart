// lib/screens/reports/combined_report_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart'; // REMOVED
import 'package:flutter_map/flutter_map.dart'; // ADDED
import 'package:latlong2/latlong.dart'; // ADDED (No alias as requested)
import 'package:provider/provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'package:get/get.dart';
import 'package:http/http.dart' as http; // ADDED for caching
import 'package:hive/hive.dart'; // ADDED for caching
import 'dart:typed_data'; // ADDED for caching
import 'package:flutter/foundation.dart'; // ADDED for caching

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
  // final Completer<GoogleMapController> _controller = Completer(); // REMOVED
  late MapController _mapController; // ADDED
  CombinedReport? _combinedReport;
  bool _isLoading = true;
  // Set to List for FlutterMap compatibility
  final List<Polyline> _polylines = []; 
  final List<Marker> _markers = []; 
  String? _deviceName;

  // Icons are now asset paths/widgets, not BitmapDescriptors
  // late BitmapDescriptor _ignitionOnIcon; // REMOVED
  // late BitmapDescriptor _ignitionOffIcon; // REMOVED
  static const String _ignitionOnIconPath = 'assets/images/accon.png'; // ADDED
  static const String _ignitionOffIconPath = 'assets/images/accoff.png'; // ADDED

  Map<int, api.Position> _positionsMap = {};
  // Replace MapType with AppMapType
  AppMapType _currentMapType = AppMapType.openStreetMap; // CHANGED

  // Caching variables
  final _TileCacheService _cacheService = _TileCacheService(); // ADDED
  final http.Client _httpClient = http.Client(); // ADDED
  late _HiveTileProvider _tileProvider; // ADDED
  bool _isCacheInitialized = false; // ADDED

  // Tile URLs
  static const String _osmUrlTemplate = 
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _satelliteUrlTemplate = 
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const List<String> _osmSubdomains = ['a', 'b', 'c'];


  @override
  void initState() {
    super.initState();
    _mapController = MapController(); // ADDED initialization

    // Initialize cache service and then the tile provider
    _cacheService.init().then((_) {
      if (mounted) { 
        _tileProvider = _HiveTileProvider(
          cacheService: _cacheService,
          httpClient: _httpClient,
        );
        setState(() {
          _isCacheInitialized = true; // Set flag when initialization is complete
        });
      }
    });

    _loadMarkerIcons();
    _fetchCombinedReport();
  }
  
  @override
  void dispose() {
    _httpClient.close(); // Dispose of http client
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
          // Convert Traccar format [lon, lat] to LatLng(lat, lon)
          .map((coord) => LatLng(coord[1], coord[0]))
          .toList();

      if (routePoints.isNotEmpty) {
        // Use FlutterMap Polyline
        _polylines.add(
          Polyline(
            points: routePoints,
            color: Colors.blue,
            strokeWidth: 4,
          ),
        );

        // Add start marker (uses Image.asset in child)
        _markers.add(
          Marker(
            point: routePoints.first,
            width: 30.0,
            height: 30.0,
            child: Image.asset(
              'assets/images/start.png',
              fit: BoxFit.contain,
            ),
          ),
        );

        // Add end marker (uses Image.asset in child)
        _markers.add(
          Marker(
            point: routePoints.last,
            width: 30.0,
            height: 30.0,
            child: Image.asset(
              'assets/images/destination.png',
              fit: BoxFit.contain,
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
          String iconPath;
          switch (event.type) {
            case 'ignitionOn':
              iconPath = _ignitionOnIconPath; // Use string path
              break;
            case 'ignitionOff':
              iconPath = _ignitionOffIconPath; // Use string path
              break;
            default:
              iconPath = 'assets/images/event_default.png'; // Generic icon
              break;
          }

          final String markerId = 'event_marker_${event.id}';
          
          // Use FlutterMap Marker
          _markers.add(
            Marker(
              point: LatLng(
                position.latitude!.toDouble(),
                position.longitude!.toDouble(),
              ),
              width: 30.0,
              height: 30.0,
              key: Key(markerId), 
              child: Image.asset(
                iconPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.warning, color: Colors.yellow),
              ),
            ),
          );
        }
      }
    }

    setState(() {});
  }

  // Future<void> _showInfoWindowForMarker(MarkerId markerId) async { ... } // REMOVED

  Future<void> _animateToPosition(LatLng latLng) async {
    _mapController.move(
      latLng,
      15,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: Text('sharedLoading'.tr)));
    }

    // Check for cache initialization
    if (!_isCacheInitialized) { 
      return Scaffold(
        appBar: AppBar(title: Text('Loading Map...'.tr)),
        body: const Center(child: Text('Initializing Map Assets...')),
      );
    }

    if (_combinedReport == null ||
        (_combinedReport!.positions.isEmpty &&
            (_combinedReport!.route == null || _combinedReport!.route!.isEmpty))) {
      return Scaffold(
        appBar: AppBar(title: Text(_deviceName ?? 'reportCombinedReport'.tr)),
        body: Center(child: Text('sharedNoData'.tr)),
      );
    }
    
    // Determine initial center for FlutterMap
    final LatLng initialCenter = (_combinedReport!.route != null && _combinedReport!.route!.isNotEmpty)
        ? LatLng(_combinedReport!.route!.first[1], _combinedReport!.route!.first[0])
        : const LatLng(0, 0);

    return Scaffold(
      appBar: AppBar(title: Text(_deviceName ?? 'reportCombinedReport'.tr)),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                // Replace GoogleMap with FlutterMap
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: 13,
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
                // Map Type Toggle Button (updated for AppMapType)
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
                            // Removed temporary marker and info window logic
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
                          // Removed _showInfoWindowForMarker call
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