import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/map_style_provider.dart';
import 'package:trabcdefg/providers/settings_provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/screens/settings/geofences_screen.dart' hide AppMapType, TileCacheService;
import 'package:trabcdefg/services/auth_session_store.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/src/utils/position_coordinates.dart';
import 'package:trabcdefg/widgets/offline_address_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/marker_icon_service.dart';
import '../services/tile_cache_service.dart';
import '../widgets/device_detail_panel.dart';
import 'share_device_screen.dart';

// ── 地圖浮動控制：尺寸／動畫常數 ─────────────────────────────────────
// 集中管理原本散落在 _buildMapControl 與兩個 Positioned 裡的魔術數字，
// 之後要調整密度或手感只需要改這裡。
const double _kControlSize = 44; // 觸控目標（iOS HIG 建議最小 44pt）
const double _kControlRadius = 12; // 方形控制鈕圓角
const double _kPillRadius = 22; // 切換列膠囊圓角
const double _kEdgeInset = 16; // 與螢幕邊緣的安全距離
const double _kControlGap = 12; // 控制群之間的間距
const double _kGlassBlurSigma = 10; // 毛玻璃模糊強度
const double _kMaxMapZoom = 19.0;
const double _kMarkerSelectionRadius = 64.0;
const Duration _kSymbolTapGuard = Duration(milliseconds: 300); // marker 點擊防誤判窗口
const Duration _kCameraEventGrace = Duration(milliseconds: 250); // 相機事件滯後寬限
const int _kMaxTrailPoints = 3000; // 選取裝置軌跡最多保留的點數（避免長時間跟車吃掉記憶體）
const double _kAddressRefreshMeters = 50; // 裝置移動超過此距離才重算地址，避免 geocode 風暴

class MapScreen extends StatefulWidget {
  final api.Device? selectedDevice;

  const MapScreen({super.key, this.selectedDevice});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  maplibre.MapLibreMapController? _mapController;
  maplibre.CameraPosition? _lastCameraPosition;
  bool _isStyleLoaded = false;
  bool _hasInitialZoomed = false;
  final Set<String> _loadedIcons = {};
  // 🚀 marker 增量更新的狀態：deviceId -> 對應的 Symbol（圖標 / 標籤）
  final Map<int, maplibre.Symbol> _deviceSymbols = {};
  final Map<int, maplibre.Symbol> _labelSymbols = {};
  final Map<int, _MarkerRenderState> _markerRenderStates = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  api.Device? _currentDevice;
  final TileCacheService _cacheService = TileCacheService();
  late MarkerIconService _iconService;
  final http.Client _httpClient = http.Client();

  final ValueNotifier<bool> _panelOpenNotifier = ValueNotifier(false);
  bool get _isPanelOpen => _panelOpenNotifier.value;
  bool _isFollowingDevice = false;

  // ── 選取裝置的即時軌跡 ─────────────────────────────────────────────
  // 從「使用者選取該車的那一刻」開始累積，換車就清空重來。
  // 線圖層一定在 symbol 之前建立，所以永遠畫在 marker 底下。
  maplibre.Line? _trailLine;
  String? _trailColorHex;
  final List<maplibre.LatLng> _trailPoints = [];
  int? _trailDeviceId;

  /// 上次查地址的座標：位移超過 [_kAddressRefreshMeters] 才重查。
  maplibre.LatLng? _lastAddressLookupPoint;

  // 底部控制列（裝置切換 + 縮放）的定位策略：
  // 面板開啟時把它放進 sheet 的 Column、排在面板「上方」；
  // 面板關閉時才畫在 Stack 底部。用佈局保證不重疊，不需要量測面板高度。

  /// 是否正在播放「程式觸發」的相機動畫。MapLibre 的 onCameraMove 分不出
  /// 使用者手勢與 animateCamera，必須靠這個旗標才不會把自己的動畫誤判成拖曳。
  bool _isCameraAnimating = false;
  Timer? _cameraAnimationGraceTimer;

  /// 最近一次點擊 marker 的時間：用來擋掉緊接在 onSymbolTapped 之後的
  /// onMapClick，否則剛打開的面板會被立刻關閉。
  DateTime? _lastSymbolTapAt;

  // Reactive notifiers for seamless detail panel updates
  final ValueNotifier<api.Device?> _selectedDeviceNotifier = ValueNotifier(null);
  final ValueNotifier<api.Position?> _selectedPositionNotifier = ValueNotifier(null);
  final ValueNotifier<String> _selectedAddressNotifier = ValueNotifier("");
  int _deviceSelectionGeneration = 0;

  bool _isCacheInitialized = false;
  Timer? _zoomDebounce;

  // Drawer 搜尋：可依車牌（name）、IMEI（uniqueId）、設備 ID 即時過濾。
  final TextEditingController _drawerSearchController = TextEditingController();
  String _drawerSearchQuery = '';

  // Drawer 車列表排序：使用者選過的模式會被記住（SharedPreferences），下次開啟沿用。
  static const String _kDrawerSortModeKey = 'drawer_device_sort_mode';
  _DrawerSortMode _drawerSortMode = _DrawerSortMode.favorite;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _drawerSearchController.addListener(() {
      final String query = _drawerSearchController.text;
      if (query == _drawerSearchQuery) return;
      setState(() => _drawerSearchQuery = query);
    });

    _loadDrawerSortMode();

    _iconService = MarkerIconService(loadedIcons: _loadedIcons);
    _cacheService.init().then((_) {
      // OPTIMIZATION: Warm up OfflineAddressService early on map screen arrival
      OfflineAddressService.initDatabase();

      if (mounted) {
        setState(() {
          _isCacheInitialized = true;
        });
      }
    });

    _currentDevice = widget.selectedDevice;

