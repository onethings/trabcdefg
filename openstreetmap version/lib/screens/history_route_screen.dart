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
import 'package:trabcdefg/models/route_positions_hive.dart'; // Assuming you put the model here
import 'package:intl/date_symbol_data_local.dart';

enum OSMMapType { normal, satellite }

class HistoryRouteScreen extends StatefulWidget {
  const HistoryRouteScreen({super.key});

  @override
  State<HistoryRouteScreen> createState() => _HistoryRouteScreenState();
}

class _HistoryRouteScreenState extends State<HistoryRouteScreen>
    with TickerProviderStateMixin {
  MapLibreMapController? _mapController;
  List<double> _distancePrefixSum = [];

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
    cleanExpiredRouteHistory();
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

  // 2. 建立計算方法
  void _calculateDistancePrefixSum() {
    _distancePrefixSum = [0.0];
    double total = 0;
    for (int i = 0; i < _movingPositionsRx.length - 1; i++) {
      total += _distanceBetween(
        _movingPositionsRx[i].latitude!.toDouble(),
        _movingPositionsRx[i].longitude!.toDouble(),
        _movingPositionsRx[i + 1].latitude!.toDouble(),
        _movingPositionsRx[i + 1].longitude!.toDouble(),
      );
      _distancePrefixSum.add(total);
    }
  }

  // --- Data Fetching ---

  // Future<void> _loadInitialParamsAndFetch() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final deviceName = prefs.getString('selectedDeviceName');
  //   _deviceId = prefs.getInt('selectedDeviceId');
  //   _historyFrom = DateTime(
  //     _focusedDay.year,
  //     _focusedDay.month,
  //     _focusedDay.day,
  //     0,
  //     0,
  //     0,
  //   );
  //   _historyTo = DateTime(
  //     _focusedDay.year,
  //     _focusedDay.month,
  //     _focusedDay.day,
  //     23,
  //     59,
  //     59,
  //   );

  //   setState(() {
  //     _selectedDeviceName = deviceName;
  //   });
  //   if (_deviceId != null) {
  //     _fetchHistoryRoute();
  //     _fetchMonthlyData(_focusedDay);
  //   }
  // }
  Future<void> _loadInitialParamsAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceName = prefs.getString('selectedDeviceName');
    final deviceId = prefs.getInt('selectedDeviceId');
    final fromString = prefs.getString('historyFrom');
    final toString = prefs.getString('historyTo');

    DateTime defaultDate = DateTime.now();

    setState(() {
      _deviceId = deviceId;
      _focusedDay = defaultDate;
      _selectedCalendarDay = defaultDate;
      _selectedDeviceName = deviceName;

      if (fromString != null && toString != null) {
        _historyFrom = DateTime.tryParse(fromString)?.toLocal();
        _historyTo = DateTime.tryParse(toString)?.toLocal();
        if (_historyFrom != null) {
          _selectedCalendarDay = DateTime(
            _historyFrom!.year,
            _historyFrom!.month,
            _historyFrom!.day,
          );
        }
      } else {
        _historyFrom = DateTime(
          defaultDate.year,
          defaultDate.month,
          defaultDate.day,
          0,
          0,
          0,
        );
        _historyTo = DateTime(
          defaultDate.year,
          defaultDate.month,
          defaultDate.day,
          23,
          59,
          59,
        );
      }
    });

    if (_deviceId != null) {
      _fetchHistoryRoute();
      await _fetchMonthlyData(_focusedDay);
    } else {
      print('Missing device ID for history route.');
    }
  }

  // Future<void> _fetchHistoryRoute({DateTime? selectedDay}) async {
  //   if (selectedDay != null) {
  //     _historyFrom = DateTime(
  //       selectedDay.year,
  //       selectedDay.month,
  //       selectedDay.day,
  //       0,
  //       0,
  //       0,
  //     );
  //     _historyTo = DateTime(
  //       selectedDay.year,
  //       selectedDay.month,
  //       selectedDay.day,
  //       23,
  //       59,
  //       59,
  //     );
  //   }
  //   if (_deviceId == null) return;

  //   setState(() => _isLoading = true);
  //   _playbackTimer?.cancel();
  //   _isPlaying = false;
  //   _playbackPositionRx.value = 0.0;

  //   final traccarProvider = Provider.of<TraccarProvider>(
  //     context,
  //     listen: false,
  //   );
  //   try {
  //     final fetched =
  //         await api.PositionsApi(traccarProvider.apiClient).positionsGet(
  //           deviceId: _deviceId,
  //           from: _historyFrom!.toUtc(),
  //           to: _historyTo!.toUtc(),
  //         ) ??
  //         [];

  //     setState(() {
  //       _positions = fetched;
  //       _movingPositionsRx.assignAll(
  //         fetched.where((p) => (p.speed ?? 0.0) > 0.5).toList(),
  //       );
  //       _isLoading = false;
  //     });

  //     if (_mapController != null) _drawFullRoute();
  //   } catch (e) {
  //     setState(() => _isLoading = false);
  //     Get.snackbar("Error", "Failed to fetch route data");
  //   }
  // }
  // Utility function to be called once on app startup or screen load
  Future<void> cleanExpiredRouteHistory() async {
    final routeBox = await Hive.openBox<RoutePositionsHive>('route_positions');
    const cacheDuration = Duration(days: 60);
    final DateTime expiryThreshold = DateTime.now().subtract(cacheDuration);

    final List<dynamic> expiredKeys = [];

    // Iterate over all keys in the box
    for (final key in routeBox.keys) {
      // Retrieve the entry directly using the key
      final entry = routeBox.get(key);

      // Check if the cache date is older than 60 days
      if (entry != null && entry.cachedAt.isBefore(expiryThreshold)) {
        expiredKeys.add(key);
      }
    }

    if (expiredKeys.isNotEmpty) {
      print('Deleting ${expiredKeys.length} expired route entries.');
      // Delete all expired entries in one batch operation
      await routeBox.deleteAll(expiredKeys);
    }
  }

  // 在 _fetchHistoryRoute 取得數據後
  void _calculatePrefixSum() {
    _distancePrefixSum = [0.0];
    double total = 0;
    for (int i = 0; i < _movingPositionsRx.length - 1; i++) {
      total += _distanceBetween(
        _movingPositionsRx[i].latitude!.toDouble(),
        _movingPositionsRx[i].longitude!.toDouble(),
        _movingPositionsRx[i + 1].latitude!.toDouble(),
        _movingPositionsRx[i + 1].longitude!.toDouble(),
      );
      _distancePrefixSum.add(total);
    }
  }

  Future<void> _fetchHistoryRoute({DateTime? selectedDay}) async {
    // 1. 初始化時間參數
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

    if (_deviceId == null || _historyFrom == null || _historyTo == null) return;

    // 2. 停止當前播放並重置 UI 狀態
    _playbackTimer?.cancel();
    setState(() {
      _isLoading = true; // 顯示載入動畫
      _isPlaying = false;
      _positions = [];
      _playbackPositionRx.value = 0.0;
    });
    _movingPositionsRx.clear();

    List<api.Position> fetchedPositions = [];
    final hiveKey =
        '$_deviceId-${DateFormat('yyyy-MM-dd').format(_historyFrom!)}';

    try {
      // 3. 檢查 Hive 快取
      final routeBox = await Hive.openBox<RoutePositionsHive>(
        'route_positions',
      );
      final cachedRoute = routeBox.get(hiveKey);

      bool isCacheValid = false;
      if (cachedRoute != null) {
        final bool isToday = isSameDay(_historyFrom, DateTime.now());
        // 關鍵修正：今日數據 10 分鐘過期，歷史數據 60 天過期
        final diff = DateTime.now().difference(cachedRoute.cachedAt);
        final bool isExpired = isToday
            ? diff > const Duration(minutes: 10)
            : diff > const Duration(days: 60);
        isCacheValid = !isExpired;
      }

      if (isCacheValid) {
        debugPrint('從快取載入: $hiveKey');
        fetchedPositions = RoutePositionsHive.fromJsonList(
          cachedRoute!.positionsJson,
        );
      } else {
        // 4. 網路抓取
        debugPrint('從網路抓取: $hiveKey');
        final traccarProvider = Provider.of<TraccarProvider>(
          context,
          listen: false,
        );
        fetchedPositions =
            await api.PositionsApi(traccarProvider.apiClient).positionsGet(
              deviceId: _deviceId,
              from: _historyFrom!.toUtc(),
              to: _historyTo!.toUtc(),
            ) ??
            [];

        // 存入快取
        if (fetchedPositions.isNotEmpty) {
          await routeBox.put(
            hiveKey,
            RoutePositionsHive(
              dateKey: hiveKey,
              positionsJson: RoutePositionsHive.toJsonList(fetchedPositions),
              cachedAt: DateTime.now(),
            ),
          );
        }
      }

      // 5. 更新數據與過濾低速點
      if (mounted) {
        setState(() {
          _positions = fetchedPositions;
          // 過濾：時速 > 2 km/h 才回放 (Traccar speed * 1.852 = km/h)
          _movingPositionsRx.assignAll(
            _positions.where((p) => ((p.speed ?? 0.0) * 1.852) > 2.0).toList(),
          );
          _isLoading = false;
        });

        // 6. 效能優化：計算里程前綴和
        _calculateDistancePrefixSum();

        // 7. 繪製地圖
        if (_mapController != null) {
          _drawFullRoute();
        }
      }
    } catch (e) {
      debugPrint('獲取軌跡失敗: $e');
      if (mounted) setState(() => _isLoading = false);
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
    });

    if (_isPlaying) {
      // 確保不會重複建立 Timer
      _playbackTimer?.cancel();

      _playbackTimer = Timer.periodic(const Duration(milliseconds: 32), (
        timer,
      ) {
        // 1. 核心安全檢查：如果 Widget 已經不存在，立即停止並退出
        if (!mounted) {
          timer.cancel();
          return;
        }

        final double maxLimit = max(
          0,
          _movingPositionsRx.length - 1,
        ).toDouble();

        if (_playbackPositionRx.value >= maxLimit) {
          // 播放結束
          _playbackPositionRx.value = maxLimit;
          timer.cancel();
          if (mounted) {
            setState(() => _isPlaying = false);
          }
        } else {
          // 2. 更新進度：使用 Rx 變數，不需要 setState
          // 這裡 0.05 是基礎增量，配合 _playbackSpeed 實現倍速
          double increment = 0.05 * _playbackSpeed;
          _playbackPositionRx.value = (_playbackPositionRx.value + increment)
              .clamp(0.0, maxLimit);

          // 3. 更新地圖與 UI 標誌物
          _updatePlaybackUI();
        }
      });
    } else {
      _playbackTimer?.cancel();
    }
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
                  _buildStatItem(
                    "positionDrivingTime".tr,
                    time,
                    Icons.access_time_rounded,
                  ),
                  _buildStatItem(
                    "positionSpeed".tr,
                    "$speed km/h",
                    Icons.speed_rounded,
                  ),
                  _buildStatItem(
                    "sharedDistance".tr,
                    distance,
                    Icons.straighten,
                  ),
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

  // String _getDistanceFormatted(int currentIndex) {
  //   if (_movingPositionsRx.isEmpty) return "0.00 km";
  //   double total = 0;
  //   for (int i = 0; i < currentIndex; i++) {
  //     total += _distanceBetween(
  //       _movingPositionsRx[i].latitude!.toDouble(),
  //       _movingPositionsRx[i].longitude!.toDouble(),
  //       _movingPositionsRx[i + 1].latitude!.toDouble(),
  //       _movingPositionsRx[i + 1].longitude!.toDouble(),
  //     );
  //   }
  //   return "${total.toStringAsFixed(2)} km";
  // }
  // 修改 _getDistanceFormatted
  String _getDistanceFormatted(int currentIndex) {
    if (_distancePrefixSum.isEmpty || currentIndex >= _distancePrefixSum.length)
      return "0.00 km";
    return "${_distancePrefixSum[currentIndex].toStringAsFixed(2)} km";
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

  // Future<void> _fetchMonthlyData(DateTime month) async {
  //   if (_deviceId == null) return;
  //   setState(() => _isCalendarLoading = true);
  //   final dailyBox = Hive.box<ReportSummaryHive>('dailySummaries');
  //   final reportsApi = api.ReportsApi(
  //     Provider.of<TraccarProvider>(context, listen: false).apiClient,
  //   );

  //   // logic simplified for brevity, keeping your existing Hive cache logic
  //   // ...
  //   setState(() => _isCalendarLoading = false);
  // }
  Future<void> _fetchMonthlyData(DateTime month) async {
    if (_deviceId == null) return;

    // 如果該月份數據已存在且不是切換月份，則不重複執行
    if (_dailySummaries.isNotEmpty &&
        month.month == _focusedDay.month &&
        month.year == _focusedDay.year)
      return;

    setState(() {
      _isCalendarLoading = true;
      _focusedDay = month;
    });

    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final reportsApi = api.ReportsApi(traccarProvider.apiClient);
    final dailyBox = await Hive.openBox<ReportSummaryHive>('daily_summaries');

    _dailySummaries.clear();
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    // --- 關鍵步驟：先從 Hive 撈取整個月的既有數據 ---
    for (
      var date = firstDayOfMonth;
      date.isBefore(lastDayOfMonth.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))
    ) {
      final dayUtc = DateTime.utc(date.year, date.month, date.day);
      // 確保這裡的 Key 與 MonthlyMileageScreen 儲存時完全一致
      // final String hiveKey =  '$_deviceId-${DateFormat('yyyy-MM-dd').format(dayUtc)}';
      final String hiveKey =
          '$_deviceId\_${DateFormat('yyyy-MM-dd').format(dayUtc)}';
      final cachedSummary = dailyBox.get(hiveKey);

      if (cachedSummary != null) {
        _dailySummaries[dayUtc] = api.ReportSummary(
          distance: cachedSummary.distance,
          averageSpeed: cachedSummary.averageSpeed,
          maxSpeed: cachedSummary.maxSpeed,
          spentFuel: cachedSummary.spentFuel,
          engineHours: cachedSummary.engineHours,
        );
      }
    }

    // 立即更新一次 UI，讓使用者在日曆上看到從 MonthlyMileageScreen 緩存過來的數據
    setState(() {
      _isCalendarLoading = false;
    });

    // --- 背景補充抓取缺失的數據 ---
    for (
      var date = firstDayOfMonth;
      date.isBefore(lastDayOfMonth.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))
    ) {
      final dayUtc = DateTime.utc(date.year, date.month, date.day);
      if (_dailySummaries.containsKey(dayUtc)) continue; // 已有快取的就跳過

      final from = DateTime(date.year, date.month, date.day, 0, 0, 0).toUtc();
      final to = DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc();
      final String hiveKey =
          '$_deviceId\_${DateFormat('yyyy-MM-dd').format(dayUtc)}';

      try {
        final summary = await reportsApi.reportsSummaryGet(
          from,
          to,
          deviceId: [_deviceId!],
        );
        if (summary != null && summary.isNotEmpty) {
          final dailySummary = summary.first;
          _dailySummaries[dayUtc] = dailySummary;

          // 存入 Hive 供下次或其他頁面使用
          await dailyBox.put(hiveKey, ReportSummaryHive.fromApi(dailySummary));
          if (mounted) setState(() {}); // 抓到一筆更新一筆
        }
      } catch (e) {
        debugPrint('背景抓取數據失敗: $e');
      }
    }
  }

  void _showCalendarDialog() async {
    if (_deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a device first.')),
      );
      return;
    }

    final currentLocale = Get.locale;
    if (currentLocale != null) {
      final localeString = currentLocale.toString();
      await initializeDateFormatting(localeString, null);
    }

    // 先執行資料抓取（會先讀取 Hive 緩存）
    _fetchMonthlyData(_focusedDay);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // 使用 StatefulBuilder 確保日曆切換月份時 UI 會更新
        builder: (context, modalSetState) {
          return AlertDialog(
            contentPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            content: SizedBox(
              width: 340,
              height: 460, // 稍微增加高度以容納里程文字
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // 載入進度條
                  if (_isCalendarLoading) const LinearProgressIndicator(),
                  Expanded(
                    child: TableCalendar(
                      locale: Get.locale?.languageCode,
                      firstDay: DateTime.utc(2020),
                      lastDay: DateTime.now(),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (d) =>
                          isSameDay(_selectedCalendarDay, d),

                      // 這裡很重要：切換月份時要觸發抓取新月份數據
                      onPageChanged: (focusedDay) {
                        modalSetState(() {
                          _focusedDay = focusedDay;
                        });
                        _fetchMonthlyData(focusedDay).then((_) {
                          if (mounted) modalSetState(() {}); // 抓完後更新 Dialog UI
                        });
                      },

                      onDaySelected: (sel, foc) {
                        _onDaySelected(sel, foc);
                        Navigator.pop(context);
                      },

                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),

                      // --- 關鍵部分：添加 MarkerBuilder 來顯示里程 ---
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          final dayUtc = DateTime.utc(
                            date.year,
                            date.month,
                            date.day,
                          );

                          // 檢查是否有該日期的數據
                          if (_dailySummaries.containsKey(dayUtc)) {
                            final summary = _dailySummaries[dayUtc]!;
                            final distanceInKm =
                                (summary.distance ?? 0.0) / 1000;

                            // 如果里程為 0，可以選擇不顯示
                            if (distanceInKm <= 0) return null;

                            return Positioned(
                              bottom: 4, // 調整文字距離底部的距離
                              child: Text(
                                '${distanceInKm.toStringAsFixed(1)}km', // 顯示到小數點第一位
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isSameDay(_selectedCalendarDay, date)
                                      ? Colors
                                            .white // 被選中時字體變白
                                      : Colors.blue[700],
                                ),
                              ),
                            );
                          }
                          return null;
                        },
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
                        // 為了不讓里程文字跟日期重疊，稍微調整邊距
                        cellMargin: EdgeInsets.all(6),
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
