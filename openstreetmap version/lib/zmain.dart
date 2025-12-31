// lib/screens/history_route_screen.dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trabcdefg/models/report_summary_hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trabcdefg/models/route_positions_hive.dart';

enum OSMMapType { normal, satellite }

class HistoryRouteScreen extends StatefulWidget {
  const HistoryRouteScreen({super.key});

  @override
  State<HistoryRouteScreen> createState() => _HistoryRouteScreenState();
}

class _HistoryRouteScreenState extends State<HistoryRouteScreen> {
  MapLibreMapController? _mapController;

  static const String _streetStyle = "https://tiles.openfreemap.org/styles/liberty";
  static const String _satelliteStyle = '''
{
  "version": 8,
  "sources": {
    "raster-tiles": {
      "type": "raster",
      "tiles": ["https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"],
      "tileSize": 256,
      "attribution": "Esri"
    }
  },
  "layers": [{"id": "simple-tiles", "type": "raster", "source": "raster-tiles"}]
}
''';

  List<api.Position> _positions = [];
  final RxList<api.Position> _movingPositionsRx = <api.Position>[].obs;
  final RxDouble _playbackPositionRx = 0.0.obs;

  bool _isPlaying = false;
  Timer? _playbackTimer;
  OSMMapType _mapType = OSMMapType.normal;
  double _playbackSpeed = 1.0;

  int? _deviceId;
  DateTime? _historyFrom;
  DateTime? _historyTo;
  String? _selectedDeviceName;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedCalendarDay = DateTime.now();
  final Map<DateTime, api.ReportSummary> _dailySummaries = {};
  bool _isCalendarLoading = false;

  static const String _playbackIconId = "playback_arrow";
  static const String _startIconId = "start_pin";
  static const String _endIconId = "end_pin";
  static const String _parkingIconIdPrefix = "parking_";

  Symbol? _playbackSymbol;
  Line? _playedLine;

