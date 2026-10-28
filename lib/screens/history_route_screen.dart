import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:trabcdefg/models/report_summary_hive.dart';
import 'package:trabcdefg/models/route_positions_hive.dart';
import 'package:trabcdefg/providers/map_style_provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/screens/reports/chart_report_screen.dart';
import 'package:trabcdefg/screens/reports/stops_report_screen.dart';
import 'package:trabcdefg/screens/reports/trips_report_screen.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/src/utils/position_cleaner.dart';
import 'package:trabcdefg/widgets/offline_address_service.dart';

enum OSMMapType { normal, satellite }

enum RouteColorMode {
  single, // 單一顏色
  speedStatus, // 依速度分色 (Turbo 漸層)
  timeGradient, // 時間漸層分色 (早:淺藍, 午:中藍, 晚:深藍)
}

// --- Turbo Colormap 演算法與係數 ---
const List<double> _turboRedCoeffs = [0.13572138, 4.6153926, -42.66032258, 132.13108234, -152.94239396, 59.28637943];
const List<double> _turboGreenCoeffs = [0.09140261, 2.19418839, 4.84296658, -14.18503333, 4.27729857, 2.82956604];
const List<double> _turboBlueCoeffs = [0.1066733, 12.64194608, -60.58204836, 110.36276771, -89.90310912, 27.34824973];

double _interpolateChannel(double normalizedValue, List<double> coeffs) {
  double result = 0;
  for (int i = 0; i < coeffs.length; i++) {
    result += coeffs[i] * pow(normalizedValue, i);
  }
  return max(0.0, min(1.0, result));
}

List<int> _interpolateTurbo(double value) {
  final normalizedValue = max(0.0, min(1.0, value));
  return [
    (255 * _interpolateChannel(normalizedValue, _turboRedCoeffs)).round(),
    (255 * _interpolateChannel(normalizedValue, _turboGreenCoeffs)).round(),
    (255 * _interpolateChannel(normalizedValue, _turboBlueCoeffs)).round(),
  ];
}

String _getTurboSpeedColor(double speedKmh, double minSpeed, double maxSpeed) {
  if (maxSpeed <= minSpeed) {
    maxSpeed = minSpeed + 1.0;
  }
  final normalizedSpeed = ((speedKmh - minSpeed) / (maxSpeed - minSpeed)).clamp(0.0, 1.0);
  final rgb = _interpolateTurbo(normalizedSpeed);
  return '#${rgb[0].toRadixString(16).padLeft(2, '0')}${rgb[1].toRadixString(16).padLeft(2, '0')}${rgb[2].toRadixString(16).padLeft(2, '0')}';
}

// --- Isolate Background Compute Helper ---
class _GeoJsonParams {
  final List<api.Position> positions;
  final RouteColorMode routeColorMode;

  _GeoJsonParams(this.positions, this.routeColorMode);
}

Map<String, dynamic> _buildGeoJsonIsolate(_GeoJsonParams params) {
  final positions = params.positions;
  final routeColorMode = params.routeColorMode;

  double minSpeed = 0;
  double maxSpeed = 120.0;
  if (routeColorMode == RouteColorMode.speedStatus && positions.isNotEmpty) {
    final speeds = positions.map((p) => (p.speed ?? 0) * 1.852).toList();
    minSpeed = speeds.reduce(min);
    maxSpeed = speeds.reduce(max);
  }

  String getColor(api.Position p) {
    final speedKmh = (p.speed ?? 0) * 1.852;
    if (routeColorMode == RouteColorMode.speedStatus) {
      return _getTurboSpeedColor(speedKmh, minSpeed, maxSpeed);
    } else if (routeColorMode == RouteColorMode.timeGradient) {
      final recordedAt = PositionCleaner.recordingTime(p);
      final hour = recordedAt?.hour ?? 12;
      if (hour >= 6 && hour < 12) {
        return "#85C1E9";
      } else if (hour >= 12 && hour < 18) {
        return "#3498DB";
      } else {
        return "#1B4F72";
      }
    }
    return "#808080";
  }

  final List<Map<String, dynamic>> features = [];

  if (routeColorMode == RouteColorMode.single) {
    final coords = positions.map((p) => [p.longitude!.toDouble(), p.latitude!.toDouble()]).toList();
    features.add({
      "type": "Feature",
      "properties": {"color": "#808080"},
      "geometry": {"type": "LineString", "coordinates": coords},
    });
  } else {
    for (int i = 0; i < positions.length - 1; i++) {
      final p1 = positions[i];
      final p2 = positions[i + 1];
      final color = getColor(p1);

      features.add({
        "type": "Feature",
        "properties": {"color": color},
        "geometry": {
          "type": "LineString",
          "coordinates": [
            [p1.longitude!.toDouble(), p1.latitude!.toDouble()],
            [p2.longitude!.toDouble(), p2.latitude!.toDouble()],
          ],
        },
      });
    }
  }

  return {"type": "FeatureCollection", "features": features};
}

