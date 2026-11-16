import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:trabcdefg/src/utils/camera_follow.dart';
import 'package:trabcdefg/src/utils/direction.dart';
import 'package:trabcdefg/src/utils/playback_pacing.dart';
import 'package:trabcdefg/src/utils/playback_view.dart';
import 'package:trabcdefg/src/utils/played_prefix.dart';
import 'package:trabcdefg/src/utils/publish_budget.dart';
import 'package:trabcdefg/src/utils/repeat_pass.dart';
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
import 'package:trabcdefg/providers/settings_provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/screens/reports/chart_report_screen.dart';
import 'package:trabcdefg/screens/reports/stops_report_screen.dart';
import 'package:trabcdefg/screens/reports/trips_report_screen.dart';
import 'package:trabcdefg/services/feedback.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/src/utils/position_cleaner.dart';
import 'package:trabcdefg/widgets/offline_address_service.dart';

enum OSMMapType { normal, satellite }

enum RouteColorMode {
  single, // 單一顏色
  speedStatus, // 依速度分色 (Turbo 漸層)
  timeGradient, // 時間漸層分色 (早:淺藍, 午:中藍, 晚:深藍)
}

/// 土地面積單位，[squareMeters] 代表 1 個單位等於多少平方公尺
enum AreaUnit {
  acre(4046.8564224, 'areaUnitAcre', 3),
  hectare(10000.0, 'areaUnitHectare', 3),
  squareMeter(1.0, 'areaUnitSquareMeter', 0),
  squareKilometer(1000000.0, 'areaUnitSquareKilometer', 4),
  jia(9699.17, 'areaUnitJia', 3), // 台甲 = 2934 坪
  fen(969.917, 'areaUnitFen', 2), // 1 分 = 0.1 甲
  mu(666.6667, 'areaUnitMu', 3), // 市畝
  ping(3.305785, 'areaUnitPing', 1),
  squareFoot(0.09290304, 'areaUnitSquareFoot', 0);

  const AreaUnit(this.squareMeters, this.labelKey, this.decimals);

  final double squareMeters;
  final String labelKey;
  final int decimals;

  double fromSquareMeters(double m2) => m2 / squareMeters;
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

// --- Isolate Background Compute Helper ---
/// Below this many points the isolate hop costs more than the work it moves.
const int _trackCleanupIsolateThreshold = 1000;

class _TrackCleanupParams {
  final List<api.Position> positions;

  /// The route cache needs the JSON form of the cleaned track, the display path
  /// does not. Encoding it eagerly on a cache-hit load would be wasted work.
  final bool encode;

  _TrackCleanupParams(this.positions, {required this.encode});
}

class _CleanedTrack {
  final List<api.Position> positions;
  final List<Map<String, dynamic>> positionsJson;

  _CleanedTrack(this.positions, this.positionsJson);
}

_CleanedTrack _cleanTrackIsolate(_TrackCleanupParams params) {
  final cleaned = PositionCleaner.clean(params.positions);
  return _CleanedTrack(cleaned, params.encode ? RoutePositionsHive.toJsonList(cleaned) : const []);
}

/// 重複經過的判斷在背景 isolate 跑，密集軌跡才不會卡住載入那一幀。
Uint8List _classifyRepeatPassesIsolate(Float64List lngLatPairs) => classifyRepeatPasses(lngLatPairs);

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
  // 靜態常數與 UI 物件抽取
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
  // 繪製序列化：避免並行的 _drawFullRoute 交錯 add/remove 圖層
  Future<void> _drawQueue = Future<void>.value();
  int _latestDrawRequest = 0;
  List<double> _distancePrefixSum = [];
  final RxString _currentAddressRx = "".obs;

  int _addressRequestToken = 0; // 用來記錄請求的流水號

  // --- 路名請求智慧排程（依倍速跳點預取 + 暫停即時校正）---
  int _addressShownIdx = -1; // 目前顯示路名對應的播放索引
  int _addressCacheCheckedIdx = -1; // 上次查快取的索引（避免每 frame 重查）
  int _addressInFlightIdx = -1; // 進行中請求的目標索引（-1 = 閒置）
  int _addressInFlightLeadIdx = 0; // 該次請求的預取領先點數
  int _addressScheduledAtMs = 0; // 上次執行排程的時間（節流）
  int _addressRequestedAtMs = 0; // 上次真正送出請求的時間（遠端限流）
  int _lastTickAtMs = 0;

  // 已播放軌跡：每次推送整包換掉 GeoJSON，頂點留樣本上限，推送壓到約 10Hz 且同一時間只跑一個
  final PlayedPrefix _playedPrefix = PlayedPrefix();
  final PublishBudget _playedBudget = PublishBudget(100);
  bool _playedPushInFlight = false;
  // 換軌跡或換 style 時 +1，讓舊軌跡的在飛推送與相機檢查回來時認得自己已經過期
  int _playbackGeneration = 0;

  /// 每個軌跡點是否重複經過。整條軌跡的性質，載入時算一次，播放時只查表。
  Uint8List? _repeatFlags;
  List<int> _repeatBoundaryIndices = <int>[];

  Timer? _zoomSaveTimer;
  double _frameRate = 60.0; // 實測播放 tick 頻率（fps）
  double _addressLatencyMs = 0; // 路名請求的實測往返時間（慢網路時要預取得更遠）

  static const int _addressRemoteMinGapMs = 1550; // 對齊 Nominatim 1.5s 限流
  static const int _addressSchedulerThrottleMs = 200; // 排程器節流

  // 狀態變數
  List<api.Position> _positions = [];
  final RxDouble _playbackPositionRx = 0.0.obs;

  /// Integer index of [playbackPositionRx]. The stat rows only change when this
  /// changes, so they follow it and rebuild a few times a second instead of on
  /// every animation frame.
  final RxInt _shownIndexRx = 0.obs;

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
  bool _isDialogDevicePickerOpen = false;
  final TextEditingController _dialogDeviceSearchController = TextEditingController();
  double _currentZoom = 14.0;
  // 跟隨視野的 zoom 是推導出來的（見 playback_view.dart），使用者自己拉出來的
  // 偏好只記成相對偏移，這樣換倍速、換軌跡長度都不會把他的選擇弄丟。
  double _followZoomOffset = 0;
  // 使用者最後一次自己動 zoom 的時間；這段時間內不覆寫他的鏡頭
  int _userZoomTouchedAtMs = 0;
  bool _gestureInProgress = false;
  double _zoomAtGestureStart = 0;
  double _lastDerivedSpeed = 0;

  CameraPosition? _lastCameraPosition;
  bool _keepCameraOnStyleReload = false;
  bool _isMinimalMode = false;
  RouteColorMode _routeColorMode = RouteColorMode.single;

  // 地圖資源常量與標示
  static const String _playbackIconId = "playback_arrow";
  // 回放箭頭貼圖在畫面上的邊長（實體像素，不是 dp；MapLibre 的 iconSize 以貼圖像素為單位）。
  // 64px 貼圖 × 1.8 = 115 實體像素 ≈ 42dp，實測箭頭本體約 70 像素寬。
  static const double _playbackIconDisplayPx = 64 * 1.8;
  // 回放箭頭貼圖的實際邊長（px）。貼圖越大越清楚，iconSize 會自動等比縮小。
  int _playbackIconPixels = 64;
  static const String _startIconId = "start_pin";
  static const String _endIconId = "end_pin";
  static const int _maxStopIconCount = 50; // 對應 assets/images/pg_1..50.png
  final List<LatLng> _stopPoints = [];
  final List<Symbol> _stopSymbols = [];

  // 已註冊到目前 style 的圖示 id；style 重載後需重新註冊
  final Set<String> _loadedIconIds = {};
  // 資產位元組快取（只存壓縮後的 PNG，不含解碼後的 bitmap）
  final Map<String, Uint8List> _iconAssetCache = {};

  bool _showGeofences = false;
  bool _isGeofenceLoading = false;
  bool _showStopPoints = true;
  List<api.Geofence> _geofences = [];

  // 土地面積量測
  bool _isMeasureMode = false;
  final List<LatLng> _measurePoints = [];
  AreaUnit _areaUnit = AreaUnit.acre;

  Symbol? _playbackSymbol;
  // 標記位置的推送：每一格都打一次平台通道太貴，30Hz 足夠順
  final PublishBudget _markerBudget = PublishBudget(30);
  // 邊緣判斷每次都要跟可見範圍借一次平台通道，200ms 一次足以在高倍速下接住標記
  final PublishBudget _cameraBudget = PublishBudget(200);

  static const int _followPanAnimMs = 250;
  static const int _focusCameraAnimMs = 800;
  static const int _followZoomAnimMs = 500;
  // 底部回放面板與頂部資訊列遮住上下兩段，實際看得到的只有中間這塊，
  // 推導 zoom 時用這塊的高度，畫面算起來才不會比眼睛看到的更遠
  static const double _visibleViewportFraction = 0.7;
  static const String _followZoomOffsetPrefsKey = 'follow_zoom_offset';

  // 放大動畫進行中時暫停跟隨鏡頭，避免跟隨鏡頭取消放大動畫
  int _suppressFollowCameraUntilMs = 0;

  // GeoJSON 圖層識別碼
  static const String _routeSourceId = "history_route_source";
  static const String _routeLayerId = "history_route_layer";
  static const String _playedSourceId = "played_route_source";
  static const String _playedLayerId = "played_layer";
  static const String _geofenceSourceId = "history_geofence_source";
  static const String _geofenceFillLayerId = "history_geofence_fill_layer";
  static const String _geofenceLineLayerId = "history_geofence_line_layer";
  static const List<String> _geofenceColors = ['#0F53FE', '#F39C12', '#27AE60', '#8E44AD', '#E74C3C', '#16A085'];