  @override
  void initState() {
    super.initState();
    _loadInitialParamsAndFetch();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  Future<void> _onStyleLoaded() async {
    await _loadCustomIconsToMap();
    if (_positions.isNotEmpty) {
      _drawFullRoute();
      _animateCameraToRoute();
    }
  }

  Future<void> _loadCustomIconsToMap() async {
    if (_mapController == null) return;
    await _addAssetImage(_playbackIconId, 'assets/images/arrow.png');
    await _addAssetImage(_startIconId, 'assets/images/start.png');
    await _addAssetImage(_endIconId, 'assets/images/destination.png');
    for (int i = 1; i <= 50; i++) {
      await _addAssetImage('$_parkingIconIdPrefix$i', 'assets/images/p_$i.png');
    }
  }

  Future<void> _addAssetImage(String id, String assetPath) async {
    final ByteData bytes = await rootBundle.load(assetPath);
    final Uint8List list = bytes.buffer.asUint8List();
    await _mapController?.addImage(id, list);
  }

  Future<void> _loadInitialParamsAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceId = prefs.getInt('selectedDeviceId');
      _selectedDeviceName = prefs.getString('selectedDeviceName');
      _historyFrom = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day, 0, 0, 0);
      _historyTo = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day, 23, 59, 59);
    });
    if (_deviceId != null) {
      _fetchHistoryRoute();
      _fetchMonthlyData(_focusedDay);
    }
  }

  Future<void> _fetchHistoryRoute({DateTime? selectedDay}) async {
    if (selectedDay != null) {
      _historyFrom = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 0, 0, 0);
      _historyTo = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, 23, 59, 59);
    }
    if (_deviceId == null) return;

    _playbackTimer?.cancel();
    setState(() => _isPlaying = false);
    _playbackPositionRx.value = 0.0;

    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    try {
      final fetched = await api.PositionsApi(traccarProvider.apiClient).positionsGet(
            deviceId: _deviceId,
            from: _historyFrom!.toUtc(),
            to: _historyTo!.toUtc(),
          ) ??
          [];

      setState(() {
        _positions = fetched;
        _movingPositionsRx.assignAll(fetched.where((p) => (p.speed ?? 0.0) > 2.0).toList());
      });

      if (_mapController != null) _drawFullRoute();
    } catch (e) {
      debugPrint('Fetch failed: $e');
    }
  }

  Future<void> _drawFullRoute() async {
    if (_mapController == null || _positions.isEmpty) return;

    await _mapController!.clearLines();
    await _mapController!.clearSymbols();

    List<LatLng> points = _positions.map((p) => LatLng(p.latitude!.toDouble(), p.longitude!.toDouble())).toList();

    await _mapController!.addLine(LineOptions(geometry: points, lineColor: "#808080", lineWidth: 4.0, lineOpacity: 0.4));
    _playedLine = await _mapController!.addLine(const LineOptions(geometry: [], lineColor: "#0F53FE", lineWidth: 5.0, lineJoin: "round"));

    for (int i = 0; i < _positions.length; i++) {
      final pos = _positions[i];
      final latLng = LatLng(pos.latitude!.toDouble(), pos.longitude!.toDouble());
      if (i == 0) {
        _addSymbol(latLng, _startIconId);
      } else if (i == _positions.length - 1) {
        _addSymbol(latLng, _endIconId);
      } else if ((pos.speed ?? 0.0) <= 2.0) {
        _addSymbol(latLng, '$_parkingIconIdPrefix${(i % 50) + 1}');
      }
    }

    if (_movingPositionsRx.isNotEmpty) {
      _playbackSymbol = await _mapController!.addSymbol(SymbolOptions(
        geometry: LatLng(_movingPositionsRx.first.latitude!.toDouble(), _movingPositionsRx.first.longitude!.toDouble()),
        iconImage: _playbackIconId,
        iconSize: 1.0,
        zIndex: 10,
      ));
    }
    _animateCameraToRoute();
  }

  void _addSymbol(LatLng point, String iconId) {
    _mapController?.addSymbol(SymbolOptions(geometry: point, iconImage: iconId, iconSize: 0.8, iconAnchor: "bottom"));
  }

  void _togglePlayback() {
    if (_movingPositionsRx.isEmpty) return;
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _playbackTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
          final double maxLimit = max(0, _movingPositionsRx.length - 1).toDouble();
          if (_playbackPositionRx.value >= maxLimit) {
            _playbackPositionRx.value = maxLimit;
            timer.cancel();
            setState(() => _isPlaying = false);
          } else {
            _playbackPositionRx.value = (_playbackPositionRx.value + 0.1 * _playbackSpeed).clamp(0.0, maxLimit);
            _updatePlaybackUI();
          }
        });
      } else {
        _playbackTimer?.cancel();
      }
    });
  }

  void _updatePlaybackUI() async {
    if (_mapController == null || _movingPositionsRx.isEmpty || _playbackSymbol == null) return;

    final double pos = _playbackPositionRx.value;
    final int idx = pos.floor().clamp(0, _movingPositionsRx.length - 1);
    final int nextIdx = (idx + 1).clamp(0, _movingPositionsRx.length - 1);
    final double fraction = pos - idx;

    final p1 = _movingPositionsRx[idx];
    final p2 = _movingPositionsRx[nextIdx];

    final double smoothLat = p1.latitude!.toDouble() + (p2.latitude!.toDouble() - p1.latitude!.toDouble()) * fraction;
    final double smoothLng = p1.longitude!.toDouble() + (p2.longitude!.toDouble() - p1.longitude!.toDouble()) * fraction;
    final currentLatLng = LatLng(smoothLat, smoothLng);

    double bearing = 0;
    if (idx < _movingPositionsRx.length - 1) {
      bearing = _calculateBearing(LatLng(p1.latitude!.toDouble(), p1.longitude!.toDouble()), LatLng(p2.latitude!.toDouble(), p2.longitude!.toDouble()));
    }

    await _mapController!.updateSymbol(_playbackSymbol!, SymbolOptions(geometry: currentLatLng, iconRotate: bearing));

    if (_playedLine != null) {
      final playedPoints = _movingPositionsRx.sublist(0, idx + 1).map((p) => LatLng(p.latitude!.toDouble(), p.longitude!.toDouble())).toList();
      playedPoints.add(currentLatLng);
      await _mapController!.updateLine(_playedLine!, LineOptions(geometry: playedPoints));
    }

    _mapController!.animateCamera(CameraUpdate.newLatLng(currentLatLng));
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * pi / 180;
    double lon1 = start.longitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double lon2 = end.longitude * pi / 180;
    return (atan2(sin(lon2 - lon1) * cos(lat2), cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(lon2 - lon1)) * 180 / pi + 360) % 360;
  }

  void _animateCameraToRoute() {
    if (_positions.isEmpty) return;
    double minLat = _positions.map((p) => p.latitude!).reduce(min).toDouble();
    double maxLat = _positions.map((p) => p.latitude!).reduce(max).toDouble();
    double minLon = _positions.map((p) => p.longitude!).reduce(min).toDouble();
    double maxLon = _positions.map((p) => p.longitude!).reduce(max).toDouble();

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat, minLon), northeast: LatLng(maxLat, maxLon)),
      left: 50,
      right: 50,
      top: 50,
      bottom: 50,
    ));
  }

  void _toggleMapType() => setState(() => _mapType = _mapType == OSMMapType.normal ? OSMMapType.satellite : OSMMapType.normal);

  // 里程計算
  double _calculateDistance(List<api.Position> positions) {
    if (positions.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < positions.length - 1; i++) {
      total += _distanceBetween(
        positions[i].latitude!.toDouble(),
        positions[i].longitude!.toDouble(),
        positions[i + 1].latitude!.toDouble(),
        positions[i + 1].longitude!.toDouble(),
      );
    }
    return total;
  }

  double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var a = 0.5 - cos((lat2 - lat1) * p) / 2 + cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('reportReplay'.tr + ': ${DateFormat.yMMMd().format(_historyFrom ?? DateTime.now())}')),
      body: Stack(
        children: [
          MapLibreMap(
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            initialCameraPosition: const CameraPosition(target: LatLng(0, 0), zoom: 2),
            styleString: _mapType == OSMMapType.normal ? _streetStyle : _satelliteStyle,
          ),
          // 地圖控制按鈕
          Positioned(
            top: 10,
            right: 10,
            child: Column(
              children: [
                _mapFab(Icons.calendar_month, _showCalendarDialog, "btn_cal"),
                const SizedBox(height: 10),
                _mapFab(_mapType == OSMMapType.normal ? Icons.satellite : Icons.map, _toggleMapType, "btn_style"),
                const SizedBox(height: 10),
                _mapFab(Icons.add, () => _mapController?.animateCamera(CameraUpdate.zoomIn()), "btn_zoom_in"),
                const SizedBox(height: 5),
                _mapFab(Icons.remove, () => _mapController?.animateCamera(CameraUpdate.zoomOut()), "btn_zoom_out"),
              ],
            ),
          ),
          _buildPlaybackPanel(),
        ],
      ),
    );
  }

  Widget _mapFab(IconData icon, VoidCallback onPressed, String tag) {
    return FloatingActionButton(heroTag: tag, mini: true, onPressed: onPressed, child: Icon(icon));
  }

  Widget _buildPlaybackPanel() {
    return Positioned(
      bottom: 20,
      left: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              final int idx = _playbackPositionRx.value.floor().clamp(0, max(0, _movingPositionsRx.length - 1));
              final pos = _movingPositionsRx.isEmpty ? null : _movingPositionsRx[idx];
              final time = pos != null ? DateFormat('HH:mm:ss').format(pos.serverTime!.toLocal()) : "--:--:--";
              final speed = pos != null ? ((pos.speed ?? 0) * 1.852).toStringAsFixed(1) : "0.0";
              final distance = _getDistanceFormatted(idx);

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem("時間", time, Icons.access_time),
                  _buildStatItem("速度", "$speed km/h", Icons.speed),
                  _buildStatItem("里程", distance, Icons.straighten),
                ],
              );
            }),
            const Divider(height: 20),
            Obx(() {
              final double maxVal = max(0, _movingPositionsRx.length - 1).toDouble();
              final double currentVal = _playbackPositionRx.value.clamp(0.0, maxVal);
              return Slider(
                value: currentVal,
                min: 0.0,
                max: maxVal,
                activeColor: const Color(0xFF0F53FE),
                onChanged: (v) {
                  _playbackPositionRx.value = v;
                  _updatePlaybackUI();
                },
              );
            }),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FloatingActionButton(
                  heroTag: "btn_play",
                  backgroundColor: const Color(0xFF0F53FE),
                  onPressed: _togglePlayback,
                  child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                ),
                _buildSpeedSelector(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _getDistanceFormatted(int currentIndex) {
    if (_movingPositionsRx.isEmpty) return "0.00 km";
    double total = 0;
    for (int i = 0; i < currentIndex; i++) {
      total += _distanceBetween(
          _movingPositionsRx[i].latitude!.toDouble(), _movingPositionsRx[i].longitude!.toDouble(), _movingPositionsRx[i + 1].latitude!.toDouble(), _movingPositionsRx[i + 1].longitude!.toDouble());
    }
    return "${total.toStringAsFixed(2)} km";
  }

  Widget _buildSpeedSelector() {
    final speeds = [0.5, 1.0, 2.0, 5.0];
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
      child: ToggleButtons(
        constraints: const BoxConstraints(minWidth: 45, minHeight: 35),
        isSelected: speeds.map((s) => s == _playbackSpeed).toList(),
        onPressed: (idx) => setState(() => _playbackSpeed = speeds[idx]),
        borderRadius: BorderRadius.circular(12),
        fillColor: const Color(0xFF0F53FE),
        selectedColor: Colors.white,
        children: speeds.map((s) => Text(s == 0.5 ? '0.5x' : '${s.toInt()}x', style: const TextStyle(fontSize: 12))).toList(),
      ),
    );
  }

  // 行事曆數據獲取 (整合自 gmain.dart)
  Future<void> _fetchMonthlyData(DateTime month) async {
    if (_deviceId == null) return;
    setState(() => _isCalendarLoading = true);

    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final dailyBox = Hive.box<ReportSummaryHive>('dailySummaries');
    final reportsApi = api.ReportsApi(Provider.of<TraccarProvider>(context, listen: false).apiClient);

    for (var date = firstDayOfMonth; date.isBefore(lastDayOfMonth.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      final dayUtc = DateTime.utc(date.year, date.month, date.day);
      final String hiveKey = '$_deviceId-${DateFormat('yyyy-MM-dd').format(dayUtc)}';
      final cachedSummary = dailyBox.get(hiveKey);

      if (cachedSummary != null) {
        _dailySummaries[dayUtc] = api.ReportSummary(
          distance: cachedSummary.distance,
          averageSpeed: cachedSummary.averageSpeed,
          maxSpeed: cachedSummary.maxSpeed,
          spentFuel: cachedSummary.spentFuel,
        );
      } else {
        // 如果沒緩存，可在此處選擇是否批量獲取，此處保持 gmain 邏輯
        try {
          final from = DateTime(date.year, date.month, date.day, 0, 0, 0);
          final to = DateTime(date.year, date.month, date.day, 23, 59, 59);
          final summary = await reportsApi.reportsSummaryGet(from.toUtc(), to.toUtc(), deviceId: [_deviceId!]);
          if (summary != null && summary.isNotEmpty) {
            _dailySummaries[dayUtc] = summary.first;
            await dailyBox.put(hiveKey, ReportSummaryHive.fromApi(summary.first));
          }
        } catch (_) {}
      }
    }

    setState(() => _isCalendarLoading = false);
  }

  void _showCalendarDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: SizedBox(
                width: 300,
                height: 400,
                child: Column(
                  children: [
                    if (_isCalendarLoading) const LinearProgressIndicator(),
                    Expanded(
                      child: TableCalendar(
                        firstDay: DateTime.utc(2020),
                        lastDay: DateTime.now(),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (d) => isSameDay(_selectedCalendarDay, d),
                        onDaySelected: (sel, foc) {
                          _onDaySelected(sel, foc);
                          Navigator.pop(context);
                        },
                        onPageChanged: (foc) => _fetchMonthlyData(foc),
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            final dayUtc = DateTime.utc(date.year, date.month, date.day);
                            final summary = _dailySummaries[dayUtc];
                            if (summary != null && (summary.distance ?? 0) > 0) {
                              return Positioned(
                                bottom: 1,
                                child: Text('${(summary.distance! / 1000).toStringAsFixed(1)}km', style: const TextStyle(fontSize: 8, color: Colors.blue)),
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ));
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedCalendarDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _fetchHistoryRoute(selectedDay: selectedDay);
  }
}