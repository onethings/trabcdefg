// lib/screens/livetracking_map_screen.dart
// LiveTrackingMapScreen with OpenStreetMap and Tile Caching

import 'dart:async';
import 'package:flutter/material.dart';
// REMOVED: import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart'; // Primary map package for OpenStreetMap
import 'package:latlong2/latlong.dart' as latlong; // LatLong for FlutterMap coordinates
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
// REMOVED: import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'dart:typed_data';
import 'package:hive/hive.dart'; // For Caching
import 'package:http/http.dart' as http; // For Caching
import 'dart:math'; // Required for math operations like pi/radians in marker rotation

// ADDED: Enum for managing map types
enum AppMapType {
  openStreetMap,
  satellite,
}

// --- Tile Caching Implementation using Hive ---

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

// Custom TileProvider to integrate Hive caching with FlutterMap
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

// Custom ImageProvider to handle the cache/network logic
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

    // 1. Check Cache
    final cachedData = await cacheService.getTile(url);

    if (cachedData != null) {
      // Load from cache
      return decode(await ImmutableBuffer.fromUint8List(cachedData));
    }

    // 2. Fetch from Network
    try {
      final response = await httpClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;

        // 3. Save to Cache
        await cacheService.saveTile(url, bytes);

        // Load from fetched bytes
        return decode(await ImmutableBuffer.fromUint8List(bytes));
      } else {
        throw Exception(
            'Failed to load tile from network: ${response.statusCode}');
      }
    } catch (e) {
      // If network fails, rethrow, or you could try a local fallback tile.
      rethrow;
    }
  }
}

// --- End of Tile Caching Implementation ---

class LiveTrackingMapScreen extends StatefulWidget {
  final Device selectedDevice;
  const LiveTrackingMapScreen({super.key, required this.selectedDevice});

  @override
  State<LiveTrackingMapScreen> createState() => _LiveTrackingMapScreenState();
}

class _LiveTrackingMapScreenState extends State<LiveTrackingMapScreen> {
  final MapController _flutterMapController = MapController();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<latlong.LatLng> _polylineCoordinates = [];
  AppMapType _mapType = AppMapType.openStreetMap;

  // FIXED: Declared missing member variable
  Position? _currentDevicePosition; 
  
  bool _isCameraLocked = true;

  // Placeholder for marker icon loading state
  bool _customIconsLoaded = false;

  // Caching variables
  final _TileCacheService _cacheService = _TileCacheService();
  final http.Client _httpClient = http.Client();
  late _HiveTileProvider _tileProvider;
  bool _isCacheInitialized = false;

  // --- Tile URLs for different map types ---
  static const String _osmUrlTemplate =
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _satelliteUrlTemplate =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const List<String> _osmSubdomains = ['a', 'b', 'c'];


  @override
  void initState() {
    super.initState();

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

    _loadMarkerIcons(); // Re-called to set the flag

    // Initial position lookup
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    // This line initializes the variable that was causing the error
    _currentDevicePosition = traccarProvider.positions.firstWhere(
      (pos) => pos.deviceId == widget.selectedDevice.id,
      orElse: () => Position(),
    );
  }

  @override
  void didUpdateWidget(covariant LiveTrackingMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );

    final newPosition = traccarProvider.positions.firstWhere(
      (pos) => pos.deviceId == widget.selectedDevice.id,
      orElse: () => Position(),
    );

    // Only update the map if the position data has actually changed
    if (newPosition.id != _currentDevicePosition?.id) {
      _currentDevicePosition = newPosition;
      _updateMap(newPosition);
    }
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  // REINTRODUCED/MODIFIED: Marker icon loading logic
  Future<void> _loadMarkerIcons() async {
    // In a FlutterMap context, this method usually ensures all asset paths
    // are known or performs pre-caching if needed. Here, we just set the flag
    // to signal the assets are ready for use via Image.asset.
    await Future.delayed(Duration.zero); // Simulate an async load operation

    if (mounted) {
      setState(() {
        _customIconsLoaded = true;
      });
    }
  }

