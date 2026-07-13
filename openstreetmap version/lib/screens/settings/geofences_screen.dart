// geofences_screen.dart (Refactored to use FlutterMap, Hive Caching, and simplified latlong2 import)
// A screen to display and manage geofences in the TracDefg app.
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// --- Imports and Definitions for FlutterMap and Caching (from map_screen.dart) ---

import 'package:flutter_map/flutter_map.dart'; // Primary map package
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart'; // <-- FIXED: Removed 'as latlong;' alias
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

// --- Tile Caching Implementation using Hive (Copied from map_screen.dart) ---

class TileCacheService {
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
  final TileCacheService cacheService;
  final http.Client httpClient;

  CachedNetworkImageProvider(this.url, {required this.cacheService, required this.httpClient});

  @override
  ImageStreamCompleter loadImage(CachedNetworkImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      informationCollector: () => <DiagnosticsNode>[DiagnosticsProperty<ImageProvider>('Image provider', this), DiagnosticsProperty<CachedNetworkImageProvider>('Original key', key)],
    );
  }

  @override
  Future<CachedNetworkImageProvider> obtainKey(ImageConfiguration configuration) {
    return Future<CachedNetworkImageProvider>.value(this);
  }

  Future<ui.Codec> _loadAsync(CachedNetworkImageProvider key, ImageDecoderCallback decode) async {
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

class HiveTileProvider extends TileProvider {
  final TileCacheService cacheService;
  final http.Client httpClient;

  HiveTileProvider({required this.cacheService, required this.httpClient});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(getTileUrl(coordinates, options), cacheService: cacheService, httpClient: httpClient);
  }
}

enum AppMapType { openStreetMap, satellite }

// --- End of Map Caching & FlutterMap Imports/Definitions ---

class GeofencesScreen extends StatefulWidget {
  const GeofencesScreen({super.key});

  @override
  GeofencesScreenState createState() => GeofencesScreenState();
}

