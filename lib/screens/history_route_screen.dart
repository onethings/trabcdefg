// lib/screens/history_route_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  return [(255 * _interpolateChannel(normalizedValue, _turboRedCoeffs)).round(), (255 * _interpolateChannel(normalizedValue, _turboGreenCoeffs)).round(), (255 * _interpolateChannel(normalizedValue, _turboBlueCoeffs)).round()];
}

String _getTurboSpeedColor(double speedKmh, double minSpeed, double maxSpeed) {
  if (maxSpeed <= minSpeed) {
    maxSpeed = minSpeed + 1.0;
  }
  final normalizedSpeed = ((speedKmh - minSpeed) / (maxSpeed - minSpeed)).clamp(0.0, 1.0);
  final rgb = _interpolateTurbo(normalizedSpeed);
  return '#${rgb[0].toRadixString(16).padLeft(2, '0')}${rgb[1].toRadixString(16).padLeft(2, '0')}${rgb[2].toRadixString(16).padLeft(2, '0')}';
}

class HistoryRouteScreen extends StatefulWidget {
  const HistoryRouteScreen({super.key});

  @override
  State<HistoryRouteScreen> createState() => _HistoryRouteScreenState();
}

class _HistoryRouteScreenState extends State<HistoryRouteScreen> with TickerProviderStateMixin {
  MapLibreMapController? _mapController;
  List<double> _distancePrefixSum = [];
  final RxString _currentAddressRx = "".obs;

  // 狀態變數
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

  // 地圖資源常量與標示
  static const String _playbackIconId = "playback_arrow";
  static const String _startIconId = "start_pin";
  static const String _endIconId = "end_pin";
  final List<LatLng> _stopPoints = [];

  Symbol? _playbackSymbol;
  int _lastCameraAnimTime = 0;

  // GeoJSON 圖層識別碼
  static const String _routeSourceId = "history_route_source";
  static const String _routeLayerId = "history_route_layer";
  static const String _playedSourceId = "played_route_source";
  static const String _playedLayerId = "played_route_layer";

  @override
  void initState() {
    super.initState();
    _initAnimationController();
    OfflineAddressService.initDatabase();
    cleanExpiredRouteHistory();
    _loadInitialParamsAndFetch();
  }

  void _initAnimationController() {
    _playbackAnimationController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..addListener(_onAnimationTick);
  }

  @override
  void dispose() {
    _playbackAnimationController?.stop();
    _playbackAnimationController?.dispose();
    super.dispose();
  }

  // --- 地圖邏輯 ---

  Future<void> _onStyleLoaded() async {
    await _loadCustomIconsToMap();
    if (_positions.isEmpty) {
      return;
    }
    final bool keepCamera = _keepCameraOnStyleReload;
    _keepCameraOnStyleReload = false;
    await _drawFullRoute(fitBounds: !keepCamera);
  }

  void _toggleMapType() {
    _lastCameraPosition = _mapController?.cameraPosition ?? _lastCameraPosition;
    _keepCameraOnStyleReload = true;
    Provider.of<MapStyleProvider>(context, listen: false).toggleMapType();
  }