  // 面積量測圖層
  static const String _measureSourceId = "measure_area_source";
  static const String _measureFillLayerId = "measure_area_fill_layer";
  static const String _measureLineLayerId = "measure_area_line_layer";
  static const String _measureVertexSourceId = "measure_vertex_source";
  static const String _measureVertexLayerId = "measure_vertex_layer";
  static const String _areaUnitPrefsKey = 'measure_area_unit';

  @override
  void initState() {
    super.initState();
    _initAnimationController();
    OfflineAddressService.initDatabase();
    cleanExpiredRouteHistory();
    _loadPlaybackSpeedFromHive();
    _loadAreaUnitFromPrefs();
    _loadInitialParamsAndFetch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    SystemChrome.setSystemUIOverlayStyle(Theme.of(context).brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark);
  }

  Future<void> _loadPlaybackSpeedFromHive() async {
    try {
      // 確保通用設定 Box 已開啟（若尚未全域開啟）
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
    _playbackAnimationController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..addListener(_onAnimationTick);
  }

  @override
  void dispose() {
    _playbackAnimationController?.stop();
    _playbackAnimationController?.dispose();
    _zoomSaveTimer?.cancel();
    _dialogDeviceSearchController.dispose();
    super.dispose();
  }

  // 安全觸發 setState 的輔助方法，防止 build 期間呼叫報錯
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

  // --- 地圖邏輯 ---

  Future<void> _onStyleLoaded() async {
    await _loadCustomIconsToMap();
    if (_positions.isEmpty) {
      if (_showGeofences) {
        await _drawGeofences();
      }
      if (_isMeasureMode) {
        await _drawMeasureOverlay();
      }
      return;
    }
    final bool keepCamera = _keepCameraOnStyleReload;
    _keepCameraOnStyleReload = false;
    await _drawFullRoute(fitBounds: !keepCamera);
    // 需在軌跡圖層建立後才重畫，belowLayerId 才找得到 _routeLayerId
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
    if (_mapController == null) {
      return;
    }
    // 新 style 會清掉已註冊的圖示，id 快取必須同步失效
    _loadedIconIds.clear();
    await Future.wait([_ensureMapIcon(_playbackIconId, 'assets/images/arrow.png'), _ensureMapIcon(_startIconId, 'assets/images/start.png'), _ensureMapIcon(_endIconId, 'assets/images/destination.png')]);
    await _refreshPlaybackIconPixels('assets/images/arrow.png');
    // 停靠點編號圖示改由 _ensureStopIcons 依實際停靠數載入
  }

  /// 讀貼圖實際邊長。換成高解析度圖之後畫面大小不變，只有邊緣變清楚。
  Future<void> _refreshPlaybackIconPixels(String assetPath) async {
    final Uint8List? bytes = _iconAssetCache[assetPath];
    if (bytes == null) return;
    try {
      final image = await decodeImageFromList(bytes);
      _playbackIconPixels = max(image.width, image.height);
      image.dispose();
    } catch (e) {
      developer.log('Failed to measure playback icon "$assetPath": $e', name: 'HistoryRouteScreen');
    }
  }

  /// 註冊單一圖示。資產缺失或 id 重複只記錄 log，不可中斷後續圖層繪製。
  Future<bool> _ensureMapIcon(String id, String assetPath) async {
    final controller = _mapController;
    if (controller == null || _loadedIconIds.contains(id)) {
      return _loadedIconIds.contains(id);
    }
    try {
      Uint8List? bytes = _iconAssetCache[assetPath];
      if (bytes == null) {
        final ByteData data = await rootBundle.load(assetPath);
        bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        _iconAssetCache[assetPath] = bytes;
      }
      await controller.addImage(id, bytes);
      _loadedIconIds.add(id);
      return true;
    } catch (e) {
      developer.log('Failed to load map icon "$id" from $assetPath: $e', name: 'HistoryRouteScreen');
      return false;
    }
  }

  /// 停靠點編號圖示：只載入實際需要的張數，並併發註冊；回傳註冊成功的 icon id
  Future<Set<String>> _ensureStopIcons(int count) async {
    final int limit = min(count, _maxStopIconCount);
    final List<bool> results = await Future.wait([for (int i = 1; i <= limit; i++) _ensureMapIcon("pg_$i", "assets/images/pg_$i.png")]);
    return {
      for (int i = 1; i <= limit; i++)
        if (results[i - 1]) "pg_$i",
    };
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
    final savedZoomOffset = prefs.getDouble(_followZoomOffsetPrefsKey);
    final savedColorMode = prefs.getString('route_color_mode');

    if (savedColorMode != null) {
      _routeColorMode = RouteColorMode.values.firstWhere((e) => e.name == savedColorMode, orElse: () => RouteColorMode.single);
    }

    DateTime defaultDate = DateTime.now();

    if (!mounted) {
      return;
    }

    _safeSetState(() {
      if (lastZoom != null) {
        _currentZoom = lastZoom;
      }
      if (savedZoomOffset != null) {
        _followZoomOffset = savedZoomOffset;
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
    } else {
      developer.log('Missing device ID for history route.', name: 'HistoryRouteScreen');
    }
  }

  Future<void> cleanExpiredRouteHistory() async {
    final routeBox = await Hive.openLazyBox<RoutePositionsHive>('route_positions');
    const cacheDuration = Duration(days: 60);
    final DateTime expiryThreshold = DateTime.now().subtract(cacheDuration);

    final List<dynamic> expiredKeys = [];

    for (final key in routeBox.keys) {
      final entry = await routeBox.get(key);
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
      if (_stopPoints.length >= _maxStopIconCount) {
        developer.log('Stop points truncated at $_maxStopIconCount (no numbered icon beyond it).', name: 'HistoryRouteScreen');
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
    _safeSetState(() {
      _isLoading = true;
      _isPlaying = false;
      _positions = [];
      _playbackPositionRx.value = 0.0;
      _shownIndexRx.value = 0;
      _currentAddressRx.value = "";
      _resetAddressSchedule();
      // 換日期/車輛後舊量測點已失去意義
      _isMeasureMode = false;
      _measurePoints.clear();
    });
    _clearMeasureLayers();

    List<api.Position> fetchedPositions = [];
    bool fetchedFromNetwork = false;
    final hiveKey = '$_deviceId-${DateFormat('yyyy-MM-dd').format(_historyFrom!)}';

    try {
      final routeBox = await Hive.openLazyBox<RoutePositionsHive>('route_positions');
      final cachedRoute = await routeBox.get(hiveKey);

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

      // Cleaning a dense day is a sort plus a trig pass per point, and encoding
      // it builds one map per point. Both are pointless on the frame that is
      // about to paint, so a dense track goes to a background isolate the same
      // way the GeoJSON layer does.
      final cleanupParams = _TrackCleanupParams(fetchedPositions, encode: fetchedFromNetwork);
      final cleanedTrack = fetchedPositions.length > _trackCleanupIsolateThreshold ? await compute(_cleanTrackIsolate, cleanupParams) : _cleanTrackIsolate(cleanupParams);
      final cleanedPositions = cleanedTrack.positions;

      if (cleanedPositions.length != fetchedPositions.length) {
        developer.log('Cleaned track: ${fetchedPositions.length} -> ${cleanedPositions.length} points', name: 'HistoryRouteScreen');
      }
      if (fetchedFromNetwork && cleanedPositions.isNotEmpty) {
        await routeBox.put(hiveKey, RoutePositionsHive(dateKey: hiveKey, positionsJson: cleanedTrack.positionsJson, cachedAt: DateTime.now()));
      }

      _calculateStops(cleanedPositions);

      final movingPositions = cleanedPositions.where((p) => (p.speed ?? 0) > 0).toList();
      final playbackPositions = movingPositions.isNotEmpty ? movingPositions : cleanedPositions;

      if (mounted) {
        _safeSetState(() {
          _positions = playbackPositions;
          _playedPrefix.clear();
          _playedPushInFlight = false;
          _repeatFlags = null;
          _repeatBoundaryIndices = <int>[];
          _playbackGeneration++;
          _isLoading = false;
          _resetAddressSchedule();
        });

        _calculateDistancePrefixSum();
        unawaited(_classifyRepeatPasses(playbackPositions));
        _refreshAddressNow(); // 先解析起點路名

        if (_mapController != null) {
          unawaited(_drawFullRoute());
        }
      }
    } catch (e) {
      debugPrint('獲取軌跡失敗: $e');
      if (mounted) {
        _safeSetState(() => _isLoading = false);
        FeedbackService.error('reportRouteLoadFailed'.tr, context: context);
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
    _stopSymbols.clear();
  }

  /// 對外入口：請求會排進序列，只執行最後一個，避免圖層 add/remove 交錯
  Future<void> _drawFullRoute({bool fitBounds = true}) {
    final int request = ++_latestDrawRequest;
    _drawQueue = _drawQueue
        .then<void>((_) async {
          if (request != _latestDrawRequest) return; // 已有更新的請求，這次直接跳過
          await _drawFullRouteNow(fitBounds: fitBounds);
        })
        .catchError((Object error, StackTrace stackTrace) {
          developer.log('Failed to draw route: $error', name: 'HistoryRouteScreen');
        });
    return _drawQueue;
  }

  Future<void> _drawFullRouteNow({bool fitBounds = true}) async {
    final controller = _mapController;
    if (controller == null || _positions.isEmpty) {
      return;
    }

    await _cleanMapLayers();
    // 圖層已清空，重建完成前不要對已移除的 symbol 送位置更新
    _playbackSymbol = null;

    // Only the two ends are used, so do not build a LatLng for every point.
    final LatLng startPoint = LatLng(_positions.first.latitude!.toDouble(), _positions.first.longitude!.toDouble());
    final LatLng endPoint = LatLng(_positions.last.latitude!.toDouble(), _positions.last.longitude!.toDouble());

    // 1. 建立背景軌跡 (超過1000點移至 Isolate 背景處理避免UI卡頓)
    Map<String, dynamic> routeGeoJson;
    if (_positions.length > 1000) {
      routeGeoJson = await compute(_buildGeoJsonIsolate, _GeoJsonParams(_positions, _routeColorMode));
    } else {
      routeGeoJson = _buildGeoJsonIsolate(_GeoJsonParams(_positions, _routeColorMode));
    }

    await controller.addSource(_routeSourceId, GeojsonSourceProperties(data: routeGeoJson));
    await controller.addLineLayer(_routeSourceId, _routeLayerId, LineLayerProperties(lineColor: ['get', 'color'], lineWidth: 4.0, lineOpacity: 0.45, lineJoin: 'round', lineCap: 'round'));

    // 2. 建立已播放軌跡圖層 (動態更新)
    final Map<String, dynamic> emptyPlayedGeoJson = {"type": "FeatureCollection", "features": []};
    await controller.addSource(_playedSourceId, GeojsonSourceProperties(data: emptyPlayedGeoJson));
    // await controller.addLineLayer(_playedSourceId, _playedLayerId, LineLayerProperties(lineColor: _routeColorMode == RouteColorMode.single ? '#0F53FE' : '#FF3D00', lineWidth: 6.5, lineOpacity: 1.0, lineJoin: 'round', lineCap: 'round'));
    await controller.addLineLayer(
      _playedSourceId,
      _playedLayerId,
      LineLayerProperties(
        lineColor: ['get', 'color'], // 改成依每個線段的 color 屬性上色
        lineWidth: 6.5,
        lineOpacity: 1.0,
        lineJoin: 'round',
        lineCap: 'round',
      ),
    );
    _playedPrefix.clear();
    _playedPushInFlight = false;
    _playbackGeneration++;
    // 新增：如果目前進度不在起點（例如切換顏色模式或地圖圖層），立刻補畫已走過的線段
    if (_playbackPositionRx.value > 0) {
      final int idx = _playbackPositionRx.value.floor().clamp(0, _positions.length - 1);
      _pushPlayedGeometry(idx, _positions[idx].longitude!.toDouble(), _positions[idx].latitude!.toDouble());
    }
    // 3. 繪製起終點標籤與停靠點（圖示失敗不可影響軌跡顯示）
    try {
      await controller.addSymbols([SymbolOptions(geometry: startPoint, iconImage: _startIconId, iconSize: 1.8, iconAnchor: "bottom"), SymbolOptions(geometry: endPoint, iconImage: _endIconId, iconSize: 1.8, iconAnchor: "bottom")]);
    } catch (e) {
      developer.log('Failed to add start/end markers: $e', name: 'HistoryRouteScreen');
    }

    try {
      // iconSize 依貼圖邊長換算，換多大的圖都維持同樣的畫面尺寸
      _playbackSymbol = await controller.addSymbol(
        SymbolOptions(geometry: LatLng(_positions.first.latitude!.toDouble(), _positions.first.longitude!.toDouble()), iconImage: _playbackIconId, iconSize: _playbackIconDisplayPx / _playbackIconPixels, zIndex: 10),
      );
    } catch (e) {
      _playbackSymbol = null;
      developer.log('Failed to add playback marker: $e', name: 'HistoryRouteScreen');
    }

    if (_showStopPoints) {
      await _drawStopSymbols();
    }

    if (fitBounds) {
      _animateCameraToBounds();
    }

    // 量測圖層需在軌跡圖層之後重建，才會保持在最上層
    if (_isMeasureMode) {
      await _drawMeasureOverlay();
    }
  }

  // --- 圍欄與停留點 ---

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
        if (mounted) FeedbackService.info('sharedNoData'.tr, context: context);
        return;
      }
      _safeSetState(() => _showGeofences = true);
      await _drawGeofences();
    } catch (e) {
      developer.log('Failed to load geofences: $e', name: 'HistoryRouteScreen');
      if (mounted) FeedbackService.error('sharedNoData'.tr, context: context);
    } finally {
      _safeSetState(() => _isGeofenceLoading = false);
    }
  }

  Future<void> _clearGeofenceLayers() async {
    final controller = _mapController;
    if (controller == null) return;
    try {
      await controller.removeLayer(_geofenceLineLayerId);
    } catch (_) {}
    try {
      await controller.removeLayer(_geofenceFillLayerId);
    } catch (_) {}
    try {
      await controller.removeSource(_geofenceSourceId);
    } catch (_) {}
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

    // 有軌跡時把圍欄壓在軌跡圖層下方
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
      return [
        {
          "type": "Feature",
          "properties": properties,
          "geometry": {
            "type": "Polygon",
            "coordinates": [_circleRing(lat, lon, radius)],
          },
        },
      ];
    }

    if (area.startsWith('POLYGON')) {
      final int openParen = area.indexOf('((');
      final int closeParen = area.lastIndexOf('))');
      if (openParen < 0 || closeParen <= openParen) return const [];
      final ring = _parseCoordinates(area.substring(openParen + 2, closeParen), closeRing: true);
      if (ring.length < 4) return const [];
      return [
        {
          "type": "Feature",
          "properties": properties,
          "geometry": {
            "type": "Polygon",
            "coordinates": [ring],
          },
        },
      ];
    }

    if (area.startsWith('LINESTRING')) {
      final int openParen = area.indexOf('(');
      final int closeParen = area.lastIndexOf(')');
      if (openParen < 0 || closeParen <= openParen) return const [];
      final line = _parseCoordinates(area.substring(openParen + 1, closeParen));
      if (line.length < 2) return const [];
      return [
        {
          "type": "Feature",
          "properties": properties,
          "geometry": {"type": "LineString", "coordinates": line},
        },
      ];
    }

    return const [];
  }

  /// Traccar 的 area 為「緯度 經度」，GeoJSON 需轉成 [經度, 緯度]。
  List<List<double>> _parseCoordinates(String raw, {bool closeRing = false}) {
    final coordinates = <List<double>>[];
    for (final pair in raw.split(',')) {
      final parts = pair.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final lat = double.tryParse(parts[0]);
      final lon = double.tryParse(parts[1]);
      if (lat == null || lon == null) continue;
      coordinates.add([lon, lat]);
    }
    if (closeRing && coordinates.length >= 3) {
      final first = coordinates.first;
      final last = coordinates.last;
      if (first[0] != last[0] || first[1] != last[1]) {
        coordinates.add([first[0], first[1]]);
      }
    }
    return coordinates;
  }

  /// MapLibre 的 circle layer 半徑是像素，直接將圓轉為多邊形環。
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
    if (_stopPoints.isEmpty) return;

    final Set<String> readyIcons = await _ensureStopIcons(_stopPoints.length);
    final List<SymbolOptions> options = [
      for (int i = 0; i < _stopPoints.length; i++)
        if (readyIcons.contains("pg_${i + 1}")) SymbolOptions(geometry: _stopPoints[i], iconImage: "pg_${i + 1}", iconSize: 3.5, iconAnchor: "center"),
    ];
    if (options.isEmpty) return;

    try {
      final List<Symbol> symbols = await controller.addSymbols(options);
      _stopSymbols.addAll(symbols);
    } catch (e) {
      developer.log('Failed to draw stop symbols: $e', name: 'HistoryRouteScreen');
    }
  }

  Future<void> _clearStopSymbols() async {
    final controller = _mapController;
    if (controller == null) return;
    for (final symbol in _stopSymbols) {
      try {
        await controller.removeSymbol(symbol);
      } catch (_) {}
    }
    _stopSymbols.clear();
  }

  void _setRouteColorMode(RouteColorMode mode) {
    _safeSetState(() {
      _routeColorMode = mode;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('route_color_mode', mode.name);
    });
    if (_positions.isNotEmpty) {
      unawaited(_drawFullRoute(fitBounds: false));
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
              Text(
                'routeColorModeTitle'.tr,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: _singleColorIcon,
                title: Text('routeColorModeSingle'.tr),
                subtitle: Text('routeColorModeSingleDesc'.tr),
                trailing: _routeColorMode == RouteColorMode.single ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  Navigator.pop(context);
                  _setRouteColorMode(RouteColorMode.single);
                },
              ),
              ListTile(
                leading: Container(width: 36, height: 12, decoration: _turboGradientDecoration),
                title: Text('routeColorModeSpeedStatus'.tr),
                trailing: _routeColorMode == RouteColorMode.speedStatus ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  Navigator.pop(context);
                  _setRouteColorMode(RouteColorMode.speedStatus);
                },
              ),
              ListTile(
                leading: _timeGradientIcons,
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
      ),
    );
  }

