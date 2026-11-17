// lib/screens/map_screen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:trabcdefg/src/utils/direction.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/map_style_provider.dart';
import 'package:trabcdefg/providers/settings_provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/screens/settings/geofences_screen.dart' hide AppMapType;
import 'package:trabcdefg/services/feedback.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/src/utils/motion.dart';
import 'package:trabcdefg/src/utils/glass_settings.dart';
import 'package:trabcdefg/src/utils/position_coordinates.dart';
import 'package:trabcdefg/src/utils/status_utils.dart';
import 'package:trabcdefg/storage/map_view_memory.dart';
import 'package:trabcdefg/widgets/offline_address_service.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:trabcdefg/services/map_navigation.dart';
import 'package:trabcdefg/services/marker_icon_service.dart';
import 'package:trabcdefg/widgets/device_detail_panel.dart';
import 'package:trabcdefg/widgets/first_run_helper.dart';
import 'package:trabcdefg/widgets/simple_mode.dart';
import 'package:trabcdefg/widgets/state_views.dart';

import 'share_device_screen.dart';

const double _kControlSize = 44;
const double _kControlRadius = 12;
const double _kPillRadius = 22;
const double _kEdgeInset = 16;
const double _kControlGap = 12;
const double _kMaxMapZoom = 19.0;
const double _kMarkerSelectionRadius = 64.0;
const Duration _kSymbolTapGuard = Duration(milliseconds: 300);
const Duration _kCameraEventGrace = Duration(milliseconds: 250);
const int _kMaxTrailPoints = 1000; //3000
const double _kAddressRefreshMeters = 50;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  maplibre.MapLibreMapController? _mapController;
  maplibre.CameraPosition? _lastCameraPosition;
  bool _isStyleLoaded = false;
  bool _hasInitialZoomed = false;

  /// 使用者自己動過鏡頭（手勢）才為 true；程式動的 fit-all、跟車、開場還原都不算。
  bool _userOwnsZoom = false;

  /// 地圖頁導覽：第一次進來才自動播，之後用右上角的問號重播。
  static const String _kMapHelperSeenKey = 'map_helper_seen';
  static const String _kPanelHelperSeenKey = 'panel_helper_seen';
  final GlobalKey _helperFollowKey = GlobalKey();
  final GlobalKey _helperFitAllKey = GlobalKey();
  final GlobalKey _helperListKey = GlobalKey();
  final GlobalKey _helperSwitcherKey = GlobalKey();
  final GlobalKey _helperZoomKey = GlobalKey();
  bool _mapHelperAttempted = false;
  bool _panelHelperAttempted = false;

  /// 導覽是一次一個 modal route；這個旗標防止同時開兩份。
  bool _guideOpen = false;
  final Set<String> _loadedIcons = {};
  final Map<int, maplibre.Symbol> _deviceSymbols = {};
  final Map<int, maplibre.Symbol> _labelSymbols = {};
  final Map<int, _MarkerRenderState> _markerRenderStates = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  api.Device? _currentDevice;
  late MarkerIconService _iconService;
  final http.Client _httpClient = http.Client();

  final ValueNotifier<bool> _panelOpenNotifier = ValueNotifier(false);
  bool get _isPanelOpen => _panelOpenNotifier.value;
  bool _isFollowingDevice = false;

  /// Shown after a manual pan drops follow mode, so the user can get it back.
  bool _showReturnToFollow = false;
  Timer? _returnToFollowTimer;

  maplibre.Line? _trailLine;
  String? _trailColorHex;
  final List<maplibre.LatLng> _trailPoints = [];
  int? _trailDeviceId;
  Timer? _trailPushTimer;

  maplibre.LatLng? _lastAddressLookupPoint;

  bool _isCameraAnimating = false;
  Timer? _cameraAnimationGraceTimer;

  DateTime? _lastSymbolTapAt;

  final ValueNotifier<api.Device?> _selectedDeviceNotifier = ValueNotifier(null);
  final ValueNotifier<api.Position?> _selectedPositionNotifier = ValueNotifier(null);
  final ValueNotifier<String> _selectedAddressNotifier = ValueNotifier("");
  int _deviceSelectionGeneration = 0;

  MapNavigation? _mapNavigation;
  int? _pendingFocusDeviceId;

  Timer? _zoomDebounce;

  bool _myLocationEnabled = false;
  bool _centerOnUserWhenLocated = false;
  maplibre.LatLng? _userLocation;

  /// 上次套用的圖標倍率，用來在倍率變更（含簡易模式切換）時立即重畫標記。
  double? _lastMarkerScale;

  @override
  void initState() {
    super.initState();

    _iconService = MarkerIconService(loadedIcons: _loadedIcons);
    // Not awaited: the map paints first, and the 20 MB address database copies
    // on its own time. Nothing on the first frame reads it.
    unawaited(OfflineAddressService.initDatabase());

    // Not awaited: the map shows up first, and the puck fades in once the user
    // answers the permission dialog.
    _resolveLocationPermission();

    _loadLastSelectedDevice();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapNavigation = context.read<MapNavigation>()..addListener(_onMapFocusRequested);
      _onMapFocusRequested();
    });
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

  Future<void> _resolveLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (!status.isGranted) {
      status = await Permission.locationWhenInUse.request();
    }
    if (!mounted || status.isGranted == _myLocationEnabled) return;

    // The plugin applies a myLocationEnabled change on the live map, so the map
    // view is not rebuilt here; MapLibreMapController.updateMyLocationEnabled()
    // enables the location component in place.
    _safeSetState(() => _myLocationEnabled = status.isGranted);
  }

  Future<void> _goToCurrentLocation() async {
    if (!_myLocationEnabled) {
      final status = await Permission.locationWhenInUse.request();
      if (!mounted) return;
      if (!status.isGranted) {
        FeedbackService.error('mapLocationDenied'.tr, context: context);
        return;
      }
      _centerOnUserWhenLocated = true;
      _safeSetState(() => _myLocationEnabled = true);
      return;
    }

    final position = _userLocation;
    if (position == null) {
      // Permission is granted but the first fix has not arrived yet; centring is
      // deferred to the location callback instead of asking for a second tap.
      _centerOnUserWhenLocated = true;
      FeedbackService.info('mapLocationUnavailable'.tr, context: context);
      return;
    }

    if (_isFollowingDevice) {
      _safeSetState(() => _isFollowingDevice = false);
    }
    _animateCamera(maplibre.CameraUpdate.newLatLngZoom(position, 16.0));
  }

  Future<void> _loadLastSelectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    // 地圖只認自己的記憶；`selectedDeviceId` 是全 App 共用的，報告頁也會改它。
    final int? lastDeviceId = MapViewMemory.read(prefs).deviceId ?? prefs.getInt('selectedDeviceId');

    if (lastDeviceId != null && mounted) {
      final provider = context.read<TraccarProvider>();
      if (provider.devices.isNotEmpty) {
        final device = provider.devices.firstWhereOrNull((d) => d.id == lastDeviceId);
        if (device != null) {
          _safeSetState(() {
            _currentDevice = device;
          });
        }
      }
    }
  }

  void _onMapFocusRequested() {
    final MapNavigation? navigation = _mapNavigation;
    if (navigation == null) return;
    final int? pending = navigation.pendingDeviceId;
    if (pending == null) return;
    _pendingFocusDeviceId = pending;
    _maybeConsumePendingFocus();
  }

  void _maybeConsumePendingFocus() {
    final MapNavigation? navigation = _mapNavigation;
    final int? deviceId = _pendingFocusDeviceId;
    if (navigation == null || deviceId == null) return;
    if (!_isStyleLoaded || _mapController == null) return;

    _pendingFocusDeviceId = null;
    navigation.takePendingDeviceId();
    final api.Device? device = context.read<TraccarProvider>().devices.firstWhereOrNull((d) => d.id == deviceId);
    if (device == null) return;

    _hasInitialZoomed = true;
    _onDeviceSelected(device, forceShowPanel: true, zoomToMax: true);
  }

  void _closeDetailPanel() {
    if (!_isPanelOpen) return;
    _bottomSheetController?.close();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 圖標倍率（含簡易模式套用的大圖標）變更時立即重畫，不必等下一包位置資料。
    final double markerScale = context.read<SettingsProvider>().markerSizeScale;
    if (_lastMarkerScale != null && _lastMarkerScale != markerScale) {
      _scheduleMarkerUpdate(context.read<TraccarProvider>());
    }
    _lastMarkerScale = markerScale;
  }

  @override
  void dispose() {
    _mapNavigation?.removeListener(_onMapFocusRequested);
    _zoomDebounce?.cancel();
    _cameraAnimationGraceTimer?.cancel();
    _returnToFollowTimer?.cancel();
    _trailPushTimer?.cancel();

    _httpClient.close();
    _panelOpenNotifier.dispose();
    _selectedDeviceNotifier.dispose();
    _selectedPositionNotifier.dispose();
    _selectedAddressNotifier.dispose();
    super.dispose();
  }

  void _onStyleLoaded() async {
    _safeSetState(() {
      _isStyleLoaded = true;
    });
    _loadedIcons.clear();
    _deviceSymbols.clear();
    _labelSymbols.clear();
    _markerRenderStates.clear();
    _trailLine = null;
    _trailPoints.clear();
    _lastAddressLookupPoint = null;

    if (!mounted) return;
    final traccarProvider = context.read<TraccarProvider>();
    final String trailColorHex = _toHexColor(Theme.of(context).colorScheme.primary);
    await _mapController!.setSymbolIconAllowOverlap(true);
    await _mapController!.setSymbolIconIgnorePlacement(true);
    await _mapController!.setSymbolTextAllowOverlap(true);
    await _mapController!.setSymbolTextIgnorePlacement(true);

    _trailColorHex = trailColorHex;
    await _createTrailLine(const <maplibre.LatLng>[], trailColorHex);
    _trailDeviceId = _currentDevice?.id;
    _pushTrailGeometry();

    await _scheduleMarkerUpdate(traccarProvider);
    _maybeConsumePendingFocus();

    if (!_hasInitialZoomed) {
      // 開場只還原一次：認「上次那台車 + 當時的 zoom」，再定位到該車現在的位置。
      // 位置永遠即時查，不存檔；存下來的只有「誰」和「多大」。
      final prefs = await SharedPreferences.getInstance();
      final memory = MapViewMemory.read(prefs);
      // 舊版沒有 MapViewMemory，退回它當年用的 key，老用戶不會被清空。
      final int? lastDeviceId = memory.deviceId ?? prefs.getInt('selectedDeviceId');
      final double? savedZoom = memory.zoom ?? prefs.getDouble('map_zoom_level');

      final api.Device? lastDevice = lastDeviceId == null ? null : await _findDevice(lastDeviceId, traccarProvider);
      if (lastDevice == null) {
        _zoomToFitAll(traccarProvider, showFeedback: false);
      } else {
        _userOwnsZoom = savedZoom != null;
        await _onDeviceSelected(lastDevice, follow: false, zoomOverride: savedZoom);
      }
      _hasInitialZoomed = true;
    }

    unawaited(_maybeShowMapHelper());
  }

  /// 上次那台車可能在裝置清單抵達前就查了；有界地等，等不到才放手。
  Future<api.Device?> _findDevice(int deviceId, TraccarProvider provider) async {
    for (int attempt = 0; attempt < 10; attempt++) {
      final api.Device? device = provider.devices.firstWhereOrNull((d) => d.id == deviceId);
      if (device != null) return device;
      // 清單已有內容卻沒有這台車，代表車被刪了，不必再等。
      if (provider.devices.isNotEmpty || !mounted) return null;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return null;
  }

  /// 記住「上次看的視角」。只在使用者自己動過鏡頭、或換車之後才寫：
  /// fit-all、跟車動畫與開場還原都不該改掉使用者的選擇。
  void _scheduleViewMemorySave() {
    _zoomDebounce?.cancel();
    _zoomDebounce = Timer(const Duration(milliseconds: 300), _saveViewMemory);
  }

  Future<void> _saveViewMemory() async {
    final int? deviceId = _currentDevice?.id;
    final double? zoom = _mapController?.cameraPosition?.zoom ?? _lastCameraPosition?.zoom;
    if (deviceId == null || zoom == null) return;
    final prefs = await SharedPreferences.getInstance();
    await MapViewMemory.record(prefs, deviceId: deviceId, zoom: zoom);
  }

  /// 第一次進到地圖頁時自動播一次；看過就記在 prefs，跳過也算看過。
  Future<void> _maybeShowMapHelper() async {
    if (!mounted || _mapHelperAttempted) return;
    _mapHelperAttempted = true;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || (prefs.getBool(_kMapHelperSeenKey) ?? false)) return;
    // 一台車都沒有時沒東西可導覽，等下次進地圖頁再說。
    if (context.read<TraccarProvider>().devices.isEmpty) {
      _mapHelperAttempted = false;
      return;
    }
    await _presentGuide(_mapHelperSteps(context), _kMapHelperSeenKey);
  }

  void _startMapHelper() {
    if (!mounted) return;
    unawaited(_presentGuide(_mapHelperSteps(context), _kMapHelperSeenKey));
  }

  /// 第一次點開車輛詳情面板時，介紹面板裡的東西。
  Future<void> _maybeShowPanelHelper(DevicePanelHelperKeys keys) async {
    if (!mounted || _panelHelperAttempted) return;
    _panelHelperAttempted = true;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || (prefs.getBool(_kPanelHelperSeenKey) ?? false)) return;
    // 等底部面板滑上來，座標才量得準。
    await Future.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    await _presentGuide(<FirstRunHelperStep>[
      FirstRunHelperStep(targetKey: keys.header, title: 'panelHelperHeaderTitle'.tr, body: 'panelHelperHeaderBody'.tr),
      FirstRunHelperStep(targetKey: keys.status, title: 'panelHelperStatusTitle'.tr, body: 'panelHelperStatusBody'.tr),
      FirstRunHelperStep(targetKey: keys.address, title: 'panelHelperAddressTitle'.tr, body: 'panelHelperAddressBody'.tr),
    ], _kPanelHelperSeenKey);
  }

  /// 導覽一律用 modal route 呈現：擋在底部面板之上、返回鍵等於跳過，
  /// 關掉之後才寫旗標（跳過也算看過）。
  Future<void> _presentGuide(List<FirstRunHelperStep> steps, String seenKey) async {
    if (!mounted || _guideOpen || steps.isEmpty) return;
    _guideOpen = true;
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'guide',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (dialogContext, _, __) => FirstRunHelperOverlay(
          steps: steps,
          nextLabel: 'helperNext'.tr,
          doneLabel: 'helperDone'.tr,
          skipLabel: 'helperSkip'.tr,
          counterLabel: (current, total) => 'helperStepOf'.trParams({'current': '$current', 'total': '$total'}),
          onFinished: () => Navigator.of(dialogContext).pop(),
        ),
        transitionBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(seenKey, true);
    } finally {
      _guideOpen = false;
    }
  }

  /// 只看得到就介紹得到：簡易模式藏起來的按鈕、只有一台車時不存在的切換列，
  /// 都不列進步驟，否則聚光燈會照向不存在的東西。
  List<FirstRunHelperStep> _mapHelperSteps(BuildContext context) {
    final bool simpleMode = isSimpleMode(context);
    final int deviceCount = _navigableDevices(context.read<TraccarProvider>()).length;
    return <FirstRunHelperStep>[
      FirstRunHelperStep(targetKey: _helperFollowKey, title: 'mapHelperFollowTitle'.tr, body: 'mapHelperFollowBody'.tr),
      if (!simpleMode) FirstRunHelperStep(targetKey: _helperFitAllKey, title: 'mapHelperFitAllTitle'.tr, body: 'mapHelperFitAllBody'.tr),
      FirstRunHelperStep(targetKey: _helperListKey, title: 'mapHelperListTitle'.tr, body: 'mapHelperListBody'.tr),
      if (deviceCount > 1) FirstRunHelperStep(targetKey: _helperSwitcherKey, title: 'mapHelperSwitcherTitle'.tr, body: 'mapHelperSwitcherBody'.tr),
      FirstRunHelperStep(targetKey: _helperZoomKey, title: 'mapHelperZoomTitle'.tr, body: 'mapHelperZoomBody'.tr),
    ];
  }

  Future<void> _animateCamera(maplibre.CameraUpdate update) async {
    final controller = _mapController;
    if (controller == null) return;

    final bool reduceMotion = mounted && reduceMotionOf(context);
    _cameraAnimationGraceTimer?.cancel();
    _isCameraAnimating = true;
    try {
      if (reduceMotion) {
        await controller.moveCamera(update);
      } else {
        await controller.animateCamera(update);
      }
    } catch (e) {
      debugPrint('Camera animation failed: $e');
    } finally {
      _cameraAnimationGraceTimer?.cancel();
      _cameraAnimationGraceTimer = Timer(_kCameraEventGrace, () {
        _isCameraAnimating = false;
      });
    }
  }

  double? _measureDetailSheetHeight() {
    final renderObject = _detailSheetKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size.height;
    }
    return null;
  }

  Future<void> _syncSheetContentInset({bool animated = true}) async {
    final controller = _mapController;
    if (controller == null) return;

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

  void _showReturnToFollowBadge() {
    _safeSetState(() => _showReturnToFollow = true);
    _returnToFollowTimer?.cancel();
    _returnToFollowTimer = Timer(const Duration(seconds: 8), () {
      _safeSetState(() => _showReturnToFollow = false);
    });
  }

  void _clearReturnToFollowBadge() {
    _returnToFollowTimer?.cancel();
    _returnToFollowTimer = null;
    if (_showReturnToFollow) _safeSetState(() => _showReturnToFollow = false);
  }

  void _toggleFollowCurrentDevice() {
    final device = _currentDevice;
    if (device == null) return;

    if (_isFollowingDevice) {
      _safeSetState(() {
        _isFollowingDevice = false;
      });
      return;
    }

    final traccarProvider = context.read<TraccarProvider>();
    if (device.id == null || traccarProvider.getPosition(device.id!) == null) {
      FeedbackService.info('mapNoPositions'.tr, context: context);
      return;
    }
    _onDeviceSelected(device, forceShowPanel: true);
    _clearReturnToFollowBadge();
  }

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
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
                  child: Text('pleaseSelectDevice'.tr, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                for (final device in devices)
                  ListTile(
                    leading: const Icon(Icons.directions_car_rounded),
                    title: Text(device.name ?? 'deviceUnknown'.tr),
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

  /// 導覽用的 GlobalKey 只掛在主畫面的那一份控制列；詳情面板裡也有一份同樣的控制列，
  /// 兩份同時掛同一個 GlobalKey 會在面板收合的過渡幀炸掉。
  Widget _maybeKeyed({required bool withHelperKeys, required Key key, required Widget child}) {
    return withHelperKeys ? KeyedSubtree(key: key, child: child) : child;
  }

  int _deviceIndexIn(List<api.Device> devices, api.Device? device) {
    final index = devices.indexWhere((d) => d.id == device?.id);
    return index < 0 ? 1 : index + 1;
  }

  api.Device? _switcherDevice(List<api.Device> devices, api.Device? currentDevice) {
    if (devices.isEmpty) return null;
    final index = devices.indexWhere((d) => d.id == currentDevice?.id);
    return devices[index < 0 ? 0 : index];
  }

  Widget _buildBottomControls(TraccarProvider traccarProvider, api.Device? currentDevice, {bool withHelperKeys = false}) {
    final List<api.Device> navigableDevices = _navigableDevices(traccarProvider);
    final api.Device? switcherDevice = _switcherDevice(navigableDevices, currentDevice);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: navigableDevices.length > 1
                ? _maybeKeyed(
                    withHelperKeys: withHelperKeys,
                    key: _helperSwitcherKey,
                    child: _DeviceSwitcherBar(
                      deviceName: switcherDevice?.name,
                      index: _deviceIndexIn(navigableDevices, currentDevice),
                      total: navigableDevices.length,
                      onPrevious: () => _navigateToDevice(-1, traccarProvider),
                      onNext: () => _navigateToDevice(1, traccarProvider),
                      onPlateTap: switcherDevice == null ? null : () => _onDeviceSelected(switcherDevice, forceShowPanel: true, zoomToMax: true),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        _maybeKeyed(
          withHelperKeys: withHelperKeys,
          key: _helperZoomKey,
          child: _GlassSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GlassIconButton(icon: Icons.my_location_rounded, label: 'mapCurrentLocation'.tr, onTap: _goToCurrentLocation),
                const _GlassDivider(),
                _GlassIconButton(icon: Icons.add_rounded, label: 'mapZoomIn'.tr, onTap: () => _animateCamera(maplibre.CameraUpdate.zoomIn())),
                const _GlassDivider(),
                _GlassIconButton(icon: Icons.remove_rounded, label: 'mapZoomOut'.tr, onTap: () => _animateCamera(maplibre.CameraUpdate.zoomOut())),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 地圖頁唯一的車輛清單入口：搜尋、常用優先、點一列就跳到那台車。
  ///
  /// 螢幕閱讀器也走這條路——地圖上的標記是原生 symbol，本身沒有語意。
  void _showDevicePicker(TraccarProvider provider) {
    if (_navigableDevices(provider).isEmpty) {
      FeedbackService.info('mapNoPositions'.tr, context: context);
      return;
    }
    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => _DevicePickerSheet(
        provider: provider,
        onSelected: (device) {
          Navigator.of(popupContext).pop();
          _onDeviceSelected(device, forceShowPanel: true, zoomToMax: true);
        },
      ),
    );
  }

  void _zoomToFitAll(TraccarProvider provider, {bool showFeedback = true}) {
    if (provider.positions.isEmpty) {
      if (showFeedback && mounted) FeedbackService.info('mapNoPositions'.tr, context: context);
      return;
    }
    if (_mapController == null) return;

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

    final double scale = context.read<SettingsProvider>().markerSizeScale;

    _updateSelectedDeviceLive(provider);

    final visibleDeviceIds = <int>{};
    final List<maplibre.SymbolOptions> pendingIcons = <maplibre.SymbolOptions>[];
    final List<int> pendingIconDeviceIds = <int>[];
    final List<Map<String, dynamic>> pendingIconData = <Map<String, dynamic>>[];
    final List<maplibre.SymbolOptions> pendingLabels = <maplibre.SymbolOptions>[];
    final List<int> pendingLabelDeviceIds = <int>[];
    final List<Map<String, dynamic>> pendingLabelData = <Map<String, dynamic>>[];

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
      final bool isSelected = deviceId == _currentDevice?.id;
      final String customLabelId = isSelected ? "label_selected_$plate" : "label_$plate";
      final latLng = maplibre.LatLng(position.latitude!.toDouble(), position.longitude!.toDouble());
      final double course = position.course?.toDouble() ?? 0.0;
      final double iconSize = 4.0 * scale;
      final previousState = _markerRenderStates[deviceId];
      final bool iconChanged =
          previousState == null || previousState.iconImage != baseIconKey || previousState.course != course || previousState.iconSize != iconSize || previousState.latitude != latLng.latitude || previousState.longitude != latLng.longitude;

      if (_deviceSymbols[deviceId] == null || previousState?.iconImage != baseIconKey) {
        await _iconService.ensureIconLoaded(controller, baseIconKey);
      }
      if (_labelSymbols[deviceId] == null || previousState?.labelImage != customLabelId) {
        await _iconService.ensureLabelIconLoaded(controller, plate, customLabelId, isSelected: isSelected);
      }
      if (!mounted || !identical(_mapController, controller) || !_isStyleLoaded) return;

      // 車牌沿用原本的 15px 偏移，但 zIndex 高於車輛圖示，所以不再被圖示蓋住。
      final bool labelChanged = previousState == null || previousState.labelImage != customLabelId || previousState.latitude != latLng.latitude || previousState.longitude != latLng.longitude;

      final deviceData = {'deviceId': deviceId.toString()};
      final maplibre.SymbolOptions iconOptions = maplibre.SymbolOptions(geometry: latLng, iconImage: baseIconKey, iconRotate: course, iconSize: iconSize, iconAnchor: 'center', zIndex: 10);
      final int labelZIndex = isSelected ? 12 : 11;
      final maplibre.SymbolOptions labelOptions = maplibre.SymbolOptions(geometry: latLng, iconImage: customLabelId, iconRotate: 0.0, iconOffset: const Offset(0, 15), iconSize: 1.2, iconAnchor: 'top', zIndex: labelZIndex);

      final iconSymbol = _deviceSymbols[deviceId];
      if (iconSymbol == null) {
        pendingIcons.add(iconOptions);
        pendingIconDeviceIds.add(deviceId);
        pendingIconData.add(deviceData);
      } else if (iconChanged) {
        await controller.updateSymbol(iconSymbol, iconOptions);
      }

      final labelSymbol = _labelSymbols[deviceId];
      if (labelSymbol == null) {
        pendingLabels.add(labelOptions);
        pendingLabelDeviceIds.add(deviceId);
        pendingLabelData.add(deviceData);
      } else if (labelChanged) {
        await controller.updateSymbol(labelSymbol, labelOptions);
      }

      _markerRenderStates[deviceId] = _MarkerRenderState(latitude: latLng.latitude, longitude: latLng.longitude, course: course, iconSize: iconSize, iconImage: baseIconKey, labelImage: customLabelId);
    }

    if (pendingIcons.isNotEmpty) {
      // addSymbols builds its result in the submitted order, so device ids zip by index.
      final List<maplibre.Symbol> addedIcons = await controller.addSymbols(pendingIcons, pendingIconData);
      for (int i = 0; i < addedIcons.length && i < pendingIconDeviceIds.length; i++) {
        _deviceSymbols[pendingIconDeviceIds[i]] = addedIcons[i];
      }
    }

    if (!mounted || !identical(_mapController, controller) || !_isStyleLoaded) return;

    if (pendingLabels.isNotEmpty) {
      final List<maplibre.Symbol> addedLabels = await controller.addSymbols(pendingLabels, pendingLabelData);
      for (int i = 0; i < addedLabels.length && i < pendingLabelDeviceIds.length; i++) {
        _labelSymbols[pendingLabelDeviceIds[i]] = addedLabels[i];
      }
    }

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

  /// Re-resolves the selected device from the provider so edited fields
  /// (category, name, ...) reach the detail panel and the marker labels.
  void _syncSelectedDeviceFromProvider(TraccarProvider provider) {
    final int? deviceId = _currentDevice?.id ?? _selectedDeviceNotifier.value?.id;
    if (deviceId == null) return;

    final api.Device? fresh = provider.devices.firstWhereOrNull((d) => d.id == deviceId);
    if (fresh == null) return;

    if (!identical(fresh, _currentDevice)) {
      _safeSetState(() => _currentDevice = fresh);
    }
    if (!identical(fresh, _selectedDeviceNotifier.value)) {
      _selectedDeviceNotifier.value = fresh;
    }
  }

  void _updateSelectedDeviceLive(TraccarProvider provider) {
    final int? currentDeviceId = _currentDevice?.id;
    if (currentDeviceId == null) return;

    final api.Position? currentPos = provider.getPosition(currentDeviceId);
    if (currentPos == null || !_hasValidCoordinates(currentPos)) return;

    final api.Position position = currentPos;
    final maplibre.LatLng currentLatLng = maplibre.LatLng(position.latitude!.toDouble(), position.longitude!.toDouble());

    if (position.deviceId == _trailDeviceId) {
      _appendTrailPoint(currentLatLng);
    }

    if (_isFollowingDevice) {
      _animateCamera(maplibre.CameraUpdate.newLatLng(currentLatLng));
    }

    if (_selectedDeviceNotifier.value?.id == currentDeviceId) {
      _selectedPositionNotifier.value = position;
      if (_isPanelOpen) {
        _maybeRefreshPanelAddress(position, currentLatLng);
      }
    }
  }

  Future<void> _createTrailLine(List<maplibre.LatLng> geometry, String colorHex) async {
    final controller = _mapController;
    if (controller == null) return;
    try {
      _trailLine = await controller.addLine(maplibre.LineOptions(geometry: geometry, lineColor: colorHex, lineWidth: 4.0, lineJoin: 'round'));
    } catch (e) {
      debugPrint('Trail line creation failed: $e');
    }
  }

  void _appendTrailPoint(maplibre.LatLng point) {
    if (_trailPoints.isNotEmpty) {
      final maplibre.LatLng last = _trailPoints.last;
      if (last.latitude == point.latitude && last.longitude == point.longitude) return;
      if (_metersBetween(last, point) < 5.0) return; // 5公尺內的飄移直接濾掉
    }

    _trailPoints.add(point);

    // 當點數超過上限時，透過清空與重新加入壓縮後的點來維持 final 屬性
    if (_trailPoints.length > _kMaxTrailPoints) {
      final compressed = _douglasPeucker(_trailPoints, 2.0);
      _trailPoints.clear();
      _trailPoints.addAll(compressed);

      // 如果壓完還是超過上限，才強制切除最舊的點
      if (_trailPoints.length > _kMaxTrailPoints) {
        _trailPoints.removeRange(0, _trailPoints.length - _kMaxTrailPoints);
      }
    }

    _scheduleTrailPush();
  }

  void _scheduleTrailPush() {
    if (_trailPushTimer != null) return;
    _trailPushTimer = Timer(const Duration(milliseconds: 250), () {
      _trailPushTimer = null;
      _pushTrailGeometry();
    });
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

    final String? colorHex = _trailColorHex;
    if (colorHex == null || geometry.length < 2) return;
    _createTrailLine(geometry, colorHex);
  }

  Future<void> _maybeRefreshPanelAddress(api.Position position, maplibre.LatLng latLng) async {
    final maplibre.LatLng? last = _lastAddressLookupPoint;
    if (last != null && _metersBetween(last, latLng) < _kAddressRefreshMeters) return;
    _lastAddressLookupPoint = latLng;

    try {
      final String addr = await OfflineAddressService.getAddress(latLng.latitude, latLng.longitude);
      if (!mounted) return;
      if (_selectedDeviceNotifier.value?.id != position.deviceId) return;
      _selectedAddressNotifier.value = addr;
    } catch (e) {
      debugPrint("Geocoder error: $e");
    }
  }

  // 放入 _MapScreenState 類別中的任意方法旁（例如 _metersBetween 附近）

  List<maplibre.LatLng> _douglasPeucker(List<maplibre.LatLng> points, double tolerance) {
    if (points.length <= 2) return points;

    int maxIndex = 0;
    double maxDist = 0.0;

    final first = points.first;
    final last = points.last;

    for (int i = 1; i < points.length - 1; i++) {
      final dist = _perpendicularDistance(points[i], first, last);
      if (dist > maxDist) {
        maxDist = dist;
        maxIndex = i;
      }
    }

    if (maxDist > tolerance) {
      final left = _douglasPeucker(points.sublist(0, maxIndex + 1), tolerance);
      final right = _douglasPeucker(points.sublist(maxIndex), tolerance);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [first, last];
    }
  }

  // 計算點 p 到直線 ab 的垂直距離（公尺）
  double _perpendicularDistance(maplibre.LatLng p, maplibre.LatLng a, maplibre.LatLng b) {
    final double x = p.longitude;
    final double y = p.latitude;
    final double x1 = a.longitude;
    final double y1 = a.latitude;
    final double x2 = b.longitude;
    final double y2 = b.latitude;

    final double dx = x2 - x1;
    final double dy = y2 - y1;

    if (dx == 0 && dy == 0) {
      return _metersBetween(a, p);
    }

    // 計算點到線段的垂直距離（利用向量叉積原理）
    final double numerator = ((dy * x) - (dx * y) + (x2 * y1) - (y2 * x1)).abs();
    final double denominator = math.sqrt(dx * dx + dy * dy);

    // 將經緯度差值粗略轉換為公尺（赤道附近 1 度約 111,000 公尺）
    final double degreesToMeters = 111000.0;
    return (numerator / denominator) * degreesToMeters;
  }

  double _metersBetween(maplibre.LatLng a, maplibre.LatLng b) {
    const double earthRadius = 6371000;
    final double dLat = (b.latitude - a.latitude) * math.pi / 180;
    final double dLng = (b.longitude - a.longitude) * math.pi / 180;
    final double h = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(a.latitude * math.pi / 180) * math.cos(b.latitude * math.pi / 180) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
  }

  PersistentBottomSheetController? _bottomSheetController;

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
          title: Text('deviceDeleteConfirmTitle'.tr),
          content: Text('Are you sure you want to delete the device "${device.name}"?'.tr),
          actions: <Widget>[
            CupertinoDialogAction(
              child: Text('sharedCancel'.tr),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            CupertinoDialogAction(
              textStyle: const TextStyle(color: CupertinoColors.systemRed),
              child: Text('sharedDelete'.tr),
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
    final traccarProvider = context.read<TraccarProvider>();

    // 直接使用 Provider 內的方法
    final success = await traccarProvider.deleteDevice(deviceId);

    if (success) {
      _bottomSheetController?.close();
      if (!mounted) return;
      FeedbackService.success('deviceDeleteSuccess'.tr, context: context);
    } else {
      if (!mounted) return;
      FeedbackService.error('deviceDeleteFailed'.tr, context: context);
    }
  }

  void _navigateToDevice(int direction, TraccarProvider provider) {
    final List<api.Device> devices = _navigableDevices(provider);
    if (devices.isEmpty) return;

    final int currentIndex = devices.indexWhere((d) => d.id == _currentDevice?.id);
    int nextIndex;
    if (currentIndex < 0) {
      nextIndex = direction > 0 ? 0 : devices.length - 1;
    } else {
      nextIndex = (currentIndex + direction) % devices.length;
      if (nextIndex < 0) nextIndex = devices.length - 1;
    }

    final nextDevice = devices[nextIndex];
    _onDeviceSelected(nextDevice, forceShowPanel: false, follow: true);
  }

  Future<void> _onDeviceSelected(api.Device device, {bool forceShowPanel = false, bool follow = true, bool zoomToMax = false, double? zoomOverride}) async {
    final int? deviceId = device.id;
    if (deviceId == null) return;

    final int selectionGeneration = ++_deviceSelectionGeneration;
    final bool deviceChanged = _selectedDeviceNotifier.value?.id != device.id;

    _safeSetState(() => _currentDevice = device);
    final traccarProvider = context.read<TraccarProvider>();

    final position = traccarProvider.getPosition(deviceId) ?? api.Position(deviceId: deviceId);

    final bool hasFix = _hasValidCoordinates(position);
    final maplibre.LatLng? latLng = hasFix ? maplibre.LatLng(position.latitude!.toDouble(), position.longitude!.toDouble()) : null;

    final String? immediateAddress = latLng == null ? null : OfflineAddressService.getAddressFromCache(latLng.latitude, latLng.longitude);

    _selectedDeviceNotifier.value = device;
    _selectedPositionNotifier.value = position;
    _selectedAddressNotifier.value = immediateAddress ?? (hasFix ? "Loading..." : "No GPS Signal");

    if (follow && !_isFollowingDevice) {
      _safeSetState(() => _isFollowingDevice = true);
    }

    if (deviceChanged) {
      _trailDeviceId = device.id;
      _trailPoints.clear();
      _pushTrailGeometry();
      _lastAddressLookupPoint = null;
    }
    if (latLng != null) {
      _appendTrailPoint(latLng);
    }

    if (forceShowPanel || _isPanelOpen) {
      _showDeviceDetailPanel(device, position);
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted || selectionGeneration != _deviceSelectionGeneration) return;
    await prefs.setInt('selectedDeviceId', deviceId);
    if (device.name != null) {
      await prefs.setString('selectedDeviceName', device.name!);
    }
    if (!mounted || selectionGeneration != _deviceSelectionGeneration) return;

    if (latLng == null) return;

    await _syncSheetContentInset(animated: false);
    if (!mounted || selectionGeneration != _deviceSelectionGeneration) return;
    // 換車時回到該車自己的 zoom；點 marker（zoomToMax）與開場還原（zoomOverride）優先。
    final double? rememberedZoom = zoomToMax ? null : zoomOverride ?? (deviceChanged ? MapViewMemory.zoomFor(prefs, deviceId) : null);
    final maplibre.CameraUpdate cameraUpdate = zoomToMax
        ? maplibre.CameraUpdate.newLatLngZoom(latLng, _kMaxMapZoom)
        : rememberedZoom == null
        ? maplibre.CameraUpdate.newLatLng(latLng)
        : maplibre.CameraUpdate.newLatLngZoom(latLng, rememberedZoom);
    await _animateCamera(cameraUpdate);
    if (!mounted || selectionGeneration != _deviceSelectionGeneration) return;
    await _scheduleMarkerUpdate(traccarProvider);
    if (!mounted || selectionGeneration != _deviceSelectionGeneration) return;
    // 選了哪台車就是在看哪台車：resume 點跟著換。
    _scheduleViewMemorySave();

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
                      device.name ?? 'mapMoreOptions'.tr,
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
                      final navigator = Navigator.of(context);

                      Navigator.of(context).pop();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('sharedDeviceId', device.id!);
                      await prefs.setString('sharedDeviceName', device.name!);

                      if (!mounted) return;

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

    _safeSetState(() {
      _panelOpenNotifier.value = true;
    });
    // 每次開面板都給一份新的導覽座標，舊面板還在收合動畫時才不會撞到同一個 GlobalKey。
    final DevicePanelHelperKeys helperKeys = DevicePanelHelperKeys();
    unawaited(_maybeShowPanelHelper(helperKeys));
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
                            Padding(padding: const EdgeInsetsDirectional.fromSTEB(_kEdgeInset, 0, _kEdgeInset, _kControlGap), child: _buildBottomControls(panelProvider, currentDev)),
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 16,
                                    offset: const Offset(0, -4), // 向上投射陰影，凸顯浮動面板效果
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                child: DeviceDetailPanel(
                                  helperKeys: helperKeys,
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
                                    final traccarProvider = context.read<TraccarProvider>();
                                    await traccarProvider.fetchInitialData();
                                  },
                                ),
                              ),
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
        _safeSetState(() {
          _panelOpenNotifier.value = false;
          _bottomSheetController = null;
          _isFollowingDevice = false;
        });
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

  @override
  Widget build(BuildContext context) {
    final MapStyleProvider mapStyleProvider = context.watch<MapStyleProvider>();
    final TraccarProvider traccarProvider = context.read<TraccarProvider>();
    final bool simpleMode = isSimpleMode(context);

    if (traccarProvider.isLoading && traccarProvider.devices.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

    return PopScope(
      canPop: !_isPanelOpen,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _closeDetailPanel();
      },
      child: SafeArea(
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
          body: Stack(
            children: [
              maplibre.MapLibreMap(
                key: ValueKey(mapStyleProvider.isSatelliteMode),
                initialCameraPosition: _lastCameraPosition ?? maplibre.CameraPosition(target: maplibre.LatLng(initialLat, initialLng), zoom: initialZoom),
                styleString: mapStyleProvider.getStyle(Theme.of(context).brightness),
                minMaxZoomPreference: const maplibre.MinMaxZoomPreference(null, _kMaxMapZoom),
                compassEnabled: false,
                trackCameraPosition: true,
                myLocationEnabled: _myLocationEnabled,
                onUserLocationUpdated: (userLocation) {
                  _userLocation = userLocation.position;
                  if (!_centerOnUserWhenLocated) return;
                  _centerOnUserWhenLocated = false;
                  _animateCamera(maplibre.CameraUpdate.newLatLngZoom(userLocation.position, 16.0));
                },
                onCameraMoveStarted: (reason) {
                  // 只有手勢才算使用者的 zoom；fit-all、跟車、開場還原都是程式動的。
                  // 手勢打斷動畫時，動畫就算結束，後續的移動由使用者作主。
                  if (reason == maplibre.CameraMoveReason.gesture) {
                    _userOwnsZoom = true;
                    _isCameraAnimating = false;
                    _cameraAnimationGraceTimer?.cancel();
                  }
                },
                onCameraMove: (position) {
                  _lastCameraPosition = position;
                  // 動畫途中的 zoom 不是終點，等它停下再記，免得存到一半的倍率。
                  if (_userOwnsZoom && !_isCameraAnimating) _scheduleViewMemorySave();

                  if (_isCameraAnimating) return;

                  if (_isFollowingDevice) {
                    _safeSetState(() {
                      _isFollowingDevice = false;
                    });
                    _showReturnToFollowBadge();
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

                  if (_appliedBottomInset > 0) {
                    controller.updateContentInsets(EdgeInsets.only(bottom: _appliedBottomInset));
                  }

                  _mapController!.onSymbolTapped.add((symbol) {
                    _lastSymbolTapAt = DateTime.now();
                    final deviceIdString = symbol.data?['deviceId'];
                    final deviceId = int.tryParse(deviceIdString ?? '');

                    if (deviceId != null && mounted) {
                      final traccarProvider = context.read<TraccarProvider>();
                      _handleDeviceMarkerTap(deviceId, traccarProvider);
                    }
                  });
                },
                onMapClick: (point, latLng) {
                  final lastSymbolTap = _lastSymbolTapAt;
                  if (lastSymbolTap != null && DateTime.now().difference(lastSymbolTap) < _kSymbolTapGuard) {
                    return;
                  }
                  if (_isFollowingDevice) {
                    _safeSetState(() {
                      _isFollowingDevice = false;
                    });
                  }
                  if (_bottomSheetController != null) {
                    _bottomSheetController!.close();
                    _bottomSheetController = null;
                  }
                },
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + _kEdgeInset,
                right: _kEdgeInset,
                child: _GlassSurface(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 圖層切換保留（空照圖看地形很實用）；指北針與自動縮放屬進階操作，簡易模式收起來。
                      _GlassIconButton(icon: mapStyleProvider.isSatelliteMode ? Icons.satellite_alt : Icons.map, label: 'mapLayerToggle'.tr, isActive: mapStyleProvider.isSatelliteMode, onTap: () => _toggleMapType(mapStyleProvider)),
                      const _GlassDivider(),
                      if (!simpleMode) ...[_GlassIconButton(icon: Icons.explore_rounded, label: 'mapCompass'.tr, onTap: () => _animateCamera(maplibre.CameraUpdate.bearingTo(0))), const _GlassDivider()],
                      KeyedSubtree(
                        key: _helperFollowKey,
                        child: _GlassIconButton(icon: _isFollowingDevice ? Icons.my_location_rounded : Icons.location_searching_rounded, label: 'mapFollowDevice'.tr, isActive: _isFollowingDevice, haptic: true, onTap: _toggleFollowCurrentDevice),
                      ),
                      const _GlassDivider(),
                      if (!simpleMode) ...[
                        KeyedSubtree(
                          key: _helperFitAllKey,
                          child: _GlassIconButton(icon: Icons.zoom_out_map_rounded, label: 'mapFitAll'.tr, onTap: () => _zoomToFitAll(context.read<TraccarProvider>())),
                        ),
                        const _GlassDivider(),
                      ],
                      KeyedSubtree(
                        key: _helperListKey,
                        child: _GlassIconButton(icon: CupertinoIcons.list_bullet, label: 'deviceTitle'.tr, onTap: () => _showDevicePicker(context.read<TraccarProvider>())),
                      ),
                      const _GlassDivider(),
                      _GlassIconButton(icon: Icons.help_outline_rounded, label: 'mapHelperReplay'.tr, onTap: _startMapHelper),
                    ],
                  ),
                ),
              ),
              Consumer<TraccarProvider>(
                builder: (context, provider, _) {
                  if (provider.positions.isEmpty && !provider.isLoading) {
                    return Positioned(
                      top: 96,
                      left: 24,
                      right: 72,
                      child: IgnorePointer(
                        child: GlassContainer(
                          shape: const LiquidRoundedSuperellipse(borderRadius: 16),
                          quality: GlassQuality.standard,
                          platformViewBackdrop: true,
                          settings: mapGlassSettings(context),
                          padding: const EdgeInsets.all(16),
                          child: EmptyState(icon: Icons.location_off_outlined, title: 'mapNoPositions'.tr, hint: 'mapNoPositionsHint'.tr),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              if (_isStyleLoaded)
                Consumer<TraccarProvider>(
                  builder: (context, provider, _) => _DataUpdateListener(
                    data: Object.hash(provider.positionsRevision, provider.devicesRevision),
                    onUpdate: () {
                      _syncSelectedDeviceFromProvider(provider);
                      _scheduleMarkerUpdate(provider);
                    },
                  ),
                ),
              if (!_isPanelOpen)
                // The bar shows device names, a position within the list and
                // follow state. A position packet changes none of that, so key
                // the rebuild on that key set instead of on every notify, or the
                // glass surface behind it recomposites several times a second.
                Selector<TraccarProvider, int>(
                  selector: (_, provider) {
                    final List<api.Device> navigable = _navigableDevices(provider);
                    return Object.hash(Object.hashAll(navigable.map((device) => '${device.id}:${device.name}')), _currentDevice?.id);
                  },
                  builder: (context, _, child) =>
                      Positioned(left: _kEdgeInset, right: _kEdgeInset, bottom: MediaQuery.of(context).padding.bottom + _kControlGap, child: _buildBottomControls(context.read<TraccarProvider>(), _currentDevice, withHelperKeys: true)),
                ),
              if (_showReturnToFollow && _currentDevice != null)
                Positioned(
                  left: _kEdgeInset,
                  bottom: MediaQuery.of(context).padding.bottom + 72,
                  child: GestureDetector(
                    onTap: () {
                      _clearReturnToFollowBadge();
                      _toggleFollowCurrentDevice();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.my_location_rounded, size: 16, color: Theme.of(context).colorScheme.onPrimary),
                          const SizedBox(width: 6),
                          Text(
                            'followReturn'.tr,
                            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ],
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

class _GlassSurface extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const _GlassSurface({required this.child, this.borderRadius = _kControlRadius, this.padding});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12), // 柔和的陰影顏色
            blurRadius: 12, // 陰影擴散範圍
            offset: const Offset(0, 4), // 向下微微偏移
          ),
        ],
      ),
      child: GlassContainer(
        padding: padding,
        shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
        quality: GlassQuality.standard,
        platformViewBackdrop: true,
        settings: mapGlassSettings(context),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

class _GlassDivider extends StatelessWidget {
  const _GlassDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: _kControlSize * 0.6, height: 0.5, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6));
  }
}

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
    final bool reduce = reduceMotionOf(context);

    return Semantics(
      button: true,
      label: widget.label,
      child: InkWell(
        onTap: widget.onTap == null
            ? null
            : () {
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
            scale: reduce ? 1.0 : (_pressed ? 0.92 : 1.0),
            duration: reduce ? Duration.zero : const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: AnimatedContainer(
                duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
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

class _DeviceSwitcherBar extends StatefulWidget {
  final String? deviceName;
  final int index;
  final int total;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

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
    final bool reduce = reduceMotionOf(context);

    return _GlassSurface(
      borderRadius: _kPillRadius,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GlassIconButton(icon: isRtlOf(context) ? Icons.chevron_right_rounded : Icons.chevron_left_rounded, label: 'devicePrevious'.tr, haptic: true, onTap: widget.onPrevious),
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
                  scale: reduce ? 1.0 : (_platePressed ? 0.94 : 1.0),
                  duration: reduce ? Duration.zero : const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.deviceName ?? 'deviceUnknown'.tr,
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
          _GlassIconButton(icon: isRtlOf(context) ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, label: 'deviceNext'.tr, haptic: true, onTap: widget.onNext),
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onUpdate();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// 改進：直接輸出完整 8 位數 ARGB 十六進位碼（#AARRGGBB），完美支援 MapLibre 軌跡透明度渲染
String _toHexColor(Color color) => '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';

/// 線上／離線等狀態的顏色只在這裡定義，車輛清單與其他清單都用它。
Color _statusColorOf(BuildContext context, String? status) {
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
      return Theme.of(context).colorScheme.onSurface;
  }
}

/// 地圖頁唯一的車輛清單：搜尋、常用優先、點一列就跳到那台車。
///
/// 這也是螢幕閱讀器的路徑——地圖上的標記是原生 symbol，本身沒有語意。
class _DevicePickerSheet extends StatefulWidget {
  const _DevicePickerSheet({required this.provider, required this.onSelected});

  final TraccarProvider provider;
  final ValueChanged<api.Device> onSelected;

  @override
  State<_DevicePickerSheet> createState() => _DevicePickerSheetState();
}

class _DevicePickerSheetState extends State<_DevicePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final String query = _searchController.text.trim().toLowerCase();
      if (query == _query) return;
      setState(() => _query = query);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<api.Device> _devices() {
    final List<api.Device> devices = widget.provider.devices.where((device) {
      if (_query.isEmpty) return true;
      final String name = (device.name ?? '').toLowerCase();
      final String uniqueId = (device.uniqueId ?? '').toLowerCase();
      return name.contains(_query) || uniqueId.contains(_query) || (device.id ?? '').toString().contains(_query);
    }).toList();

    devices.sort((a, b) {
      final bool aFavorite = a.id != null && widget.provider.isFavorite(a.id!);
      final bool bFavorite = b.id != null && widget.provider.isFavorite(b.id!);
      if (aFavorite != bFavorite) return aFavorite ? -1 : 1;
      return (a.name ?? '').compareTo(b.name ?? '');
    });
    return devices;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime now = DateTime.now().toUtc();
    final List<api.Device> devices = _devices();

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text('deviceTitle'.tr, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'sharedSearchDevices'.tr,
                    prefixIcon: const Icon(CupertinoIcons.search),
                    suffixIcon: _query.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'sharedCancel'.tr, onPressed: () => _searchController.clear()),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: devices.isEmpty
                    ? Center(
                        child: Padding(padding: const EdgeInsets.all(24), child: Text('sharedNoData'.tr)),
                      )
                    : ListView(children: [for (final device in devices) _buildTile(context, device, now)]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, api.Device device, DateTime now) {
    final api.Position? position = device.id == null ? null : widget.provider.getPosition(device.id!);
    final String status = resolveDeviceStatus(device, position, now);
    final double speedKmh = (position?.speed ?? 0.0) * 1.852;
    final String statusLabel = switch (status) {
      'online' => 'deviceStatusOnline'.tr,
      'offline' => 'deviceStatusOffline'.tr,
      _ => 'deviceStatusUnknown'.tr,
    };
    final String name = device.name ?? 'deviceUnknown'.tr;

    return Semantics(
      button: true,
      label: '$name, $statusLabel, ${speedKmh.toStringAsFixed(0)} ${'sharedKmh'.tr}',
      child: ListTile(
        leading: Icon(CupertinoIcons.car_fill, color: _statusColorOf(context, status)),
        title: Text(name),
        subtitle: Text('$statusLabel · ${speedKmh.toStringAsFixed(0)} ${'sharedKmh'.tr}'),
        onTap: () => widget.onSelected(device),
      ),
    );
  }
}
