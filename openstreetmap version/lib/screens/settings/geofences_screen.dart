// geofences_screen.dart (Refactored to use FlutterMap, Hive Caching, and simplified latlong2 import)
// A screen to display and manage geofences in the TracDefg app.
import 'package:flutter/material.dart';
import 'dart:collection';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:get/get.dart';

// --- Imports and Definitions for FlutterMap and Caching (from map_screen.dart) ---

import 'package:flutter_map/flutter_map.dart'; // Primary map package
import 'package:latlong2/latlong.dart'; // <-- FIXED: Removed 'as latlong;' alias
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'dart:ui' as ui; 
import 'package:flutter/foundation.dart';

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

class GeofencesScreen extends StatefulWidget {
  const GeofencesScreen({super.key});

  @override
  _GeofencesScreenState createState() => _GeofencesScreenState();
}

class _GeofencesScreenState extends State<GeofencesScreen> {
  late Future<List<api.Geofence>> _geofencesFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _geofencesFuture = _fetchGeofences();
  }

  Future<List<api.Geofence>> _fetchGeofences() async {
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final geofencesApi = api.GeofencesApi(traccarProvider.apiClient);
    final geofences = await geofencesApi.geofencesGet();
    return geofences ?? [];
  }

  void _deleteGeofence(int geofenceId) async {
    try {
      final traccarProvider = Provider.of<TraccarProvider>(
        context,
        listen: false,
      );
      final geofencesApi = api.GeofencesApi(traccarProvider.apiClient);
      await geofencesApi.geofencesIdDelete(geofenceId);
      setState(() {
        _geofencesFuture = _fetchGeofences();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('sharedRemoveConfirm'.tr)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete geofence: $e')));
    }
  }

  void _editGeofence(api.Geofence geofence) async {
    final updatedGeofence = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddGeofenceScreen(geofence: geofence),
      ),
    );

    if (updatedGeofence != null) {
      try {
        final traccarProvider = Provider.of<TraccarProvider>(
          context,
          listen: false,
        );
        final geofencesApi = api.GeofencesApi(traccarProvider.apiClient);
        // Correct API method is PUT for update
        await geofencesApi.geofencesIdPut(updatedGeofence.id!, updatedGeofence); 
        setState(() {
          _geofencesFuture = _fetchGeofences();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('sharedSaved'.tr)));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update geofence: $e')),
        );
      }
    }
  }

  String _getGeofenceDetails(api.Geofence geofence) {
    final area = geofence.area;
    if (area == null || area.isEmpty) return 'sharedNoData'.tr;
    if (area.startsWith('CIRCLE')) {
      try {
        final parts = area
            .substring(area.indexOf('(') + 1, area.indexOf(')'))
            .split(' ');
        final radius = double.tryParse(parts[2]) ?? 0.0;
        return 'Circle: ${radius.round()}m';
      } catch (e) {
        return 'Circle: Invalid format';
      }
    } else if (area.startsWith('POLYGON')) {
      try {
        final content = area.substring(
          area.indexOf('((') + 2,
          area.lastIndexOf('))'),
        );
        final points = content.split(',');
        return 'Polygon: ${points.length} points';
      } catch (e) {
        return 'Polygon: Invalid format';
      }
    }
    return 'sharedType'.tr + ' ' + 'Unknown Type';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('sharedGeofences'.tr)),
      body: FutureBuilder<List<api.Geofence>>(
        future: _geofencesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('errorGeneral'.tr + ': ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('sharedNoData'.tr));
          } else {
            final geofences = snapshot.data!;
            return ListView.builder(
              itemCount: geofences.length,
              itemBuilder: (context, index) {
                final geofence = geofences[index];
                final details = _getGeofenceDetails(geofence);
                return ListTile(
                  title: Text(geofence.name ?? 'sharedNoData'.tr),
                  subtitle: Text(details),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editGeofence(geofence),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteGeofence(geofence.id!),
                      ),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newGeofence = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddGeofenceScreen()),
          );

          if (newGeofence != null) {
            try {
              final traccarProvider = Provider.of<TraccarProvider>(
                context,
                listen: false,
              );
              final geofencesApi = api.GeofencesApi(traccarProvider.apiClient);
              await geofencesApi.geofencesPost(newGeofence);
              setState(() {
                _geofencesFuture = _fetchGeofences();
              });
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('sharedSaved'.tr)));
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to add geofence: $e')),
              );
            }
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddGeofenceScreen extends StatefulWidget {
  final api.Geofence? geofence;

  const AddGeofenceScreen({super.key, this.geofence});

  @override
  _AddGeofenceScreenState createState() => _AddGeofenceScreenState();
}