    if (_currentDevice == null) {
      _loadLastSelectedDevice();
    }
  }

  Future<void> _loadLastSelectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDeviceId = prefs.getInt('selectedDeviceId');

    if (lastDeviceId != null && mounted) {
      final provider = Provider.of<TraccarProvider>(context, listen: false);
      if (provider.devices.isNotEmpty) {
        final device = provider.devices.firstWhereOrNull((d) => d.id == lastDeviceId);
        if (device != null) {
          setState(() {
            _currentDevice = device;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _zoomDebounce?.cancel();
    _cameraAnimationGraceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _httpClient.close();
    _drawerSearchController.dispose();
    _panelOpenNotifier.dispose();
    _selectedDeviceNotifier.dispose();
    _selectedPositionNotifier.dispose();
    _selectedAddressNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
        traccarProvider
            .fetchInitialData()
            .then((_) {
              if (mounted) {
                _scheduleMarkerUpdate(traccarProvider);
              }
            })
            .catchError((error) {
              debugPrint("Session validation failed on resume: $error");
              // A network/timeout/server error does not invalidate the
              // session. Only redirect when the server actually rejected it
              // and the silent re-login failed (the interceptor then clears
              // the stored session).
              if (mounted && AuthSessionStore.instance.sessionId == null) {
                Get.offAllNamed('/login');
              }
            });
      }
    }
  }

  void _onStyleLoaded() async {
    setState(() {
      _isStyleLoaded = true;
    });
    _loadedIcons.clear();
    // 樣式重建後舊 controller 的 symbol 與軌跡線都已失效，必須清掉增量狀態
    _deviceSymbols.clear();
    _labelSymbols.clear();
    _markerRenderStates.clear();
    _trailLine = null;
    _trailPoints.clear();
    _lastAddressLookupPoint = null;

    if (!mounted) return;
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    // 顏色要先在 await 之前取好，避免跨異步間隙使用 BuildContext
    final String trailColorHex = _toHexColor(Theme.of(context).colorScheme.primary);
    await _mapController!.setSymbolIconAllowOverlap(true);
    await _mapController!.setSymbolIconIgnorePlacement(true);
    await _mapController!.setSymbolTextAllowOverlap(true);
    await _mapController!.setSymbolTextIgnorePlacement(true);

    // 軌跡線必須在 symbol 之前建立，線圖層才會落在 marker 底下
    _trailColorHex = trailColorHex;
    await _createTrailLine(const <maplibre.LatLng>[], trailColorHex);
    // 樣式重建後從「目前選取裝置」重新播種軌跡（換車才會清空，這裡不清）
    _trailDeviceId = _currentDevice?.id;
    _pushTrailGeometry();

    await _scheduleMarkerUpdate(traccarProvider);

    if (widget.selectedDevice == null && !_hasInitialZoomed) {
      final prefs = await SharedPreferences.getInstance();
      final lastDeviceId = prefs.getInt('selectedDeviceId');

      if (lastDeviceId != null) {
        final device = traccarProvider.devices.firstWhereOrNull((d) => d.id == lastDeviceId);
        if (device != null) {
          _onDeviceSelected(device, follow: false);
        } else {
          _zoomToFitAll(traccarProvider);
        }
      } else {
        _zoomToFitAll(traccarProvider);
      }
      _hasInitialZoomed = true;
    }
  }

  /// 所有「程式觸發」的相機移動都必須走這裡。
  /// 為什麼？MapLibre 的 onCameraMove 無法區分使用者手勢與 animateCamera，
  /// 過去點裝置開面板時，緊接的鏡頭動畫會立刻觸發 onCameraMove 而把
  /// _isFollowingDevice 關掉（並印出 Auto-Follow disabled by user gesture）。
  /// 這裡在動畫期間（含結束後一小段事件滯後）標記 _isCameraAnimating，
  /// 讓 onCameraMove 能正確忽略自己造成的位移。
  Future<void> _animateCamera(maplibre.CameraUpdate update) async {
    final controller = _mapController;
    if (controller == null) return;

    _cameraAnimationGraceTimer?.cancel();
    _isCameraAnimating = true;
    try {
      await controller.animateCamera(update);
    } catch (e) {
      debugPrint('Camera animation failed: $e');
    } finally {
      // platform channel 的相機事件可能比 Future 晚到，留一點寬限再解除
      _cameraAnimationGraceTimer?.cancel();
      _cameraAnimationGraceTimer = Timer(_kCameraEventGrace, () {
        _isCameraAnimating = false;
      });
    }
  }

  /// 量測 sheet 目前高度；尚未佈局（或面板關閉中）時回傳 null。
  double? _measureDetailSheetHeight() {
    final renderObject = _detailSheetKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size.height;
    }
    return null;
  }

  /// 把「sheet 蓋住的高度」套成地圖的底部 content inset。
  ///
  /// 為什麼不直接把目標座標往上偏移？MapLibre 的 content inset 是由原生端
  /// 依目前方位角換算的，使用者旋轉地圖後仍然正確；手動換算經緯度只在
  /// bearing = 0 時成立。套用後相機的「中心」就是面板上方那塊可視區的中心，
  /// marker 不會被明細面板擋住。
  Future<void> _syncSheetContentInset({bool animated = true}) async {
    final controller = _mapController;
    if (controller == null) return;

    // sheet 由 showBottomSheet 建立，要等下一個 frame 才完成佈局；面板又會在
    // 讀完偏好設定前先以最小高度出現，所以等到連續兩個 frame 高度相同才套用，
    // 避免鏡頭先對到錯誤的中心再跳一次。
    double? measured;
    if (_isPanelOpen) {
      for (int i = 0; i < 12; i++) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        final double? next = _measureDetailSheetHeight();
        if (next == null) continue;
        if (next == measured) break;
        measured = next;
      }
    }

    final double bottomInset = _isPanelOpen ? (measured ?? _appliedBottomInset) : 0;
    if ((bottomInset - _appliedBottomInset).abs() < 0.5) return;
    _appliedBottomInset = bottomInset;

    _cameraAnimationGraceTimer?.cancel();
    _isCameraAnimating = true;
    try {
      await controller.updateContentInsets(EdgeInsets.only(bottom: bottomInset), animated);
    } catch (e) {
      debugPrint('Map content insets update failed: $e');
    } finally {
      _cameraAnimationGraceTimer?.cancel();
      _cameraAnimationGraceTimer = Timer(_kCameraEventGrace, () {
        _isCameraAnimating = false;
      });
    }
  }

  /// 面板內容高度變動（展開／收合、偏好設定載入完成）時重新同步 inset。
  void _scheduleSheetInsetSync() {
    if (_insetSyncScheduled) return;
    _insetSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _insetSyncScheduled = false;
      if (mounted) _syncSheetContentInset();
    });
  }

  void _toggleMapType(MapStyleProvider mapStyleProvider) {
    final cameraPosition = _mapController?.cameraPosition;
    if (cameraPosition != null) {
      _lastCameraPosition = cameraPosition;
    }
    mapStyleProvider.toggleMapType();
  }

  /// 「我的位置」按鈕：跟隨中再按一次 = 取消跟隨（面板保持開啟）；
  /// 未跟隨時按下 = 鏡頭回到目前裝置並重新跟隨。
  void _toggleFollowCurrentDevice() {
    final device = _currentDevice;
    if (device == null) return;

    if (_isFollowingDevice) {
      setState(() {
        _isFollowingDevice = false;
      });
      return;
    }

    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    if (device.id == null || traccarProvider.getPosition(device.id!) == null) return;
    _onDeviceSelected(device, forceShowPanel: true);
  }

  /// 只回傳「地圖上看得到」的裝置：有定位資料（緯度不為 null）才算。
  /// 切換列只在這些裝置之間移動，沒有定位數據的車會自動跳過。
  List<api.Device> _navigableDevices(TraccarProvider provider) {
    return provider.devices.where((device) {
      return _hasValidCoordinates(_positionForDevice(provider, device.id));
    }).toList();
  }

  List<api.Device> _devicesNearMarker(api.Device tappedDevice, TraccarProvider provider) {
    final tappedPosition = _positionForDevice(provider, tappedDevice.id);
    final cameraZoom = _mapController?.cameraPosition?.zoom;
    if (!_hasValidCoordinates(tappedPosition) || cameraZoom == null) {
      return [tappedDevice];
    }

    final tappedPoint = _projectToWorldPixels(tappedPosition!, cameraZoom);
    final nearbyDevices = _navigableDevices(provider).where((device) {
      final position = _positionForDevice(provider, device.id);
      if (!_hasValidCoordinates(position)) return false;

      final point = _projectToWorldPixels(position!, cameraZoom);
      final worldSize = 256 * math.pow(2, cameraZoom);
      final dx = (point.dx - tappedPoint.dx).abs();
      final wrappedDx = math.min(dx, worldSize - dx);
      final dy = point.dy - tappedPoint.dy;
      return math.sqrt(wrappedDx * wrappedDx + dy * dy) <= _kMarkerSelectionRadius;
    }).toList();

    return nearbyDevices.contains(tappedDevice) ? nearbyDevices : [tappedDevice, ...nearbyDevices];
  }

  Offset _projectToWorldPixels(api.Position position, double zoom) {
    final latitude = position.latitude!.toDouble().clamp(-85.05112878, 85.05112878);
    final longitude = position.longitude!.toDouble();
    final worldSize = 256 * math.pow(2, zoom);
    final x = (longitude + 180) / 360 * worldSize;
    final sinLatitude = math.sin(latitude * math.pi / 180);
    final y = (0.5 - math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * math.pi)) * worldSize;
    return Offset(x, y);
  }

  void _handleDeviceMarkerTap(int deviceId, TraccarProvider provider) {
    final device = provider.devices.firstWhereOrNull((item) => item.id == deviceId);
    if (device == null) return;

    final nearbyDevices = _devicesNearMarker(device, provider);
    if (nearbyDevices.length > 1) {
      _showNearbyDevicePicker(nearbyDevices, provider);
      return;
    }

    _onDeviceSelected(device, forceShowPanel: true, zoomToMax: true);
  }

  void _showNearbyDevicePicker(List<api.Device> devices, TraccarProvider provider) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext popupContext) => Material(
        color: Theme.of(popupContext).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text('pleaseSelectDevice'.tr, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                for (final device in devices)
                  ListTile(
                    leading: const Icon(Icons.directions_car_rounded),
                    title: Text(device.name ?? 'Unknown Device'.tr),
                    onTap: () {
                      Navigator.of(popupContext).pop();
                      _onDeviceSelected(device, forceShowPanel: true, zoomToMax: true);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 指定裝置在清單中的位置（1-based，找不到時回 1），給切換列顯示「n / N」。
  int _deviceIndexIn(List<api.Device> devices, api.Device? device) {
    final index = devices.indexWhere((d) => d.id == device?.id);
    return index < 0 ? 1 : index + 1;
  }

  /// 切換列中間車牌代表的那台車：目前裝置不在可切換清單時退回第一台，
  /// 讓顯示的名稱、n/N 與「點車牌放大」永遠指的是同一台。
  api.Device? _switcherDevice(List<api.Device> devices, api.Device? currentDevice) {
    if (devices.isEmpty) return null;
    final index = devices.indexWhere((d) => d.id == currentDevice?.id);
    return devices[index < 0 ? 0 : index];
  }

  /// 底部控制列本體（裝置切換 + 縮放）。
  /// 面板開／關兩條繪製路徑都用這個 builder，所以永遠長得一樣。
  Widget _buildBottomControls(TraccarProvider traccarProvider, api.Device? currentDevice) {
    // 切換列只在「有定位數據」的裝置之間移動，沒數據的車直接跳過。
    final List<api.Device> navigableDevices = _navigableDevices(traccarProvider);
    final api.Device? switcherDevice = _switcherDevice(navigableDevices, currentDevice);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: navigableDevices.length > 1
                ? _DeviceSwitcherBar(
                    deviceName: switcherDevice?.name,
                    index: _deviceIndexIn(navigableDevices, currentDevice),
                    total: navigableDevices.length,
                    onPrevious: () => _navigateToDevice(-1, traccarProvider),
                    onNext: () => _navigateToDevice(1, traccarProvider),
                    // 點車牌 = 回到這台車：鏡頭拉近到最大縮放（19），明細面板一起打開。
                    onPlateTap: switcherDevice == null ? null : () => _onDeviceSelected(switcherDevice, forceShowPanel: true, zoomToMax: true),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        // 縮放：兩顆按鈕合成一顆膠囊（一組陰影 + 一條分隔線）
        _GlassSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GlassIconButton(icon: Icons.add_rounded, label: 'mapZoomIn'.tr, onTap: () => _animateCamera(maplibre.CameraUpdate.zoomIn())),
              const _GlassDivider(),
              _GlassIconButton(icon: Icons.remove_rounded, label: 'mapZoomOut'.tr, onTap: () => _animateCamera(maplibre.CameraUpdate.zoomOut())),
            ],
          ),
        ),
      ],
    );
  }

  void _zoomToFitAll(TraccarProvider provider) {
    if (provider.positions.isEmpty || _mapController == null) return;

    double? minLat, maxLat, minLng, maxLng;

    for (var pos in provider.positions) {
      if (!_hasValidCoordinates(pos)) continue;
      double lat = pos.latitude!.toDouble();
      double lng = pos.longitude!.toDouble();

      if (minLat == null || lat < minLat) minLat = lat;
      if (maxLat == null || lat > maxLat) maxLat = lat;
      if (minLng == null || lng < minLng) minLng = lng;
      if (maxLng == null || lng > maxLng) maxLng = lng;
    }

    if (minLat != null && maxLat != null && minLng != null && maxLng != null) {
      if ((maxLat - minLat).abs() < 0.0001 && (maxLng - minLng).abs() < 0.0001) {
        _animateCamera(maplibre.CameraUpdate.newLatLngZoom(maplibre.LatLng(minLat, minLng), 14.0));
      } else {
        _animateCamera(maplibre.CameraUpdate.newLatLngBounds(maplibre.LatLngBounds(southwest: maplibre.LatLng(minLat, minLng), northeast: maplibre.LatLng(maxLat, maxLng)), left: 50, right: 50, top: 100, bottom: 100));
      }
    }
  }

  // 排程器：併攏短時間內的多個位置更新，避免每次都打爆地圖。
  // 若上一次更新還在進行中，先標記 dirty，完成後再補跑一次最新狀態。
  bool _markerUpdating = false;
  bool _markersDirty = false;

  Future<void> _scheduleMarkerUpdate(TraccarProvider provider) async {
    if (_markerUpdating) {
      _markersDirty = true;
      return;
    }
    _markerUpdating = true;
    try {
      do {
        _markersDirty = false;
        await _updateAllMarkers(provider);
      } while (_markersDirty);
    } finally {
      _markerUpdating = false;
    }
  }

  Future<void> _updateAllMarkers(TraccarProvider provider) async {
    final controller = _mapController;
    if (controller == null || !_isStyleLoaded) return;

    // 💡 優化：在任何 await 異步操作之前，先安全地讀取變數並存為區域變數
    // 這樣可以完美避開「跨異步間隙使用 BuildContext」的 linter 報錯
    final double scale = Provider.of<SettingsProvider>(context, listen: false).markerSizeScale;

    // 選取的裝置：軌跡累積 + 跟隨鏡頭 + 明細面板同步
    // 這是選取之後「持續跟隨」的唯一來源，每次位置更新都會跑一次。
    _updateSelectedDeviceLive(provider);

    // 🚀 效能優化：不再「整批清空 + 重畫」所有 marker。
    // 改為「新增 / 原地更新 / 移除」：已有 marker 的設備用 updateSymbol 直接搬移，
    // 避免每次位置更新都重建整個 symbol layer（這是手划地圖時卡頓的主因）。
    final visibleDeviceIds = <int>{};

    for (final device in provider.devices) {
      final int? deviceId = device.id;
      if (deviceId == null) continue;
      final pos = provider.getPosition(deviceId);
      if (pos == null || !_hasValidCoordinates(pos)) continue;
      final position = pos;
      visibleDeviceIds.add(deviceId);

      final String category = device.category ?? 'default';
      final String status = device.status ?? 'unknown';
      final String baseIconKey = 'marker_${category.toLowerCase()}_${status.toLowerCase()}';

      final String plate = device.name ?? '';
      final String customLabelId = "label_$plate";
      final latLng = maplibre.LatLng(position.latitude!.toDouble(), position.longitude!.toDouble());
      final double course = position.course?.toDouble() ?? 0.0;
      final double iconSize = 4.0 * scale;
      final previousState = _markerRenderStates[deviceId];
      final bool iconChanged =
          previousState == null || previousState.iconImage != baseIconKey || previousState.course != course || previousState.iconSize != iconSize || previousState.latitude != latLng.latitude || previousState.longitude != latLng.longitude;
      final bool labelChanged = previousState == null || previousState.labelImage != customLabelId || previousState.latitude != latLng.latitude || previousState.longitude != latLng.longitude;

      if (_deviceSymbols[deviceId] == null || previousState?.iconImage != baseIconKey) {
        await _iconService.ensureIconLoaded(controller, baseIconKey);
      }
      if (_labelSymbols[deviceId] == null || previousState?.labelImage != customLabelId) {
        await _iconService.ensureLabelIconLoaded(controller, plate, customLabelId);
      }
      if (!mounted || !identical(_mapController, controller) || !_isStyleLoaded) return;

      final deviceData = {'deviceId': deviceId.toString()};

      // 設備圖標：存在就原地更新，不存在才新增
      final iconSymbol = _deviceSymbols[deviceId];
      if (iconSymbol == null) {
        _deviceSymbols[deviceId] = await controller.addSymbol(maplibre.SymbolOptions(geometry: latLng, iconImage: baseIconKey, iconRotate: course, iconSize: iconSize, iconAnchor: 'center', zIndex: 10), deviceData);
      } else if (iconChanged) {
        await controller.updateSymbol(iconSymbol, maplibre.SymbolOptions(geometry: latLng, iconImage: baseIconKey, iconRotate: course, iconSize: iconSize, iconAnchor: 'center', zIndex: 10));
      }

      // 名稱標籤：同樣「新增或原地更新」
      final labelSymbol = _labelSymbols[deviceId];
      if (labelSymbol == null) {
        _labelSymbols[deviceId] = await controller.addSymbol(maplibre.SymbolOptions(geometry: latLng, iconImage: customLabelId, iconRotate: 0.0, iconOffset: const Offset(0, 15), iconSize: 1.2, iconAnchor: 'top', zIndex: 5), deviceData);
      } else if (labelChanged) {
        await controller.updateSymbol(labelSymbol, maplibre.SymbolOptions(geometry: latLng, iconImage: customLabelId, iconRotate: 0.0, iconOffset: const Offset(0, 15), iconSize: 1.2, iconAnchor: 'top', zIndex: 5));
      }

      _markerRenderStates[deviceId] = _MarkerRenderState(latitude: latLng.latitude, longitude: latLng.longitude, course: course, iconSize: iconSize, iconImage: baseIconKey, labelImage: customLabelId);
    }

    // 清除已經沒有位置資料（或已被移除）的設備 marker
    final staleIds = <int>{..._deviceSymbols.keys, ..._labelSymbols.keys}.where((id) => !visibleDeviceIds.contains(id)).toList();
    for (final id in staleIds) {
      final iconSymbol = _deviceSymbols.remove(id);
      if (iconSymbol != null) {
        try {
          await controller.removeSymbol(iconSymbol);
        } catch (error) {
          debugPrint('Failed to remove device marker $id: $error');
        }
      }
      final labelSymbol = _labelSymbols.remove(id);
      if (labelSymbol != null) {
        try {
          await controller.removeSymbol(labelSymbol);
        } catch (error) {
          debugPrint('Failed to remove device label $id: $error');
        }
      }
      _markerRenderStates.remove(id);
    }
  }

  /// 讓「目前選取的裝置」保持即時：累積軌跡、跟隨鏡頭、同步明細面板。
  /// 選取當下只是把鏡頭帶過去一次，真正的持續跟隨靠這裡。
  void _updateSelectedDeviceLive(TraccarProvider provider) {
    final int? currentDeviceId = _currentDevice?.id;
    if (currentDeviceId == null) return;

    final api.Position? currentPos = provider.getPosition(currentDeviceId);
    if (currentPos == null || !_hasValidCoordinates(currentPos)) return;

    final api.Position position = currentPos;
    final maplibre.LatLng currentLatLng = maplibre.LatLng(position.latitude!.toDouble(), position.longitude!.toDouble());

    // 軌跡：只累積目前選取裝置的移動
    if (position.deviceId == _trailDeviceId) {
      _appendTrailPoint(currentLatLng);
    }

    // 跟隨鏡頭
    if (_isFollowingDevice) {
      _animateCamera(maplibre.CameraUpdate.newLatLng(currentLatLng));
    }

    // 明細面板：位置/地址跟著車跑（面板沒開也先更新，打開時就是最新的）
    if (_selectedDeviceNotifier.value?.id == currentDeviceId) {
      _selectedPositionNotifier.value = position;
      if (_isPanelOpen) {
        _maybeRefreshPanelAddress(position, currentLatLng);
      }
    }
  }

  // ── 選取裝置的軌跡線 ──────────────────────────────────────────────

  /// 建立軌跡線圖層。正常情況會在 symbol 之前用「空幾何」先建立，這樣線才會
  /// 畫在 marker 底下；樣式重建後舊的 Line 已失效，所以要重新呼叫。
  Future<void> _createTrailLine(List<maplibre.LatLng> geometry, String colorHex) async {
    final controller = _mapController;
    if (controller == null) return;
    try {
      _trailLine = await controller.addLine(maplibre.LineOptions(geometry: geometry, lineColor: colorHex, lineWidth: 4.0, lineJoin: 'round'));
    } catch (e) {
      debugPrint('Trail line creation failed: $e');
    }
  }

  /// 追加一個軌跡點：同一位置不重複加，有點變化才更新線圖層。
  void _appendTrailPoint(maplibre.LatLng point) {
    if (_trailPoints.isNotEmpty) {
      final maplibre.LatLng last = _trailPoints.last;
      if (last.latitude == point.latitude && last.longitude == point.longitude) return;
    }

    _trailPoints.add(point);
    // 長時間跟車時限制點數，避免 list 無限成長
    if (_trailPoints.length > _kMaxTrailPoints) {
      _trailPoints.removeRange(0, _trailPoints.length - _kMaxTrailPoints);
    }
    _pushTrailGeometry();
  }

  void _pushTrailGeometry() {
    final controller = _mapController;
    if (controller == null) return;

    final List<maplibre.LatLng> geometry = List<maplibre.LatLng>.of(_trailPoints);
    final line = _trailLine;
    if (line != null) {
      controller.updateLine(line, maplibre.LineOptions(geometry: geometry));
      return;
    }

    // 退路：上一行若建立空線失敗，這裡改用延遲建立。
    // 缺點是線會被畫在 marker 上層，但至少軌跡不會整條消失。
    final String? colorHex = _trailColorHex;
    if (colorHex == null || geometry.length < 2) return;
    _createTrailLine(geometry, colorHex);
  }

  /// 面板開啟時讓地址跟著車跑。位移小於 [_kAddressRefreshMeters] 就沿用舊值，
  /// 避免每次位置更新都打一次地理編碼。
  Future<void> _maybeRefreshPanelAddress(api.Position position, maplibre.LatLng latLng) async {
    final maplibre.LatLng? last = _lastAddressLookupPoint;
    if (last != null && _metersBetween(last, latLng) < _kAddressRefreshMeters) return;
    _lastAddressLookupPoint = latLng;

    try {
      final String addr = await OfflineAddressService.getAddress(latLng.latitude, latLng.longitude);
      if (!mounted) return;
      // 查詢期間可能已經換車，避免把舊車的地址寫到新車的面板上
      if (_selectedDeviceNotifier.value?.id != position.deviceId) return;
      _selectedAddressNotifier.value = addr;
    } catch (e) {
      debugPrint("Geocoder error: $e");
    }
  }

  /// 兩點間的概略距離（公尺）。只用來判斷要不要重查地址，不需要高精度。
  double _metersBetween(maplibre.LatLng a, maplibre.LatLng b) {
    const double earthRadius = 6371000;
    final double dLat = (b.latitude - a.latitude) * math.pi / 180;
    final double dLng = (b.longitude - a.longitude) * math.pi / 180;
    final double h = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(a.latitude * math.pi / 180) * math.cos(b.latitude * math.pi / 180) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
  }

  PersistentBottomSheetController? _bottomSheetController;

  /// 底部 sheet（切換列 + 明細面板）的量測目標：量到的實際高度會同步成
  /// 地圖的底部 content inset，鏡頭中心才會落在面板上方的可視區中央。
  final GlobalKey _detailSheetKey = GlobalKey();
  double _appliedBottomInset = 0;
  bool _insetSyncScheduled = false;

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat.yMd().add_Hms().format(date.toLocal());
  }

  Future<void> _showDeleteConfirmationDialog(api.Device device) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text('Delete Device'.tr),
          content: Text('Are you sure you want to delete the device "${device.name}"?'.tr),
          actions: <Widget>[
            CupertinoDialogAction(
              child: Text('Cancel'.tr),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            CupertinoDialogAction(
              textStyle: const TextStyle(color: CupertinoColors.systemRed),
              child: Text('Delete'.tr),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (result == true && device.id != null) {
      _deleteDevice(device.id!);
    }
  }

  Future<void> _deleteDevice(int deviceId) async {
    if (!mounted) return;
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    final devicesApi = api.DevicesApi(traccarProvider.apiClient);

    try {
      await devicesApi.deleteDevicesId(deviceId);

      _bottomSheetController?.close();

      await traccarProvider.fetchInitialData();

      Get.snackbar('Success'.tr, 'Device deleted successfully.'.tr, snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green.shade100);
    } on api.ApiException catch (e) {
      Get.snackbar('Error'.tr, 'Failed to delete device: ${e.message}'.tr, snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.shade100);
    } catch (e) {
      Get.snackbar('Error'.tr, 'An unknown error occurred.'.tr, snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.shade100);
    }
  }

  void _navigateToDevice(int direction, TraccarProvider provider) {
    // 沒有定位數據的裝置不會顯示在地圖上，切換時直接跳過它們。
    final List<api.Device> devices = _navigableDevices(provider);
    if (devices.isEmpty) return;

    final int currentIndex = devices.indexWhere((d) => d.id == _currentDevice?.id);
    int nextIndex;
    if (currentIndex < 0) {
      // 目前裝置不在可見清單中（例如沒有定位）：往後切從頭、往前切從尾端開始。
      nextIndex = direction > 0 ? 0 : devices.length - 1;
    } else {
      nextIndex = (currentIndex + direction) % devices.length;
      if (nextIndex < 0) nextIndex = devices.length - 1;
    }

    final nextDevice = devices[nextIndex];
    // 直接跟隨切換到的車：鏡頭立刻回到它的「現在」位置，之後每次位置更新
    // 都由 _updateSelectedDeviceLive 持續跟隨，軌跡也從這一刻重新開始。
    _onDeviceSelected(nextDevice, forceShowPanel: false, follow: true);
  }

  /// 唯一的「選取裝置」入口：上/下台車、點地圖 marker、Drawer 列表全部走這裡。
  ///
  /// - 一律取 [_positionMap] 裡最即時的位置（WebSocket 會同步寫入），
  ///   避免拿到舊快照、停在「車輛移動前」的位置。
  /// - `follow: true` 時直接開啟跟隨並立刻把鏡頭帶到現在位置，之後由
  ///   [_updateSelectedDeviceLive] 隨每次位置更新持續跟隨。
  /// - 軌跡從「選取那一刻」重新開始：換車清空，同一台車再次選取（例如按
  ///   「我的位置」恢復跟隨）則保留既有軌跡。
  void _onDeviceSelected(api.Device device, {bool forceShowPanel = false, bool follow = true, bool zoomToMax = false}) async {
    final int? deviceId = device.id;
    if (deviceId == null) return;

    final int selectionGeneration = ++_deviceSelectionGeneration;
    final bool deviceChanged = _selectedDeviceNotifier.value?.id != device.id;

    // 同步地更新兩處選取狀態，避免位置推送仍以舊的 _currentDevice 更新面板。
    setState(() => _currentDevice = device);
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);

    final position = traccarProvider.getPosition(deviceId) ?? api.Position(deviceId: deviceId);

    final bool hasFix = _hasValidCoordinates(position);
    final maplibre.LatLng? latLng = hasFix ? maplibre.LatLng(position.latitude!.toDouble(), position.longitude!.toDouble()) : null;

    final String? immediateAddress = latLng == null ? null : OfflineAddressService.getAddressFromCache(latLng.latitude, latLng.longitude);

    _selectedDeviceNotifier.value = device;
    _selectedPositionNotifier.value = position;
    _selectedAddressNotifier.value = immediateAddress ?? (hasFix ? "Loading..." : "No GPS Signal");

    if (follow && !_isFollowingDevice) {
      setState(() => _isFollowingDevice = true);
    }

    // 軌跡：換車就從現在這個位置重新累積
    if (deviceChanged) {
      _trailDeviceId = device.id;
      _trailPoints.clear();
      _lastAddressLookupPoint = null;
    }
    if (latLng != null) {
      _appendTrailPoint(latLng);
    }

    if (forceShowPanel || _isPanelOpen) {
      _showDeviceDetailPanel(device, position);
    }

    traccarProvider.prefetchDeviceHistory(deviceId);

    final prefs = await SharedPreferences.getInstance();
    if (!mounted || selectionGeneration != _deviceSelectionGeneration) return;
    await prefs.setInt('selectedDeviceId', deviceId);
    if (device.name != null) {
      await prefs.setString('selectedDeviceName', device.name!);
    }
    if (!mounted || selectionGeneration != _deviceSelectionGeneration) return;

    if (latLng == null) return;

    // 先讓地圖可視範圍扣掉明細面板（含上方切換列），鏡頭再對準裝置，
    // marker 才會落在「面板上緣 ~ 地圖頂部」的正中央，而不是被面板遮住。
    await _syncSheetContentInset(animated: false);
    if (!mounted || selectionGeneration != _deviceSelectionGeneration) return;
    await _animateCamera(zoomToMax ? maplibre.CameraUpdate.newLatLngZoom(latLng, _kMaxMapZoom) : maplibre.CameraUpdate.newLatLng(latLng));
    if (!mounted || selectionGeneration != _deviceSelectionGeneration) return;
    // 立刻用最新資料跑一次 marker / 跟隨流程，不用等下一次位置更新
    await _scheduleMarkerUpdate(traccarProvider);

    if (immediateAddress != null) return;

    try {
      final String addr = await OfflineAddressService.getAddress(latLng.latitude, latLng.longitude);
      if (!mounted || selectionGeneration != _deviceSelectionGeneration) return;
      _selectedAddressNotifier.value = addr;
    } catch (e) {
      debugPrint("Geocoder error: $e");
      if (!mounted || selectionGeneration != _deviceSelectionGeneration) return;
      _selectedAddressNotifier.value = "Location: ${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
    }
  }

  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url)) {
      throw 'Could not launch $url';
    }
  }

  void _showMoreOptionsDialog(api.Device device, api.Position? currentPosition) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      device.name ?? 'More Options'.tr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                  ListTile(
                    title: Text('sharedCreateGeofence'.tr),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AddGeofenceScreen()));
                    },
                  ),
                  ListTile(
                    title: Text('linkGoogleMaps'.tr),
                    onTap: () {
                      Navigator.of(context).pop();
                      if (_hasValidCoordinates(currentPosition)) {
                        final url = Uri.parse('https://maps.google.com/maps?q=${currentPosition!.latitude!.toDouble()},${currentPosition.longitude!.toDouble()}');
                        _launchUrl(url);
                      }
                    },
                  ),
                  ListTile(
                    title: Text('linkAppleMaps'.tr),
                    onTap: () {
                      Navigator.of(context).pop();
                      if (_hasValidCoordinates(currentPosition)) {
                        final url = Uri.parse('https://maps.apple.com/?q=${currentPosition!.latitude!.toDouble()},${currentPosition.longitude!.toDouble()}');
                        _launchUrl(url);
                      }
                    },
                  ),
                  ListTile(
                    title: Text('linkStreetView'.tr),
                    onTap: () {
                      Navigator.of(context).pop();
                      if (_hasValidCoordinates(currentPosition)) {
                        final url = Uri.parse('google.streetview:cbll=${currentPosition!.latitude!.toDouble()},${currentPosition.longitude!.toDouble()}');
                        _launchUrl(url);
                      }
                    },
                  ),
                  ListTile(
                    title: Text('deviceShare'.tr),
                    onTap: () async {
                      // 1. 在非同步操作前，先把 Navigator 存起來（最推薦的做法）
                      final navigator = Navigator.of(context);

                      Navigator.of(context).pop();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('sharedDeviceId', device.id!);
                      await prefs.setString('sharedDeviceName', device.name!);

                      // 2. 檢查目前 State 是否還活在樹中
                      if (!mounted) return;

                      // 3. 使用安全存下來的 navigator 導頁
                      navigator.push(MaterialPageRoute(builder: (context) => const ShareDeviceScreen()));
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeviceDetailPanel(api.Device device, api.Position? currentPosition) {
    if (_isPanelOpen && _bottomSheetController != null) {
      return;
    }

    setState(() {
      _panelOpenNotifier.value = true;
    });
    // Transparent background + no elevation: the sheet itself is invisible, so
    // only the panel's own rounded card is drawn on top of the map.
    _bottomSheetController = _scaffoldKey.currentState!.showBottomSheet(backgroundColor: Colors.transparent, elevation: 0, (context) {
      return ValueListenableBuilder<api.Device?>(
        valueListenable: _selectedDeviceNotifier,
        builder: (context, currentDev, _) {
          return ValueListenableBuilder<api.Position?>(
            valueListenable: _selectedPositionNotifier,
            builder: (context, currentPos, _) {
              return ValueListenableBuilder<String>(
                valueListenable: _selectedAddressNotifier,
                builder: (context, currentAddr, _) {
                  if (currentDev == null) return const SizedBox.shrink();

                  // 控制列與面板放在同一個 Column：控制列永遠排在面板上方，
                  // 由佈局保證不會被面板遮住（不需要量測面板高度）。
                  // 這裡量的是「控制列 + 面板」整塊高度，同步給地圖的底部 inset。
                  return Consumer<TraccarProvider>(
                    builder: (context, panelProvider, _) => NotificationListener<SizeChangedLayoutNotification>(
                      onNotification: (_) {
                        _scheduleSheetInsetSync();
                        return true;
                      },
                      child: SizeChangedLayoutNotifier(
                        child: Column(
                          key: _detailSheetKey,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(padding: const EdgeInsets.fromLTRB(_kEdgeInset, 0, _kEdgeInset, _kControlGap), child: _buildBottomControls(panelProvider, currentDev)),
                            DeviceDetailPanel(
                              device: currentDev,
                              position: currentPos ?? api.Position(),
                              address: currentAddr,
                              formattedDate: _formatDate(currentPos?.fixTime),
                              onMoreOptionsPressed: () => _showMoreOptionsDialog(currentDev, currentPos),
                              onDeletePressed: () {
                                _bottomSheetController?.close();
                                _showDeleteConfirmationDialog(currentDev);
                              },
                              onRefresh: () async {
                                final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
                                await traccarProvider.fetchInitialData();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    });

    _bottomSheetController!.closed.then((_) {
      if (mounted) {
        setState(() {
          _panelOpenNotifier.value = false;
          _bottomSheetController = null;
          _isFollowingDevice = false;
        });
        // 面板收起來後把底部 inset 還原，地圖中心回到整個可視區中央。
        _syncSheetContentInset();
      }
    });
  }

  api.Position? _positionForDevice(TraccarProvider provider, int? deviceId) {
    if (deviceId == null) return null;
    return provider.getPosition(deviceId);
  }

  bool _hasValidCoordinates(api.Position? position) {
    return hasValidPositionCoordinates(position);
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'online':
        return Colors.green;
      case 'offline':
        return Colors.red;
      case 'unknown':
        return Colors.grey;
      case 'static':
        return Colors.blue;
      case 'idle':
        return Colors.orange;
      default:
        // 這個顏色現在會套在車號文字上，寫死黑色在深色模式會看不見，
        // 所以改跟著主題的 onSurface。
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  /// 讀回使用者上次選的排序模式。讀不到（第一次用、或模式被改過名）就維持預設值。
  Future<void> _loadDrawerSortMode() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_kDrawerSortModeKey);
    final mode = _DrawerSortMode.values.firstWhereOrNull((m) => m.name == stored);
    if (mode != null && mounted) {
      setState(() => _drawerSortMode = mode);
    }
  }

  void _setDrawerSortMode(_DrawerSortMode mode) {
    if (mode == _drawerSortMode) return;
    setState(() => _drawerSortMode = mode);
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_kDrawerSortModeKey, mode.name));
  }

  Widget _buildDeviceListDrawer(BuildContext context, TraccarProvider traccarProvider) {
    final String query = _drawerSearchQuery.trim().toLowerCase();

    // 依車牌（name）/ IMEI（uniqueId）/ 設備 ID 即時過濾
    final devices = traccarProvider.devices.where((device) {
      if (query.isEmpty) return true;
      final String name = (device.name ?? '').toLowerCase();
      final String uniqueId = (device.uniqueId ?? '').toLowerCase();
      final String deviceId = (device.id ?? '').toString();
      return name.contains(query) || uniqueId.contains(query) || deviceId.contains(query);
    }).toList();

    // 速度排序會用到每台車的當前速度；先在這裡一次算好（O(n)），
    // 不要在 comparator 裡重複掃 positions 清單。
    final Map<int, double> speedByDeviceId = {
      for (final device in devices)
        if (device.id != null) device.id!: (_positionForDevice(traccarProvider, device.id)?.speed ?? 0.0).toDouble(),
    };

    devices.sort((a, b) {
      // 最愛（關注）永遠排最前面 —— 三種模式都一樣
      final aFav = traccarProvider.isFavorite(a.id!);
      final bFav = traccarProvider.isFavorite(b.id!);
      if (aFav != bFav) return aFav ? -1 : 1;

      switch (_drawerSortMode) {
        case _DrawerSortMode.favorite:
          break;
        case _DrawerSortMode.online:
          final bool aOnline = a.status == 'online';
          final bool bOnline = b.status == 'online';
          if (aOnline != bOnline) return aOnline ? -1 : 1;
          break;
        case _DrawerSortMode.speed:
          final int bySpeed = (speedByDeviceId[b.id] ?? 0).compareTo(speedByDeviceId[a.id] ?? 0);
          if (bySpeed != 0) return bySpeed;
          break;
      }

      // 同分時用車號決定順序。Dart 的 List.sort 不穩定，
      // 沒有這個 tie-break 的話，同速度的車每次 rebuild 順序都會亂跳。
      return (a.name ?? '').compareTo(b.name ?? '');
    });

    return Drawer(
      child: Column(
        children: [
          // 原本的 App 名稱／用戶名稱換成搜尋框，可直接搜車牌、IMEI、設備 ID。
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_kEdgeInset, _kEdgeInset, _kEdgeInset, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _drawerSearchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'sharedSearchDevices'.tr,
                        prefixIcon: const Icon(CupertinoIcons.search),
                        suffixIcon: _drawerSearchQuery.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Cancel'.tr, onPressed: () => _drawerSearchController.clear()),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 排序模式：圖示就是目前模式，點一下可切換，選擇會被記住。
                  PopupMenuButton<_DrawerSortMode>(
                    initialValue: _drawerSortMode,
                    tooltip: 'sharedSortBy'.tr,
                    onSelected: _setDrawerSortMode,
                    itemBuilder: (context) => [
                      for (final mode in _DrawerSortMode.values)
                        PopupMenuItem<_DrawerSortMode>(
                          value: mode,
                          child: Row(children: [Icon(mode.icon, size: 18), const SizedBox(width: 12), Text(mode.labelKey.tr)]),
                        ),
                    ],
                    child: SizedBox(width: 44, height: 44, child: Icon(_drawerSortMode.icon, color: Theme.of(context).colorScheme.onSurface)),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: devices.isEmpty
                ? Center(child: Text('sharedNoData'.tr))
                : ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      final position = _positionForDevice(traccarProvider, device.id);

                      final speed = (position?.speed ?? 0.0).toStringAsFixed(1);
                      final isIgnitionOn = (position?.attributes as Map<String, dynamic>?)?['ignition'] == true;

                      // 一台車一行：車號 + 速度/鑰匙都在同一行。
                      // 狀態不再用圓點表示，直接把車號文字上色（_getStatusColor）。
                      return ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                device.name ?? 'Unknown Device'.tr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w500, color: _getStatusColor(device.status)),
                              ),
                            ),
                            if (double.parse(speed) > 0.0) ...[const SizedBox(width: 8), Text('$speed km/h', style: Theme.of(context).textTheme.bodySmall)],
                            const SizedBox(width: 8),
                            Icon(Icons.key, color: isIgnitionOn ? Colors.green : Colors.red, size: 16),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).pop();

                          if (position != null) {
                            _onDeviceSelected(device, forceShowPanel: true);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TraccarProvider, MapStyleProvider>(
      builder: (context, traccarProvider, mapStyleProvider, child) {
        if (traccarProvider.isLoading && traccarProvider.devices.isEmpty) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!_isCacheInitialized) {
          // 純文字對使用者沒有「正在載入」的感覺，改成與主題一致的進度指示
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: _kControlGap),
                  Text('Initializing Map Assets...'.tr, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          );
        }

        double initialLat = 0, initialLng = 0, initialZoom = 2.0;

        if (_currentDevice != null) {
          final initialPosition = _positionForDevice(traccarProvider, _currentDevice!.id);

          if (_hasValidCoordinates(initialPosition)) {
            initialLat = initialPosition!.latitude!.toDouble();
            initialLng = initialPosition.longitude!.toDouble();
            initialZoom = 15.0;
          }
        } else if (traccarProvider.positions.isNotEmpty) {
          final api.Position firstPosition = traccarProvider.positions.first;
          if (_hasValidCoordinates(firstPosition)) {
            initialLat = firstPosition.latitude!.toDouble();
            initialLng = firstPosition.longitude!.toDouble();
            initialZoom = 5.0;
          }
        }

        return SafeArea(
          top: false,
          child: Scaffold(
            extendBodyBehindAppBar: true,
            key: _scaffoldKey,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              title: null,
              flexibleSpace: null,
              iconTheme: IconThemeData(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
            ),
            drawer: traccarProvider.devices.length > 1 ? _buildDeviceListDrawer(context, traccarProvider) : null,
            body: Stack(
              children: [
                maplibre.MapLibreMap(
                  key: ValueKey(mapStyleProvider.isSatelliteMode),
                  initialCameraPosition: _lastCameraPosition ?? maplibre.CameraPosition(target: maplibre.LatLng(initialLat, initialLng), zoom: initialZoom),
                  styleString: mapStyleProvider.getStyle(Theme.of(context).brightness),
                  minMaxZoomPreference: const maplibre.MinMaxZoomPreference(null, _kMaxMapZoom),
                  compassEnabled: false,
                  trackCameraPosition: true,
                  onCameraMove: (position) {
                    _lastCameraPosition = position;
                    _zoomDebounce?.cancel();
                    _zoomDebounce = Timer(const Duration(milliseconds: 300), () {
                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setDouble('map_zoom_level', position.zoom);
                      });
                    });

                    // 程式自己觸發的鏡頭動畫不算「使用者拖曳」，
                    // 否則點裝置/按我的位置後，跟隨模式會馬上被自己的動畫關掉。
                    if (_isCameraAnimating) return;

                    if (_isFollowingDevice) {
                      setState(() {
                        _isFollowingDevice = false;
                      });
                    }
                  },
                  onCameraIdle: () {
                    final cameraPosition = _mapController?.cameraPosition;
                    if (cameraPosition != null) {
                      _lastCameraPosition = cameraPosition;
                      debugPrint('Map zoom: ${cameraPosition.zoom}');
                    }
                  },
                  onStyleLoadedCallback: _onStyleLoaded,
                  onMapCreated: (controller) {
                    _mapController = controller;

                    // 切換圖層會用新的 ValueKey 重建原生地圖，content inset 不會
                    // 被保留；面板仍開著時把上次量到的高度補回去。
                    if (_appliedBottomInset > 0) {
                      controller.updateContentInsets(EdgeInsets.only(bottom: _appliedBottomInset));
                    }

                    _mapController!.onSymbolTapped.add((symbol) {
                      // 記下時間：緊接而來的 onMapClick 需要靠它避免把面板關掉
                      _lastSymbolTapAt = DateTime.now();
                      final deviceIdString = symbol.data?['deviceId'];
                      final deviceId = int.tryParse(deviceIdString ?? '');

                      if (deviceId != null && mounted) {
                        final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
                        _handleDeviceMarkerTap(deviceId, traccarProvider);
                      }
                    });
                  },
                  onMapClick: (point, latLng) {
                    // 點在 marker 上時，MapLibre 可能同時送出 onSymbolTapped 與
                    // onMapClick；不在這裡擋掉的話，剛打開的面板會被立刻關閉。
                    final lastSymbolTap = _lastSymbolTapAt;
                    if (lastSymbolTap != null && DateTime.now().difference(lastSymbolTap) < _kSymbolTapGuard) {
                      return;
                    }
                    if (_isFollowingDevice) {
                      setState(() {
                        _isFollowingDevice = false;
                      });
                    }
                    if (_bottomSheetController != null) {
                      _bottomSheetController!.close();
                      _bottomSheetController = null;
                    }
                  },
                ),
                // 右側控制列：四顆按鈕共用「一塊」毛玻璃面板（一組陰影），
                // 取代原本每顆按鈕各自 2 層陰影、共 8 層互相疊加的視覺噪音。
                Positioned(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + _kEdgeInset,
                  right: _kEdgeInset,
                  child: _GlassSurface(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GlassIconButton(icon: mapStyleProvider.isSatelliteMode ? Icons.satellite_alt : Icons.map, label: 'mapLayerToggle'.tr, isActive: mapStyleProvider.isSatelliteMode, onTap: () => _toggleMapType(mapStyleProvider)),
                        const _GlassDivider(),
                        _GlassIconButton(icon: Icons.explore_rounded, label: 'mapCompass'.tr, onTap: () => _animateCamera(maplibre.CameraUpdate.bearingTo(0))),
                        const _GlassDivider(),
                        _GlassIconButton(icon: _isFollowingDevice ? Icons.my_location_rounded : Icons.location_searching_rounded, label: 'mapFollowDevice'.tr, isActive: _isFollowingDevice, haptic: true, onTap: _toggleFollowCurrentDevice),
                        const _GlassDivider(),
                        _GlassIconButton(icon: Icons.zoom_out_map_rounded, label: 'mapFitAll'.tr, onTap: () => _zoomToFitAll(traccarProvider)),
                      ],
                    ),
                  ),
                ),
                // 用 positionsRevision（遞增版本號）而不是 positions 清單：
                // Provider 的 WebSocket 是 in-place 改同一個 List，
                // 比對清單參考永遠相等，不會觸發更新。
                if (_isStyleLoaded) _DataUpdateListener(data: traccarProvider.positionsRevision, onUpdate: () => _scheduleMarkerUpdate(traccarProvider)),
                // 底部控制列（僅面板關閉時）：面板開啟時改由 sheet 內部繪製，
                // 兩者用同一個 builder，所以永遠不會互相遮住。
                if (!_isPanelOpen) Positioned(left: _kEdgeInset, right: _kEdgeInset, bottom: MediaQuery.of(context).padding.bottom + _kControlGap, child: _buildBottomControls(traccarProvider, _currentDevice)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MarkerRenderState {
  final double latitude;
  final double longitude;
  final double course;
  final double iconSize;
  final String iconImage;
  final String labelImage;

  const _MarkerRenderState({required this.latitude, required this.longitude, required this.course, required this.iconSize, required this.iconImage, required this.labelImage});
}

// ── 毛玻璃 UI 基礎元件 ──────────────────────────────────────────────
// 為什麼要抽出來？原本每顆控制鈕各自畫 2 層陰影與自己的模糊，一群按鈕
// 疊在一起會互相汙染；抽成 _GlassSurface 後「一群按鈕共用一塊玻璃、一組陰影」。

/// 毛玻璃的顏色與陰影。全部取自 Theme.colorScheme，
/// 所以 App 內任一個 theme preset（含強制日夜間）都會跟著正確。
class _GlassPalette {
  final Color fill;
  final Color border;
  final List<BoxShadow> shadows;

  const _GlassPalette({required this.fill, required this.border, required this.shadows});

  factory _GlassPalette.of(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return _GlassPalette(
      // 接近不透明的底色：避免外層陰影從半透明處透進按鈕內部
      fill: (isDark ? colorScheme.surfaceContainerHighest : colorScheme.surface).withValues(alpha: 0.94),
      border: colorScheme.outlineVariant.withValues(alpha: 0.5),
      shadows: [
        // 環境光（ambient）：較大、較柔，營造浮起的層次
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.32),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
        // 主光（key light）：較小、較實，貼合邊緣增加立體感
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.2),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

/// 毛玻璃面板容器：陰影 → 圓角裁切 → 背景模糊 → 底色/邊框。
class _GlassSurface extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const _GlassSurface({required this.child, this.borderRadius = _kControlRadius, this.padding});

  @override
  Widget build(BuildContext context) {
    final _GlassPalette palette = _GlassPalette.of(context);

    return Container(
      // 陰影畫在圓角裁切「外面」，否則會被 ClipRRect 裁掉
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(borderRadius), boxShadow: palette.shadows),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: _kGlassBlurSigma, sigmaY: _kGlassBlurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: palette.fill,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: palette.border, width: 0.5),
            ),
            // InkWell 需要 Material ancestor，用 transparency 不影響底色
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
      ),
    );
  }
}

/// 玻璃面板內的 0.5pt 內縮分隔線（對齊 app_theme.dart 的 iOS 分隔線語彙）。
class _GlassDivider extends StatelessWidget {
  const _GlassDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: _kControlSize * 0.6, height: 0.5, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6));
  }
}

/// 玻璃面板內的圖示按鈕（44pt 觸控目標）。
/// 為什麼要自己做按壓回饋？app_theme.dart 已把 highlight/splash 設為透明、
/// splashFactory 設為 NoSplash，InkWell 不會有任何視覺反應，
/// 所以改用 AnimatedScale 做「按下縮小」的微互動（iOS 扁平感不退讓）。
class _GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String label;
  final bool isActive;
  final bool haptic;
  const _GlassIconButton({required this.icon, required this.onTap, required this.label, this.isActive = false, this.haptic = false});

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: widget.label,
      child: InkWell(
        onTap: widget.onTap == null
            ? null
            : () {
                // 只在重要動作（切換裝置、跟隨）給觸覺回饋，避免整頁一直震
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!.call();
              },
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        borderRadius: BorderRadius.circular(_kControlRadius - 3),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: SizedBox(
          width: _kControlSize,
          height: _kControlSize,
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: widget.isActive ? colorScheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(_kControlRadius - 3)),
                child: Icon(widget.icon, size: 20, color: widget.isActive ? colorScheme.onPrimary : colorScheme.onSurface.withValues(alpha: 0.82)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 裝置快速切換列：單一玻璃膠囊（左箭頭｜車牌 + n/N｜右箭頭）。
/// 原本兩顆獨立按鈕中間留 28px 空白浮在底部，跟明細面板分不出層級；
/// 合併成膠囊後視覺更集中，也能一眼看出「現在在看第幾台」。
/// 中間的車牌本身也是按鈕：點一下鏡頭就回到該車並放到最大縮放（zoom 19）。
class _DeviceSwitcherBar extends StatefulWidget {
  final String? deviceName;
  final int index;
  final int total;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// 點擊中間車牌的動作；null 表示目前沒有可放大的目標。
  final VoidCallback? onPlateTap;

  const _DeviceSwitcherBar({required this.deviceName, required this.index, required this.total, required this.onPrevious, required this.onNext, this.onPlateTap});

  @override
  State<_DeviceSwitcherBar> createState() => _DeviceSwitcherBarState();
}

class _DeviceSwitcherBarState extends State<_DeviceSwitcherBar> {
  bool _platePressed = false;

  void _setPlatePressed(bool value) {
    if (_platePressed == value || !mounted) return;
    setState(() => _platePressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final VoidCallback? onPlateTap = widget.onPlateTap;

    return _GlassSurface(
      borderRadius: _kPillRadius,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GlassIconButton(icon: Icons.chevron_left_rounded, label: 'devicePrevious'.tr, haptic: true, onTap: widget.onPrevious),
          Semantics(
            button: true,
            child: InkWell(
              onTap: onPlateTap == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onPlateTap();
                    },
              onTapDown: (_) => _setPlatePressed(true),
              onTapUp: (_) => _setPlatePressed(false),
              onTapCancel: () => _setPlatePressed(false),
              borderRadius: BorderRadius.circular(_kControlRadius - 3),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 92, maxWidth: 132),
                child: AnimatedScale(
                  // 跟箭頭一樣用「按下縮小」回饋，因為 splash/highlight 已被主題關掉
                  scale: _platePressed ? 0.94 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.deviceName ?? 'Unknown Device'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: textTheme.labelLarge?.copyWith(fontSize: 14, color: colorScheme.onSurface),
                        ),
                        Text('${widget.index} / ${widget.total}', style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _GlassIconButton(icon: Icons.chevron_right_rounded, label: 'deviceNext'.tr, haptic: true, onTap: widget.onNext),
        ],
      ),
    );
  }
}

class _DataUpdateListener extends StatefulWidget {
  final dynamic data;
  final VoidCallback onUpdate;

  const _DataUpdateListener({required this.data, required this.onUpdate});

  @override
  _DataUpdateListenerState createState() => _DataUpdateListenerState();
}

class _DataUpdateListenerState extends State<_DataUpdateListener> {
  @override
  void didUpdateWidget(_DataUpdateListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      widget.onUpdate();
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Drawer 車列表的排序模式。
/// 注意：`name` 會被寫進 SharedPreferences，改名等於讓使用者的既有設定失效
/// （讀不到時自動退回 favorite），要改請一併考慮相容性。
enum _DrawerSortMode {
  /// 最愛（關注）優先 —— 原本就有的排序行為。
  favorite('sharedPriority', Icons.star_rounded),

  /// 在線的車排在最前面。
  online('dashboardOnline', Icons.wifi_tethering_rounded),

  /// 速度高 → 低。
  speed('positionSpeed', Icons.speed_rounded);

  const _DrawerSortMode(this.labelKey, this.icon);

  /// 直接沿用既有 l10n key，不需要新增字串到 60 多個語系檔。
  final String labelKey;

  final IconData icon;
}

/// 把顏色轉成 MapLibre 需要的 `#RRGGBB` 字串。
/// 軌跡線要用主題色（不像回放頁可以寫死色碼），所以需要這個轉換。
String _toHexColor(Color color) => '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