  String _getTranslatedStatus(String? status) {
    if (status == null) return 'N/A';

    switch (status.toLowerCase()) {
      case 'online':
        return 'deviceStatusOnline'.tr;
      case 'offline':
        return 'deviceStatusOffline'.tr;
      case 'idle':
        return 'alarmIdle'.tr;
      case 'static':
        return 'alarmParking'.tr;
      case 'unknown':
      default:
        return 'deviceStatusUnknown'.tr;
    }
  }

  void _updateMap(Position? currentPosition) {
    // Ensure all prerequisites are met before attempting to update the map
    if (!_isCacheInitialized ||
        !_customIconsLoaded || // Check the icon loading flag
        currentPosition == null ||
        currentPosition.latitude == null ||
        currentPosition.longitude == null) {
      return;
    }

    final newPosition = latlong.LatLng(
      currentPosition.latitude!.toDouble(),
      currentPosition.longitude!.toDouble(),
    );

    setState(() {
      _markers.clear();

      // Add new position to polyline if different from the last point
      if (_polylineCoordinates.isEmpty ||
          _polylineCoordinates.last != newPosition) {
        _polylineCoordinates.add(newPosition);
      }

      final String category = widget.selectedDevice.category ?? 'default';
      final String status = widget.selectedDevice.status ?? 'unknown';
      final double course = currentPosition.course?.toDouble() ?? 0.0;

      // Flutter Map Marker Implementation using Image.asset
      _markers.add(
        Marker(
          width: 50.0,
          height: 50.0,
          point: newPosition,
          // Marker rotation using Transform.rotate
          child: Transform.rotate(
            angle: course * (pi / 180),
            child: Tooltip(
              message: widget.selectedDevice.name ?? 'Device Location',
              child: Image.asset(
                'assets/images/marker_${category}_$status.png',
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.location_on),
              ),
            ),
          ),
        ),
      );

      _polylines.clear(); // Clear old polyline set
      _polylines.add(
        Polyline(
          points: _polylineCoordinates,
          color: Colors.blue,
          strokeWidth: 5,
        ),
      );
    });