  Future<void> _loadCustomIconsToMap() async {
    if (_mapController == null) {
      return;
    }
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
      total += _distanceBetween(_positions[i].latitude!.toDouble(), _positions[i].longitude!.toDouble(), _positions[i + 1].latitude!.toDouble(), _positions[i + 1].longitude!.toDouble());
      _distancePrefixSum.add(total);
    }
  }

  // --- 資料抓取與異步處理 ---

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

    if (!mounted) {
      return;
    }

    setState(() {
      if (lastZoom != null) {
        _currentZoom = lastZoom;
      }
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
    } else {
      developer.log('Missing device ID for history route.', name: 'HistoryRouteScreen');
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
      developer.log('Deleting ${expiredKeys.length} expired route entries.', name: 'HistoryRouteScreen');
      await routeBox.deleteAll(expiredKeys);
    }
  }

  void _calculateStops(List<api.Position> allPositions) {
    _stopPoints.clear();
    if (allPositions.length < 2) {
      return;
    }

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
      if (_stopPoints.length >= 50) {
        break;
      }
    }
  }

  Future<void> _fetchHistoryRoute({DateTime? selectedDay}) async {
    if (selectedDay != null) {
      _historyFrom = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 0, 0, 0);
      _historyTo = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 23, 59, 59);
    }

    if (_deviceId == null || _historyFrom == null || _historyTo == null) {
      return;
    }

    _playbackAnimationController?.stop();
    setState(() {
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
        final bool isExpired = isToday ? diff > const Duration(minutes: 10) : diff > const Duration(days: 60);
        isCacheValid = !isExpired;
      }

      if (isCacheValid) {
        debugPrint('從快取載入: $hiveKey');
        fetchedPositions = RoutePositionsHive.fromJsonList(cachedRoute!.positionsJson);
      } else {
        debugPrint('從網路抓取: $hiveKey');

        if (!mounted) {
          return;
        }
        fetchedFromNetwork = true;
        final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);

        fetchedPositions = await api.PositionsApi(traccarProvider.apiClient).getPositions(deviceId: _deviceId, from: _historyFrom!.toUtc(), to: _historyTo!.toUtc()) ?? [];
      }

      final cleanedPositions = PositionCleaner.clean(fetchedPositions);
      if (cleanedPositions.length != fetchedPositions.length) {
        developer.log('Cleaned track: ${fetchedPositions.length} -> ${cleanedPositions.length} points', name: 'HistoryRouteScreen');
      }
      if (fetchedFromNetwork && cleanedPositions.isNotEmpty) {
        await routeBox.put(hiveKey, RoutePositionsHive(dateKey: hiveKey, positionsJson: RoutePositionsHive.toJsonList(cleanedPositions), cachedAt: DateTime.now()));
      }

      _calculateStops(cleanedPositions);

      final movingPositions = cleanedPositions.where((p) => (p.speed ?? 0) > 0).toList();
      final playbackPositions = movingPositions.isNotEmpty ? movingPositions : cleanedPositions;

      if (mounted) {
        setState(() {
          _positions = playbackPositions;
          _isLoading = false;
        });

        _calculateDistancePrefixSum();

        if (_mapController != null) {
          _drawFullRoute();
        }
      }
    } catch (e) {
      debugPrint('獲取軌跡失敗: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        Get.snackbar("Error", "Failed to fetch route data");
      }
    }
  }

  // --- 高效能 GeoJSON 地圖繪製與動畫播放 ---

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
  }

  Future<void> _drawFullRoute({bool fitBounds = true}) async {
    if (_mapController == null || _positions.isEmpty) {
      return;
    }

    await _cleanMapLayers();

    final List<LatLng> points = _positions.map((p) => LatLng(p.latitude!.toDouble(), p.longitude!.toDouble())).toList();

    // 1. 建立背景軌跡 (使用 GeoJSON Source 與 LineLayer 實現極速渲染)
    final Map<String, dynamic> routeGeoJson = _buildFullRouteGeoJson();
    await _mapController!.addSource(_routeSourceId, GeojsonSourceProperties(data: routeGeoJson));
    await _mapController!.addLineLayer(_routeSourceId, _routeLayerId, LineLayerProperties(lineColor: ['get', 'color'], lineWidth: 4.0, lineOpacity: 0.8, lineJoin: 'round', lineCap: 'round'));

    // 2. 建立已播放軌跡圖層 (動態更新)
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
    await _mapController!.addLineLayer(_playedSourceId, _playedLayerId, LineLayerProperties(lineColor: '#0F53FE', lineWidth: 5.5, lineOpacity: 1.0, lineJoin: 'round', lineCap: 'round'));

    // 3. 繪製起終點標籤與停靠點
    _addMarker(points.first, _startIconId);
    _addMarker(points.last, _endIconId);

    if (_positions.isNotEmpty) {
      _playbackSymbol = await _mapController!.addSymbol(SymbolOptions(geometry: LatLng(_positions.first.latitude!.toDouble(), _positions.first.longitude!.toDouble()), iconImage: _playbackIconId, iconSize: 1.8, zIndex: 10));
    }

    for (int i = 0; i < _stopPoints.length; i++) {
      await _mapController!.addSymbol(SymbolOptions(geometry: _stopPoints[i], iconImage: "pg_${i + 1}", iconSize: 3.5, iconAnchor: "center"));
    }

    if (fitBounds) {
      _animateCameraToBounds();
    }
  }

  Map<String, dynamic> _buildFullRouteGeoJson() {
    double minSpeed = 0;
    double maxSpeed = 120.0;
    if (_routeColorMode == RouteColorMode.speedStatus && _positions.isNotEmpty) {
      final speeds = _positions.map((p) => (p.speed ?? 0) * 1.852).toList();
      minSpeed = speeds.reduce(min);
      maxSpeed = speeds.reduce(max);
    }

    String getColor(api.Position p) {
      final speedKmh = (p.speed ?? 0) * 1.852;
      if (_routeColorMode == RouteColorMode.speedStatus) {
        return _getTurboSpeedColor(speedKmh, minSpeed, maxSpeed);
      } else if (_routeColorMode == RouteColorMode.timeGradient) {
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

    if (_routeColorMode == RouteColorMode.single) {
      final coords = _positions.map((p) => [p.longitude!.toDouble(), p.latitude!.toDouble()]).toList();
      features.add({
        "type": "Feature",
        "properties": {"color": "#808080"},
        "geometry": {"type": "LineString", "coordinates": coords},
      });
    } else {
      for (int i = 0; i < _positions.length - 1; i++) {
        final p1 = _positions[i];
        final p2 = _positions[i + 1];
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

  void _setRouteColorMode(RouteColorMode mode) {
    setState(() {
      _routeColorMode = mode;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('route_color_mode', mode.name);
    });
    if (_positions.isNotEmpty) {
      _drawFullRoute(fitBounds: false);
    }
  }

  void _showColorModeMenu() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'routeColorModeTitle'.tr,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.lens, color: Color(0xFF0F53FE)),
              title: Text('routeColorModeSingle'.tr),
              subtitle: Text('routeColorModeSingleDesc'.tr),
              trailing: _routeColorMode == RouteColorMode.single ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                Navigator.pop(context);
                _setRouteColorMode(RouteColorMode.single);
              },
            ),
            ListTile(
              leading: Container(
                width: 36,
                height: 12,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF350A66), Color(0xFF3858E9), Color(0xFF2490EA), Color(0xFF1EC0AC), Color(0xFF7FE23E), Color(0xFFFDE725)]),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              title: Text('routeColorModeSpeedStatus'.tr),
              trailing: _routeColorMode == RouteColorMode.speedStatus ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                Navigator.pop(context);
                _setRouteColorMode(RouteColorMode.speedStatus);
              },
            ),
            ListTile(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.lens, size: 12, color: Color(0xFF85C1E9)),
                  SizedBox(width: 4),
                  Icon(Icons.lens, size: 12, color: Color(0xFF3498DB)),
                  SizedBox(width: 4),
                  Icon(Icons.lens, size: 12, color: Color(0xFF1B4F72)),
                ],
              ),
              title: Text('routeColorModeTimeGradient'.tr),
              subtitle: Text('routeColorModeTimeGradientDesc'.tr),
              trailing: _routeColorMode == RouteColorMode.timeGradient ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                Navigator.pop(context);
                _setRouteColorMode(RouteColorMode.timeGradient);
              },
            ),
            const SizedBox(height: 12),
          ],
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
      setState(() => _isPlaying = false);
      return;
    }

    final double maxLimit = max(0, _positions.length - 1).toDouble();
    if (_playbackPositionRx.value >= maxLimit) {
      _playbackPositionRx.value = 0;
      _updatePlaybackUI();
    }

    if (_playbackPositionRx.value == 0) {
      _followUser = true;
      final startPoint = LatLng(_positions.first.latitude!.toDouble(), _positions.first.longitude!.toDouble());
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(startPoint, 16.0), duration: const Duration(milliseconds: 800));
    }

    setState(() => _isPlaying = true);
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
      setState(() => _isPlaying = false);
    } else {
      _playbackPositionRx.value = nextVal;
    }

    _updatePlaybackUI();
  }

  void _updatePlaybackUI() async {
    if (_mapController == null || _positions.isEmpty || _playbackSymbol == null) {
      return;
    }

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

    if (_currentAddressRx.value == "" || idx % 20 == 0) {
      OfflineAddressService.getAddress(p1.latitude!.toDouble(), p1.longitude!.toDouble()).then((addr) {
        _currentAddressRx.value = addr;
      });
    }

    // 更新行進中的小車標記
    _mapController!.updateSymbol(_playbackSymbol!, SymbolOptions(geometry: currentLatLng, iconRotate: bearing));

    // 高效更新已播放軌跡 GeoJSON 數據 (使用正確的 setGeoJsonSource 方法)
    final List<List<double>> playedCoords = [];
    for (int i = 0; i <= idx; i++) {
      playedCoords.add([_positions[i].longitude!.toDouble(), _positions[i].latitude!.toDouble()]);
    }
    playedCoords.add([smoothLng, smoothLat]);

    final Map<String, dynamic> updatedPlayedGeoJson = {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "geometry": {"type": "LineString", "coordinates": playedCoords},
        },
      ],
    };
    await _mapController!.setGeoJsonSource(_playedSourceId, updatedPlayedGeoJson);

    // 相機跟隨與節流機制
    if (_followUser) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastCameraAnimTime > 600) {
        _lastCameraAnimTime = now;
        LatLngBounds? visibleRegion = await _mapController!.getVisibleRegion();
        double latSpan = visibleRegion.northeast.latitude - visibleRegion.southwest.latitude;
        double lngSpan = visibleRegion.northeast.longitude - visibleRegion.southwest.longitude;

        double latThreshold = latSpan * 0.2;
        double lngThreshold = lngSpan * 0.2;

        bool isNearEdge =
            currentLatLng.latitude > (visibleRegion.northeast.latitude - latThreshold) ||
            currentLatLng.latitude < (visibleRegion.southwest.latitude + latThreshold) ||
            currentLatLng.longitude > (visibleRegion.northeast.longitude - lngThreshold) ||
            currentLatLng.longitude < (visibleRegion.southwest.longitude + lngThreshold);

        if (isNearEdge) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(currentLatLng), duration: const Duration(milliseconds: 600));
        }
      }
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * pi / 180;
    double lon1 = start.longitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double lon2 = end.longitude * pi / 180;
    return (atan2(sin(lon2 - lon1) * cos(lat2), cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lon2 - lon1)) * 180 / pi + 360) % 360;
  }

  void _animateCameraToBounds() {
    if (_positions.isEmpty) {
      return;
    }
    double minLat = _positions.map((p) => p.latitude!).reduce(min).toDouble();
    double maxLat = _positions.map((p) => p.latitude!).reduce(max).toDouble();
    double minLon = _positions.map((p) => p.longitude!).reduce(min).toDouble();
    double maxLon = _positions.map((p) => p.longitude!).reduce(max).toDouble();

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(minLat, minLon), northeast: LatLng(maxLat, maxLon)), left: 70, right: 70, top: 70, bottom: 250));
  }

  double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var a = 0.5 - cos((lat2 - lat1) * p) / 2 + cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // --- UI 元件建立 ---

  @override
  Widget build(BuildContext context) {
    String devicePart = _selectedDeviceName != null ? ' | (${_selectedDeviceName!})' : '';
    final double safeTop = MediaQuery.of(context).padding.top;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _isMinimalMode
          ? null
          : AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
              elevation: 0,
              title: Text(
                '${'reportReplay'.tr}: ${DateFormat('MM/dd').format(_historyFrom ?? DateTime.now())}$devicePart',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
            ),
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
              SharedPreferences.getInstance().then((prefs) {
                prefs.setDouble('history_zoom_level', position.zoom);
              });
            },
            myLocationEnabled: false,
            trackCameraPosition: true,
            onMapClick: (_, _) {
              setState(() => _followUser = false);
            },
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            top: safeTop + (_isMinimalMode ? 12 : 60),
            left: 12,
            child: _mapFab(
              _isMinimalMode ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
              () => setState(() => _isMinimalMode = !_isMinimalMode),
              "btn_minimal",
              active: _isMinimalMode,
              tooltip: _isMinimalMode ? 'standardViewMode'.tr : 'minimalViewMode'.tr,
            ),
          ),

          if (!_isMinimalMode) ...[
            Positioned(
              top: safeTop + 60,
              right: 12,
              child: Column(
                children: [
                  _mapFab(Icons.palette_rounded, _showColorModeMenu, "btn_color_mode", active: _routeColorMode != RouteColorMode.single, tooltip: 'routeColorModeTooltip'.tr),
                  const SizedBox(height: 12),
                  _mapFab(Icons.calendar_month, _showCalendarDialog, "btn_cal"),
                  const SizedBox(height: 12),
                  _mapFab(Provider.of<MapStyleProvider>(context).isSatelliteMode ? Icons.map : Icons.satellite_alt, _toggleMapType, "btn_style"),
                  const SizedBox(height: 12),
                  _mapFab(
                    Icons.center_focus_strong,
                    () {
                      setState(() => _followUser = true);
                      _animateCameraToBounds();
                    },
                    "btn_recenter",
                    active: _followUser,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              right: 12,
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: 1.0,
                child: Column(mainAxisSize: MainAxisSize.min, children: [_mapFab(Icons.add, () => _zoomMap(1), "btn_zoom_in"), const SizedBox(height: 8), _mapFab(Icons.remove, () => _zoomMap(-1), "btn_zoom_out")]),
              ),
            ),
          ],
          _buildPlaybackPanel(),
        ],
      ),
    );
  }

  void _zoomMap(double delta) {
    final controller = _mapController;
    if (controller == null) {
      return;
    }
    final double current = controller.cameraPosition?.zoom ?? _currentZoom;
    final double target = (current + delta).clamp(2.0, 20.0);
    if (target == current) {
      return;
    }
    controller.animateCamera(CameraUpdate.zoomTo(target), duration: const Duration(milliseconds: 250));
  }

  Widget _mapFab(IconData icon, VoidCallback onPressed, String tag, {bool active = false, String? tooltip}) {
    final theme = Theme.of(context);
    final bgColor = active ? const Color(0xFF0F53FE) : theme.colorScheme.surface;
    final iconColor = active ? Colors.white : theme.colorScheme.onSurface;

    return FloatingActionButton(
      heroTag: tag,
      mini: true,
      tooltip: tooltip,
      backgroundColor: bgColor,
      onPressed: onPressed,
      child: Icon(icon, color: iconColor),
    );
  }

  Widget _buildPlaybackPanel() {
    return Positioned(
      bottom: 24 + MediaQuery.of(context).padding.bottom,
      left: 16,
      right: 16,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(alignment: Alignment.bottomCenter, children: [...previousChildren, ?currentChild]),
        child: _isMinimalMode ? _buildMinimalPlaybackPanel() : _buildFullPlaybackPanel(),
      ),
    );
  }

  Widget _buildFullPlaybackPanel() {
    return Container(
      key: const ValueKey('history_playback_panel_full'),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(
            () => Text(
              _currentAddressRx.value.isEmpty ? 'sharedLocating'.tr : _currentAddressRx.value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Obx(() {
            final int idx = _playbackPositionRx.value.floor().clamp(0, max(0, _positions.length - 1));
            final pos = _positions.isEmpty ? null : _positions[idx];
            final recordedAt = pos == null ? null : PositionCleaner.recordingTime(pos);
            final time = recordedAt != null ? DateFormat('HH:mm:ss').format(recordedAt.toLocal()) : "--:--:--";
            final speed = pos != null ? ((pos.speed ?? 0) * 1.852).toStringAsFixed(1) : "0.0";
            final distance = _getDistanceFormatted(idx);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [_buildStatItem("positionDrivingTime".tr, time, CupertinoIcons.clock), _buildStatItem("positionSpeed".tr, "$speed ${'sharedKmh'.tr}", Icons.speed_rounded), _buildStatItem("sharedDistance".tr, distance, Icons.straighten)],
            );
          }),
          const SizedBox(height: 8),
          Obx(() {
            final double maxVal = max(0, _positions.length - 1).toDouble();
            return SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8), overlayShape: const RoundSliderOverlayShape(overlayRadius: 16)),
              child: Slider(
                value: _playbackPositionRx.value,
                max: maxVal,
                onChanged: (v) {
                  _playbackPositionRx.value = v;
                  _updatePlaybackUI();
                },
                activeColor: Theme.of(context).colorScheme.primary,
                inactiveColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              ),
            );
          }),
          Row(
            children: [
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, minimumSize: const Size(50, 50)),
                onPressed: _togglePlayback,
                icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 30),
              ),
              const Spacer(),
              _buildSpeedSelector(),
              const SizedBox(width: 12),
              IconButton.outlined(onPressed: _exportToGPX, icon: const Icon(Icons.download_rounded, size: 20), tooltip: "Export GPX"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalPlaybackPanel() {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('history_playback_panel_minimal'),
      padding: const EdgeInsets.fromLTRB(10, 2, 14, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: theme.brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() {
            final double maxVal = max(0, _positions.length - 1).toDouble();
            return SizedBox(
              height: 18,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  activeTrackColor: theme.colorScheme.primary,
                  inactiveTrackColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                ),
                child: Slider(
                  value: _playbackPositionRx.value,
                  max: maxVal,
                  onChanged: (v) {
                    _playbackPositionRx.value = v;
                    _updatePlaybackUI();
                  },
                ),
              ),
            );
          }),
          Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: theme.colorScheme.primary, minimumSize: const Size(40, 40), padding: EdgeInsets.zero),
                  onPressed: _togglePlayback,
                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: theme.colorScheme.onPrimary, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(() {
                  final int idx = _playbackPositionRx.value.floor().clamp(0, max(0, _positions.length - 1));
                  final pos = _positions.isEmpty ? null : _positions[idx];
                  final recordedAt = pos == null ? null : PositionCleaner.recordingTime(pos);
                  final time = recordedAt != null ? DateFormat('MM/dd HH:mm:ss').format(recordedAt.toLocal()) : "--/-- --:--:--";
                  final speed = pos != null ? ((pos.speed ?? 0) * 1.852).toStringAsFixed(1) : "0.0";
                  return Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          time,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface, letterSpacing: -0.2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 2,
                        child: Text(
                          "$speed ${'sharedKmh'.tr}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _exportToGPX() async {
    if (_positions.isEmpty) {
      Get.snackbar("Error", "No track data to export");
      return;
    }

    final deviceName = _selectedDeviceName ?? "Device";
    final date = DateFormat('yyyy-MM-dd').format(_historyFrom ?? DateTime.now());

    StringBuffer gpx = StringBuffer();
    gpx.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    gpx.writeln('<gpx version="1.1" creator="Trabcdefg" xmlns="http://www.topografix.com/GPX/1/1">');
    gpx.writeln('  <trk>');
    gpx.writeln('    <name>$deviceName - $date</name>');
    gpx.writeln('    <trkseg>');

    for (var p in _positions) {
      final timeStr = p.serverTime?.toUtc().toIso8601String() ?? "";
      gpx.writeln('      <trkpt lat="${p.latitude}" lon="${p.longitude}">');
      gpx.writeln('        <time>$timeStr</time>');
      if (p.speed != null) {
        gpx.writeln('        <speed>${p.speed}</speed>');
      }
      gpx.writeln('      </trkpt>');
    }

    gpx.writeln('    </trkseg>');
    gpx.writeln('  </trk>');
    gpx.writeln('</gpx>');

    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${deviceName}_$date.gpx');
      await file.writeAsString(gpx.toString());

      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'GPX Export for $deviceName'));
    } catch (e) {
      Get.snackbar("Export Failed", e.toString());
    }
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, letterSpacing: -0.5),
        ),
      ],
    );
  }

  String _getDistanceFormatted(int currentIndex) {
    if (_distancePrefixSum.isEmpty || currentIndex >= _distancePrefixSum.length) {
      return "0.00 ${'sharedKm'.tr}";
    }
    return "${_distancePrefixSum[currentIndex].toStringAsFixed(2)} ${'sharedKm'.tr}";
  }

  Widget _buildSpeedSelector() {
    final speeds = [1.0, 5.0, 10.0, 20.0];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: speeds.map((s) {
          bool selected = _playbackSpeed == s;
          return GestureDetector(
            onTap: () => setState(() => _playbackSpeed = s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : [],
              ),
              child: Text(
                '${s.toInt()}x',
                style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- 日曆邏輯 ---

  Future<void> _fetchMonthlyData(DateTime month) async {
    if (_deviceId == null) {
      return;
    }

    if (_dailySummaries.isNotEmpty && month.month == _focusedDay.month && month.year == _focusedDay.year) {
      return;
    }

    setState(() {
      _isCalendarLoading = true;
      _focusedDay = month;
    });

    if (!mounted) {
      return;
    }
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    final reportsApi = api.ReportsApi(traccarProvider.apiClient);
    final dailyBox = await Hive.openBox<ReportSummaryHive>('daily_summaries');
    final serverVersion = await traccarProvider.fetchServerVersion();
    final today = DateTime.now();

    developer.log('Server version: $serverVersion — fetching monthly data for ${month.year}-${month.month}', name: 'HistoryRouteScreen');

    _dailySummaries.clear();
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    for (var date = firstDayOfMonth; date.isBefore(lastDayOfMonth.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      final dayUtc = DateTime.utc(date.year, date.month, date.day);
      final String hiveKey = '${_deviceId}_${DateFormat('yyyy-MM-dd').format(dayUtc)}';
      final cachedSummary = dailyBox.get(hiveKey);

      if (cachedSummary != null) {
        final distance = cachedSummary.distance ?? 0;
        final engineHours = cachedSummary.engineHours ?? 0;
        if (date.isAfter(today) && distance <= 0 && engineHours <= 0) {
          developer.log('Skipping stale zero cache for future date: ${DateFormat('yyyy-MM-dd').format(date)}', name: 'HistoryRouteScreen');
          await dailyBox.delete(hiveKey);
          continue;
        }
        _dailySummaries[dayUtc] = api.ReportSummary(distance: cachedSummary.distance, averageSpeed: cachedSummary.averageSpeed, maxSpeed: cachedSummary.maxSpeed, spentFuel: cachedSummary.spentFuel, engineHours: cachedSummary.engineHours);
      }
    }

    setState(() {
      _isCalendarLoading = false;
    });

    for (var date = firstDayOfMonth; date.isBefore(lastDayOfMonth.add(const Duration(days: 15))); date = date.add(const Duration(days: 1))) {
      final dayUtc = DateTime.utc(date.year, date.month, date.day);

      if (date.isAfter(today)) {
        developer.log('Skipping future date (no network fetch): ${DateFormat('yyyy-MM-dd').format(date)}', name: 'HistoryRouteScreen');
        continue;
      }

      if (_dailySummaries.containsKey(dayUtc)) {
        continue;
      }

      final from = DateTime(date.year, date.month, date.day, 0, 0, 0).toUtc();
      final to = DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc();
      final String hiveKey = '${_deviceId}_${DateFormat('yyyy-MM-dd').format(dayUtc)}';

      try {
        api.ReportSummary? dailySummary;
        try {
          final summary = await reportsApi.getReportsSummary(from, to, deviceId: [_deviceId!]);
          if (summary != null && summary.isNotEmpty) {
            dailySummary = summary.first;
          }
        } catch (e) {
          developer.log('Generated API failed, trying raw API fallback: $e', name: 'HistoryRouteScreen');
          try {
            final response = await traccarProvider.apiClient.invokeAPI(
              '/reports/summary',
              'GET',
              [api.QueryParam('from', from.toIso8601String()), api.QueryParam('to', to.toIso8601String()), api.QueryParam('deviceId', _deviceId.toString())],
              null,
              {},
              {},
              'application/json',
            );
            if (response.body.isNotEmpty) {
              final decoded = json.decode(response.body) as List?;
              if (decoded != null && decoded.isNotEmpty) {
                final raw = decoded.first as Map<String, dynamic>;
                dailySummary = api.ReportSummary(
                  distance: (raw['distance'] as num?)?.toDouble(),
                  averageSpeed: (raw['averageSpeed'] as num?)?.toDouble(),
                  maxSpeed: (raw['maxSpeed'] as num?)?.toDouble(),
                  spentFuel: (raw['spentFuel'] as num?)?.toDouble(),
                  engineHours: raw['engineHours'] as int?,
                );
              }
            }
          } catch (e2) {
            developer.log('Raw API fallback also failed for day $date: $e2', name: 'HistoryRouteScreen');
          }
        }

        if (dailySummary != null) {
          developer.log('Fetched summary for ${DateFormat('yyyy-MM-dd').format(date)}: distance=${dailySummary.distance}, engineHours=${dailySummary.engineHours}, avgSpeed=${dailySummary.averageSpeed}', name: 'HistoryRouteScreen');
          _dailySummaries[dayUtc] = dailySummary;

          await dailyBox.put(hiveKey, ReportSummaryHive.fromApi(dailySummary));
          if (mounted) {
            setState(() {});
          }
        } else {
          developer.log('  → empty result (no data for this day)', name: 'HistoryRouteScreen');
        }
      } catch (e) {
        developer.log('Failed to fetch data for day $date: $e', name: 'HistoryRouteScreen');
      }
    }
  }

  void _showCalendarDialog() async {
    if (_deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('pleaseSelectDevice'.tr)));
      return;
    }

    final currentLocale = Get.locale;
    if (currentLocale != null) {
      final localeString = currentLocale.toString();
      await initializeDateFormatting(localeString, null);
    }

    _fetchMonthlyData(_focusedDay);

    if (!mounted) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) {
          return AlertDialog(
            contentPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: SizedBox(
              width: 340,
              height: 520,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  if (_isCalendarLoading) const LinearProgressIndicator(),
                  Expanded(
                    child: TableCalendar(
                      locale: Get.locale?.languageCode,
                      firstDay: DateTime.utc(2020),
                      lastDay: DateTime.now(),
                      focusedDay: _focusedDay,
                      daysOfWeekHeight: 24,
                      selectedDayPredicate: (d) => isSameDay(_selectedCalendarDay, d),
                      onPageChanged: (focusedDay) {
                        modalSetState(() {
                          _focusedDay = focusedDay;
                        });
                        _fetchMonthlyData(focusedDay).then((_) {
                          if (mounted) {
                            modalSetState(() {});
                          }
                        });
                      },
                      onDaySelected: (sel, foc) {
                        _onDaySelected(sel, foc);
                        Navigator.pop(context);
                      },
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          final dayUtc = DateTime.utc(date.year, date.month, date.day);

                          if (_dailySummaries.containsKey(dayUtc)) {
                            final summary = _dailySummaries[dayUtc]!;
                            final distanceInKm = (summary.distance ?? 0.0) / 1000;

                            if (distanceInKm <= 0) {
                              return null;
                            }

                            return Positioned(
                              bottom: 4,
                              child: Text(
                                '${distanceInKm.toStringAsFixed(1)} km',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isSameDay(_selectedCalendarDay, date) ? Colors.white : Colors.blue[700]),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5), shape: BoxShape.circle),
                        selectedDecoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                        defaultTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        weekendTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                        outsideTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                        cellMargin: const EdgeInsets.all(4),
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 17, fontWeight: FontWeight.bold),
                        leftChevronIcon: Icon(Icons.chevron_left, color: Theme.of(context).colorScheme.primary),
                        rightChevronIcon: Icon(CupertinoIcons.chevron_right, color: Theme.of(context).colorScheme.primary),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                        weekendStyle: TextStyle(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8), fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedCalendarDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _fetchHistoryRoute(selectedDay: selectedDay);
  }
}
