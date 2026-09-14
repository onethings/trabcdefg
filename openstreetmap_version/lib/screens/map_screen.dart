import 'dart:async';
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
import 'package:trabcdefg/src/generated_api/api.dart' as api;
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
const Duration _kSymbolTapGuard = Duration(milliseconds: 300); // marker 點擊防誤判窗口
const Duration _kCameraEventGrace = Duration(milliseconds: 250); // 相機事件滯後寬限

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  api.Device? _currentDevice;
  final TileCacheService _cacheService = TileCacheService();
  late MarkerIconService _iconService;
  final http.Client _httpClient = http.Client();

  final ValueNotifier<bool> _panelOpenNotifier = ValueNotifier(false);
  bool get _isPanelOpen => _panelOpenNotifier.value;
  bool _isFollowingDevice = false;

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

  bool _isCacheInitialized = false;
  Timer? _zoomDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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
              if (mounted) {
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
    // 樣式重建後舊 controller 的 symbol 已失效，必須清掉增量狀態
    _deviceSymbols.clear();
    _labelSymbols.clear();

    if (!mounted) return;
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    await _mapController!.setSymbolIconAllowOverlap(true);
    await _mapController!.setSymbolIconIgnorePlacement(true);
    await _mapController!.setSymbolTextAllowOverlap(true);
    await _mapController!.setSymbolTextIgnorePlacement(true);

    await _scheduleMarkerUpdate(traccarProvider);

    if (widget.selectedDevice == null && !_hasInitialZoomed) {
      final prefs = await SharedPreferences.getInstance();
      final lastDeviceId = prefs.getInt('selectedDeviceId');

      if (lastDeviceId != null) {
        final device = traccarProvider.devices.firstWhereOrNull((d) => d.id == lastDeviceId);
        if (device != null) {
          _onDeviceSelected(device, traccarProvider.positions);
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
    _onDeviceSelected(device, traccarProvider.positions, forceShowPanel: true);
  }

  /// 指定裝置在清單中的位置（1-based，找不到時回 1），給切換列顯示「n / N」。
  int _deviceIndexIn(List<api.Device> devices, api.Device? device) {
    final index = devices.indexWhere((d) => d.id == device?.id);
    return index < 0 ? 1 : index + 1;
  }

  /// 底部控制列本體（裝置切換 + 縮放）。
  /// 面板開／關兩條繪製路徑都用這個 builder，所以永遠長得一樣。
  Widget _buildBottomControls(TraccarProvider traccarProvider, api.Device? currentDevice) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: traccarProvider.devices.length > 1
                ? _DeviceSwitcherBar(
                    deviceName: currentDevice?.name,
                    index: _deviceIndexIn(traccarProvider.devices, currentDevice),
                    total: traccarProvider.devices.length,
                    onPrevious: () => _navigateToDevice(-1, traccarProvider.devices, traccarProvider.positions),
                    onNext: () => _navigateToDevice(1, traccarProvider.devices, traccarProvider.positions),
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
      if (pos.latitude == null || pos.longitude == null) continue;
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
    if (_mapController == null || !_isStyleLoaded) return;

    // 💡 優化：在任何 await 異步操作之前，先安全地讀取變數並存為區域變數
    // 這樣可以完美避開「跨異步間隙使用 BuildContext」的 linter 報錯
    final double scale = Provider.of<SettingsProvider>(context, listen: false).markerSizeScale;

    if (_currentDevice != null && _isFollowingDevice) {
      final currentPos = provider.positions.firstWhereOrNull((p) => p.deviceId == _currentDevice!.id);
      if (currentPos != null && currentPos.latitude != null && currentPos.longitude != null) {
        _animateCamera(maplibre.CameraUpdate.newLatLng(maplibre.LatLng(currentPos.latitude!.toDouble(), currentPos.longitude!.toDouble())));
      }
    }

    // 🚀 效能優化：不再「整批清空 + 重畫」所有 marker。
    // 改為「新增 / 原地更新 / 移除」：已有 marker 的設備用 updateSymbol 直接搬移，
    // 避免每次位置更新都重建整個 symbol layer（這是手划地圖時卡頓的主因）。
    final visibleDeviceIds = <int>{};

    for (final device in provider.devices) {
      final pos = _findPositionOrNull(provider.positions, device.id);
      if (pos == null || pos.latitude == null) continue;

      final int? deviceId = device.id;
      if (deviceId == null) continue;
      visibleDeviceIds.add(deviceId);

      final String category = device.category ?? 'default';
      final String status = device.status ?? 'unknown';
      final String baseIconKey = 'marker_${category.toLowerCase()}_${status.toLowerCase()}';

      final String plate = device.name ?? '';
      final String customLabelId = "label_$plate";

      await _iconService.ensureIconLoaded(_mapController, baseIconKey);
      await _iconService.ensureLabelIconLoaded(_mapController, plate, customLabelId);

      final latLng = maplibre.LatLng(pos.latitude!.toDouble(), pos.longitude!.toDouble());
      final deviceData = {'deviceId': deviceId.toString()};

      // 設備圖標：存在就原地更新，不存在才新增
      final iconSymbol = _deviceSymbols[deviceId];
      if (iconSymbol != null) {
        await _mapController!.updateSymbol(iconSymbol, maplibre.SymbolOptions(geometry: latLng, iconImage: baseIconKey, iconRotate: pos.course?.toDouble() ?? 0.0, iconSize: 4.0 * scale, iconAnchor: 'center', zIndex: 10));
      } else {
        _deviceSymbols[deviceId] = await _mapController!.addSymbol(
          maplibre.SymbolOptions(
            geometry: latLng,
            iconImage: baseIconKey,
            iconRotate: pos.course?.toDouble() ?? 0.0,
            iconSize: 4.0 * scale, // 💡 這裡直接使用剛剛存好的 scale 變數
            iconAnchor: 'center',
            zIndex: 10,
          ),
          deviceData,
        );
      }

      // 名稱標籤：同樣「新增或原地更新」
      final labelSymbol = _labelSymbols[deviceId];
      if (labelSymbol != null) {
        await _mapController!.updateSymbol(labelSymbol, maplibre.SymbolOptions(geometry: latLng, iconImage: customLabelId, iconRotate: 0.0, iconOffset: const Offset(0, 15), iconSize: 1.2, iconAnchor: 'top', zIndex: 5));
      } else {
        _labelSymbols[deviceId] = await _mapController!.addSymbol(maplibre.SymbolOptions(geometry: latLng, iconImage: customLabelId, iconRotate: 0.0, iconOffset: const Offset(0, 15), iconSize: 1.2, iconAnchor: 'top', zIndex: 5), deviceData);
      }
    }

    // 清除已經沒有位置資料（或已被移除）的設備 marker
    final staleIds = _deviceSymbols.keys.where((id) => !visibleDeviceIds.contains(id)).toList();
    for (final id in staleIds) {
      final iconSymbol = _deviceSymbols.remove(id);
      if (iconSymbol != null) {
        try {
          await _mapController!.removeSymbol(iconSymbol);
        } catch (_) {}
      }
      final labelSymbol = _labelSymbols.remove(id);
      if (labelSymbol != null) {
        try {
          await _mapController!.removeSymbol(labelSymbol);
        } catch (_) {}
      }
    }
  }

  PersistentBottomSheetController? _bottomSheetController;
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

  void _navigateToDevice(int direction, List<api.Device> devices, List<api.Position> positions) {
    if (devices.isEmpty) return;
    int currentIndex = devices.indexWhere((d) => d.id == _currentDevice?.id);
    int nextIndex = (currentIndex + direction) % devices.length;
    if (nextIndex < 0) nextIndex = devices.length - 1;

    final nextDevice = devices[nextIndex];
    setState(() {
      _currentDevice = nextDevice;
      _isFollowingDevice = true;
    });

    _onDeviceSelected(nextDevice, positions, forceShowPanel: false);
  }

  void _onDeviceSelected(api.Device device, List<api.Position> allPositions, {bool forceShowPanel = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedDeviceId', device.id!);
    await prefs.setString('selectedDeviceName', device.name!);

    final position = allPositions.firstWhere((p) => p.deviceId == device.id, orElse: () => api.Position(deviceId: device.id, latitude: 0.0, longitude: 0.0));

    String? immediateAddress;

    if (position.latitude != null && position.longitude != null) {
      immediateAddress = OfflineAddressService.getAddressFromCache(position.latitude!.toDouble(), position.longitude!.toDouble());
    }

    _selectedDeviceNotifier.value = device;
    _selectedPositionNotifier.value = position;
    _selectedAddressNotifier.value = immediateAddress ?? "Loading...";

    if (forceShowPanel) {
      _isFollowingDevice = true;
    }

    if (forceShowPanel || _isPanelOpen) {
      _showDeviceDetailPanel(device, position);
    }

    if (device.id != null && mounted) {
      Provider.of<TraccarProvider>(context, listen: false).prefetchDeviceHistory(device.id!);
    }

    if (position.latitude != null && position.longitude != null && position.latitude != 0.0) {
      _animateCamera(maplibre.CameraUpdate.newLatLng(maplibre.LatLng(position.latitude!.toDouble(), position.longitude!.toDouble())));

      if (immediateAddress == null) {
        try {
          String addr = await OfflineAddressService.getAddress(position.latitude!.toDouble(), position.longitude!.toDouble());

          if (mounted) {
            _selectedAddressNotifier.value = addr;

            if (forceShowPanel || _isPanelOpen) {
              _showDeviceDetailPanel(device, position);
            }
          }
        } catch (e) {
          debugPrint("Geocoder error: $e");
          if (mounted) {
            _selectedAddressNotifier.value = "Location: ${position.latitude!.toStringAsFixed(4)}, ${position.longitude!.toStringAsFixed(4)}";
            _showDeviceDetailPanel(device, position);
          }
        }
      }
    } else {
      if (mounted) {
        _selectedAddressNotifier.value = "No GPS Signal";
        if (forceShowPanel || _isPanelOpen) {
          _showDeviceDetailPanel(device, position);
        }
      }
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
                      if (currentPosition?.latitude != null && currentPosition?.longitude != null) {
                        final url = Uri.parse('https://maps.google.com/maps?q=${currentPosition!.latitude!.toDouble()},${currentPosition.longitude!.toDouble()}');
                        _launchUrl(url);
                      }
                    },
                  ),
                  ListTile(
                    title: Text('linkAppleMaps'.tr),
                    onTap: () {
                      Navigator.of(context).pop();
                      if (currentPosition?.latitude != null && currentPosition?.longitude != null) {
                        final url = Uri.parse('https://maps.apple.com/?q=${currentPosition!.latitude!.toDouble()},${currentPosition.longitude!.toDouble()}');
                        _launchUrl(url);
                      }
                    },
                  ),
                  ListTile(
                    title: Text('linkStreetView'.tr),
                    onTap: () {
                      Navigator.of(context).pop();
                      if (currentPosition?.latitude != null && currentPosition?.longitude != null) {
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
                  return Consumer<TraccarProvider>(
                    builder: (context, panelProvider, _) => Column(
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
      }
    });
  }

  api.Position? _findPositionOrNull(List<api.Position> positions, int? deviceId) {
    if (deviceId == null) return null;
    try {
      return positions.firstWhere((p) => p.deviceId == deviceId);
    } catch (_) {
      return null;
    }
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
        return Colors.black;
    }
  }

  Widget _buildDeviceListDrawer(BuildContext context, TraccarProvider traccarProvider) {
    final devices = traccarProvider.devices.toList();
    devices.sort((a, b) {
      final aFav = traccarProvider.isFavorite(a.id!);
      final bFav = traccarProvider.isFavorite(b.id!);
      if (aFav && !bFav) return -1;
      if (!aFav && bFav) return 1;
      return 0;
    });

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'trabcdefg',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(traccarProvider.currentUser?.email ?? 'Logged in user'.tr, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8), fontSize: 14)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                final position = _findPositionOrNull(traccarProvider.positions, device.id);

                final speed = (position?.speed ?? 0.0).toStringAsFixed(1);
                final isIgnitionOn = (position?.attributes as Map<String, dynamic>?)?['ignition'] == true;

                return ListTile(
                  leading: Icon(Icons.circle, color: _getStatusColor(device.status), size: 10),
                  title: Text(
                    device.name ?? 'Unknown Device'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Row(
                    children: [
                      if (double.parse(speed) > 0.0) Text('$speed km/h'),
                      const SizedBox(width: 12),
                      Icon(Icons.key, color: isIgnitionOn ? Colors.green : Colors.red, size: 16),
                    ],
                  ),
                  trailing: const Icon(CupertinoIcons.chevron_right),
                  onTap: () {
                    Navigator.of(context).pop();

                    if (position != null) {
                      _onDeviceSelected(device, traccarProvider.positions, forceShowPanel: true);
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
          final initialPosition = _findPositionOrNull(traccarProvider.positions, _currentDevice!.id);

          if (initialPosition?.latitude != null && initialPosition?.longitude != null) {
            initialLat = initialPosition!.latitude!.toDouble();
            initialLng = initialPosition.longitude!.toDouble();
            initialZoom = 15.0;
          }
        } else if (traccarProvider.positions.isNotEmpty) {
          final api.Position firstPosition = traccarProvider.positions.first;
          if (firstPosition.latitude != null && firstPosition.longitude != null) {
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
                  styleString: mapStyleProvider.styleString,
                  compassEnabled: false,
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
                  onStyleLoadedCallback: _onStyleLoaded,
                  onMapCreated: (controller) {
                    _mapController = controller;

                    _mapController!.onSymbolTapped.add((symbol) {
                      // 記下時間：緊接而來的 onMapClick 需要靠它避免把面板關掉
                      _lastSymbolTapAt = DateTime.now();
                      final deviceIdString = symbol.data?['deviceId'];
                      final deviceId = int.tryParse(deviceIdString ?? '');

                      if (deviceId != null && mounted) {
                        final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
                        _onDeviceSelected(traccarProvider.devices.firstWhere((d) => d.id == deviceId), traccarProvider.positions, forceShowPanel: true);
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
                        _GlassIconButton(icon: mapStyleProvider.isSatelliteMode ? Icons.satellite_alt : Icons.map, label: 'mapLayerToggle'.tr, isActive: mapStyleProvider.isSatelliteMode, onTap: () => mapStyleProvider.toggleMapType()),
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
                if (_isStyleLoaded) _DataUpdateListener(data: traccarProvider.positions, onUpdate: () => _scheduleMarkerUpdate(traccarProvider)),
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

/// 裝置快速切換列：單一玻璃膠囊（左箭頭｜裝置名稱 + n/N｜右箭頭）。
/// 原本兩顆獨立按鈕中間留 28px 空白浮在底部，跟明細面板分不出層級；
/// 合併成膠囊後視覺更集中，也能一眼看出「現在在看第幾台」。
class _DeviceSwitcherBar extends StatelessWidget {
  final String? deviceName;
  final int index;
  final int total;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _DeviceSwitcherBar({required this.deviceName, required this.index, required this.total, required this.onPrevious, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return _GlassSurface(
      borderRadius: _kPillRadius,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GlassIconButton(icon: Icons.chevron_left_rounded, label: 'devicePrevious'.tr, haptic: true, onTap: onPrevious),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 92, maxWidth: 132),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  deviceName ?? 'Unknown Device'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textTheme.labelLarge?.copyWith(fontSize: 14, color: colorScheme.onSurface),
                ),
                Text('$index / $total', style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          _GlassIconButton(icon: Icons.chevron_right_rounded, label: 'deviceNext'.tr, haptic: true, onTap: onNext),
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