    if (_isCameraLocked) {
      // Use MapController to move the map
      _flutterMapController.move(newPosition, _flutterMapController.camera.zoom);
    }
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == AppMapType.openStreetMap
          ? AppMapType.satellite
          : AppMapType.openStreetMap;
    });
  }

  Future<void> _recenter(Position? lastPosition) async {
    if (lastPosition == null ||
        lastPosition.latitude == null ||
        lastPosition.longitude == null) {
      return;
    }

    final position = latlong.LatLng(
      lastPosition.latitude!.toDouble(),
      lastPosition.longitude!.toDouble(),
    );

    setState(() {
      _isCameraLocked = true;
    });

    // Use MapController to move
    _flutterMapController.move(position, 17.0);
  }

  void _zoomIn() {
    // Use MapController to adjust zoom
    final currentZoom = _flutterMapController.camera.zoom;
    _flutterMapController.move(
      _flutterMapController.camera.center,
      currentZoom + 1.0,
    );
  }

  void _zoomOut() {
    // Use MapController to adjust zoom
    final currentZoom = _flutterMapController.camera.zoom;
    _flutterMapController.move(
      _flutterMapController.camera.center,
      currentZoom - 1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selectedDevice.name ?? 'mapLiveRoutes'.tr,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _mapType == AppMapType.satellite ? Icons.map : Icons.satellite,
            ),
            onPressed: _toggleMapType,
          ),
        ],
      ),
      body: Consumer<TraccarProvider>(
        builder: (context, traccarProvider, child) {
          final lastPosition = traccarProvider.positions.firstWhere(
            (pos) => pos.deviceId == widget.selectedDevice.id,
            orElse: () => Position(),
          );

          // Handle initial position
          latlong.LatLng initialLatLng = const latlong.LatLng(0, 0);
          if (lastPosition.latitude != null && lastPosition.longitude != null) {
            initialLatLng = latlong.LatLng(
              lastPosition.latitude!.toDouble(),
              lastPosition.longitude!.toDouble(),
            );
          }

          // Show loading spinner if cache, icons, or initial data is not ready
          if (!_isCacheInitialized ||
              !_customIconsLoaded ||
              (traccarProvider.isLoading && _polylineCoordinates.isEmpty)) {
            return const Center(child: CircularProgressIndicator());
          }

          // Force an initial update call in case state was ready but build was called first
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateMap(lastPosition);
          });


          return Stack(
            children: [
              // REPLACED: GoogleMap with FlutterMap
              FlutterMap(
                mapController: _flutterMapController,
                options: MapOptions(
                  initialCenter: initialLatLng,
                  initialZoom: 14.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture) {
                      setState(() {
                        _isCameraLocked = false;
                      });
                    }
                  },
                  onTap: (tapPosition, latLng) {
                    // Optionally close a bottom sheet if one were present
                  },
                ),
                children: [
                  // Tile Layer with Caching
                  TileLayer(
                    urlTemplate: _mapType == AppMapType.openStreetMap
                        ? _osmUrlTemplate
                        : _satelliteUrlTemplate,
                    subdomains: _mapType == AppMapType.openStreetMap
                        ? _osmSubdomains
                        : const [],
                    userAgentPackageName: 'com.trabcdefg.app',
                    tileProvider: _tileProvider, // Use the custom cached provider
                  ),
                  // Polyline Layer for routes
                  PolylineLayer(polylines: _polylines.toList()),
                  // Marker Layer for device position
                  MarkerLayer(markers: _markers.toList()),
                ],
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: Column(
                  children: [
                    FloatingActionButton(
                      heroTag: "zoomIn",
                      mini: true,
                      onPressed: _zoomIn,
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: "zoomOut",
                      mini: true,
                      onPressed: _zoomOut,
                      child: const Icon(Icons.remove),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: "recenter",
                      mini: true,
                      onPressed: () => _recenter(lastPosition),
                      child: const Icon(Icons.my_location),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomSheet: _buildBottomSheet(context),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    return Consumer<TraccarProvider>(
      builder: (context, provider, child) {
        final lastPosition = provider.positions.firstWhere(
          (pos) => pos.deviceId == widget.selectedDevice.id,
          orElse: () => Position(),
        );
        // Traccar speed is in knots (nautical miles per hour). 1 knot = 1.852 km/h
        final speedKmh = lastPosition.speed != null
            ? (lastPosition.speed!.toDouble() * 1.852).toStringAsFixed(2)
            : 'N/A';
        final attributes =
            lastPosition.attributes as Map<String, dynamic>? ?? {};
        final translatedStatus = _getTranslatedStatus(
          widget.selectedDevice.status,
        );

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                offset: Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.selectedDevice.name ?? 'Unknown Device',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8.0),
              Text('deviceStatus'.tr + ': $translatedStatus'),
              const SizedBox(height: 4.0),
              Text(
                'deviceLastUpdate'.tr +
                    ': ${lastPosition.deviceTime?.toLocal() ?? 'N/A'}',
              ),
              Text('positionSpeed'.tr + ': $speedKmh ' + 'sharedKmh'.tr),
              const Divider(),
              Text(
                'deviceSecondaryInfo'.tr + ':',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (attributes.containsKey('batteryLevel'))
                ListTile(
                  leading: const Icon(Icons.battery_std),
                  title: Text('positionBatteryLevel'.tr),
                  subtitle: Text('${attributes['batteryLevel']}%'),
                ),
              if (attributes.containsKey('totalDistance'))
                ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: Text('deviceTotalDistance'.tr),
                  subtitle: Text(
                    // Check for num type and safely convert
                    '${((attributes['totalDistance'] is num ? attributes['totalDistance'] : 0.0) / 1000).toStringAsFixed(2)} ' +
                        'sharedKm'.tr,
                  ),
                ),
              if (attributes.containsKey('engineHours'))
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: Text('reportEngineHours'.tr),
                  subtitle: Text(
                    // Check for num type and safely convert
                    '${((attributes['engineHours'] is num ? attributes['engineHours'] : 0.0) / 3600).toStringAsFixed(2)} ' +
                        'sharedHourAbbreviation'.tr,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}