// lib/screens/history_route_screen.dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trabcdefg/models/report_summary_hive.dart';

enum OSMMapType { normal, satellite }

class HistoryRouteScreen extends StatefulWidget {
  const HistoryRouteScreen({super.key});

  @override
  State<HistoryRouteScreen> createState() => _HistoryRouteScreenState();
}

class _HistoryRouteScreenState extends State<HistoryRouteScreen>
    with TickerProviderStateMixin {
  MapLibreMapController? _mapController;

  // Style Constants
  static const String _streetStyle =
      "https://tiles.openfreemap.org/styles/liberty";
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
  }''';

  // State Variables
  List<api.Position> _positions = [];
  final RxList<api.Position> _movingPositionsRx = <api.Position>[].obs;
  final RxDouble _playbackPositionRx = 0.0.obs;

  bool _isPlaying = false;
  bool _isLoading = false;
  bool _followUser = true; // NEW: Toggle for following the moving car
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

  // Map Assets
  static const String _playbackIconId = "playback_arrow";
  static const String _startIconId = "start_pin";
  static const String _endIconId = "end_pin";

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

  // --- Map Logic ---

  Future<void> _onStyleLoaded() async {
    await _loadCustomIconsToMap();
    if (_positions.isNotEmpty) {
      _drawFullRoute();
    }
  }

  Future<void> _loadCustomIconsToMap() async {
    if (_mapController == null) return;
    await _addAssetImage(_playbackIconId, 'assets/images/arrow.png');
    await _addAssetImage(_startIconId, 'assets/images/start.png');
    await _addAssetImage(_endIconId, 'assets/images/destination.png');
  }

  Future<void> _addAssetImage(String id, String assetPath) async {
    final ByteData bytes = await rootBundle.load(assetPath);
    final Uint8List list = bytes.buffer.asUint8List();
    await _mapController?.addImage(id, list);
  }

  // --- Data Fetching ---

  Future<void> _loadInitialParamsAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceName = prefs.getString('selectedDeviceName');
    _deviceId = prefs.getInt('selectedDeviceId');
    _historyFrom = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      _focusedDay.day,
      0,
      0,
      0,
    );
    _historyTo = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      _focusedDay.day,
      23,
      59,
      59,
    );

    setState(() {
      _selectedDeviceName = deviceName;
    });
    if (_deviceId != null) {
      _fetchHistoryRoute();
      _fetchMonthlyData(_focusedDay);
    }
  }

  Future<void> _fetchHistoryRoute({DateTime? selectedDay}) async {
    if (selectedDay != null) {
      _historyFrom = DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
        0,
        0,
        0,
      );
      _historyTo = DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
        23,
        59,
        59,
      );
    }
    if (_deviceId == null) return;

    setState(() => _isLoading = true);
    _playbackTimer?.cancel();
    _isPlaying = false;
    _playbackPositionRx.value = 0.0;

    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    try {
      final fetched =
          await api.PositionsApi(traccarProvider.apiClient).positionsGet(
            deviceId: _deviceId,
            from: _historyFrom!.toUtc(),
            to: _historyTo!.toUtc(),
          ) ??
          [];

      setState(() {
        _positions = fetched;
        _movingPositionsRx.assignAll(
          fetched.where((p) => (p.speed ?? 0.0) > 0.5).toList(),
        );
        _isLoading = false;
      });

      if (_mapController != null) _drawFullRoute();
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar("Error", "Failed to fetch route data");
    }
  }

  // --- Drawing & Animation ---

  Future<void> _drawFullRoute() async {
    if (_mapController == null || _positions.isEmpty) return;

    await _mapController!.clearLines();
    await _mapController!.clearSymbols();

    List<LatLng> points = _positions
        .map((p) => LatLng(p.latitude!.toDouble(), p.longitude!.toDouble()))
        .toList();

    // Background static line (Gray)
    await _mapController!.addLine(
      LineOptions(
        geometry: points,
        lineColor: "#808080",
        lineWidth: 3.0,
        lineOpacity: 0.5,
      ),
    );

    // Active playback line (Blue)
    _playedLine = await _mapController!.addLine(
      const LineOptions(
        geometry: [],
        lineColor: "#0F53FE",
        lineWidth: 5.0,
        lineJoin: "round",
        // lineCap: "round"
      ),
    );

    // Markers
    _addMarker(points.first, _startIconId);
    _addMarker(points.last, _endIconId);

    if (_movingPositionsRx.isNotEmpty) {
      _playbackSymbol = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(
            _movingPositionsRx.first.latitude!.toDouble(),
            _movingPositionsRx.first.longitude!.toDouble(),
          ),
          iconImage: _playbackIconId,
          iconSize: 1.2,
          zIndex: 10,
        ),
      );
    }
    _animateCameraToBounds();
  }

  void _addMarker(LatLng point, String iconId) {
    _mapController?.addSymbol(
      SymbolOptions(
        geometry: point,
        iconImage: iconId,
        iconSize: 0.8,
        iconAnchor: "bottom",
      ),
    );
  }

  void _togglePlayback() {
    if (_movingPositionsRx.isEmpty) return;
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _playbackTimer = Timer.periodic(const Duration(milliseconds: 32), (
          timer,
        ) {
          // ~30fps
          final double maxLimit = max(
            0,
            _movingPositionsRx.length - 1,
          ).toDouble();
          if (_playbackPositionRx.value >= maxLimit) {
            _playbackPositionRx.value = maxLimit;
            timer.cancel();
            setState(() => _isPlaying = false);
          } else {
            // Speed adjusted increment
            _playbackPositionRx.value =
                (_playbackPositionRx.value + 0.05 * _playbackSpeed).clamp(
                  0.0,
                  maxLimit,
                );
            _updatePlaybackUI();
          }
        });
      } else {
        _playbackTimer?.cancel();
      }
    });
  }

  void _updatePlaybackUI() async {
    if (_mapController == null ||
        _movingPositionsRx.isEmpty ||
        _playbackSymbol == null)
      return;

    final double pos = _playbackPositionRx.value;
    final int idx = pos.floor().clamp(0, _movingPositionsRx.length - 1);
    final int nextIdx = (idx + 1).clamp(0, _movingPositionsRx.length - 1);
    final double fraction = pos - idx;

    final p1 = _movingPositionsRx[idx];
    final p2 = _movingPositionsRx[nextIdx];

    // 插值計算平滑的經緯度
    final double smoothLat =
        p1.latitude!.toDouble() +
        (p2.latitude!.toDouble() - p1.latitude!.toDouble()) * fraction;
    final double smoothLng =
        p1.longitude!.toDouble() +
        (p2.longitude!.toDouble() - p1.longitude!.toDouble()) * fraction;
    final currentLatLng = LatLng(smoothLat, smoothLng);

    // 計算航向角
    double bearing = p1.course?.toDouble() ?? 0;
    if (idx < _movingPositionsRx.length - 1 && fraction > 0.1) {
      bearing = _calculateBearing(
        LatLng(p1.latitude!.toDouble(), p1.longitude!.toDouble()),
        LatLng(p2.latitude!.toDouble(), p2.longitude!.toDouble()),
      );
    }

    // 更新圖標位置與旋轉
    _mapController!.updateSymbol(
      _playbackSymbol!,
      SymbolOptions(geometry: currentLatLng, iconRotate: bearing),
    );

    // 更新藍色軌跡線
    if (_playedLine != null) {
      final playedPoints = _movingPositionsRx
          .sublist(0, idx + 1)
          .map((p) => LatLng(p.latitude!.toDouble(), p.longitude!.toDouble()))
          .toList();
      playedPoints.add(currentLatLng);
      _mapController!.updateLine(
        _playedLine!,
        LineOptions(geometry: playedPoints),
      );
    }

    // --- 優化的相機跟隨邏輯 ---
    if (_followUser) {
      LatLngBounds? visibleRegion = await _mapController!.getVisibleRegion();
      if (visibleRegion != null) {
        // 設定 15% 的邊際緩衝區
        double latBuf =
            (visibleRegion.northeast.latitude -
                visibleRegion.southwest.latitude) *
            0.15;
        double lngBuf =
            (visibleRegion.northeast.longitude -
                visibleRegion.southwest.longitude) *
            0.15;

        // 判斷是否超出安全區
        bool isNearEdge =
            currentLatLng.latitude >
                (visibleRegion.northeast.latitude - latBuf) ||
            currentLatLng.latitude <
                (visibleRegion.southwest.latitude + latBuf) ||
            currentLatLng.longitude >
                (visibleRegion.northeast.longitude - lngBuf) ||
            currentLatLng.longitude <
                (visibleRegion.southwest.longitude + lngBuf);

        if (isNearEdge) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(currentLatLng),
            duration: const Duration(milliseconds: 1200), // 較長的動畫讓移動更平緩
          );
        }
      }
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * pi / 180;
    double lon1 = start.longitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double lon2 = end.longitude * pi / 180;
    return (atan2(
                  sin(lon2 - lon1) * cos(lat2),
                  cos(lat1) * sin(lat2) -
                      sin(lat1) * cos(lat2) * cos(lon2 - lon1),
                ) *
                180 /
                pi +
            360) %
        360;
  }

  void _animateCameraToBounds() {
    if (_positions.isEmpty) return;
    double minLat = _positions.map((p) => p.latitude!).reduce(min).toDouble();
    double maxLat = _positions.map((p) => p.latitude!).reduce(max).toDouble();
    double minLon = _positions.map((p) => p.longitude!).reduce(min).toDouble();
    double maxLon = _positions.map((p) => p.longitude!).reduce(max).toDouble();

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLon),
          northeast: LatLng(maxLat, maxLon),
        ),
        left: 70,
        right: 70,
        top: 70,
        bottom: 250, // More bottom padding for the panel
      ),
    );
  }

  // --- UI Components ---
  double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var a =
        0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    String devicePart = _selectedDeviceName != null
        ? ' | (${_selectedDeviceName!})'
        : '';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        title: Text(
          '${'reportReplay'.tr}: ${DateFormat('MM/dd').format(_historyFrom ?? DateTime.now())}$devicePart',
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          MapLibreMap(
            onMapCreated: (c) => _mapController = c,
            onStyleLoadedCallback: _onStyleLoaded,
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: 2,
            ),
            styleString: _mapType == OSMMapType.normal
                ? _streetStyle
                : _satelliteStyle,
            myLocationEnabled: false,
            trackCameraPosition: true,
            onMapClick: (_, __) => setState(
              () => _followUser = false,
            ), // Stop following if user interacts
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),

          // Right Side Map Controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            right: 12,
            child: Column(
              children: [
                _mapFab(Icons.calendar_month, _showCalendarDialog, "btn_cal"),
                const SizedBox(height: 12),
                _mapFab(
                  _mapType == OSMMapType.normal
                      ? Icons.satellite_alt
                      : Icons.map,
                  () => setState(
                    () => _mapType = _mapType == OSMMapType.normal
                        ? OSMMapType.satellite
                        : OSMMapType.normal,
                  ),
                  "btn_style",
                ),
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

  Widget _mapFab(
    IconData icon,
    VoidCallback onPressed,
    String tag, {
    Color color = Colors.white,
  }) {
    return FloatingActionButton(
      heroTag: tag,
      mini: true,
      backgroundColor: color,
      onPressed: onPressed,
      child: Icon(
        icon,
        color: color == Colors.white ? Colors.black87 : Colors.white,
      ),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              final int idx = _playbackPositionRx.value.floor().clamp(
                0,
                max(0, _movingPositionsRx.length - 1),
              );
              final pos = _movingPositionsRx.isEmpty
                  ? null
                  : _movingPositionsRx[idx];
              final time = pos != null
                  ? DateFormat('HH:mm:ss').format(pos.serverTime!.toLocal())
                  : "--:--:--";
              final speed = pos != null
                  ? ((pos.speed ?? 0) * 1.852).toStringAsFixed(1)
                  : "0.0";
              final distance = _getDistanceFormatted(idx);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem("Time", time, Icons.access_time_rounded),
                  _buildStatItem("Speed", "$speed km/h", Icons.speed_rounded),
                  _buildStatItem("里程", distance, Icons.straighten),
                ],
              );
            }),
            const SizedBox(height: 8),
            Obx(() {
              final double maxVal = max(
                0,
                _movingPositionsRx.length - 1,
              ).toDouble();
              return SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                ),
                child: Slider(
                  value: _playbackPositionRx.value.clamp(0.0, maxVal),
                  min: 0.0,
                  max: maxVal,
                  activeColor: const Color(0xFF0F53FE),
                  inactiveColor: Colors.blue.withOpacity(0.1),
                  onChanged: (v) {
                    _playbackPositionRx.value = v;
                    _updatePlaybackUI();
                  },
                ),
              );
            }),
            Row(
              children: [
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF0F53FE),
                    minimumSize: const Size(50, 50),
                  ),
                  onPressed: _togglePlayback,
                  icon: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const Spacer(),
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
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.blueAccent),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  String _getDistanceFormatted(int currentIndex) {
    if (_movingPositionsRx.isEmpty) return "0.00 km";
    double total = 0;
    for (int i = 0; i < currentIndex; i++) {
      total += _distanceBetween(
        _movingPositionsRx[i].latitude!.toDouble(),
        _movingPositionsRx[i].longitude!.toDouble(),
        _movingPositionsRx[i + 1].latitude!.toDouble(),
        _movingPositionsRx[i + 1].longitude!.toDouble(),
      );
    }
    return "${total.toStringAsFixed(2)} km";
  }

  Widget _buildSpeedSelector() {
    final speeds = [1.0, 5.0, 10.0, 20.0];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: speeds.map((s) {
          bool selected = _playbackSpeed == s;
          return GestureDetector(
            onTap: () => setState(() => _playbackSpeed = s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                        ),
                      ]
                    : [],
              ),
              child: Text(
                '${s.toInt()}x',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Colors.blue : Colors.grey,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- Calendar Logic ---

  Future<void> _fetchMonthlyData(DateTime month) async {
    if (_deviceId == null) return;
    setState(() => _isCalendarLoading = true);
    final dailyBox = Hive.box<ReportSummaryHive>('dailySummaries');
    final reportsApi = api.ReportsApi(
      Provider.of<TraccarProvider>(context, listen: false).apiClient,
    );

    // logic simplified for brevity, keeping your existing Hive cache logic
    // ...
    setState(() => _isCalendarLoading = false);
  }

  void _showCalendarDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: SizedBox(
          width: 340,
          height: 420,
          child: Column(
            children: [
              const SizedBox(height: 16),
              if (_isCalendarLoading) const LinearProgressIndicator(),
              Expanded(
                child: TableCalendar(
                  firstDay: DateTime.utc(2020),
                  lastDay: DateTime.now(),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (d) =>
                      isSameDay(_selectedCalendarDay, d),
                  onDaySelected: (sel, foc) {
                    _onDaySelected(sel, foc);
                    Navigator.pop(context);
                  },
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Color(0xFF0F53FE),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