class GeofencesScreenState extends State<GeofencesScreen> {
  late Future<List<api.Geofence>> _geofencesFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _geofencesFuture = _fetchGeofences();
  }

  Future<List<api.Geofence>> _fetchGeofences() async {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    final geofencesApi = api.GeofencesApi(traccarProvider.apiClient);
    final geofences = await geofencesApi.getGeofences();
    return geofences ?? [];
  }

  void _deleteGeofence(int geofenceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('sharedRemoveConfirm'.tr),
        content: Text('Are you sure you want to delete this geofence?'.tr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('sharedCancel'.tr)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('sharedRemove'.tr)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
      final response = await traccarProvider.apiClient.invokeAPI('/geofences/$geofenceId', 'DELETE', [], null, {'Accept': 'application/json'}, {}, 'application/json');
      debugPrint('Delete geofence $geofenceId: status=${response.statusCode}');

      if (response.statusCode >= 400) {
        throw Exception('Server returned ${response.statusCode}');
      }

      if (!mounted) return;
      setState(() {
        _geofencesFuture = _fetchGeofences();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('sharedRemoveConfirm'.tr)));
    } catch (e) {
      debugPrint('Delete geofence error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete geofence: $e')));
    }
  }

  void _editGeofence(api.Geofence geofence) async {
    final updatedGeofence = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddGeofenceScreen(geofence: geofence)));

    if (updatedGeofence != null) {
      if (!mounted) {
        return;
      }
      try {
        final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
        final geofencesApi = api.GeofencesApi(traccarProvider.apiClient);
        await geofencesApi.putGeofencesId(updatedGeofence.id!, updatedGeofence);

        if (!mounted) {
          return;
        }
        setState(() {
          _geofencesFuture = _fetchGeofences();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('sharedSaved'.tr)));
      } catch (e) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update geofence: $e')));
      }
    }
  }

  String _getGeofenceDetails(api.Geofence geofence) {
    final area = geofence.area;
    if (area == null || area.isEmpty) return 'sharedNoData'.tr;
    if (area.startsWith('CIRCLE')) {
      try {
        final parts = area.substring(area.indexOf('(') + 1, area.indexOf(')')).split(' ');
        final radius = double.tryParse(parts[2]) ?? 0.0;
        return 'Circle: ${radius.round()}m';
      } catch (e) {
        return 'Circle: Invalid format';
      }
    } else if (area.startsWith('POLYGON')) {
      try {
        final content = area.substring(area.indexOf('((') + 2, area.lastIndexOf('))'));
        final points = content.split(',');
        return 'Polygon: ${points.length} points';
      } catch (e) {
        return 'Polygon: Invalid format';
      }
    }
    return '${'sharedType'.tr} Unknown Type';
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
            return Center(child: Text('${'errorGeneral'.tr}: ${snapshot.error}'));
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
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _editGeofence(geofence)),
                      IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteGeofence(geofence.id!)),
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
          // 【核心修正】在任何 await 發生之前（完全同步的當下），把所有需要 context 的東西通通準備好！
          final navigator = Navigator.of(context);
          final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
          final messenger = ScaffoldMessenger.of(context);

          // 1. 進入第一個非同步：等待頁面回傳結果
          final newGeofence = await navigator.push(MaterialPageRoute(builder: (context) => const AddGeofenceScreen()));

          if (newGeofence != null) {
            // 2. 異步回來後，檢查組件是否還掛載著
            if (!mounted) return;

            try {
              final geofencesApi = api.GeofencesApi(traccarProvider.apiClient);

              // 3. 進入第二個非同步：打 API
              await geofencesApi.postGeofences(newGeofence);

              if (!mounted) return;
              setState(() {
                _geofencesFuture = _fetchGeofences();
              });

              // 4. 這裡直接使用最前面存好的 messenger，它完全不需要再存取 context 了
              messenger.showSnackBar(SnackBar(content: Text('sharedSaved'.tr)));
            } catch (e) {
              if (!mounted) return;

              // 5. 失敗時同理
              messenger.showSnackBar(SnackBar(content: Text('Failed to add geofence: $e')));
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
  AddGeofenceScreenState createState() => AddGeofenceScreenState();
}

class AddGeofenceScreenState extends State<AddGeofenceScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late double _radius;
  late String _geofenceType;
  LatLng? _circleCenter;
  List<LatLng> _polygonPoints = [];
  AppMapType _mapType = AppMapType.openStreetMap;

  final List<CircleMarker> _circles = [];
  final List<Polygon> _polygons = [];
  final List<Marker> _polygonMarkers = [];

  late MapController _mapController;
  static final LatLng _center = LatLng(37.7749, -122.4194);

  final TileCacheService _cacheService = TileCacheService();
  final http.Client _httpClient = http.Client();
  late HiveTileProvider _tileProvider;
  bool _isCacheInitialized = false;

  // --- Tile URLs ---
  static const String _osmUrlTemplate = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _satelliteUrlTemplate = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const List<String> _osmSubdomains = ['a', 'b', 'c'];

  // --- Geocoding search ---
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  // --- Polygon simplification ---
  double _simplifyFactor = 1.0; // 0.0 = most simplified, 1.0 = original
  List<LatLng> _simplifiedPoints = [];
  bool _showSimplified = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _cacheService.init().then((_) {
      _tileProvider = HiveTileProvider(cacheService: _cacheService, httpClient: _httpClient);
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
            final parts = area.substring(area.indexOf('(') + 1, area.indexOf(')')).split(' ');
            _circleCenter = LatLng(double.tryParse(parts[0]) ?? 0.0, double.tryParse(parts[1]) ?? 0.0);
            final parsedRadius = double.tryParse(parts[2]);
            _radius = (parsedRadius != null && parsedRadius >= 10 && parsedRadius <= 2000) ? parsedRadius : 100.0;
          } catch (e) {
            _circleCenter = null;
            _radius = 100.0;
          }
        } else if (area.startsWith('POLYGON')) {
          _geofenceType = 'POLYGON';
          _radius = 0.0;
          try {
            final content = area.substring(area.indexOf('((') + 2, area.lastIndexOf('))'));
            final points = content.split(',').map((p) {
              final coords = p.trim().split(' ');
              return LatLng(double.tryParse(coords[0]) ?? 0.0, double.tryParse(coords[1]) ?? 0.0);
            }).toList();
            _polygonPoints = points;
            _simplifiedPoints = points;
          } catch (e) {
            _polygonPoints = [];
          }
        }
      } else {
        _geofenceType = 'CIRCLE';
        _radius = 100.0;
      }
    } else {
      _geofenceType = 'CIRCLE';
      _name = '';
      _radius = 100.0;
    }
    _updateShapes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _httpClient.close();
    super.dispose();
  }

  void _onMapReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_geofenceType == 'CIRCLE' && _circleCenter != null) {
        _mapController.move(_circleCenter!, 14.0);
      } else if (_geofenceType == 'POLYGON' && _polygonPoints.isNotEmpty) {
        _fitPolygonBounds();
      } else {
        _mapController.move(_center, 14.0);
      }
    });
  }

  void _fitPolygonBounds() {
    if (_polygonPoints.isEmpty) return;
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
    _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)), padding: const EdgeInsets.all(50)));
  }

  void _onTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      if (_geofenceType == 'CIRCLE') {
        _circleCenter = point;
      } else {
        _polygonPoints.add(point);
        _applySimplify();
      }
      _updateShapes();
    });
  }

  void _updateShapes() {
    _circles.clear();
    _polygons.clear();
    _polygonMarkers.clear();

    if (_geofenceType == 'CIRCLE' && _circleCenter != null) {
      _circles.add(CircleMarker(point: _circleCenter!, radius: _radius, color: Colors.blue.withValues(alpha: 0.3), borderColor: Colors.blue, borderStrokeWidth: 2));
    } else if (_geofenceType == 'POLYGON') {
      final displayPoints = _showSimplified && _simplifiedPoints.length >= 3 ? _simplifiedPoints : _polygonPoints;
      if (displayPoints.length >= 3) {
        _polygons.add(Polygon(points: displayPoints, color: Colors.green.withValues(alpha: 0.3), borderColor: Colors.green, borderStrokeWidth: 2));
      }
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

  // --- Douglas-Peucker polygon simplification ---
  void _applySimplify() {
    if (_polygonPoints.length < 3) {
      _simplifiedPoints = List.from(_polygonPoints);
      return;
    }
    final targetCount = max(3, (_polygonPoints.length * _simplifyFactor).round());
    _simplifiedPoints = _simplifyPolygon(_polygonPoints, targetCount);
  }

  List<LatLng> _simplifyPolygon(List<LatLng> points, int targetCount) {
    if (points.length <= targetCount) return List.from(points);
    // Douglas-Peucker: iteratively remove the point with smallest area contribution
    var simplified = List<LatLng>.from(points);
    while (simplified.length > targetCount) {
      double minArea = double.infinity;
      int minIdx = 1;
      for (int i = 1; i < simplified.length - 1; i++) {
        final area = _triangleArea(simplified[i - 1], simplified[i], simplified[i + 1]);
        if (area < minArea) {
          minArea = area;
          minIdx = i;
        }
      }
      simplified.removeAt(minIdx);
    }
    return simplified;
  }

  double _triangleArea(LatLng a, LatLng b, LatLng c) {
    return ((a.latitude * (b.longitude - c.longitude) + b.latitude * (c.longitude - a.longitude) + c.latitude * (a.longitude - b.longitude)) / 2).abs();
  }

  // --- OpenStreetMap Nominatim search ---
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      // polygon_geojson=1 returns full boundary polygon geometry
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=geojson&polygon_geojson=1&limit=8&addressdetails=1');
      final response = await _httpClient.get(url, headers: {'User-Agent': 'Trabcdefg/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List? ?? [];
        setState(() {
          _searchResults = features.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _applySearchResult(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    if (geometry == null) return;
    final bbox = feature['bbox'] as List?;
    final type = geometry['type'] as String? ?? '';

    setState(() {
      _searchResults = [];
      _searchController.clear();

      // Try to extract polygon boundary first (from polygon_geojson=1 response)
      final extracted = (type != 'Point') ? _extractPolygonPoints(geometry) : <LatLng>[];

      if (extracted.length >= 3) {
        // ✅ Have real boundary polygon from OSM
        _geofenceType = 'POLYGON';
        _polygonPoints = extracted;
        _simplifiedPoints = List.from(_polygonPoints);
        _showSimplified = true; // Enable simplify by default for imported boundaries
        _applySimplify();
        _updateShapes();
      } else if (bbox != null && bbox.length >= 4) {
        // Fallback: use bbox to build a rectangle polygon
        _geofenceType = 'POLYGON';
        final minLng = (bbox[0] as num).toDouble();
        final minLat = (bbox[1] as num).toDouble();
        final maxLng = (bbox[2] as num).toDouble();
        final maxLat = (bbox[3] as num).toDouble();
        _polygonPoints = [LatLng(minLat, minLng), LatLng(minLat, maxLng), LatLng(maxLat, maxLng), LatLng(maxLat, minLng)];
        _simplifiedPoints = List.from(_polygonPoints);
        _showSimplified = false;
        _updateShapes();
      } else if (type == 'Point') {
        // Last resort: Point → Circle
        final coords = geometry['coordinates'] as List;
        final lng = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        _geofenceType = 'CIRCLE';
        _circleCenter = LatLng(lat, lng);
        _radius = 100.0;
        _updateShapes();
      }

      // Zoom to bounds
      if (bbox != null && bbox.length >= 4) {
        final minLat = (bbox[1] as num).toDouble();
        final minLng = (bbox[0] as num).toDouble();
        final maxLat = (bbox[3] as num).toDouble();
        final maxLng = (bbox[2] as num).toDouble();
        _mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)), padding: const EdgeInsets.all(50)));
      } else if (_polygonPoints.isNotEmpty) {
        _fitPolygonBounds();
      } else if (_circleCenter != null) {
        _mapController.move(_circleCenter!, 16.0);
      }
    });
  }

  List<LatLng> _extractPolygonPoints(Map<String, dynamic> geometry) {
    final result = <LatLng>{};

    void walkCoords(dynamic coords) {
      if (coords is List) {
        if (coords.isNotEmpty && coords[0] is num) {
          // Leaf: [lng, lat]
          result.add(LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble()));
        } else {
          for (final item in coords) {
            walkCoords(item);
          }
        }
      }
    }

    walkCoords(geometry['coordinates']);

    // Remove duplicate last point (closed ring)
    final list = result.toList();
    if (list.length >= 4 && list.first.latitude == list.last.latitude && list.first.longitude == list.last.longitude) {
      list.removeLast();
    }
    return list;
  }

  // --- Device location picker ---
  void _showDevicePicker() {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('sharedDevice'.tr),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: traccarProvider.devices.length,
            itemBuilder: (_, i) {
              final device = traccarProvider.devices[i];
              final pos = traccarProvider.getPosition(device.id!);
              return ListTile(
                leading: Icon(Icons.directions_car, color: Theme.of(context).colorScheme.primary),
                title: Text(device.name ?? '#${device.id}'),
                subtitle: pos != null ? Text('${pos.latitude?.toStringAsFixed(4) ?? "?"}, ${pos.longitude?.toStringAsFixed(4) ?? "?"}') : Text('sharedNoData'.tr),
                onTap: () {
                  if (pos != null && pos.latitude != null && pos.longitude != null) {
                    final lat = pos.latitude!.toDouble();
                    final lng = pos.longitude!.toDouble();
                    setState(() {
                      _geofenceType = 'CIRCLE';
                      _circleCenter = LatLng(lat, lng);
                      _radius = 100.0;
                      _polygonPoints.clear();
                      _updateShapes();
                      _mapController.move(LatLng(lat, lng), 15.0);
                    });
                    Navigator.pop(ctx);
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCacheInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text('sharedLoading'.tr)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.geofence == null ? 'sharedCreateGeofence'.tr : '${'sharedEdit'.tr} ${'sharedGeofence'.tr}'),
        actions: [
          IconButton(icon: Icon(_mapType == AppMapType.satellite ? Icons.map : Icons.satellite), onPressed: () => setState(() => _mapType = _mapType == AppMapType.satellite ? AppMapType.openStreetMap : AppMapType.satellite)),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              if (_formKey.currentState!.validate() && ((_geofenceType == 'CIRCLE' && _circleCenter != null) || (_geofenceType == 'POLYGON' && (_showSimplified ? _simplifiedPoints : _polygonPoints).length >= 3))) {
                _formKey.currentState!.save();

                final String area;
                if (_geofenceType == 'CIRCLE') {
                  area = 'CIRCLE(${_circleCenter!.latitude} ${_circleCenter!.longitude} $_radius)';
                } else {
                  final usePoints = _showSimplified && _simplifiedPoints.length >= 3 ? _simplifiedPoints : _polygonPoints;
                  final pointsString = usePoints.map((p) => '${p.latitude} ${p.longitude}').join(', ');
                  final closedPointsString = '$pointsString, ${usePoints.first.latitude} ${usePoints.first.longitude}';
                  area = 'POLYGON(($closedPointsString))';
                }

                final geofence = api.Geofence(id: widget.geofence?.id, name: _name, area: area);
                if (!mounted) return;
                Navigator.pop(context, geofence);
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_geofenceType == 'CIRCLE' ? 'Please enter a name and select a point on the map.'.tr : 'Please enter a name and draw a polygon with at least 3 points.'.tr)));
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
                  validator: (value) => (value == null || value.isEmpty) ? 'Please enter a name' : null,
                  onSaved: (value) => _name = value!,
                ),
                const SizedBox(height: 12),

                // --- Device location picker ---
                OutlinedButton.icon(icon: const Icon(Icons.my_location), label: Text('deviceSelectLocation'.tr), onPressed: _showDevicePicker),
                const SizedBox(height: 12),

                // --- Search bar ---
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'searchOsm'.tr,
                    suffixIcon: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(icon: const Icon(Icons.search), onPressed: () => _searchLocation(_searchController.text)),
                  ),
                  onSubmitted: _searchLocation,
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (_, i) {
                        final feat = _searchResults[i];
                        final props = feat['properties'] as Map<String, dynamic>? ?? {};
                        final displayName = props['display_name'] as String? ?? 'Result ${i + 1}';
                        return ListTile(
                          dense: true,
                          title: Text(displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                          leading: const Icon(Icons.place, size: 20),
                          onTap: () => _applySearchResult(feat),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),

                // --- Type selector ---
                DropdownButtonFormField<String>(
                  initialValue: _geofenceType,
                  decoration: InputDecoration(labelText: 'sharedType'.tr),
                  items: [
                    DropdownMenuItem(value: 'CIRCLE', child: Text('mapShapeCircle'.tr)),
                    DropdownMenuItem(value: 'POLYGON', child: Text('mapShapePolygon'.tr)),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _geofenceType = value!;
                      _polygonPoints.clear();
                      _circleCenter = null;
                      _simplifiedPoints = [];
                      _showSimplified = false;
                      _updateShapes();
                    });
                  },
                ),
                const SizedBox(height: 12),

                // --- Circle radius ---
                if (_geofenceType == 'CIRCLE')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('${'commandRadius'.tr}: ${_radius.round()} ${'sharedMeters'.tr}'),
                      Slider(
                        value: _radius,
                        min: 10,
                        max: 2000,
                        divisions: 199,
                        label: _radius.round().toString(),
                        onChanged: (value) {
                          setState(() {
                            _radius = value;
                            _updateShapes();
                          });
                        },
                      ),
                      Text(_circleCenter == null ? 'Tap map to set circle center' : 'mapShapeCircle'.tr, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),

                // --- Polygon controls ---
                if (_geofenceType == 'POLYGON')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('${'mapShapePolygon'.tr}: ${_polygonPoints.length} pts'),
                      const SizedBox(height: 4),
                      Text('TapMapAddPolygon'.tr, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      if (_polygonPoints.length >= 3) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: Text('Simplify: ${_polygonPoints.length} → ${_simplifiedPoints.length} nodes')),
                            Switch(
                              value: _showSimplified,
                              onChanged: (v) {
                                setState(() {
                                  _showSimplified = v;
                                  _updateShapes();
                                });
                              },
                            ),
                          ],
                        ),
                        if (_showSimplified)
                          Slider(
                            value: _simplifyFactor,
                            min: 0.05,
                            max: 1.0,
                            divisions: 19,
                            label: '${(_simplifyFactor * 100).round()}%',
                            onChanged: (v) {
                              setState(() {
                                _simplifyFactor = v;
                                _applySimplify();
                                _updateShapes();
                              });
                            },
                          ),
                      ],
                      if (_polygonPoints.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.clear, size: 18),
                            label: Text('Clear Points'.tr),
                            onPressed: () {
                              setState(() {
                                _polygonPoints.clear();
                                _simplifiedPoints = [];
                                _updateShapes();
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 400,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _circleCenter ?? _polygonPoints.firstOrNull ?? _center,
                      initialZoom: 14.0,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                      onTap: _onTap,
                      onMapReady: _onMapReady,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _mapType == AppMapType.openStreetMap ? _osmUrlTemplate : _satelliteUrlTemplate,
                        subdomains: _mapType == AppMapType.openStreetMap ? _osmSubdomains : const [],
                        userAgentPackageName: 'com.trabcdefg.app',
                        tileProvider: _tileProvider,
                      ),
                      CircleLayer(circles: _circles),
                      PolygonLayer(polygons: _polygons),
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