  // --- 土地面積量測 ---

  Future<void> _loadAreaUnitFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? saved = prefs.getString(_areaUnitPrefsKey);
      if (saved == null) return;
      final AreaUnit unit = AreaUnit.values.firstWhere((e) => e.name == saved, orElse: () => AreaUnit.acre);
      _safeSetState(() => _areaUnit = unit);
    } catch (e) {
      developer.log('Failed to load area unit from prefs: $e', name: 'HistoryRouteScreen');
    }
  }

  void _setAreaUnit(AreaUnit unit) {
    _safeSetState(() => _areaUnit = unit);
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_areaUnitPrefsKey, unit.name));
  }

  void _enterMeasureMode() {
    _playbackAnimationController?.stop();
    _safeSetState(() {
      _isPlaying = false;
      _followUser = false;
      _isMeasureMode = true;
      _measurePoints.clear();
    });
    _clearMeasureLayers();
    FeedbackService.info('historyMeasureHint'.tr, context: context);
  }

  Future<void> _exitMeasureMode() async {
    _safeSetState(() {
      _isMeasureMode = false;
      _measurePoints.clear();
    });
    await _clearMeasureLayers();
  }

  void _undoMeasurePoint() {
    if (_measurePoints.isEmpty) return;
    _safeSetState(() => _measurePoints.removeLast());
    _drawMeasureOverlay();
  }

  void _clearMeasurePoints() {
    if (_measurePoints.isEmpty) return;
    _safeSetState(_measurePoints.clear);
    _drawMeasureOverlay();
  }

  Future<void> _addMeasurePoint(LatLng raw) async {
    final LatLng snapped = _snapMeasurePointToTrack(raw);
    _safeSetState(() => _measurePoints.add(snapped));
    await _drawMeasureOverlay();
  }

  /// 手指不易精準點在軌跡上，點擊處附近（約 22 畫面像素）有軌跡點時吸附過去
  LatLng _snapMeasurePointToTrack(LatLng raw) {
    if (_positions.isEmpty) return raw;
    final double zoom = _mapController?.cameraPosition?.zoom ?? _currentZoom;
    final double metersPerPixel = 156543.03392 * cos(raw.latitude * pi / 180) / pow(2, zoom);
    final double threshold = metersPerPixel * 22;
    final double latSpan = threshold / 111320.0;
    final double lngSpan = latSpan / max(0.01, cos(raw.latitude * pi / 180));

    LatLng best = raw;
    double bestMeters = double.infinity;
    for (final p in _positions) {
      final double lat = p.latitude!.toDouble();
      final double lng = p.longitude!.toDouble();
      if ((lat - raw.latitude).abs() > latSpan || (lng - raw.longitude).abs() > lngSpan) continue;
      final double d = _distanceBetween(raw.latitude, raw.longitude, lat, lng) * 1000;
      if (d < bestMeters) {
        bestMeters = d;
        best = LatLng(lat, lng);
      }
    }
    return bestMeters <= threshold ? best : raw;
  }

  /// 球面多邊形面積（與 Turf 的 ringArea 相同算法），回傳平方公尺
  double _measureAreaSquareMeters() {
    if (_measurePoints.length < 3) return 0;
    const double earthRadius = 6378137.0;
    double total = 0;
    for (int i = 0; i < _measurePoints.length; i++) {
      final p1 = _measurePoints[i];
      final p2 = _measurePoints[(i + 1) % _measurePoints.length];
      total += (p2.longitude - p1.longitude) * pi / 180 * (2 + sin(p1.latitude * pi / 180) + sin(p2.latitude * pi / 180));
    }
    return (total * earthRadius * earthRadius / 2).abs();
  }

  double _measurePerimeterMeters() {
    final pts = _measurePoints;
    if (pts.length < 2) return 0;
    double total = 0;
    for (int i = 1; i < pts.length; i++) {
      total += _distanceBetween(pts[i - 1].latitude, pts[i - 1].longitude, pts[i].latitude, pts[i].longitude);
    }
    if (pts.length >= 3) {
      total += _distanceBetween(pts.last.latitude, pts.last.longitude, pts.first.latitude, pts.first.longitude);
    }
    return total * 1000;
  }

  String _formatAreaValue(double squareMeters, AreaUnit unit) {
    final String pattern = unit.decimals == 0 ? '#,##0' : '#,##0.${'0' * unit.decimals}';
    return NumberFormat(pattern, 'en_US').format(unit.fromSquareMeters(squareMeters));
  }

  Future<void> _clearMeasureLayers() async {
    final controller = _mapController;
    if (controller == null) return;
    for (final id in [_measureVertexLayerId, _measureLineLayerId, _measureFillLayerId]) {
      try {
        await controller.removeLayer(id);
      } catch (_) {}
    }
    for (final id in [_measureVertexSourceId, _measureSourceId]) {
      try {
        await controller.removeSource(id);
      } catch (_) {}
    }
  }

  /// 可重複呼叫：先清再畫，確保量測圖層在軌跡之上
  Future<void> _drawMeasureOverlay() async {
    final controller = _mapController;
    if (controller == null) return;
    await _clearMeasureLayers();
    if (!_isMeasureMode || _measurePoints.isEmpty) return;

    final List<List<double>> ring = _measurePoints.map((p) => [p.longitude, p.latitude]).toList();
    final List<Map<String, dynamic>> features = [];
    if (ring.length >= 3) {
      features.add({
        "type": "Feature",
        "properties": {"kind": "fill"},
        "geometry": {
          "type": "Polygon",
          "coordinates": [
            [...ring, ring.first],
          ],
        },
      });
    }
    if (ring.length >= 2) {
      features.add({
        "type": "Feature",
        "properties": {"kind": "line"},
        "geometry": {
          "type": "LineString",
          "coordinates": ring.length >= 3 ? [...ring, ring.first] : ring,
        },
      });
    }

    if (features.isNotEmpty) {
      await controller.addSource(_measureSourceId, GeojsonSourceProperties(data: {"type": "FeatureCollection", "features": features}));
      await controller.addFillLayer(_measureSourceId, _measureFillLayerId, FillLayerProperties(fillColor: '#FF9800', fillOpacity: 0.22), filter: ['==', 'kind', 'fill'], enableInteraction: false);
      await controller.addLineLayer(
        _measureSourceId,
        _measureLineLayerId,
        LineLayerProperties(lineColor: '#EF6C00', lineWidth: 2.5, lineDasharray: [2, 1.5], lineJoin: 'round'),
        filter: ['==', 'kind', 'line'],
        enableInteraction: false,
      );
    }

    final Map<String, dynamic> vertices = {
      "type": "FeatureCollection",
      "features": _measurePoints
          .map(
            (p) => {
              "type": "Feature",
              "geometry": {
                "type": "Point",
                "coordinates": [p.longitude, p.latitude],
              },
            },
          )
          .toList(),
    };
    await controller.addSource(_measureVertexSourceId, GeojsonSourceProperties(data: vertices));
    await controller.addCircleLayer(_measureVertexSourceId, _measureVertexLayerId, CircleLayerProperties(circleColor: '#EF6C00', circleRadius: 5, circleStrokeColor: '#FFFFFF', circleStrokeWidth: 2), enableInteraction: false);
  }

  Widget _buildMeasurePanel() {
    final theme = Theme.of(context);
    final double m2 = _measureAreaSquareMeters();
    final double perimeter = _measurePerimeterMeters();
    final bool hasArea = _measurePoints.length >= 3;
    final List<AreaUnit> secondaryUnits = [AreaUnit.hectare, AreaUnit.squareMeter, AreaUnit.jia].where((u) => u != _areaUnit).take(2).toList();

    return Container(
      key: const ValueKey('history_measure_panel'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 8, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.4 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.square_foot, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'historyMeasureTooltip'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                ),
              ),
              const SizedBox(width: 8),
              Text('${_measurePoints.length}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
              IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.undo, size: 20), onPressed: _measurePoints.isEmpty ? null : _undoMeasurePoint, tooltip: 'historyMeasureUndo'.tr),
              IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.delete_outline, size: 20), onPressed: _measurePoints.isEmpty ? null : _clearMeasurePoints, tooltip: 'historyMeasureClear'.tr),
              IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.close_rounded, size: 20), onPressed: _exitMeasureMode, tooltip: 'historyMeasureExit'.tr),
            ],
          ),
          if (hasArea)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: _formatAreaValue(m2, _areaUnit),
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: theme.colorScheme.primary, letterSpacing: -0.5),
                  ),
                  TextSpan(
                    text: ' ${_areaUnit.labelKey.tr}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            )
          else
            Text('historyMeasureNeedThree'.tr, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
          if (hasArea) Text(secondaryUnits.map((u) => '${_formatAreaValue(m2, u)} ${u.labelKey.tr}').join(' · '), style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
          Text('${'historyMeasurePerimeter'.tr}: ${NumberFormat('#,##0.0', 'en_US').format(perimeter)} ${'sharedMeter'.tr}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: AreaUnit.values.map((u) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(u.labelKey.tr, style: const TextStyle(fontSize: 11)),
                    selected: _areaUnit == u,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (_) => _setAreaUnit(u),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 前後步進一個軌跡點（播放面板的跳點按鈕共用）
  void _stepPlayback(int delta) {
    if (_positions.isEmpty) return;
    HapticFeedback.selectionClick();
    final double maxLimit = max(0, _positions.length - 1).toDouble();
    _playbackPositionRx.value = (_playbackPositionRx.value + delta).clamp(0.0, maxLimit).toDouble();
    _updatePlaybackUI();
  }

  void _togglePlayback() {
    if (_positions.isEmpty) return;

    HapticFeedback.selectionClick();

    if (_isPlaying) {
      _playbackAnimationController?.stop();
      _safeSetState(() => _isPlaying = false);
      _refreshAddressNow(); // 暫停時立刻校正目前位置的路名
      return;
    }

    final double maxLimit = max(0, _positions.length - 1).toDouble();
    if (_playbackPositionRx.value >= maxLimit) {
      _playbackPositionRx.value = 0;
      _updatePlaybackUI();
    }

    _followUser = true;
    _focusCameraOnPlayback();

    _lastTickAtMs = 0;
    _addressRequestedAtMs = 0; // 重新開始時立刻允許預取
    _safeSetState(() => _isPlaying = true);
    _playbackAnimationController?.repeat();
  }

  // 開始播放時把鏡頭移到目前播放位置並擺到跟隨視野；使用者剛自己動過 zoom 就只置中。
  void _focusCameraOnPlayback() {
    final controller = _mapController;
    if (controller == null || _positions.isEmpty) return;

    final int idx = _playbackPositionRx.value.floor().clamp(0, _positions.length - 1);
    final pos = _positions[idx];
    final point = LatLng(pos.latitude!.toDouble(), pos.longitude!.toDouble());
    final double targetZoom = _followZoomOrKeep(point.latitude);
    final int now = DateTime.now().millisecondsSinceEpoch;

    _lastDerivedSpeed = _playbackSpeed;
    _suppressFollowCameraUntilMs = now + _focusCameraAnimMs + 100;
    _cameraBudget.reset();
    controller.animateCamera(CameraUpdate.newLatLngZoom(point, targetZoom), duration: const Duration(milliseconds: _focusCameraAnimMs));
  }

  /// 跟隨鏡頭該用的 zoom。使用者剛動過就回傳他現在的 zoom，等於不動。
  double _followZoomOrKeep(double latitude) {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    if (isInsideZoomFreeze(nowMs: nowMs, lastUserZoomAtMs: _userZoomTouchedAtMs)) return _currentZoom;
    return _derivedFollowZoom(latitude);
  }

  /// 只由倍速、這條軌跡的長度、緯度、可用畫面高度推導，不含使用者的凍結期。
  double _derivedFollowZoom(double latitude) {
    return followZoom(trackLengthMeters: _trackLengthMeters(), speed: _playbackSpeed, latitude: latitude, viewportHeightPx: _visibleViewportHeight(), userOffsetLog2: _followZoomOffset);
  }

  /// 這條軌跡總長（公尺）。同一趟回放不分長短都是兩分鐘，所以視野必須跟著它縮放。
  double _trackLengthMeters() {
    if (_distancePrefixSum.length < 2) return 0;
    return _distancePrefixSum.last * 1000;
  }

  double _visibleViewportHeight() {
    final size = MediaQuery.maybeSizeOf(context);
    if (size == null) return 800 * _visibleViewportFraction;
    return size.height * _visibleViewportFraction;
  }

  /// 使用者自己挑了 zoom：記下他能插手的時間，播放中就順便把偏好折進偏移。
  void _noteUserZoom(double zoom) {
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    _userZoomTouchedAtMs = nowMs;
    if (!_isPlaying || _positions.isEmpty) return;
    final int idx = _playbackPositionRx.value.floor().clamp(0, _positions.length - 1);
    final double latitude = _positions[idx].latitude!.toDouble();
    final double settled = settleFollowOffset(currentOffset: _followZoomOffset, userZoom: zoom, derivedZoom: _derivedFollowZoom(latitude));
    if ((settled - _followZoomOffset).abs() < 0.01) return;
    _followZoomOffset = settled;
    _saveFollowZoomOffset();
  }

  void _saveFollowZoomOffset() {
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.setDouble(_followZoomOffsetPrefsKey, _followZoomOffset);
        })
        .catchError((Object error) => developer.log('Failed to save follow zoom offset: $error', name: 'HistoryRouteScreen'));
  }

  /// 換日期 / 換車輛 / 重新載入軌跡時，丟掉所有排程狀態與在飛請求
  void _resetAddressSchedule() {
    _addressRequestToken++; // 讓所有在飛的回覆失效
    _addressShownIdx = -1;
    _addressCacheCheckedIdx = -1;
    _addressInFlightIdx = -1;
    _addressInFlightLeadIdx = 0;
    _addressScheduledAtMs = 0;
    _addressRequestedAtMs = 0;
  }

  /// 播放每個 tick 前進 0.05 × 倍速，所以「一次請求往返所需的時間」內會走過的點數，
  /// 就是該提前預取的點數：請求在標記抵達該點時剛好回來，路名才不會落後。
  int _addressLeadPoints() {
    final double pointsPerSecond = 0.05 * _playbackSpeed * _frameRate;
    final double cycleMs = max(_addressRemoteMinGapMs.toDouble(), _addressLatencyMs);
    return max(0, (pointsPerSecond * cycleMs / 1000).round());
  }

  bool _isAddressCached(api.Position p) => OfflineAddressService.getAddressFromCache(p.latitude!.toDouble(), p.longitude!.toDouble()) != null;

  void _trackFrameRate() {
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (_lastTickAtMs > 0) {
      final int dt = now - _lastTickAtMs;
      if (dt > 0) _frameRate = (_frameRate * 0.9 + (1000 / dt) * 0.1).clamp(24.0, 144.0).toDouble();
    }
    _lastTickAtMs = now;
  }

  /// 顯示層：目前位置的位址若已在 Hive 快取，立即更新（零網路成本）
  void _applyCachedAddress(int idx) {
    if (idx < 0 || idx >= _positions.length) return;
    if (idx == _addressShownIdx) return;
    final api.Position p = _positions[idx];
    final String? cached = OfflineAddressService.getAddressFromCache(p.latitude!.toDouble(), p.longitude!.toDouble());
    if (cached == null || cached == _currentAddressRx.value) return;
    _currentAddressRx.value = cached;
    _addressShownIdx = idx;
  }

  /// 請求層：單一 in-flight；播放中依倍速往前「跳點預取」，避免回放跑到新路時還顯示舊路名
  void _scheduleAddressRequest(int idx, {bool forceCurrent = false}) {
    if (_positions.isEmpty) return;
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (!forceCurrent && now - _addressScheduledAtMs < _addressSchedulerThrottleMs) return;
    _addressScheduledAtMs = now;

    final int cur = idx.clamp(0, _positions.length - 1);
    _applyCachedAddress(cur);

    // 一次只允許一個請求在飛；回覆回來時會自行判斷是否過期並補發
    if (_addressInFlightIdx >= 0) return;

    // 依倍速往前找第一個「還沒快取」的點，這才是真正需要請求的位置
    final int lead = forceCurrent ? 0 : _addressLeadPoints();
    final int end = min(_positions.length - 1, cur + lead);
    int? target;
    for (int i = cur; i <= end; i++) {
      if (!_isAddressCached(_positions[i])) {
        target = i;
        break;
      }
    }
    if (target == null) return; // 前方路段都已在快取內

    // 遠端查詢限流；暫停 / 拖曳 / 換倍速的強制校正不受此限
    if (!forceCurrent && now - _addressRequestedAtMs < _addressRemoteMinGapMs) return;

    final int targetIdx = target;
    final api.Position targetPosition = _positions[targetIdx];
    final double targetLat = targetPosition.latitude!.toDouble();
    final double targetLng = targetPosition.longitude!.toDouble();
    final int token = ++_addressRequestToken;

    _addressRequestedAtMs = now;
    _addressInFlightIdx = targetIdx;
    _addressInFlightLeadIdx = lead;
    final int sentAtMs = now;

    OfflineAddressService.getAddress(targetLat, targetLng).then((addr) {
      if (!mounted || token != _addressRequestToken) return;
      final int leadAtRequest = _addressInFlightLeadIdx;
      _addressInFlightIdx = -1;

      // 追蹤實際往返時間（含服務層 1.5s 限流），慢網路時下一輪會預取得更遠
      final double rttMs = (DateTime.now().millisecondsSinceEpoch - sentAtMs).toDouble();
      _addressLatencyMs = _addressLatencyMs == 0 ? rttMs : (_addressLatencyMs * 0.7 + rttMs * 0.3).clamp(0.0, 15000.0).toDouble();

      final int nowIdx = _playbackPositionRx.value.floor().clamp(0, _positions.length - 1);
      // 播放已跑得比目標點更遠（超過一個請求週期）→ 這筆結果沒有意義，改用目前位置重發
      if (nowIdx - targetIdx > max(4, leadAtRequest)) {
        if (_isPlaying) {
          _addressRequestedAtMs = 0;
          _scheduleAddressRequest(nowIdx);
        }
        return;
      }

      if (addr.isEmpty || addr.startsWith('Error')) return;
      if (addr != _currentAddressRx.value) _currentAddressRx.value = addr;
      _addressShownIdx = targetIdx;
    });
  }

  /// 暫停 / 拖曳結束 / 換倍速：立刻校正「目前位置」的路名
  void _refreshAddressNow() {
    if (_positions.isEmpty) return;
    final int cur = _playbackPositionRx.value.floor().clamp(0, _positions.length - 1);
    _addressRequestToken++; // 讓先前預取的回覆失效，避免暫停後又被「前方路名」蓋掉
    _addressInFlightIdx = -1;
    _addressScheduledAtMs = 0;
    _addressRequestedAtMs = 0;
    _scheduleAddressRequest(cur, forceCurrent: true);
  }

  void _pushPlayedGeometry(int idx, double smoothLng, double smoothLat) {
    final controller = _mapController;
    if (controller == null || _positions.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (_playedPushInFlight || (_isPlaying && !_playedBudget.due(now))) {
      return;
    }

    // 重複判斷整條軌跡只算一次（_repeatFlags），這裡只查表，不重算，
    // 否則每次推送都要重掃已播放的座標，長軌跡會變成平方級成本。
    final Uint8List? repeatFlags = _repeatFlags;
    final String firstPassColor = _routeColorMode == RouteColorMode.single ? '#0F53FE' : '#FF3D00';
    const String repeatPassColor = '#9C27B0';

    final int safeIdx = idx.clamp(0, _positions.length - 1);
    // 頂點數壓在約 1500 以內；但顏色切換點必須保留，否則抽樣會
    // 跳過重複路段邊界，造成紫色線段看起來斷斷續續。
    final int step = max(1, (safeIdx + 1) ~/ 1500);

    final List<Map<String, dynamic>> features = <Map<String, dynamic>>[];
    List<List<double>> run = <List<double>>[];
    bool runIsRepeat = false;

    bool isRepeatAt(int index) => repeatFlags != null && index >= 0 && index < repeatFlags.length && repeatFlags[index] == 1;

    void flushRun() {
      if (run.length < 2) return;
      features.add({
        'type': 'Feature',
        'properties': {'color': runIsRepeat ? repeatPassColor : firstPassColor},
        'geometry': {'type': 'LineString', 'coordinates': run},
      });
    }

    void addVertex(double lng, double lat, bool repeat) {
      if (run.isEmpty) {
        run = [
          [lng, lat],
        ];
        runIsRepeat = repeat;
        return;
      }
      if (repeat == runIsRepeat) {
        run.add([lng, lat]);
        return;
      }
      // 換色處從交界點接上，線條才不會斷
      final List<double> junction = run.last;
      flushRun();
      run = [
        junction,
        [lng, lat],
      ];
      runIsRepeat = repeat;
    }

    final Set<int> sampleIndices = <int>{};
    for (var i = 0; i <= safeIdx; i += step) {
      sampleIndices.add(i);
    }
    sampleIndices.add(safeIdx);
    // 強制保留每個重複/非重複顏色轉換的兩側頂點。
    for (final int boundary in _repeatBoundaryIndices) {
      if (boundary > safeIdx) break;
      sampleIndices.add(boundary - 1);
      sampleIndices.add(boundary);
    }
    final List<int> orderedIndices = sampleIndices.toList()..sort();
    for (final int i in orderedIndices) {
      final p = _positions[i];
      final double? lng = p.longitude?.toDouble();
      final double? lat = p.latitude?.toDouble();
      if (lng == null || lat == null) continue;
      addVertex(lng.toDouble(), lat.toDouble(), isRepeatAt(i));
    }
    addVertex(smoothLng, smoothLat, isRepeatAt(safeIdx));
    flushRun();

    if (features.isEmpty) return;

    _playedPushInFlight = true;
    final geoJson = <String, dynamic>{'type': 'FeatureCollection', 'features': features};
    final int generation = _playbackGeneration;

    unawaited(
      controller
          .setGeoJsonSource(_playedSourceId, geoJson)
          .catchError((Object error) {
            developer.log('Failed to push played line: $error', name: 'HistoryRouteScreen');
          })
          .whenComplete(() {
            if (generation == _playbackGeneration) {
              _playedPushInFlight = false;
            }
          }),
    );
  }

  /// 重複經過的判斷是整條軌跡的性質，載入時算一次就好。
  Future<void> _classifyRepeatPasses(List<api.Position> positions) async {
    if (positions.isEmpty) return;
    final Float64List packed = Float64List(positions.length * 2);
    for (var i = 0; i < positions.length; i++) {
      packed[i * 2] = positions[i].longitude?.toDouble() ?? double.nan;
      packed[i * 2 + 1] = positions[i].latitude?.toDouble() ?? double.nan;
    }
    final int generation = _playbackGeneration;
    Uint8List flags;
    try {
      flags = positions.length > _trackCleanupIsolateThreshold ? await compute(_classifyRepeatPassesIsolate, packed) : classifyRepeatPasses(packed);
    } catch (error) {
      developer.log('Failed to classify repeat passes: $error', name: 'HistoryRouteScreen');
      return;
    }
    if (!mounted || generation != _playbackGeneration) return;
    _repeatFlags = flags;
    _repeatBoundaryIndices = <int>[];
    for (var i = 1; i < flags.length; i++) {
      if (flags[i] != flags[i - 1]) _repeatBoundaryIndices.add(i);
    }
    // 旗標晚到時補畫一次，否則暫停中的畫面會停在算完之前那條全藍的線
    if (_mapController != null) _updatePlaybackUI();
  }

  void _onAnimationTick() {
    if (!_isPlaying || _positions.isEmpty) return;
    // 這一格距離上一格的真實秒數；用時間推進，螢幕更新率就不會改變回放速度
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final double deltaSeconds = _lastTickAtMs == 0 ? 1 / 60 : ((nowMs - _lastTickAtMs) / 1000).clamp(0.0, 0.1);
    _trackFrameRate();

    final double maxLimit = max(0, _positions.length - 1).toDouble();
    final double nextVal = advancePlaybackPosition(position: _playbackPositionRx.value, maxPosition: maxLimit, speed: _playbackSpeed, deltaSeconds: deltaSeconds);

    if (nextVal >= maxLimit) {
      _playbackPositionRx.value = maxLimit;
      _playbackAnimationController?.stop();
      _safeSetState(() => _isPlaying = false);
      _refreshAddressNow(); // 播完停在終點，校正終點路名
    } else {
      _playbackPositionRx.value = nextVal;
    }

    _updatePlaybackUI();
  }

  void _publishShownIndex() {
    final int idx = _playbackPositionRx.value.floor().clamp(0, max(0, _positions.length - 1));
    if (idx != _shownIndexRx.value) _shownIndexRx.value = idx;
  }

  void _updatePlaybackUI() async {
    _publishShownIndex();

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

    // 路名：換一個點就查一次快取（零成本）；播放中依倍速跳點預取
    if (idx != _addressCacheCheckedIdx) {
      _addressCacheCheckedIdx = idx;
      _applyCachedAddress(idx);
    }
    if (_isPlaying) {
      _scheduleAddressRequest(idx);
    }

    // 更新行進中的小車標記
    // 播放中每一幀都打一次平台通道太貴，用量由 _markerBudget 顧；暫停與拖曳時立即更新。
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!_isPlaying || _markerBudget.due(nowMs)) {
      _mapController!.updateSymbol(_playbackSymbol!, SymbolOptions(geometry: currentLatLng, iconRotate: bearing));
    }

    // 已播放軌跡：只補新增點，並把平台通道更新壓到約 10Hz
    _pushPlayedGeometry(idx, smoothLng, smoothLat);

    // 相機跟隨：標記還留在畫面裡時鏡頭不動，跑進外圈才把它推回中央。
    // 倍速換了就跟著換視野：20x 一小時走完的路用 1x 的視野看只會看到箭頭亂跳。
    final controller = _mapController;
    if (_followUser && _isPlaying && controller != null && nowMs >= _suppressFollowCameraUntilMs && _cameraBudget.due(nowMs)) {
      final int generation = _playbackGeneration;
      final bool zoomStale = _playbackSpeed != _lastDerivedSpeed && !isInsideZoomFreeze(nowMs: nowMs, lastUserZoomAtMs: _userZoomTouchedAtMs);
      if (zoomStale) {
        _lastDerivedSpeed = _playbackSpeed;
        controller.animateCamera(CameraUpdate.newLatLngZoom(currentLatLng, _derivedFollowZoom(currentLatLng.latitude)), duration: const Duration(milliseconds: _followZoomAnimMs));
        _suppressFollowCameraUntilMs = nowMs + _followZoomAnimMs + 100;
        return;
      }
      final LatLngBounds visibleRegion = await controller.getVisibleRegion();
      // 這一趟回來時使用者可能已經暫停、放開跟隨或換了軌跡，就不該再動鏡頭
      if (!mounted || generation != _playbackGeneration || !_isPlaying || !_followUser) return;
      final bool nearEdge = isInEdgeZone(
        latitude: currentLatLng.latitude,
        longitude: currentLatLng.longitude,
        south: visibleRegion.southwest.latitude,
        west: visibleRegion.southwest.longitude,
        north: visibleRegion.northeast.latitude,
        east: visibleRegion.northeast.longitude,
      );
      if (nearEdge) {
        controller.animateCamera(CameraUpdate.newLatLng(currentLatLng), duration: const Duration(milliseconds: _followPanAnimMs));
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

    final controller = _mapController;
    // 總覽就是「整條軌跡」這個視圖，它的 zoom 只能是框住軌跡，跟使用者偏好無關。
    controller?.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(minLat, minLon), northeast: LatLng(maxLat, maxLon)), left: 70, right: 70, top: 70, bottom: 250));
  }

  double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var a = 0.5 - cos((lat2 - lat1) * p) / 2 + cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // --- 報表頁跳轉 ---

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

  // --- UI 元件建立 ---

  @override
  Widget build(BuildContext context) {
    final double safeTop = MediaQuery.of(context).padding.top;
    final bool simpleMode = context.watch<SettingsProvider>().simpleMode;
    // 簡易模式不使用極簡視圖：切換鈕會被藏起來，停在極簡模式就回不去了。
    final bool minimalMode = _isMinimalMode && !simpleMode;
    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            key: ValueKey(Provider.of<MapStyleProvider>(context).isSatelliteMode),
            onMapCreated: (c) => _mapController = c,
            onStyleLoadedCallback: _onStyleLoaded,
            initialCameraPosition: _lastCameraPosition ?? CameraPosition(target: const LatLng(0, 0), zoom: _currentZoom),
            styleString: Provider.of<MapStyleProvider>(context).getStyle(Theme.of(context).brightness),
            onCameraMoveStarted: (reason) {
              if (reason != CameraMoveReason.gesture) return;
              _gestureInProgress = true;
              _zoomAtGestureStart = _currentZoom;
            },
            onCameraMove: (position) {
              _lastCameraPosition = position;
              _currentZoom = position.zoom;
              // 手指捏合拉開就是在挑 zoom，跟播放時的每格移動無關
              if (_gestureInProgress && (position.zoom - _zoomAtGestureStart).abs() > 0.05) {
                _noteUserZoom(position.zoom);
              }
              _saveCameraZoomSoon();
            },
            onCameraIdle: () => _gestureInProgress = false,
            myLocationEnabled: false,
            trackCameraPosition: true,
            onMapClick: (_, LatLng point) {
              if (_isMeasureMode) {
                _addMeasurePoint(point);
                return;
              }
              _safeSetState(() => _followUser = false);
            },
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),

          if (!minimalMode)
            Positioned(
              top: safeTop + 12,
              left: 64,
              right: 64,
              child: Center(child: _buildDeviceDatePill()),
            ),

          if (!simpleMode)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              top: safeTop + (_isMinimalMode ? 12 : 60),
              left: 12,
              child: _mapFab(
                _isMinimalMode ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                () => _safeSetState(() => _isMinimalMode = !_isMinimalMode),
                "btn_minimal",
                active: _isMinimalMode,
                tooltip: _isMinimalMode ? 'standardViewMode'.tr : 'minimalViewMode'.tr,
              ),
            ),

          if (!minimalMode) ...[
            Positioned(
              top: safeTop + 60,
              right: 12,
              child: Column(
                children: simpleMode
                    ? [
                        // 圖層切換保留（空照圖看地形很實用）。
                        _mapFab(Provider.of<MapStyleProvider>(context).isSatelliteMode ? Icons.map : Icons.satellite_alt, _toggleMapType, "btn_style"),
                        const SizedBox(height: 8),
                        _mapFab(
                          Icons.center_focus_strong,
                          () {
                            _safeSetState(() => _followUser = true);
                            _animateCameraToBounds();
                          },
                          "btn_recenter",
                          active: _followUser,
                        ),
                      ]
                    : [
                        _mapFab(Icons.show_chart_rounded, () => _openReportPage((_) => const ChartReportScreen()), "btn_chart", tooltip: 'reportChart'.tr),
                        const SizedBox(height: 8),
                        _mapFab(Icons.route_rounded, () => _openReportPage((_) => const TripsReportScreen()), "btn_trips", tooltip: 'reportTrips'.tr),
                        const SizedBox(height: 8),
                        _mapFab(Icons.pause_circle_outline_rounded, () => _openReportPage((_) => const StopsReportScreen()), "btn_stops", tooltip: 'reportStops'.tr),
                        const SizedBox(height: 8),
                        _mapFab(Icons.pin_drop_rounded, _toggleStopPoints, "btn_stop_points", active: _showStopPoints, tooltip: 'historyStopPointsToggle'.tr),
                        const SizedBox(height: 8),
                        _mapFab(Icons.palette_rounded, _showColorModeMenu, "btn_color_mode", active: _routeColorMode != RouteColorMode.single, tooltip: 'routeColorModeTooltip'.tr),
                        const SizedBox(height: 8),
                        // _mapFab(Icons.calendar_month, _showCalendarDialog, "btn_cal"),
                        // const SizedBox(height: 8),
                        _mapFab(Provider.of<MapStyleProvider>(context).isSatelliteMode ? Icons.map : Icons.satellite_alt, _toggleMapType, "btn_style"),
                        const SizedBox(height: 8),
                        _mapFab(
                          Icons.center_focus_strong,
                          () {
                            _safeSetState(() => _followUser = true);
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
              left: 12,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
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
    _noteUserZoom(target);
    controller.animateCamera(CameraUpdate.zoomTo(target), duration: const Duration(milliseconds: 250));
  }

  void _saveCameraZoomSoon() {
    _zoomSaveTimer?.cancel();
    _zoomSaveTimer = Timer(const Duration(milliseconds: 300), () {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setDouble('history_zoom_level', _currentZoom);
      });
    });
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

  Widget _buildDeviceDatePill() {
    final theme = Theme.of(context);
    final String dateLabel = DateFormat('yyyy/MM/dd').format(_historyFrom ?? DateTime.now());
    // 簡易模式字級 1.4 倍：車牌與日期改成上下兩行，車牌用滿可用寬度完整顯示。
    final bool simpleMode = context.watch<SettingsProvider>().simpleMode;

    final TextStyle nameStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface);
    final TextStyle dateStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface);

    final Widget pillContent = simpleMode
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_car_filled_rounded, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(_selectedDeviceName ?? '--', maxLines: 2, softWrap: true, overflow: TextOverflow.ellipsis, style: nameStyle),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(dateLabel, style: dateStyle),
                  const SizedBox(width: 6),
                  Icon(Icons.calendar_month_rounded, size: 15, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_car_filled_rounded, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(_selectedDeviceName ?? '--', maxLines: 1, overflow: TextOverflow.ellipsis, style: nameStyle),
              ),
              const SizedBox(width: 8),
              Text('·', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(width: 8),
              Text(dateLabel, style: dateStyle),
              const SizedBox(width: 6),
              Icon(Icons.calendar_month_rounded, size: 15, color: theme.colorScheme.onSurfaceVariant),
            ],
          );

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
      elevation: 2,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: _showCalendarDialog,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), child: pillContent),
      ),
    );
  }

  Widget _buildPlaybackPanel() {
    final bool simpleMode = context.watch<SettingsProvider>().simpleMode;
    final bool minimalMode = _isMinimalMode && !simpleMode;
    return Positioned(
      bottom: 24 + MediaQuery.of(context).padding.bottom,
      left: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 地理圍欄與面積量測屬進階工具，簡易模式不顯示。
          if (!simpleMode)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _mapFab(_isGeofenceLoading ? Icons.hourglass_top_rounded : Icons.fence_rounded, _toggleGeofences, "btn_geofence", active: _showGeofences, tooltip: 'historyGeofenceToggle'.tr),
                _mapFab(
                  Icons.square_foot,
                  () {
                    if (_isMeasureMode) {
                      _exitMeasureMode();
                    } else {
                      _enterMeasureMode();
                    }
                  },
                  "btn_measure",
                  active: _isMeasureMode,
                  tooltip: 'historyMeasureTooltip'.tr,
                ),
              ],
            ),
          if (_isMeasureMode && !simpleMode) ...[const SizedBox(height: 10), _buildMeasurePanel()],
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) => Stack(alignment: Alignment.bottomCenter, children: [...previousChildren, ?currentChild]),
            child: minimalMode ? _buildMinimalPlaybackPanel() : _buildFullPlaybackPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildFullPlaybackPanel() {
    final bool simpleMode = context.watch<SettingsProvider>().simpleMode;
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
              maxLines: simpleMode ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Obx(() {
            final int idx = _shownIndexRx.value.clamp(0, max(0, _positions.length - 1));
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
                onChangeEnd: (_) => _refreshAddressNow(), // 拖曳結束立刻校正路名
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
                tooltip: _isPlaying ? 'playbackPause'.tr : 'playbackPlay'.tr,
                icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 30),
              ),
              const SizedBox(width: 4),
              IconButton(
                style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: () => _stepPlayback(-1),
                icon: const Icon(Icons.skip_previous_rounded, size: 24),
              ),
              IconButton(
                style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: () => _stepPlayback(1),
                icon: const Icon(Icons.skip_next_rounded, size: 24),
              ),
              // 倍速選擇器與 GPX 匯出屬進階操作，簡易模式不顯示。
              if (!simpleMode) ...[
                // 倍速選擇器：空間足夠時外觀不變，窄螢幕自動縮放，避免 Row 溢出
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: FittedBox(fit: BoxFit.scaleDown, child: _buildSpeedSelector()),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.outlined(onPressed: _exportToGPX, icon: const Icon(Icons.download_rounded, size: 20), tooltip: 'exportGpx'.tr),
              ],
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
      padding: const EdgeInsetsDirectional.fromSTEB(10, 2, 14, 6),
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
                  onChangeEnd: (_) => _refreshAddressNow(), // 拖曳結束立刻校正路名
                ),
              ),
            );
          }),
          Row(
            children: [
              IconButton(
                style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: () => _stepPlayback(-1),
                icon: const Icon(Icons.skip_previous_rounded, size: 22),
              ),
              IconButton(
                style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: () => _stepPlayback(1),
                icon: const Icon(Icons.skip_next_rounded, size: 22),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: theme.colorScheme.primary, minimumSize: const Size(40, 40), padding: EdgeInsets.zero),
                  onPressed: _togglePlayback,
                  tooltip: _isPlaying ? 'playbackPause'.tr : 'playbackPlay'.tr,
                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: theme.colorScheme.onPrimary, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(() {
                  final int idx = _shownIndexRx.value.clamp(0, max(0, _positions.length - 1));
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
      FeedbackService.error('exportNoTrackData'.tr, context: context);
      return;
    }

    final deviceName = _selectedDeviceName ?? 'sharedDevice'.tr;
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

      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'exportGpxShareText'.trParams({'name': deviceName})));
    } catch (e) {
      FeedbackService.error(e.toString(), context: context);
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: _playbackSpeeds.map((s) {
          bool selected = _playbackSpeed == s;
          return GestureDetector(
            onTap: () {
              _safeSetState(() => _playbackSpeed = s);
              _savePlaybackSpeedToHive(s);
              _addressRequestedAtMs = 0; // 倍速變了，預取領先量與節奏立即重算
            },
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

  Future<void> _fetchMonthlyData(DateTime month, {VoidCallback? onUpdated}) async {
    if (_deviceId == null) {
      return;
    }

    if (_dailySummaries.isNotEmpty && month.month == _focusedDay.month && month.year == _focusedDay.year) {
      onUpdated?.call();
      return;
    }

    _safeSetState(() {
      _isCalendarLoading = true;
      _focusedDay = month;
    });
    onUpdated?.call();

    if (!mounted) {
      return;
    }
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    final reportsApi = api.ReportsApi(traccarProvider.apiClient);
    final dailyBox = await Hive.openLazyBox<ReportSummaryHive>('daily_summaries');
    final serverVersion = await traccarProvider.fetchServerVersion();
    final today = DateTime.now();

    developer.log('Server version: $serverVersion — fetching monthly data for ${month.year}-${month.month}', name: 'HistoryRouteScreen');

    _dailySummaries.clear();
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    for (var date = firstDayOfMonth; date.isBefore(lastDayOfMonth.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      final dayUtc = DateTime.utc(date.year, date.month, date.day);
      final String hiveKey = '${_deviceId}_${DateFormat('yyyy-MM-dd').format(dayUtc)}';
      final cachedSummary = await dailyBox.get(hiveKey);

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

    _safeSetState(() {
      _isCalendarLoading = false;
    });
    onUpdated?.call();

    Future<void> fetchDay(DateTime date) async {
      final dayUtc = DateTime.utc(date.year, date.month, date.day);
      if (date.isAfter(today) || _dailySummaries.containsKey(dayUtc)) {
        return;
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
        } else {
          developer.log('  → empty result (no data for this day)', name: 'HistoryRouteScreen');
        }
      } catch (e) {
        developer.log('Failed to fetch data for day $date: $e', name: 'HistoryRouteScreen');
      }
    }

    final List<DateTime> pendingDays = [];
    for (var date = firstDayOfMonth; date.isBefore(lastDayOfMonth.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      pendingDays.add(date);
    }

    const int concurrency = 4;
    for (var i = 0; i < pendingDays.length; i += concurrency) {
      final chunk = pendingDays.sublist(i, min(i + concurrency, pendingDays.length));
      await Future.wait(chunk.map(fetchDay));
      if (mounted) {
        _safeSetState(() {});
        onUpdated?.call();
      }
    }
  }

  Widget _buildDialogCurrentDeviceButton(VoidCallback refreshDialog) {
    final theme = Theme.of(context);
    final int deviceCount = Provider.of<TraccarProvider>(context, listen: false).devices.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _isDialogDevicePickerOpen = true;
            refreshDialog();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.directions_car_filled_rounded, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedDeviceName ?? '--',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                ),
                if (deviceCount > 1) Text('$deviceCount', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(width: 4),
                Icon(Icons.expand_more_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogDevicePicker(VoidCallback refreshDialog) {
    final theme = Theme.of(context);
    final devices = Provider.of<TraccarProvider>(context, listen: false).devices;
    final String query = _dialogDeviceSearchController.text.trim().toLowerCase();
    final List<api.Device> filtered = query.isEmpty
        ? devices
        : devices.where((device) {
            final String name = (device.name ?? '').toLowerCase();
            final String uniqueId = (device.uniqueId ?? '').toLowerCase();
            return name.contains(query) || uniqueId.contains(query) || '${device.id}'.contains(query);
          }).toList();

    void closePicker() {
      _isDialogDevicePickerOpen = false;
      _dialogDeviceSearchController.clear();
      refreshDialog();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 0),
          child: Row(
            children: [
              Icon(Icons.directions_car_filled_rounded, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'sharedDevice'.tr,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                ),
              ),
              IconButton(tooltip: 'sharedCancel'.tr, visualDensity: VisualDensity.compact, icon: const Icon(Icons.close_rounded, size: 20), onPressed: closePicker),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _dialogDeviceSearchController,
            autofocus: devices.length > 5,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'sharedSearchDevices'.tr,
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _dialogDeviceSearchController.clear();
                        refreshDialog();
                      },
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => refreshDialog(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('sharedNoData'.tr, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final device = filtered[index];
                    final bool selected = device.id == _deviceId;
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      selected: selected,
                      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                      leading: Icon(Icons.directions_car_filled_rounded, size: 20, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                      title: Text(
                        device.name ?? '--',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.bold : FontWeight.w500, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface),
                      ),
                      trailing: selected ? Icon(Icons.check_circle_rounded, size: 20, color: theme.colorScheme.primary) : null,
                      onTap: () {
                        _isDialogDevicePickerOpen = false;
                        _dialogDeviceSearchController.clear();
                        unawaited(_switchDeviceFromCalendar(device, refreshDialog));
                        refreshDialog();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _switchDeviceFromCalendar(api.Device device, VoidCallback refreshDialog) async {
    final int? newDeviceId = device.id;
    if (newDeviceId == null || newDeviceId == _deviceId) {
      return;
    }

    _safeSetState(() {
      _deviceId = newDeviceId;
      _selectedDeviceName = device.name;
      // 公里數標記依裝置計算，切換後必須重抓
      _dailySummaries.clear();
    });
    refreshDialog();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedDeviceId', newDeviceId);
    if (device.name != null) {
      await prefs.setString('selectedDeviceName', device.name!);
    }

    // 舊裝置的軌跡與圍欄先移除；新裝置當天沒資料時 _drawFullRoute 會直接 return，舊軌跡會留在畫面上
    await _cleanMapLayers();
    await _clearGeofenceLayers();
    _geofences = [];

    if (!mounted) {
      return;
    }

    final Future<void> monthlyFuture = _fetchMonthlyData(_focusedDay);
    refreshDialog();
    await monthlyFuture;

    if (!mounted) {
      return;
    }
    refreshDialog();

    await _fetchHistoryRoute(selectedDay: _selectedCalendarDay ?? DateTime.now());

    if (!mounted) {
      return;
    }
    if (!_showGeofences) {
      return;
    }
    try {
      final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
      _geofences = await api.GeofencesApi(traccarProvider.apiClient).getGeofences(deviceId: _deviceId) ?? [];
      if (mounted) {
        await _drawGeofences();
      }
    } catch (e) {
      developer.log('Failed to reload geofences after device switch: $e', name: 'HistoryRouteScreen');
    }
  }

  void _showCalendarDialog() async {
    if (_deviceId == null) {
      FeedbackService.info('pleaseSelectDevice'.tr, context: context);
      return;
    }

    final currentLocale = Get.locale;
    if (currentLocale != null) {
      final localeString = currentLocale.toString();
      await initializeDateFormatting(localeString, null);
    }

    if (!mounted) {
      return;
    }

    bool isDialogOpen = true;
    _isDialogDevicePickerOpen = false;
    _dialogDeviceSearchController.clear();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) {
          void refreshDialog() {
            if (isDialogOpen && mounted) modalSetState(() {});
          }

          // 首次開啟時綁定 refreshDialog，確保抓完資料能立刻重繪彈窗
          if (_dailySummaries.isEmpty && !_isCalendarLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fetchMonthlyData(_focusedDay, onUpdated: refreshDialog);
            });
          }

          return AlertDialog(
            contentPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: SizedBox(
              width: 340,
              height: 620,
              child: Column(
                children: [
                  if (_isDialogDevicePickerOpen)
                    Expanded(child: _buildDialogDevicePicker(refreshDialog))
                  else ...[
                    const SizedBox(height: 12),
                    _buildDialogCurrentDeviceButton(refreshDialog),
                    const SizedBox(height: 4),
                    if (_isCalendarLoading) const LinearProgressIndicator(),
                    Expanded(
                      child: TableCalendar(
                        locale: Get.locale?.languageCode,
                        firstDay: DateTime.utc(2020),
                        lastDay: DateTime.now(),
                        focusedDay: _focusedDay,
                        rowHeight: 60,
                        daysOfWeekHeight: 24,
                        selectedDayPredicate: (d) => isSameDay(_selectedCalendarDay, d),
                        onPageChanged: (focusedDay) {
                          modalSetState(() {
                            _focusedDay = focusedDay;
                          });
                          _fetchMonthlyData(focusedDay, onUpdated: refreshDialog);
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
                                bottom: 2,
                                left: 0,
                                right: 0,
                                child: Text(
                                  '${distanceInKm.round()}',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isSameDay(_selectedCalendarDay, date) ? Theme.of(context).colorScheme.primary : Colors.blue[700]),
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
                          cellMargin: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 14),
                        ),
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 17, fontWeight: FontWeight.bold),
                          leftChevronIcon: Icon(isRtlOf(context) ? Icons.chevron_right : Icons.chevron_left, color: Theme.of(context).colorScheme.primary),
                          rightChevronIcon: Icon(isRtlOf(context) ? Icons.chevron_left : Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                        ),
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                          weekendStyle: TextStyle(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8), fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() => isDialogOpen = false);
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    _safeSetState(() {
      _selectedCalendarDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _fetchHistoryRoute(selectedDay: selectedDay);
  }
}
