import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart'; // Primary map package for OpenStreetMap
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:flutter_map/flutter_map.dart' hide LatLng, LatLngBounds;
import 'package:latlong2/latlong.dart'
    as latlong; // LatLong for FlutterMap coordinates
// ALIAS: Required for Satellite view, Marker, BitmapDescriptor - REMOVED: google_maps_flutter is gone
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
// import 'package:trabcdefg/src/generated_api/model/device_extensions.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'monthly_mileage_screen.dart';
import 'device_list_screen.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'device_details_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trabcdefg/screens/settings/geofences_screen.dart' hide AppMapType;
import 'package:trabcdefg/constants.dart';
import 'dart:io';
import 'share_device_screen.dart';
import 'command_screen.dart';
import 'package:trabcdefg/screens/settings/devices_screen.dart';
import 'package:trabcdefg/screens/settings/add_device_screen.dart';
import 'dart:math'; // Required for math operations like pi/radians in marker rotation
import 'package:hive/hive.dart';
import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart'; // Ensure this is imported for TileProvider
import 'package:flutter/foundation.dart'; // Required for DiagnosticsProperty
import 'package:trabcdefg/widgets/OfflineAddressService.dart';
import 'package:trabcdefg/providers/map_style_provider.dart';

// --- Tile Caching Implementation using Hive ---

class _TileCacheService {
  late Box<Uint8List> _tileBox;
  static const String boxName = 'mapTilesCache';

  Future<void> init() async {
    // Open the Hive box for storing map tiles.
    _tileBox = await Hive.openBox<Uint8List>(boxName);
  }

  // Generate a unique key for the tile URL to use in Hive.
  String _generateKey(String url) {
    return url.hashCode.toString();
  }

  Future<Uint8List?> getTile(String url) async {
    // Try to retrieve the tile from the local cache.
    return _tileBox.get(_generateKey(url));
  }

  Future<void> saveTile(String url, Uint8List tileData) async {
    // Save the tile data to the local cache.
    await _tileBox.put(_generateKey(url), tileData);
  }
}

// Custom TileProvider to integrate Hive caching with FlutterMap
class _HiveTileProvider extends TileProvider {
  final _TileCacheService cacheService;
  final http.Client httpClient;

  _HiveTileProvider({required this.cacheService, required this.httpClient});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    // This is the key method to load the image. We return a FutureProvider.
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      cacheService: cacheService,
      httpClient: httpClient,
    );
  }
}

// Custom ImageProvider to handle the cache/network logic
class CachedNetworkImageProvider
    extends ImageProvider<CachedNetworkImageProvider> {
  final String url;
  final _TileCacheService cacheService;
  final http.Client httpClient;

  CachedNetworkImageProvider(
    this.url, {
    required this.cacheService,
    required this.httpClient,
  });

  @override
  ImageStreamCompleter loadImage(
    CachedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<CachedNetworkImageProvider>('Original key', key),
      ],
    );
  }

  // Corrected obtainKey signature
  @override
  Future<CachedNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    // FIXED: Corrected the type name from CachedNetworkProvider to CachedNetworkImageProvider
    return Future<CachedNetworkImageProvider>.value(this);
  }

  Future<ui.Codec> _loadAsync(
    CachedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    assert(key == this);

    // 1. Check Cache
    final cachedData = await cacheService.getTile(url);

    if (cachedData != null) {
      // Load from cache
      return decode(await ImmutableBuffer.fromUint8List(cachedData));
    }

    // 2. Fetch from Network
    try {
      final response = await httpClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;

        // 3. Save to Cache
        await cacheService.saveTile(url, bytes);

        // Load from fetched bytes
        return decode(await ImmutableBuffer.fromUint8List(bytes));
      } else {
        // Fallback or error handling for network failure
        throw Exception(
          'Failed to load tile from network: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Fallback or error handling for any other failure
      rethrow;
    }
  }
}

// --- End of Tile Caching Implementation ---

// ADDED: Enum for managing map types
// REMOVED local AppMapType to use provider's version

class MapScreen extends StatefulWidget {
  final api.Device? selectedDevice;

  const MapScreen({super.key, this.selectedDevice});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _isSatelliteMode = false;
  // 街道模式：直接使用 URL (確保伺服器有提供 glyphs 屬性)
  // 街道模式：手動組合 JSON，確保包含字體路徑
  // 街道模式：直接使用 URL。Liberty 樣式通常已經內嵌了 glyphs 設定
  static const String _satelliteStyle = "assets/styles/aws-hybrid.json";

  static const String _streetStyle =
      "assets/styles/liberty.json";
  static const String _brightStyle = "assets/styles/aws-standard.json";

  // 1. Positron (簡潔淺色模式) - 非常適合用來凸顯彩色車輛圖標
  static const String _positronStyle =
      "assets/styles/positron-gl-style.json";