class _AddGeofenceScreenState extends State<AddGeofenceScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late double _radius;
  late String _geofenceType;
  LatLng? _circleCenter; // <-- FIXED: Changed to LatLng
  List<LatLng> _polygonPoints = []; // <-- FIXED: Changed to LatLng
  AppMapType _mapType = AppMapType.openStreetMap; // Default to OSM

  final List<CircleMarker> _circles = [];
  final List<Polygon> _polygons = [];
  final List<Marker> _polygonMarkers = [];

  late MapController _mapController;
  static final LatLng _center = LatLng(37.7749, -122.4194); // <-- FIXED: Changed to LatLng

  final _TileCacheService _cacheService = _TileCacheService();
  final http.Client _httpClient = http.Client();
  late _HiveTileProvider _tileProvider;
  bool _isCacheInitialized = false;

  // --- Tile URLs from map_screen.dart ---
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

    if (widget.geofence != null) {
      _name = widget.geofence!.name!;
      final area = widget.geofence!.area;
      if (area != null) {
        if (area.startsWith('CIRCLE')) {
          _geofenceType = 'CIRCLE';
          try {
            // Parses "CIRCLE(lat lon radius)"
            final parts = area
                .substring(area.indexOf('(') + 1, area.indexOf(')'))
                .split(' ');
            _circleCenter = LatLng( // <-- FIXED: Changed to LatLng
              double.tryParse(parts[0]) ?? 0.0,
              double.tryParse(parts[1]) ?? 0.0,
            );
            final parsedRadius = double.tryParse(parts[2]);
            if (parsedRadius != null &&
                parsedRadius >= 10 &&
                parsedRadius <= 2000) {
              _radius = parsedRadius;
            } else {
              _radius = 10.0;
            }
          } catch (e) {
            _circleCenter = null;
            _radius = 10.0;
          }
        } else if (area.startsWith('POLYGON')) {
          _geofenceType = 'POLYGON';
          _radius = 0.0;
          try {
            // Parses "POLYGON((lat lon, lat lon, ...))"
            final content = area.substring(
              area.indexOf('((') + 2,
              area.lastIndexOf('))'),
            );
            final points = content.split(',').map((p) {
              final coords = p.trim().split(' ');
              return LatLng( // <-- FIXED: Changed to LatLng
                double.tryParse(coords[0]) ?? 0.0,
                double.tryParse(coords[1]) ?? 0.0,
              );
            }).toList();
            _polygonPoints = points;
          } catch (e) {
            _polygonPoints = [];
          }
        }
      } else {
        _geofenceType = 'CIRCLE';
        _radius = 10.0;
      }
    } else {
      _geofenceType = 'CIRCLE';
      _name = '';
      _radius = 10;
    }
    _updateShapes();
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  void _onMapReady() {
    // Ensure the camera moves to the geofence location after map is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_geofenceType == 'CIRCLE' && _circleCenter != null) {
        _mapController.move(_circleCenter!, 14.0);
      } else if (_geofenceType == 'POLYGON' && _polygonPoints.isNotEmpty) {
        
        // Calculate bounds for polygon zoom
        double minLat = _polygonPoints[0].latitude;
        double maxLat = _polygonPoints[0].latitude;
        double minLng = _polygonPoints[0].longitude;
        double maxLng = _polygonPoints[0].longitude;
        
        for (final point in _polygonPoints) {
          minLat = min(minLat, point.latitude);
          maxLat = max(maxLat, point.latitude);
          minLng = min(minLng, point.longitude);
          maxLng = max(maxLng, point.longitude);
        }
        
        final bounds = LatLngBounds( // <-- FIXED: Changed to LatLngBounds
          LatLng(minLat, minLng), // <-- FIXED: Changed to LatLng
          LatLng(maxLat, maxLng), // <-- FIXED: Changed to LatLng
        );
        
        // Fit bounds with a bit of padding (zoom level will be calculated)
        _mapController.fitCamera(CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ));

      } else {
        // Fallback to center
        _mapController.move(_center, 14.0);
      }
    });
  }

  void _onTap(TapPosition tapPosition, LatLng point) { // <-- FIXED: Changed to LatLng
    setState(() {
      if (_geofenceType == 'CIRCLE') {
        _circleCenter = point;
      } else {
        _polygonPoints.add(point);
      }
      _updateShapes();
    });
  }

  void _updateShapes() {
    _circles.clear();
    _polygons.clear();
    _polygonMarkers.clear();

    if (_geofenceType == 'CIRCLE' && _circleCenter != null) {
      _circles.add(
        CircleMarker(
          point: _circleCenter!,
          radius: _radius,
          color: Colors.blue.withOpacity(0.3),
          borderColor: Colors.blue,
          borderStrokeWidth: 2,
        ),
      );
    } else if (_geofenceType == 'POLYGON' && _polygonPoints.isNotEmpty) {
      _polygons.add(
        Polygon(
          points: _polygonPoints,
          color: Colors.green.withOpacity(0.3),
          borderColor: Colors.green,
          borderStrokeWidth: 2,
        ),
      );
      for (int i = 0; i < _polygonPoints.length; i++) {
        _polygonMarkers.add(
          Marker(
            point: _polygonPoints[i],
            width: 30,
            height: 30,
            child: const Icon(Icons.location_on, color: Colors.red),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wait for the cache and tile provider to initialize
    if (!_isCacheInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text('Loading Map...'.tr)),
        body: const Center(child: Text('Initializing Map Assets...')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.geofence == null
              ? 'sharedCreateGeofence'.tr
              : 'sharedEdit'.tr + ' ' + 'sharedGeofence'.tr,
        ),
        actions: [
          // Map type toggle logic
          IconButton(
            icon: Icon(
              _mapType == AppMapType.satellite ? Icons.map : Icons.satellite
            ),
            onPressed: () {
              setState(() {
                _mapType = _mapType == AppMapType.satellite
                    ? AppMapType.openStreetMap // Switch to OSM (normal)
                    : AppMapType.satellite; // Switch to Satellite
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              if (_formKey.currentState!.validate() &&
                  ((_geofenceType == 'CIRCLE' && _circleCenter != null) ||
                      (_geofenceType == 'POLYGON' &&
                          _polygonPoints.length >= 3))) {
                _formKey.currentState!.save();
                final String area;
                if (_geofenceType == 'CIRCLE') {
                  area =
                      'CIRCLE(${_circleCenter!.latitude} ${_circleCenter!.longitude} $_radius)';
                } else {
                  final pointsString = _polygonPoints
                      .map((p) => '${p.latitude} ${p.longitude}')
                      .join(', ');
                  // Traccar requires the polygon to be closed, so the first point must be repeated at the end.
                  final closedPointsString = '$pointsString, ${_polygonPoints.first.latitude} ${_polygonPoints.first.longitude}'; 

                  area = 'POLYGON(($closedPointsString))';
                }

                final geofence = api.Geofence(
                  id: widget.geofence?.id,
                  name: _name,
                  area: area,
                );
                Navigator.pop(context, geofence);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _geofenceType == 'CIRCLE'
                          ? 'Please enter a name and select a point on the map.'
                                .tr
                          : 'Please enter a name and draw a polygon with at least 3 points.'
                                .tr,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  initialValue: _name,
                  decoration: InputDecoration(labelText: 'sharedName'.tr),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _name = value!;
                  },
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _geofenceType,
                  decoration: InputDecoration(labelText: 'sharedType'.tr),
                  items: [
                    DropdownMenuItem(
                      value: 'CIRCLE',
                      child: Text('mapShapeCircle'.tr),
                    ),
                    DropdownMenuItem(
                      value: 'POLYGON',
                      child: Text('mapShapePolygon'.tr),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _geofenceType = value!;
                      _polygonPoints.clear(); // Clear points when changing type
                      _circleCenter = null; 
                      _updateShapes();
                    });
                  },
                ),
                const SizedBox(height: 20),
                if (_geofenceType == 'CIRCLE')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${'commandRadius'.tr}: ${_radius.round()} ${'sharedMeters'.tr}',
                      ),
                      Slider(
                        value: _radius,
                        min: 10,
                        max: 2000,
                        divisions: 199,
                        label: _radius.round().toString(),
                        onChanged: (double value) {
                          setState(() {
                            _radius = value;
                            _updateShapes();
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      Text('mapShapeCircle'.tr + (_circleCenter == null ? ' (Tap map to select center)' : '')),
                    ],
                  ),
                if (_geofenceType == 'POLYGON')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('mapShapePolygon'.tr + ': ${_polygonPoints.length} points'),
                      const SizedBox(height: 10),
                      Text('TapMapAddPolygon'.tr),
                      if (_polygonPoints.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.clear, size: 18),
                            label: Text('Clear Points'.tr),
                            onPressed: () {
                              setState(() {
                                _polygonPoints.clear();
                                _updateShapes();
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 10),
                // --- FlutterMap Implementation ---
                SizedBox(
                  height: 400,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      // Use a safe initial center for MapOptions
                      initialCenter: _circleCenter ?? _polygonPoints.firstOrNull ?? _center,
                      initialZoom: 14.0,
                      interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                      onTap: _onTap,
                      onMapReady: _onMapReady, // Custom callback for initial positioning
                    ),
                    children: [
                      // Tile Layer: Conditional based on map type (OSM/Satellite)
                      TileLayer(
                        urlTemplate: _mapType == AppMapType.openStreetMap
                            ? _osmUrlTemplate
                            : _satelliteUrlTemplate,
                        subdomains: _mapType == AppMapType.openStreetMap
                            ? _osmSubdomains
                            : const [],
                        userAgentPackageName: 'com.trabcdefg.app',
                        tileProvider: _tileProvider, // Hive Caching
                      ),
                      
                      // Circle Layer (Equivalent to GoogleMap Circle)
                      CircleLayer(circles: _circles),
                      
                      // Polygon Layer (Equivalent to GoogleMap Polygon)
                      PolygonLayer(polygons: _polygons),

                      // Marker Layer (For polygon points)
                      MarkerLayer(markers: _polygonMarkers),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}