class HistoryRouteScreen extends StatefulWidget {
  const HistoryRouteScreen({super.key});

  @override
  State<HistoryRouteScreen> createState() => _HistoryRouteScreenState();
}

class _HistoryRouteScreenState extends State<HistoryRouteScreen> with TickerProviderStateMixin {
  static const List<double> _playbackSpeeds = [1.0, 5.0, 10.0, 20.0];

  static const BoxDecoration _turboGradientDecoration = BoxDecoration(
    gradient: LinearGradient(colors: [Color(0xFF350A66), Color(0xFF3858E9), Color(0xFF2490EA), Color(0xFF1EC0AC), Color(0xFF7FE23E), Color(0xFFFDE725)]),
    borderRadius: BorderRadius.all(Radius.circular(6)),
  );

  static const Widget _singleColorIcon = Icon(Icons.lens, color: Color(0xFF0F53FE));

  static const Widget _timeGradientIcons = Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.lens, size: 12, color: Color(0xFF85C1E9)),
      SizedBox(width: 4),
      Icon(Icons.lens, size: 12, color: Color(0xFF3498DB)),
      SizedBox(width: 4),
      Icon(Icons.lens, size: 12, color: Color(0xFF1B4F72)),
    ],
  );

  MapLibreMapController? _mapController;
  List<double> _distancePrefixSum = [];
  final RxString _currentAddressRx = "".obs;
  int _addressRequestToken = 0;

  List<api.Position> _positions = [];
  final RxDouble _playbackPositionRx = 0.0.obs;

  bool _isPlaying = false;
  bool _isLoading = false;
  bool _followUser = true;
  double _playbackSpeed = 1.0;

  AnimationController? _playbackAnimationController;

  int? _deviceId;
  DateTime? _historyFrom;
  DateTime? _historyTo;
  String? _selectedDeviceName;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedCalendarDay = DateTime.now();
  final Map<DateTime, api.ReportSummary> _dailySummaries = {};
  bool _isCalendarLoading = false;
  double _currentZoom = 14.0;

  CameraPosition? _lastCameraPosition;
  bool _keepCameraOnStyleReload = false;
  bool _isMinimalMode = false;
  RouteColorMode _routeColorMode = RouteColorMode.single;

  static const String _playbackIconId = "playback_arrow";
  static const String _startIconId = "start_pin";
  static const String _endIconId = "end_pin";
  final List<LatLng> _stopPoints = [];
  final List<Symbol> _stopSymbols = [];

  bool _showGeofences = false;
  bool _isGeofenceLoading = false;
  bool _showStopPoints = true;
  List<api.Geofence> _geofences = [];

  Symbol? _playbackSymbol;
  int _lastCameraAnimTime = 0;

  static const String _routeSourceId = "history_route_source";
  static const String _routeLayerId = "history_route_layer";
  static const String _playedSourceId = "played_route_source";
  static const String _playedLayerId = "played_layer";
  static const String _geofenceSourceId = "history_geofence_source";
  static const String _geofenceFillLayerId = "history_geofence_fill_layer";
  static const String _geofenceLineLayerId = "history_geofence_line_layer";
  static const List<String> _geofenceColors = ['#0F53FE', '#F39C12', '#27AE60', '#8E44AD', '#E74C3C', '#16A085'];

  @override
  void initState() {
    super.initState();
    _initAnimationController();
    OfflineAddressService.initDatabase();
    cleanExpiredRouteHistory();
    _loadPlaybackSpeedFromHive();
    _loadInitialParamsAndFetch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    SystemChrome.setSystemUIOverlayStyle(
      Theme.of(context).brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
  }

  Future<void> _loadPlaybackSpeedFromHive() async {
    try {
      var settingsBox = Hive.isBoxOpen('settings') ? Hive.box('settings') : await Hive.openBox('settings');
      final savedSpeed = settingsBox.get('playback_speed');
      if (savedSpeed != null && savedSpeed is num) {
        final speedDouble = savedSpeed.toDouble();
        if (_playbackSpeeds.contains(speedDouble)) {
          _safeSetState(() {
            _playbackSpeed = speedDouble;
          });
        }
      }
    } catch (e) {
      developer.log('Failed to load playback speed from Hive: $e', name: 'HistoryRouteScreen');
    }
  }

  Future<void> _savePlaybackSpeedToHive(double speed) async {
    try {
      var settingsBox = Hive.isBoxOpen('settings') ? Hive.box('settings') : await Hive.openBox('settings');
      await settingsBox.put('playback_speed', speed);
    } catch (e) {
      developer.log('Failed to save playback speed to Hive: $e', name: 'HistoryRouteScreen');
    }
  }

  void _initAnimationController() {
    _playbackAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onAnimationTick);
  }

  @override
  void dispose() {
    _playbackAnimationController?.stop();
    _playbackAnimationController?.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  Future<void> _onStyleLoaded() async {
    await _loadCustomIconsToMap();
    if (_positions.isEmpty) {
      if (_showGeofences) {
        await _drawGeofences();
      }
      return;
    }
    final bool keepCamera = _keepCameraOnStyleReload;
    _keepCameraOnStyleReload = false;
    await _drawFullRoute(fitBounds: !keepCamera);
    if (_showGeofences) {
      await _drawGeofences();
    }
  }

  void _toggleMapType() {
    _lastCameraPosition = _mapController?.cameraPosition ?? _lastCameraPosition;
    _keepCameraOnStyleReload = true;
    Provider.of<MapStyleProvider>(context, listen: false).toggleMapType();
  }

  Future<void> _loadCustomIconsToMap() async {
    if (_mapController == null) return;
    await _addAssetImage(_playbackIconId, 'assets/images/arrow.png');
    await _addAssetImage(_startIconId, 'assets/images/start.png');
    await _addAssetImage(_endIconId, 'assets/images/destination.png');

    for (int i = 1; i <= 50; i++) {
      await _addAssetImage("pg_$i", "assets/images/pg_$i.png");
    }
  }

  Future<void> _addAssetImage(String id, String assetPath) async {
    final ByteData bytes = await rootBundle.load(assetPath);
    final Uint8List list = bytes.buffer.asUint8List();
    await _mapController?.addImage(id, list);
  }

  void _calculateDistancePrefixSum() {
    _distancePrefixSum = [0.0];
    double total = 0;
    for (int i = 0; i < _positions.length - 1; i++) {
      total += _distanceBetween(
        _positions[i].latitude!.toDouble(),
        _positions[i].longitude!.toDouble(),
        _positions[i + 1].latitude!.toDouble(),
        _positions[i + 1].longitude!.toDouble(),
      );
      _distancePrefixSum.add(total);
    }
  }

  Future<void> _loadInitialParamsAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceName = prefs.getString('selectedDeviceName');
    final deviceId = prefs.getInt('selectedDeviceId');
    final fromString = prefs.getString('historyFrom');
    final toString = prefs.getString('historyTo');
    final lastZoom = prefs.getDouble('history_zoom_level');
    final savedColorMode = prefs.getString('route_color_mode');

    if (savedColorMode != null) {
      _routeColorMode = RouteColorMode.values.firstWhere((e) => e.name == savedColorMode, orElse: () => RouteColorMode.single);
    }

    DateTime defaultDate = DateTime.now();

    if (!mounted) return;

    _safeSetState(() {
      if (lastZoom != null) _currentZoom = lastZoom;
      _deviceId = deviceId;
      _focusedDay = defaultDate;
      _selectedCalendarDay = defaultDate;
      _selectedDeviceName = deviceName;

      if (fromString != null && toString != null) {
        _historyFrom = DateTime.tryParse(fromString)?.toLocal();
        _historyTo = DateTime.tryParse(toString)?.toLocal();
        if (_historyFrom != null) {
          _selectedCalendarDay = DateTime(_historyFrom!.year, _historyFrom!.month, _historyFrom!.day);
        }
      } else {
        _historyFrom = DateTime(defaultDate.year, defaultDate.month, defaultDate.day, 0, 0, 0);
        _historyTo = DateTime(defaultDate.year, defaultDate.month, defaultDate.day, 23, 59, 59);
      }
    });

    if (_deviceId != null) {
      _fetchHistoryRoute();
      await _fetchMonthlyData(_focusedDay);
    }
  }

  Future<void> cleanExpiredRouteHistory() async {
    final routeBox = await Hive.openBox<RoutePositionsHive>('route_positions');
    const cacheDuration = Duration(days: 60);
    final DateTime expiryThreshold = DateTime.now().subtract(cacheDuration);
    final List<dynamic> expiredKeys = [];

    for (final key in routeBox.keys) {
      final entry = routeBox.get(key);
      if (entry != null && entry.cachedAt.isBefore(expiryThreshold)) {
        expiredKeys.add(key);
      }
    }

    if (expiredKeys.isNotEmpty) {
      await routeBox.deleteAll(expiredKeys);
    }
  }

  void _calculateStops(List<api.Position> allPositions) {
    _stopPoints.clear();
    if (allPositions.length < 2) return;

    for (int i = 0; i < allPositions.length - 1; i++) {
      final p1 = allPositions[i];
      final p2 = allPositions[i + 1];

      final recordedAt1 = PositionCleaner.recordingTime(p1);
      final recordedAt2 = PositionCleaner.recordingTime(p2);

      if (recordedAt1 != null && recordedAt2 != null) {
        final diff = recordedAt2.difference(recordedAt1);
        if (diff.inMinutes >= 5) {
          _stopPoints.add(LatLng(p1.latitude!.toDouble(), p1.longitude!.toDouble()));
        }
      }
      if (_stopPoints.length >= 50) break;
    }
  }

  Future<void> _fetchHistoryRoute({DateTime? selectedDay}) async {
    if (selectedDay != null) {
      _historyFrom = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 0, 0, 0);
      _historyTo = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 23, 59, 59);
    }

    if (_deviceId == null || _historyFrom == null || _historyTo == null) return;

    _playbackAnimationController?.stop();
    _safeSetState(() {
      _isLoading = true;
      _isPlaying = false;
      _positions = [];
      _playbackPositionRx.value = 0.0;
    });

    List<api.Position> fetchedPositions = [];
    bool fetchedFromNetwork = false;
    final hiveKey = '$_deviceId-${DateFormat('yyyy-MM-dd').format(_historyFrom!)}';

    try {
      final routeBox = await Hive.openBox<RoutePositionsHive>('route_positions');
      final cachedRoute = routeBox.get(hiveKey);

      bool isCacheValid = false;
      if (cachedRoute != null) {
        final bool isToday = isSameDay(_historyFrom, DateTime.now());
        final diff = DateTime.now().difference(cachedRoute.cachedAt);
        isCacheValid = isToday ? diff <= const Duration(minutes: 10) : diff <= const Duration(days: 60);
      }

      if (isCacheValid) {
        fetchedPositions = RoutePositionsHive.fromJsonList(cachedRoute!.positionsJson);
      } else {
        if (!mounted) return;
        fetchedFromNetwork = true;
        final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
        fetchedPositions = await api.PositionsApi(traccarProvider.apiClient).getPositions(
          deviceId: _deviceId,
          from: _historyFrom!.toUtc(),
          to: _historyTo!.toUtc(),
        ) ?? [];
      }

      final cleanedPositions = PositionCleaner.clean(fetchedPositions);
      if (fetchedFromNetwork && cleanedPositions.isNotEmpty) {
        await routeBox.put(
          hiveKey,
          RoutePositionsHive(
            dateKey: hiveKey,
            positionsJson: RoutePositionsHive.toJsonList(cleanedPositions),
            cachedAt: DateTime.now(),
          ),
        );
      }

      _calculateStops(cleanedPositions);
      final movingPositions = cleanedPositions.where((p) => (p.speed ?? 0) > 0).toList();
      final playbackPositions = movingPositions.isNotEmpty ? movingPositions : cleanedPositions;

      if (mounted) {
        _safeSetState(() {
          _positions = playbackPositions;
          _isLoading = false;
        });

        _calculateDistancePrefixSum();
        if (_mapController != null) {
          _drawFullRoute();
        }
      }
    } catch (e) {
      if (mounted) {
        _safeSetState(() => _isLoading = false);
        Get.snackbar("Error", "Failed to fetch route data");
      }
    }
  }

  Future<void> _cleanMapLayers() async {
    if (_mapController == null) return;
    try {
      await _mapController!.removeLayer(_playedLayerId);
      await _mapController!.removeSource(_playedSourceId);
      await _mapController!.removeLayer(_routeLayerId);
      await _mapController!.removeSource(_routeSourceId);
    } catch (_) {}
    await _mapController!.clearLines();
    await _mapController!.clearSymbols();
    _stopSymbols.clear();
  }

  Future<void> _drawFullRoute({bool fitBounds = true}) async {
    if (_mapController == null || _positions.isEmpty) return;

    await _cleanMapLayers();
    final List<LatLng> points = _positions.map((p) => LatLng(p.latitude!.toDouble(), p.longitude!.toDouble())).toList();

    Map<String, dynamic> routeGeoJson;
    if (_positions.length > 1000) {
      routeGeoJson = await compute(_buildGeoJsonIsolate, _GeoJsonParams(_positions, _routeColorMode));
    } else {
      routeGeoJson = _buildGeoJsonIsolate(_GeoJsonParams(_positions, _routeColorMode));
    }

    await _mapController!.addSource(_routeSourceId, GeojsonSourceProperties(data: routeGeoJson));
    await _mapController!.addLineLayer(
      _routeSourceId,
      _routeLayerId,
      LineLayerProperties(lineColor: ['get', 'color'], lineWidth: 4.0, lineOpacity: 0.8, lineJoin: 'round', lineCap: 'round'),
    );

    final Map<String, dynamic> emptyPlayedGeoJson = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {"type": "LineString", "coordinates": []},
        },
      ],
    };
    await _mapController!.addSource(_playedSourceId, GeojsonSourceProperties(data: emptyPlayedGeoJson));
    await _mapController!.addLineLayer(
      _playedSourceId,
      _playedLayerId,
      LineLayerProperties(lineColor: '#0F53FE', lineWidth: 5.5, lineOpacity: 1.0, lineJoin: 'round', lineCap: 'round'),
    );

    _addMarker(points.first, _startIconId);
    _addMarker(points.last, _endIconId);

    if (_positions.isNotEmpty) {
      _playbackSymbol = await _mapController!.addSymbol(SymbolOptions(
        geometry: LatLng(_positions.first.latitude!.toDouble(), _positions.first.longitude!.toDouble()),
        iconImage: _playbackIconId,
        iconSize: 1.8,
        zIndex: 10,
      ));
    }

    if (_showStopPoints) {
      await _drawStopSymbols();
    }

    if (fitBounds) {
      _animateCameraToBounds();
    }
  }

  Future<void> _toggleGeofences() async {
    if (_showGeofences) {
      _safeSetState(() => _showGeofences = false);
      await _clearGeofenceLayers();
      return;
    }

    if (_mapController == null || _isGeofenceLoading) return;
    _safeSetState(() => _isGeofenceLoading = true);

    try {
      if (_geofences.isEmpty) {
        final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
        _geofences = await api.GeofencesApi(traccarProvider.apiClient).getGeofences(deviceId: _deviceId) ?? [];
      }
      if (_geofences.isEmpty) {
        if (mounted) Get.snackbar('sharedGeofences'.tr, 'sharedNoData'.tr);
        return;
      }
      _safeSetState(() => _showGeofences = true);
      await _drawGeofences();
    } catch (e) {
      if (mounted) Get.snackbar("Error", 'sharedNoData'.tr);
    } finally {
      _safeSetState(() => _isGeofenceLoading = false);
    }
  }

  Future<void> _clearGeofenceLayers() async {
    final controller = _mapController;
    if (controller == null) return;
    try { await controller.removeLayer(_geofenceLineLayerId); } catch (_) {}
    try { await controller.removeLayer(_geofenceFillLayerId); } catch (_) {}
    try { await controller.removeSource(_geofenceSourceId); } catch (_) {}
  }

  Future<void> _drawGeofences() async {
    final controller = _mapController;
    if (controller == null || !_showGeofences) return;

    await _clearGeofenceLayers();
    final List<Map<String, dynamic>> features = [];
    for (int i = 0; i < _geofences.length; i++) {
      features.addAll(_geofenceFeatures(_geofences[i], i));
    }
    if (features.isEmpty) return;

    final String? belowLayerId = _positions.isNotEmpty ? _routeLayerId : null;
    await controller.addSource(_geofenceSourceId, GeojsonSourceProperties(data: {"type": "FeatureCollection", "features": features}));
    await controller.addFillLayer(_geofenceSourceId, _geofenceFillLayerId, FillLayerProperties(fillColor: ['get', 'color'], fillOpacity: 0.18), belowLayerId: belowLayerId);
    await controller.addLineLayer(_geofenceSourceId, _geofenceLineLayerId, LineLayerProperties(lineColor: ['get', 'color'], lineWidth: 2.0), belowLayerId: belowLayerId);
  }

  List<Map<String, dynamic>> _geofenceFeatures(api.Geofence geofence, int index) {
    final area = geofence.area;
    if (area == null || area.isEmpty) return const [];
    final properties = {"color": _geofenceColors[index % _geofenceColors.length], "name": geofence.name ?? ''};

    if (area.startsWith('CIRCLE')) {
      final int openParen = area.indexOf('(');
      final int closeParen = area.lastIndexOf(')');
      if (openParen < 0 || closeParen <= openParen) return const [];
      final parts = area.substring(openParen + 1, closeParen).trim().split(RegExp(r'\s+'));
      if (parts.length < 3) return const [];
      final lat = double.tryParse(parts[0]);
      final lon = double.tryParse(parts[1]);
      final radius = double.tryParse(parts[2]);
      if (lat == null || lon == null || radius == null) return const [];
      return [{
        "type": "Feature",
        "properties": properties,
        "geometry": {"type": "Polygon", "coordinates": [_circleRing(lat, lon, radius)]},
      }];
    }
    return const [];
  }

  List<List<double>> _circleRing(double lat, double lon, double radiusMeters) {
    const int segments = 64;
    final double dLat = radiusMeters / 111320.0;
    final double dLon = radiusMeters / (111320.0 * max(cos(lat * pi / 180).abs(), 0.01));
    final ring = <List<double>>[];
    for (int i = 0; i < segments; i++) {
      final double angle = 2 * pi * i / segments;
      ring.add([lon + dLon * cos(angle), lat + dLat * sin(angle)]);
    }
    ring.add([ring.first[0], ring.first[1]]);
    return ring;
  }

  Future<void> _toggleStopPoints() async {
    final bool nextVisible = !_showStopPoints;
    _safeSetState(() => _showStopPoints = nextVisible);
    if (nextVisible) {
      await _drawStopSymbols();
    } else {
      await _clearStopSymbols();
    }
  }

  Future<void> _drawStopSymbols() async {
    final controller = _mapController;
    if (controller == null || !_showStopPoints) return;
    await _clearStopSymbols();
    for (int i = 0; i < _stopPoints.length; i++) {
      final symbol = await controller.addSymbol(SymbolOptions(geometry: _stopPoints[i], iconImage: "pg_${i + 1}", iconSize: 3.5, iconAnchor: "center"));
      _stopSymbols.add(symbol);
    }
  }

  Future<void> _clearStopSymbols() async {
    final controller = _mapController;
    if (controller == null) return;
    for (final symbol in _stopSymbols) {
      try { await controller.removeSymbol(symbol); } catch (_) {}
    }
    _stopSymbols.clear();
  }

  void _setRouteColorMode(RouteColorMode mode) {
    _safeSetState(() => _routeColorMode = mode);
    SharedPreferences.getInstance().then((prefs) => prefs.setString('route_color_mode', mode.name));
    if (_positions.isNotEmpty) {
      _drawFullRoute(fitBounds: false);
    }
  }

  void _showColorModeMenu() {
    Get.bottomSheet(
      Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('routeColorModeTitle'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 16),
              ListTile(
                leading: _singleColorIcon,
                title: Text('routeColorModeSingle'.tr),
                trailing: _routeColorMode == RouteColorMode.single ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () { Navigator.pop(context); _setRouteColorMode(RouteColorMode.single); },
              ),
              ListTile(
                leading: Container(width: 36, height: 12, decoration: _turboGradientDecoration),
                title: Text('routeColorModeSpeedStatus'.tr),
                trailing: _routeColorMode == RouteColorMode.speedStatus ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () { Navigator.pop(context); _setRouteColorMode(RouteColorMode.speedStatus); },
              ),
              ListTile(
                leading: _timeGradientIcons,
                title: Text('routeColorModeTimeGradient'.tr),
                trailing: _routeColorMode == RouteColorMode.timeGradient ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () { Navigator.pop(context); _setRouteColorMode(RouteColorMode.timeGradient); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addMarker(LatLng point, String iconId) {
    _mapController?.addSymbol(SymbolOptions(geometry: point, iconImage: iconId, iconSize: 1.8, iconAnchor: "bottom"));
  }

  void _togglePlayback() {
    if (_positions.isEmpty) return;
    if (_isPlaying) {
      _playbackAnimationController?.stop();
      _safeSetState(() => _isPlaying = false);
      return;
    }

    final double maxLimit = max(0, _positions.length - 1).toDouble();
    if (_playbackPositionRx.value >= maxLimit) {
      _playbackPositionRx.value = 0;
    }

    _safeSetState(() => _isPlaying = true);
    _playbackAnimationController?.repeat();
  }

  void _onAnimationTick() {
    if (!_isPlaying || _positions.isEmpty) return;

    final double maxLimit = max(0, _positions.length - 1).toDouble();
    double step = 0.05 * _playbackSpeed;
    double nextVal = _playbackPositionRx.value + step;

    if (nextVal >= maxLimit) {
      _playbackPositionRx.value = maxLimit;
      _playbackAnimationController?.stop();
      _safeSetState(() => _isPlaying = false);
    } else {
      _playbackPositionRx.value = nextVal;
    }
    _updatePlaybackUI();
  }

  void _updatePlaybackUI() async {
    if (_mapController == null || _positions.isEmpty || _playbackSymbol == null) return;

    final double pos = _playbackPositionRx.value;
    final int idx = pos.floor().clamp(0, _positions.length - 1);
    final int nextIdx = (idx + 1).clamp(0, _positions.length - 1);
    final double fraction = pos - idx;

    final p1 = _positions[idx];
    final p2 = _positions[nextIdx];

    final double smoothLat = p1.latitude!.toDouble() + (p2.latitude!.toDouble() - p1.latitude!.toDouble()) * fraction;
    final double smoothLng = p1.longitude!.toDouble() + (p2.longitude!.toDouble() - p1.longitude!.toDouble()) * fraction;
    final currentLatLng = LatLng(smoothLat, smoothLng);

    double bearing = p1.course?.toDouble() ?? 0;
    if (idx < _positions.length - 1 && fraction > 0.1) {
      bearing = _calculateBearing(LatLng(p1.latitude!.toDouble(), p1.longitude!.toDouble()), LatLng(p2.latitude!.toDouble(), p2.longitude!.toDouble()));
    }

    if (_currentAddressRx.value.isEmpty || idx % 20 == 0) {
      final int currentToken = ++_addressRequestToken;
      OfflineAddressService.getAddress(p1.latitude!.toDouble(), p1.longitude!.toDouble()).then((addr) {
        if (currentToken == _addressRequestToken) {
          _currentAddressRx.value = addr;
        }
      });
    }

    _mapController!.updateSymbol(_playbackSymbol!, SymbolOptions(geometry: currentLatLng, iconRotate: bearing));

    final List<List<double>> playedCoords = [];
    for (int i = 0; i <= idx; i++) {
      playedCoords.add([_positions[i].longitude!.toDouble(), _positions[i].latitude!.toDouble()]);
    }
    playedCoords.add([smoothLng, smoothLat]);

    await _mapController!.setGeoJsonSource(_playedSourceId, {
      "type": "FeatureCollection",
      "features": [{
        "type": "Feature",
        "geometry": {"type": "LineString", "coordinates": playedCoords},
      }],
    });
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * pi / 180;
    double lon1 = start.longitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double lon2 = end.longitude * pi / 180;
    return (atan2(sin(lon2 - lon1) * cos(lat2), cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lon2 - lon1)) * 180 / pi + 360) % 360;
  }

  void _animateCameraToBounds() {
    if (_positions.isEmpty) return;
    double minLat = _positions.map((p) => p.latitude!).reduce(min).toDouble();
    double maxLat = _positions.map((p) => p.latitude!).reduce(max).toDouble();
    double minLon = _positions.map((p) => p.longitude!).reduce(min).toDouble();
    double maxLon = _positions.map((p) => p.longitude!).reduce(max).toDouble();

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat, minLon), northeast: LatLng(maxLat, maxLon)),
      left: 70, right: 70, top: 70, bottom: 250,
    ));
  }

  double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var a = 0.5 - cos((lat2 - lat1) * p) / 2 + cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Future<void> _syncReportPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (_deviceId != null) await prefs.setInt('selectedDeviceId', _deviceId!);
    if (_selectedDeviceName != null) await prefs.setString('selectedDeviceName', _selectedDeviceName!);
    if (_historyFrom != null) await prefs.setString('historyFrom', _historyFrom!.toIso8601String());
    if (_historyTo != null) await prefs.setString('historyTo', _historyTo!.toIso8601String());
  }

  Future<void> _openReportPage(WidgetBuilder builder) async {
    await _syncReportPreferences();
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: builder));
  }

  @override
  Widget build(BuildContext context) {
    final double safeTop = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            key: ValueKey(Provider.of<MapStyleProvider>(context).isSatelliteMode),
            onMapCreated: (c) => _mapController = c,
            onStyleLoadedCallback: _onStyleLoaded,
            initialCameraPosition: _lastCameraPosition ?? CameraPosition(target: const LatLng(0, 0), zoom: _currentZoom),
            styleString: Provider.of<MapStyleProvider>(context).getStyle(Theme.of(context).brightness),
            onCameraMove: (position) {
              _lastCameraPosition = position;
              _currentZoom = position.zoom;
              SharedPreferences.getInstance().then((prefs) => prefs.setDouble('history_zoom_level', position.zoom));
            },
            myLocationEnabled: false,
            trackCameraPosition: true,
            onMapClick: (_, __) => _safeSetState(() => _followUser = false),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (!_isMinimalMode)
            Positioned(
              top: safeTop + 12,
              left: 64,
              right: 64,
              child: Center(child: _buildDeviceDatePill()),
            ),
          Positioned(
            top: safeTop + (_isMinimalMode ? 12 : 60),
            left: 12,
            child: _mapFab(
              _isMinimalMode ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
              () => _safeSetState(() => _isMinimalMode = !_isMinimalMode),
              "btn_minimal",
              active: _isMinimalMode,
            ),
          ),
          if (!_isMinimalMode) ...[
            Positioned(
              top: safeTop + 60,
              right: 12,
              child: Column(
                children: [
                  _mapFab(Icons.show_chart_rounded, () => _openReportPage((_) => const ChartReportScreen()), "btn_chart"),
                  const SizedBox(height: 8),
                  _mapFab(Icons.route_rounded, () => _openReportPage((_) => const TripsReportScreen()), "btn_trips"),
                  const SizedBox(height: 8),
                  _mapFab(Icons.pin_drop_rounded, _toggleStopPoints, "btn_stop_points", active: _showStopPoints),
                  const SizedBox(height: 8),
                  _mapFab(Icons.palette_rounded, _showColorModeMenu, "btn_color_mode", active: _routeColorMode != RouteColorMode.single),
                  const SizedBox(height: 8),
                  _mapFab(Icons.calendar_month, _showCalendarDialog, "btn_cal"),
                  const SizedBox(height: 8),
                  _mapFab(Provider.of<MapStyleProvider>(context).isSatelliteMode ? Icons.map : Icons.satellite_alt, _toggleMapType, "btn_style"),
                ],
              ),
            ),
          ],
          _buildPlaybackPanel(),
        ],
      ),
    );
  }

  Widget _mapFab(IconData icon, VoidCallback onPressed, String tag, {bool active = false, String? tooltip}) {
    final theme = Theme.of(context);
    return FloatingActionButton(
      heroTag: tag,
      mini: true,
      tooltip: tooltip,
      backgroundColor: active ? const Color(0xFF0F53FE) : theme.colorScheme.surface,
      onPressed: onPressed,
      child: Icon(icon, color: active ? Colors.white : theme.colorScheme.onSurface),
    );
  }

  Widget _buildDeviceDatePill() {
    final theme = Theme.of(context);
    final String dateLabel = DateFormat('yyyy/MM/dd').format(_historyFrom ?? DateTime.now());
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
      elevation: 2,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _showCalendarDialog,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_car_filled_rounded, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Flexible(child: Text(_selectedDeviceName ?? '--', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
              const SizedBox(width: 8),
              Text(dateLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackPanel() {
    return Positioned(
      bottom: 24 + MediaQuery.of(context).padding.bottom,
      left: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _mapFab(_isGeofenceLoading ? Icons.hourglass_top_rounded : Icons.fence_rounded, _toggleGeofences, "btn_geofence", active: _showGeofences),
          ),
          const SizedBox(height: 10),
          _isMinimalMode ? _buildMinimalPlaybackPanel() : _buildFullPlaybackPanel(),
        ],
      ),
    );
  }

  Widget _buildFullPlaybackPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() => Text(_currentAddressRx.value.isEmpty ? 'sharedLocating'.tr : _currentAddressRx.value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Obx(() {
            final int idx = _playbackPositionRx.value.floor().clamp(0, max(0, _positions.length - 1));
            final pos = _positions.isEmpty ? null : _positions[idx];
            final recordedAt = pos == null ? null : PositionCleaner.recordingTime(pos);
            final time = recordedAt != null ? DateFormat('HH:mm:ss').format(recordedAt.toLocal()) : "--:--:--";
            final speed = pos != null ? ((pos.speed ?? 0) * 1.852).toStringAsFixed(1) : "0.0";
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem("positionDrivingTime".tr, time, CupertinoIcons.clock),
                _buildStatItem("positionSpeed".tr, "$speed km/h", Icons.speed_rounded),
              ],
            );
          }),
          Obx(() => Slider(
            value: _playbackPositionRx.value,
            max: max(0, _positions.length - 1).toDouble(),
            onChanged: (v) { _playbackPositionRx.value = v; _updatePlaybackUI(); },
          )),
          Row(
            children: [
              IconButton.filled(
                onPressed: _togglePlayback,
                icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30),
              ),
              const Spacer(),
              _buildSpeedSelector(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalPlaybackPanel() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 2, 14, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: _togglePlayback,
            icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Obx(() {
              final int idx = _playbackPositionRx.value.floor().clamp(0, max(0, _positions.length - 1));
              final pos = _positions.isEmpty ? null : _positions[idx];
              final speed = pos != null ? ((pos.speed ?? 0) * 1.852).toStringAsFixed(1) : "0.0";
              return Text("$speed km/h", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.primary));
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(children: [Icon(icon, size: 14), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 11))]),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSpeedSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: _playbackSpeeds.map((s) {
          bool selected = _playbackSpeed == s;
          return GestureDetector(
            onTap: () { _safeSetState(() => _playbackSpeed = s); _savePlaybackSpeedToHive(s); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${s.toInt()}x', style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _fetchMonthlyData(DateTime month) async {
    if (_deviceId == null) return;
    _safeSetState(() { _isCalendarLoading = true; _focusedDay = month; });
    await Future.delayed(const Duration(milliseconds: 300));
    _safeSetState(() { _isCalendarLoading = false; });
  }

  void _showCalendarDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: SizedBox(
          width: 340,
          height: 400,
          child: TableCalendar(
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.now(),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(_selectedCalendarDay, d),
            onDaySelected: (sel, foc) {
              _safeSetState(() { _selectedCalendarDay = sel; _focusedDay = foc; });
              _fetchHistoryRoute(selectedDay: sel);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }
}