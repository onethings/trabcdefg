// lib/screens/history_route_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

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
import 'package:trabcdefg/widgets/offline_address_service.dart';

enum OSMMapType { normal, satellite }

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
  Timer? _playbackTimer;
  double _playbackSpeed = 1.0;

  int? _deviceId;
  DateTime? _historyFrom;
  DateTime? _historyTo;
  String? _selectedDeviceName;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedCalendarDay = DateTime.now();
  final Map<DateTime, api.ReportSummary> _dailySummaries = {};
  bool _isCalendarLoading = false;
  double _currentZoom = 14.0;

  // 地圖資源
  static const String _playbackIconId = "playback_arrow";
  static const String _startIconId = "start_pin";
  static const String _endIconId = "end_pin";
  final List<LatLng> _stopPoints = [];

  Symbol? _playbackSymbol;
  Line? _playedLine;

  @override
  void initState() {
    super.initState();
    OfflineAddressService.initDatabase();
    cleanExpiredRouteHistory();
    _loadInitialParamsAndFetch();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  // --- 地圖邏輯 ---

  Future<void> _onStyleLoaded() async {
    await _loadCustomIconsToMap();
    if (_positions.isNotEmpty) {
      _drawFullRoute();
    }
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

    DateTime defaultDate = DateTime.now();

    // ✨ 已確認：嚴格落實大括號區塊區隔，後面無贅餘分號
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

      if (p1.serverTime != null && p2.serverTime != null) {
        final diff = p2.serverTime!.difference(p1.serverTime!);
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

    _playbackTimer?.cancel();
    setState(() {
      _isLoading = true;
      _isPlaying = false;
      _positions = [];
      _playbackPositionRx.value = 0.0;
    });

    List<api.Position> fetchedPositions = [];
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
        final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);

        fetchedPositions = await api.PositionsApi(traccarProvider.apiClient).getPositions(deviceId: _deviceId, from: _historyFrom!.toUtc(), to: _historyTo!.toUtc()) ?? [];

        if (fetchedPositions.isNotEmpty) {
          await routeBox.put(hiveKey, RoutePositionsHive(dateKey: hiveKey, positionsJson: RoutePositionsHive.toJsonList(fetchedPositions), cachedAt: DateTime.now()));
        }
      }

      final originalPositions = List<api.Position>.from(fetchedPositions);
      final filteredPositions = fetchedPositions.where((p) => (p.speed ?? 0) > 0).toList();
      if (filteredPositions.isNotEmpty) {
        fetchedPositions = filteredPositions;
      }

      _calculateStops(originalPositions);

      if (mounted) {
        setState(() {
          _positions = fetchedPositions;
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

  // --- 繪製與動畫播放 ---

  Future<void> _drawFullRoute() async {
    if (_mapController == null || _positions.isEmpty) {
      return;
    }

    await _mapController!.clearLines();
    await _mapController!.clearSymbols();

    List<LatLng> points = _positions.map((p) => LatLng(p.latitude!.toDouble(), p.longitude!.toDouble())).toList();

    await _mapController!.addLine(LineOptions(geometry: points, lineColor: "#808080", lineWidth: 3.0, lineOpacity: 0.5));

    _playedLine = await _mapController!.addLine(const LineOptions(geometry: [], lineColor: "#0F53FE", lineWidth: 5.0, lineJoin: "round"));

    _addMarker(points.first, _startIconId);
    _addMarker(points.last, _endIconId);

    if (_positions.isNotEmpty) {
      _playbackSymbol = await _mapController!.addSymbol(SymbolOptions(geometry: LatLng(_positions.first.latitude!.toDouble(), _positions.first.longitude!.toDouble()), iconImage: _playbackIconId, iconSize: 1.2, zIndex: 10));
    }

    for (int i = 0; i < _stopPoints.length; i++) {
      await _mapController!.addSymbol(SymbolOptions(geometry: _stopPoints[i], iconImage: "pg_${i + 1}", iconSize: 1.2, iconAnchor: "center"));
    }

    _animateCameraToBounds();
  }

  void _addMarker(LatLng point, String iconId) {
    _mapController?.addSymbol(SymbolOptions(geometry: point, iconImage: iconId, iconSize: 0.8, iconAnchor: "bottom"));
  }

  void _togglePlayback() {
    if (_positions.isEmpty) {
      return;
    }

    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _playbackTimer?.cancel();

      _playbackTimer = Timer.periodic(const Duration(milliseconds: 32), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        final double maxLimit = max(0, _positions.length - 1).toDouble();

        if (_playbackPositionRx.value >= maxLimit) {
          _playbackPositionRx.value = maxLimit;
          timer.cancel();
          if (mounted) {
            setState(() => _isPlaying = false);
          }
        } else {
          double increment = 0.05 * _playbackSpeed;
          _playbackPositionRx.value = (_playbackPositionRx.value + increment).clamp(0.0, maxLimit);

          _updatePlaybackUI();
        }
      });
    } else {
      _playbackTimer?.cancel();
    }
  }

  int _lastCameraUpdateTick = 0;

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

    _mapController!.updateSymbol(_playbackSymbol!, SymbolOptions(geometry: currentLatLng, iconRotate: bearing));

    if (_playedLine != null) {
      final playedPoints = _positions.sublist(0, idx + 1).map((p) => LatLng(p.latitude!.toDouble(), p.longitude!.toDouble())).toList();
      playedPoints.add(currentLatLng);
      _mapController!.updateLine(_playedLine!, LineOptions(geometry: playedPoints));
    }

    if (_followUser) {
      _lastCameraUpdateTick++;
      if (_lastCameraUpdateTick % 10 == 0) {
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
          _mapController!.animateCamera(CameraUpdate.newLatLng(currentLatLng), duration: const Duration(milliseconds: 1500));
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
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
            onMapCreated: (c) => _mapController = c,
            onStyleLoadedCallback: _onStyleLoaded,
            initialCameraPosition: CameraPosition(target: const LatLng(0, 0), zoom: _currentZoom),
            styleString: Provider.of<MapStyleProvider>(context).getStyle(Theme.of(context).brightness),
            onCameraMove: (position) {
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

          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            right: 12,
            child: Column(
              children: [
                _mapFab(Icons.calendar_month, _showCalendarDialog, "btn_cal"),
                const SizedBox(height: 12),
                _mapFab(Provider.of<MapStyleProvider>(context).isSatelliteMode ? Icons.map : Icons.satellite_alt, () => Provider.of<MapStyleProvider>(context, listen: false).toggleMapType(), "btn_style"),
                const SizedBox(height: 12),
                _mapFab(
                  Icons.center_focus_strong,
                  () {
                    setState(() => _followUser = true);
                    _animateCameraToBounds();
                  },
                  "btn_recenter",
                  color: _followUser ? const Color(0xFF0F53FE) : Colors.white,
                ),
              ],
            ),
          ),
          _buildPlaybackPanel(),
        ],
      ),
    );
  }

  Widget _mapFab(IconData icon, VoidCallback onPressed, String tag, {Color? color}) {
    final theme = Theme.of(context);
    final bgColor = color ?? theme.colorScheme.surface;
    final iconColor = color == null ? theme.colorScheme.onSurface : Colors.white;

    return FloatingActionButton(
      heroTag: tag,
      mini: true,
      backgroundColor: bgColor,
      onPressed: onPressed,
      child: Icon(icon, color: iconColor),
    );
  }

  Widget _buildPlaybackPanel() {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Obx(() {
              final int idx = _playbackPositionRx.value.floor().clamp(0, max(0, _positions.length - 1));
              final pos = _positions.isEmpty ? null : _positions[idx];
              final time = pos != null ? DateFormat('HH:mm:ss').format(pos.serverTime!.toLocal()) : "--:--:--";
              final speed = pos != null ? ((pos.speed ?? 0) * 1.852).toStringAsFixed(1) : "0.0";
              final distance = _getDistanceFormatted(idx);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem("positionDrivingTime".tr, time, Icons.access_time_rounded),
                  _buildStatItem("positionSpeed".tr, "$speed ${'sharedKmh'.tr}", Icons.speed_rounded),
                  _buildStatItem("sharedDistance".tr, distance, Icons.straighten),
                ],
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

      // ✨ 符合最新 share_plus 套件的實例化 ShareParams 傳參
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
        // ❗ Old API (e.g., v4.4) may have cached zero-value entries for future dates.
        // Skip cached zero entries for dates after today so they get re-fetched later.
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

    for (var date = firstDayOfMonth; date.isBefore(lastDayOfMonth.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      final dayUtc = DateTime.utc(date.year, date.month, date.day);

      // 🔥 Skip future dates — no data exists yet, and old API (v4.4) incorrectly
      // returns zero-value summaries for future dates that would pollute our cache.
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
          // Try using the generated API first (works on v6.x+)
          final summary = await reportsApi.getReportsSummary(from, to, deviceId: [_deviceId!]);
          if (summary != null && summary.isNotEmpty) {
            dailySummary = summary.first;
          }
        } catch (e) {
          // Fallback for old API (v4.x) — the generated fromJson may fail
          // on missing fields. Use raw API call with manual parsing instead.
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
              height: 460,
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
                        cellMargin: const EdgeInsets.all(6),
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 17, fontWeight: FontWeight.bold),
                        leftChevronIcon: Icon(Icons.chevron_left, color: Theme.of(context).colorScheme.primary),
                        rightChevronIcon: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        weekendStyle: TextStyle(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)),
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