  // 2. Dark Matter (酷炫深色模式) - 適合夜間使用
  static const String _darkStyle = "assets/styles/dark.json";

  // 3. Google Maps 2026 (Local)
  static const String _osmBrightStyle = "assets/styles/gmap.json";

  // 4. Terrain (地形等高線模式) - 使用 OpenFreeMap 提供的地形樣式
  static const String _terrainStyle =
      "assets/styles/fiord.json";

  // 5. Google Maps 混合風格 (混合衛星與路網) - 透過自定義 JSON 實作
  static const String _hybridStyle =
      "assets/styles/positron.json";
  maplibre.MapLibreMapController? _mapController;
  bool _isStyleLoaded = false;
  final Set<String> _loadedIcons = {};
  // REMOVED: final Map<String, gmap.BitmapDescriptor> _markerIcons = {};
  bool _markersLoaded = false;
  // MapType moved to provider
  MapController flutterMapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  api.Device? _currentDevice;
  final _TileCacheService _cacheService = _TileCacheService();
  final http.Client _httpClient = http.Client();
  // Adjust 0.005 based on how tall your bottom sheet is
  double _mapCenterOffset = 0.001;
  // final OfflineGeocoder _geocoder = OfflineGeocoder();
  String _currentAddress = "";

  String _getStyleString(AppMapType type) {
    switch (type) {
      case AppMapType.bright:
        return _brightStyle;
      case AppMapType.satellite:
        return _satelliteStyle;
      default:
        return _brightStyle;
    }
  }

  // --- Tile URLs for different map types ---
  static const String _osmUrlTemplate =
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _satelliteUrlTemplate =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const List<String> _osmSubdomains = ['a', 'b', 'c'];

  // Custom Tile Provider
  late _HiveTileProvider _tileProvider;
  bool _isCacheInitialized =
      false; // State to track cache/provider initialization

  @override
  void initState() {
    super.initState();
    // Preference loading moved to provider
    // Initialize cache service and then the tile provider
    _cacheService.init().then((_) {
      _tileProvider = _HiveTileProvider(
        cacheService: _cacheService,
        httpClient: _httpClient,
      );
      if (mounted) {
        setState(() {
          _isCacheInitialized =
              true; // Set flag when initialization is complete
        });
      }
    });

    _loadMarkerIcons();
    _currentDevice = widget.selectedDevice;

    if (_currentDevice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Your logic for initial state handling
      });
    }
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  void _applyAutoTheme() {
    final hour = DateTime.now().hour;
    if (hour >= 18 || hour <= 6) {
      _updateMapStyle(AppMapType.dark);
    } else {
      _updateMapStyle(AppMapType.bright);
    }
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getStatusColor(status).withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: _getStatusColor(status),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Preference loading moved to provider

  void _updateMapStyle(AppMapType type) async {
    final styleProvider = Provider.of<MapStyleProvider>(context, listen: false);
    await styleProvider.setMapType(type);

    setState(() {
      _isStyleLoaded = false;
      _isSatelliteMode = (type == AppMapType.satellite);
    });

    try {
      _mapController?.setStyle(styleProvider.styleString);
    } catch (e) {
      debugPrint("setStyle failed: $e");
    }
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

    // 在 _zoomToFitAll 方法中修正
    if (minLat != null && maxLat != null && minLng != null && maxLng != null) {
      _mapController!.animateCamera(
        maplibre.CameraUpdate.newLatLngBounds(
          // 修正：明確指定使用 MapLibre 的定義
          maplibre.LatLngBounds(
            southwest: maplibre.LatLng(minLat, minLng),
            northeast: maplibre.LatLng(maxLat, maxLng),
          ),
          left: 50,
          right: 50,
          top: 100,
          bottom: 100,
        ),
      );
    }
  }

  // Add this inside _MapScreenState
  Future<void> _ensureIconLoaded(String iconKey) async {
    if (_mapController == null || _loadedIcons.contains(iconKey)) return;

    try {
      final String assetPath = 'assets/images/$iconKey.png';
      final ByteData bytes = await rootBundle.load(assetPath);
      final Uint8List list = bytes.buffer.asUint8List();

      await _mapController!.addImage(iconKey, list);
      _loadedIcons.add(iconKey);

      // Small delay to ensure the engine registers the new sprite
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      debugPrint("❌ Failed to load icon '$iconKey': $e");
      if (iconKey != 'marker_default_unknown') {
        await _ensureIconLoaded('marker_default_unknown');
      }
    }
  }

  // void _updateAllMarkers(TraccarProvider provider) async {
  //   if (_mapController == null || !_isStyleLoaded) return;

  //   await _mapController!.clearSymbols();

  //   for (final device in provider.devices) {
  //     final pos = _findPositionOrNull(provider.positions, device.id);
  //     if (pos == null || pos.latitude == null) continue;

  //     final String category = device.category ?? 'default';
  //     final String status = device.status ?? 'unknown';
  //     final String iconKey =
  //         'marker_${category.toLowerCase()}_${status.toLowerCase()}';

  //     await _ensureIconLoaded(iconKey);
  //     await _mapController!.addSymbol(
  //       SymbolOptions(
  //         geometry: LatLng(pos.latitude!.toDouble(), pos.longitude!.toDouble()),
  //         iconImage: _loadedIcons.contains(iconKey)
  //             ? iconKey
  //             : 'marker_default_unknown',
  //         iconRotate: pos.course?.toDouble() ?? 0.0,
  //         iconSize: 3.0,
  //         iconAnchor: iconKey.endsWith('_online')
  //             ? 'bottom'
  //             : 'center', // Different anchor for online vs offline
  //         // --- 顯示車牌 ---
  //         fontNames: ['Noto Sans Regular', 'Arial Unicode MS Regular'],
  //         // 顯示車牌
  //         textField: device.name ?? '',
  //         textOffset: const Offset(0, 2.5),
  //         textSize: 12.0,
  //         textColor: '#000000',
  //         textHaloColor: '#FFFFFF',
  //         textHaloWidth: 2.0,
  //       ),
  //       // DATA goes here (Outside SymbolOptions)
  //       {'deviceId': device.id.toString()},
  //     );
  //   }
  // }
  void _updateAllMarkers(TraccarProvider provider) async {
    if (_mapController == null || !_isStyleLoaded) return;

    for (final device in provider.devices) {
      final pos = _findPositionOrNull(provider.positions, device.id);
      if (pos == null || pos.latitude == null) continue;

      final String category = device.category ?? 'default';
      final String status = device.status ?? 'unknown';
      final String baseIconKey =
          'marker_${category.toLowerCase()}_${status.toLowerCase()}';

      // 唯一的圖標 ID，例如：marker_car_online_ABC-1234
      final String plate = device.name ?? '';
      final String customIconId = "${baseIconKey}_$plate";

      // 使用自定義方法合成並加載圖標
      await _ensureCustomIconLoaded(baseIconKey, plate, customIconId);

      await _mapController!.addSymbol(
        maplibre.SymbolOptions(
          geometry: maplibre.LatLng(
            pos.latitude!.toDouble(),
            pos.longitude!.toDouble(),
          ),
          iconImage: customIconId, // 使用合成後的圖片
          iconRotate: pos.course?.toDouble() ?? 0.0,
          iconSize: 3.0, // 因為合成圖較大，size 可以設為 1.0
        ),
        {'deviceId': device.id.toString()},
      );
    }
  }

  Future<void> _ensureCustomIconLoaded(
    String baseIconKey,
    String plate,
    String customIconId,
  ) async {
    if (_loadedIcons.contains(customIconId)) return;

    try {
      // 1. 加載原始圖標
      final ByteData data = await rootBundle.load(
        'assets/images/$baseIconKey.png',
      );
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      final ui.Image markerImage = fi.image;

      // 2. 準備文字繪製器 (TextPainter)
      final textPainter = TextPainter(
        text: TextSpan(
          text: plate,
          style: TextStyle(
            color: Colors.black,
            fontSize: 8.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'Noto Sans Myanmar',
            backgroundColor: Colors.white.withOpacity(0.0), // 文字背景 //0.85
          ),
        ),
        // 修正點：使用 ui.TextDirection.ltr 確保編譯通過
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();

      // 3. 建立畫布並繪製
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();

      // 計算畫布總尺寸：寬度取圖標或文字的最大值，高度為圖標+文字+間距
      final double canvasWidth = markerImage.width > textPainter.width
          ? markerImage.width.toDouble()
          : textPainter.width;
      final double canvasHeight = markerImage.height + textPainter.height + 10;

      // A. 畫車輛圖標 (置中)
      final double markerX = (canvasWidth - markerImage.width) / 2;
      canvas.drawImage(markerImage, Offset(markerX, 0), paint);

      // B. 畫車牌文字 (置中，放在車圖下方 5 像素處)
      final double textX = (canvasWidth - textPainter.width) / 2;
      textPainter.paint(
        canvas,
        Offset(textX, markerImage.height.toDouble() + 5),
      );

      // 4. 轉換為圖片格式
      final picture = recorder.endRecording();
      final img = await picture.toImage(
        canvasWidth.toInt(),
        canvasHeight.toInt(),
      );
      final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

      if (pngBytes != null) {
        // 5. 註冊到 MapLibre 引擎
        await _mapController!.addImage(
          customIconId,
          pngBytes.buffer.asUint8List(),
        );
        _loadedIcons.add(customIconId);
      }
    } catch (e) {
      debugPrint("❌ 合成圖標錯誤 ($customIconId): $e");
    }
  }

  // Simplified _loadMarkerIcons: now just sets _markersLoaded
  Future<void> _loadMarkerIcons() async {
    await Future.delayed(Duration.zero);

    if (mounted) {
      setState(() {
        _markersLoaded = true;
      });
    }
  }

  PersistentBottomSheetController? _bottomSheetController;
  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat.yMd().add_Hms().format(date.toLocal());
  }

  Future<void> _showDeleteConfirmationDialog(api.Device device) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Device'.tr),
          content: Text(
            'Are you sure you want to delete the device "${device.name}"?'.tr,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'.tr),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text(
                'Delete'.tr,
                style: const TextStyle(color: Colors.red),
              ),
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
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final devicesApi = api.DevicesApi(traccarProvider.apiClient);

    try {
      // API Call: DELETE /devices/{id}
      await devicesApi.devicesIdDelete(deviceId);

      _bottomSheetController?.close();

      // Refresh the devices list and update the UI (using existing provider method)
      await traccarProvider.fetchInitialData();

      Get.snackbar(
        'Success'.tr,
        'Device deleted successfully.'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
      );
    } on api.ApiException catch (e) {
      Get.snackbar(
        'Error'.tr,
        'Failed to delete device: ${e.message}'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    } catch (e) {
      Get.snackbar(
        'Error'.tr,
        'An unknown error occurred.'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
      );
    }
  }

  latlong.LatLng _toFlutterLatLng(double latitude, double longitude) {
    return latlong.LatLng(latitude, longitude);
  }

  void _navigateToDevice(
    int direction,
    List<api.Device> devices,
    List<api.Position> positions,
  ) {
    if (devices.isEmpty) return;

    // 1. 找到當前選中設備的索引
    int currentIndex = devices.indexWhere((d) => d.id == _currentDevice?.id);

    // 2. 計算下一個索引（循環切換）
    int nextIndex = (currentIndex + direction) % devices.length;
    if (nextIndex < 0) nextIndex = devices.length - 1;

    final nextDevice = devices[nextIndex];

    // 3. 更新當前狀態並導航
    setState(() {
      _currentDevice = nextDevice;
    });

    _onDeviceSelected(nextDevice, positions);
  }

  void _onDeviceSelected(
    api.Device device,
    List<api.Position> allPositions,
  ) async {
    // 1. 基本資料準備
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedDeviceId', device.id!);
    await prefs.setString('selectedDeviceName', device.name!);

    final position = allPositions.firstWhere(
      (p) => p.deviceId == device.id,
      orElse: () =>
          api.Position(deviceId: device.id, latitude: 0.0, longitude: 0.0),
    );

    // 2. 立即顯示面板 (不要等地址查詢)
    // 這樣使用者點擊後面板會立刻跳出來，地址顯示 "Loading..."
    _showDeviceDetailPanel(device, position);

    // 3. 重置地址狀態並開始相機動畫
    setState(() {
      _currentAddress = "Loading...";
    });

    if (position.latitude != null &&
        position.longitude != null &&
        position.latitude != 0.0) {
      // 異步移動相機
      _mapController!.animateCamera(
        maplibre.CameraUpdate.newCameraPosition(
          maplibre.CameraPosition(
            target: maplibre.LatLng(
              position.latitude!.toDouble() - _mapCenterOffset,
              position.longitude!.toDouble(),
            ),
            zoom: 16.0,
          ),
        ),
      );

      // 4. 異步獲取地址 (在背景執行)
      try {
        String addr = await OfflineAddressService.getAddress(
          position.latitude!.toDouble(),
          position.longitude!.toDouble(),
        );

        if (mounted) {
          setState(() {
            _currentAddress = addr;
          });
          // 關鍵：地址更新後，重新刷一次面板內容（或確保面板內部的 Consumer/Provider 會自動刷新）
          _showDeviceDetailPanel(device, position);
        }
      } catch (e) {
        debugPrint("Geocoder error: $e");
        if (mounted) {
          setState(() => _currentAddress = "Address Unavailable");
          _showDeviceDetailPanel(device, position);
        }
      }
    } else {
      setState(() {
        _currentAddress = "No GPS Signal";
      });
      _showDeviceDetailPanel(device, position); // 也要刷新面板顯示此訊息
    }
  }

  Color _getBatteryColor(double batteryLevel) {
    if (batteryLevel > 75) {
      return Colors.green;
    } else if (batteryLevel > 25) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Future<void> _launchUrl(Uri url) async {
    if (!await launchUrl(url)) {
      throw 'Could not launch $url';
    }
  }

  void _showMoreOptionsDialog(
    api.Device device,
    api.Position? currentPosition,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(device.name ?? 'More Options'.tr),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                ListTile(
                  title: Text('sharedCreateGeofence'.tr),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddGeofenceScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  title: Text('linkGoogleMaps'.tr),
                  onTap: () {
                    Navigator.of(context).pop();
                    if (currentPosition?.latitude != null &&
                        currentPosition?.longitude != null) {
                      // FIXED: Added .toDouble() to cast nullable num to non-nullable double inside the string interpolation.
                      final url = Uri.parse(
                        'https://maps.google.com/maps?q=${currentPosition!.latitude!.toDouble()},${currentPosition.longitude!.toDouble()}',
                      );
                      _launchUrl(url);
                    }
                  },
                ),
                ListTile(
                  title: Text('linkAppleMaps'.tr),
                  onTap: () {
                    Navigator.of(context).pop();
                    if (currentPosition?.latitude != null &&
                        currentPosition?.longitude != null) {
                      // FIXED: Added .toDouble()
                      final url = Uri.parse(
                        'https://maps.apple.com/?q=${currentPosition!.latitude!.toDouble()},${currentPosition.longitude!.toDouble()}',
                      );
                      _launchUrl(url);
                    }
                  },
                ),
                ListTile(
                  title: Text('linkStreetView'.tr),
                  onTap: () {
                    Navigator.of(context).pop();
                    if (currentPosition?.latitude != null &&
                        currentPosition?.longitude != null) {
                      // FIXED: Added .toDouble()
                      final url = Uri.parse(
                        'google.streetview:cbll=${currentPosition!.latitude!.toDouble()},${currentPosition.longitude!.toDouble()}',
                      );
                      _launchUrl(url);
                    }
                  },
                ),
                ListTile(
                  title: Text('deviceShare'.tr),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('sharedDeviceId', device.id!);
                    await prefs.setString('sharedDeviceName', device.name!);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ShareDeviceScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeviceDetailPanel(
    api.Device device,
    api.Position? currentPosition,
  ) {
    _bottomSheetController?.close();

    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );

    _bottomSheetController = _scaffoldKey.currentState!.showBottomSheet((
      context,
    ) {
      final currentPosition =
          Provider.of<TraccarProvider>(
            context,
            listen: false,
          ).positions.firstWhere(
            (p) => p.deviceId == device.id,
            orElse: () => api.Position(),
          );

      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95), // 增加一點透明感
            borderRadius: BorderRadius.circular(28.0), // 更圓潤的角，視覺更柔和
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Device Name and Status
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          device.name ?? 'Unknown Device'.tr,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.info,
                            color: Color(0xFF5B697B),
                          ),
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setInt('selectedDeviceId', device.id!);
                            await prefs.setString(
                              'selectedDeviceName',
                              device.name!,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const DeviceDetailsScreen(),
                              ),
                            );
                            print('Info button tapped!');
                          },
                        ),
                        if ((currentPosition.attributes
                                    as Map<String, dynamic>?)?['distance'] !=
                                null &&
                            ((currentPosition.attributes
                                        as Map<String, dynamic>)['distance']
                                    as double) >
                                0.0)
                          Text(
                            '${((currentPosition.attributes as Map<String, dynamic>)['distance'] as double).toStringAsFixed(0)} ' +
                                'sharedKm'.tr, //2
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        //Speed
                        if (currentPosition.speed != null &&
                            currentPosition.speed != 0.0)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: Text(
                              '${currentPosition.speed?.toStringAsFixed(0)}' +
                                  ' ' +
                                  'km/h',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        // Ignition Icon
                        if ((currentPosition.attributes
                                as Map<String, dynamic>?)?['ignition'] !=
                            null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: Icon(
                              Icons.key,
                              color:
                                  (currentPosition.attributes
                                          as Map<
                                            String,
                                            dynamic
                                          >?)?['ignition'] ==
                                      true
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        // Battery Icon with Percentage
                        if ((currentPosition.attributes
                                as Map<String, dynamic>?)?['batteryLevel'] !=
                            null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.battery_full,
                                  color: _getBatteryColor(
                                    ((currentPosition.attributes
                                                as Map<
                                                  String,
                                                  dynamic
                                                >)['batteryLevel']
                                            as int)
                                        .toDouble(), // Cast to double
                                  ),
                                ),
                                Text(
                                  '${(currentPosition.attributes as Map<String, dynamic>)['batteryLevel']}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              //Road Name Start
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.red[400]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      // 如果查到的是 Myanmar Road，顯示為 "Myanmar (Road info unavailable)" 比較專業
                      _currentAddress == "Myanmar Road"
                          ? "Myanmar (Street name unlisted)"
                          : _currentAddress,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey[800],
                        fontStyle: _currentAddress == "Myanmar Road"
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              //Road Name End
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    _buildDetailsPanel(
                      fixTime: _formatDate(currentPosition.fixTime),
                      address:
                          (currentPosition.attributes
                              as Map<String, dynamic>?)?['address'] ??
                          'N/A',
                      totalDistance:
                          (currentPosition.attributes
                                  as Map<String, dynamic>?)?['totalDistance'] !=
                              null
                          ? '${((currentPosition.attributes as Map<String, dynamic>)['totalDistance'] / 1000).toStringAsFixed(0)} ${'sharedKm'.tr}'
                          : 'N/A',
                    ),
                    _buildReportPanel(
                      onRefreshPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt('selectedDeviceId', device.id!);
                        await prefs.setString(
                          'selectedDeviceName',
                          device.name!,
                        );
                        _bottomSheetController?.close();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MonthlyMileageScreen(),
                          ),
                        );
                      },
                      onMoreOptionsPressed: () =>
                          _showMoreOptionsDialog(device, currentPosition),
                      onUploadPressed: () async {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CommandScreen(),
                          ),
                        );
                      },
                      onEditPressed: () async {
                        _bottomSheetController?.close();

                        final updatedDevice = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AddDeviceScreen(device: device),
                          ),
                        );

                        if (updatedDevice != null) {
                          await traccarProvider.fetchInitialData();
                        }
                      },
                      onDeletePressed: () {
                        _bottomSheetController?.close();
                        _showDeleteConfirmationDialog(device);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // Widget to build the details panel (unchanged)
  Widget _buildDetailsPanel({
    required String fixTime,
    required String address,
    required String totalDistance,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fix Time Row
        Row(
          children: [
            // const Icon(Icons.access_time, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              'deviceLastUpdate'.tr + ':',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text(fixTime),
          ],
        ),
        const SizedBox(height: 1),

        // Address Row
        if (address != 'N/A')
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(child: Text(address)),
            ],
          ),
        const SizedBox(height: 1),

        // Total Distance Row
        Row(
          children: [
            // const Icon(Icons.directions_car, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              'deviceTotalDistance'.tr + ':',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text(totalDistance),
          ],
        ),
        const SizedBox(height: 1), // Separator before the report panel
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, TraccarProvider traccarProvider) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'trabcdefg',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Display current user email/login if available
                Text(
                  traccarProvider.currentUser?.email ?? 'Logged in user'.tr,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.devices),
            title: Text('Devices'.tr),
            onTap: () {
              Navigator.of(context).pop(); // Close the drawer
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const DeviceListScreen(), // Use existing DeviceListScreen
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.fence),
            title: Text('Geofences'.tr),
            onTap: () {
              Navigator.of(context).pop(); // Close the drawer
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const GeofencesScreen(), // Use existing GeofencesScreen
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text('Settings'.tr),
            onTap: () {
              Navigator.of(context).pop(); // Close the drawer
              Get.snackbar('Coming Soon'.tr, 'Settings screen placeholder');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text('Logout'.tr, style: const TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.of(context).pop(); // Close the drawer
              // await traccarProvider.clearSession();
            },
          ),
        ],
      ),
    );
  }

  // Widget to build the report and history panel
  Widget _buildReportPanel({
    required VoidCallback onRefreshPressed,
    required VoidCallback onMoreOptionsPressed,
    required VoidCallback onUploadPressed,
    required VoidCallback onEditPressed,
    required VoidCallback onDeletePressed,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        // More options icon
        IconButton(
          icon: const Icon(Icons.more_horiz, color: Color(0xFF5B697B)),
          onPressed: onMoreOptionsPressed,
        ),
        // Route icon
        IconButton(
          icon: const Icon(Icons.route, color: Color(0xFF5B697B)),
          onPressed: onRefreshPressed,
        ),
        // Upload icon
        IconButton(
          icon: const Icon(
            Icons.cloud_upload_outlined,
            color: Color(0xFF246BFD),
          ),
          onPressed: onUploadPressed,
        ),
        // Edit icon
        IconButton(
          icon: const Icon(Icons.edit, color: Color(0xFF5B697B)),
          onPressed: onEditPressed,
        ),
        // Delete icon
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onDeletePressed,
        ),
      ],
    );
  }

  // Helper to safely find a position
  api.Position? _findPositionOrNull(
    List<api.Position> positions,
    int? deviceId,
  ) {
    if (deviceId == null) return null;
    try {
      return positions.firstWhere((p) => p.deviceId == deviceId);
    } catch (_) {
      return null;
    }
  }

  // Helper method to get status color
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

  Widget _buildDeviceListDrawer(
    BuildContext context,
    TraccarProvider traccarProvider,
  ) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'trabcdefg',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  traccarProvider.currentUser?.email ?? 'Logged in user'.tr,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          // Device List
          Expanded(
            child: ListView.builder(
              itemCount: traccarProvider.devices.length,
              itemBuilder: (context, index) {
                final device = traccarProvider.devices[index];
                final position = _findPositionOrNull(
                  traccarProvider.positions,
                  device.id,
                );

                // Get status details
                final speed = (position?.speed ?? 0.0).toStringAsFixed(1);
                final isIgnitionOn =
                    (position?.attributes
                        as Map<String, dynamic>?)?['ignition'] ==
                    true;

                return ListTile(
                  leading: Icon(
                    Icons.circle,
                    color: _getStatusColor(
                      device.status,
                    ), // Online/Offline status
                    size: 10,
                  ),
                  title: Text(
                    device.name ?? 'Unknown Device'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Row(
                    children: [
                      // Speed
                      if (double.parse(speed) > 0.0) Text('$speed km/h'),
                      const SizedBox(width: 12),
                      // Ignition Status
                      Icon(
                        Icons.key,
                        color: isIgnitionOn ? Colors.green : Colors.red,
                        size: 16,
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // 1. Close the drawer
                    Navigator.of(context).pop();
                    // 2. Call the existing method to select the device, focus the map, and show the detail panel
                    if (position != null) {
                      _onDeviceSelected(device, traccarProvider.positions);
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
    return Consumer<TraccarProvider>(
      builder: (context, traccarProvider, child) {
        // 1. Handle Loading State
        if (traccarProvider.isLoading && traccarProvider.devices.isEmpty) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Wait for Tile Provider to initialize
        if (!_isCacheInitialized) {
          return const Scaffold(
            body: Center(child: Text('Initializing Map Assets...')),
          );
        }

        // 3. Prepare Markers
        final flutterMarkers = <Marker>{};

        // 4. Determine Initial Camera Position
        latlong.LatLng initialFlutterLatLng = latlong.LatLng(0, 0);
        double initialZoom = 2.0;

        if (_markersLoaded) {
          for (final api.Device device in traccarProvider.devices) {
            final api.Position? position = _findPositionOrNull(
              traccarProvider.positions,
              device.id,
            );

            if (position != null &&
                position.latitude != null &&
                position.longitude != null) {
              // FIXED: Added .toDouble() to cast num to double
              final latlong.LatLng flutterMarkerPosition = _toFlutterLatLng(
                position.latitude!.toDouble(),
                position.longitude!.toDouble(),
              );

              final String category = device.category ?? 'default';
              final String status = device.status ?? 'unknown';
              final double course = position.course?.toDouble() ?? 0.0;

              // Flutter Map Marker (RETAINED/MODIFIED)
              flutterMarkers.add(
                Marker(
                  width: 50.0,
                  height: 50.0,
                  point: flutterMarkerPosition,
                  child: Transform.rotate(
                    angle: course * (pi / 180),
                    child: GestureDetector(
                      onTap: () {
                        _onDeviceSelected(device, traccarProvider.positions);
                      },
                      child: Image.asset(
                        'assets/images/marker_${category}_$status.png',
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.location_on),
                      ),
                    ),
                  ),
                ),
              );
            }
          }
        }

        // 5. Determine Initial Camera Position (Updated for FlutterMap only)
        if (_currentDevice != null) {
          final initialPosition = _findPositionOrNull(
            traccarProvider.positions,
            _currentDevice!.id,
          );

          if (initialPosition?.latitude != null &&
              initialPosition?.longitude != null) {
            // FIXED: Added .toDouble() to cast num to double
            initialFlutterLatLng = latlong.LatLng(
              initialPosition!.latitude!.toDouble(),
              initialPosition.longitude!.toDouble(),
            );
            initialZoom = 15.0;
          }
        } else if (traccarProvider.positions.isNotEmpty) {
          final api.Position firstPosition = traccarProvider.positions.first;
          if (firstPosition.latitude != null &&
              firstPosition.longitude != null) {
            // FIXED: Added .toDouble() to cast num to double
            initialFlutterLatLng = latlong.LatLng(
              firstPosition.latitude!.toDouble(),
              firstPosition.longitude!.toDouble(),
            );
            initialZoom = 5.0;
          }
        }

        // 6. Build the Scaffold and Map
        return SafeArea(
          top:
              false, // Set to false if you want the map to bleed into the status bar area
          child: Scaffold(
            extendBodyBehindAppBar: true,
            key: _scaffoldKey,
            appBar: AppBar(
              //    title: Text('mapTitle'.tr),
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
            ),
            // The Drawer
            drawer: _buildDeviceListDrawer(context, traccarProvider),
            body: Stack(
              children: [
                maplibre.MapLibreMap(
                  // key: ValueKey(_isSatelliteMode),
                  key: ValueKey(Provider.of<MapStyleProvider>(context).mapType),
                  initialCameraPosition: maplibre.CameraPosition(
                    target: maplibre.LatLng(
                      initialFlutterLatLng.latitude,
                      initialFlutterLatLng.longitude,
                    ),
                    zoom: initialZoom,
                  ),
                  // styleString: _isSatelliteMode ? _satelliteStyle : _streetStyle,
                  styleString: Provider.of<MapStyleProvider>(context).styleString,
                  onMapCreated: (controller) {
                    _mapController = controller;

                    // This listener acts as your "InfoWindow"
                    _mapController!.onSymbolTapped.add((symbol) {
                      final deviceIdString = symbol.data?['deviceId'];
                      final deviceId = int.tryParse(deviceIdString ?? '');

                      if (deviceId != null) {
                        final traccarProvider = Provider.of<TraccarProvider>(
                          context,
                          listen: false,
                        );

                        // Find the specific device and its last position
                        final device = traccarProvider.devices.firstWhere(
                          (d) => d.id == deviceId,
                        );
                        final pos = traccarProvider.positions.firstWhere(
                          (p) => p.deviceId == deviceId,
                        );

                        // 1. Show your detail panel (This is your InfoWindow)
                        _showDeviceDetailPanel(device, pos);
                        _onDeviceSelected(device, traccarProvider.positions);

                        // 2. Center the camera on the device with the offset
                        _mapController!.animateCamera(
                          // CameraUpdate.newLatLng(
                          //   LatLng(
                          //     pos.latitude!.toDouble() - _mapCenterOffset,
                          //     pos.longitude!.toDouble(),
                          //   ),
                          // ),
                          maplibre.CameraUpdate.newCameraPosition(
                            maplibre.CameraPosition(
                              target: maplibre.LatLng(
                                pos.latitude!.toDouble() -
                                    _mapCenterOffset, // 您的垂直偏移量
                                pos.longitude!.toDouble(),
                              ),
                              zoom: 16.0, // 在這裡設定縮放等級
                            ),
                          ),
                        );
                      }
                    });
                  },
                  onStyleLoadedCallback: () {
                    setState(() => _isStyleLoaded = true);
                    _loadedIcons.clear();
                    _updateAllMarkers(traccarProvider);

                    // --- 新增：如果是初次進入且沒有選定特定設備，則顯示全部 ---
                    if (widget.selectedDevice == null) {
                      // 延遲一點點確保標記都已計算完成
                      Future.delayed(const Duration(milliseconds: 500), () {
                        _zoomToFitAll(traccarProvider);
                      });
                    }
                  },
                ),
                // 在 Stack 的 children 中
                Positioned(
                  top: 60,
                  right: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Map Style Selection (Floating Action Button)
                      FloatingActionButton.small(
                        heroTag: "map_layers",
                        backgroundColor: Colors.white,
                        child: const Icon(
                          Icons.layers_outlined,
                          color: Colors.blueGrey,
                        ),
                        onPressed: () {
                          _showMapTypeSelector();
                        },
                      ),
                      const SizedBox(height: 8),
                      // 1. 顯示全部按鈕
                      FloatingActionButton.small(
                        heroTag: "zoom_all",
                        backgroundColor: Colors.white,
                        onPressed: () => _zoomToFitAll(traccarProvider),
                        child: const Icon(
                          Icons.zoom_out_map,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 只有在多台車時才顯示切換按鈕
                      if (traccarProvider.devices.length > 1) ...[
                        // 2. 上一台按鈕
                        FloatingActionButton.small(
                          heroTag: "prev_car",
                          backgroundColor: Colors.white,
                          onPressed: () => _navigateToDevice(
                            -1,
                            traccarProvider.devices,
                            traccarProvider.positions,
                          ),
                          child: const Icon(
                            Icons.arrow_upward,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 3. 下一台按鈕
                        FloatingActionButton.small(
                          heroTag: "next_car",
                          backgroundColor: Colors.white,
                          onPressed: () => _navigateToDevice(
                            1,
                            traccarProvider.devices,
                            traccarProvider.positions,
                          ),
                          child: const Icon(
                            Icons.arrow_downward,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMapTypeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Select Map Style'.tr,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildMapTypeItem(
                      AppMapType.bright,
                      'Standard', // Aws Standard renamed to Standard for clarity
                      Icons.map_outlined,
                    ),
                    _buildMapTypeItem(
                      AppMapType.liberty,
                      'Liberty',
                      Icons.streetview_outlined,
                    ),
                    _buildMapTypeItem(
                      AppMapType.dark,
                      'Dark Mode',
                      Icons.dark_mode_outlined,
                    ),
                    _buildMapTypeItem(
                      AppMapType.terrain,
                      'Fiord/Terrain',
                      Icons.terrain_outlined,
                    ),
                    _buildMapTypeItem(
                      AppMapType.satellite,
                      'Satellite', // Aws Satellite renamed to Satellite for clarity
                      Icons.satellite_alt_outlined,
                    ),
                    _buildMapTypeItem(
                      AppMapType.hybrid,
                      'Positron',
                      Icons.layers_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapTypeItem(AppMapType type, String label, IconData icon) {
    final styleProvider = Provider.of<MapStyleProvider>(context);
    final isSelected = styleProvider.mapType == type;
    return GestureDetector(
      onTap: () {
        _updateMapStyle(type);
        Navigator.pop(context);
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[200]!,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? Colors.blue : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              label.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
