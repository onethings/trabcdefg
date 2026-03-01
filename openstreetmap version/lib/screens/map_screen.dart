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

import '../services/tile_cache_service.dart';
import '../services/marker_icon_service.dart';
import '../widgets/device_detail_panel.dart';

// --- End of Imports ---

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
  final TileCacheService _cacheService = TileCacheService();
  late MarkerIconService _iconService;
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
  late HiveTileProvider _tileProvider;
  bool _isCacheInitialized =
      false; // State to track cache/provider initialization

  @override
  void initState() {
    super.initState();
    // Preference loading moved to provider
    // Initialize cache service and then the tile provider
    _iconService = MarkerIconService(loadedIcons: _loadedIcons);
    _cacheService.init().then((_) {
      _tileProvider = HiveTileProvider(
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
    await _iconService.ensureIconLoaded(_mapController, iconKey);
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

    // 清除舊標記以避免重複
    await _mapController!.clearSymbols();

    for (final device in provider.devices) {
      final pos = _findPositionOrNull(provider.positions, device.id);
      if (pos == null || pos.latitude == null) continue;

      final String category = device.category ?? 'default';
      final String status = device.status ?? 'unknown';
      final String baseIconKey =
          'marker_${category.toLowerCase()}_${status.toLowerCase()}';

      final String plate = device.name ?? '';
      final String customIconId = "${baseIconKey}_$plate";

      // 修正：傳入 _mapController
      await _ensureCustomIconLoaded(baseIconKey, plate, customIconId);

      await _mapController!.addSymbol(
        maplibre.SymbolOptions(
          geometry: maplibre.LatLng(
            pos.latitude!.toDouble(),
            pos.longitude!.toDouble(),
          ),
          iconImage: customIconId,
          iconRotate: pos.course?.toDouble() ?? 0.0,
          iconSize: 3, // 調整：從 1.0 增加到 1.5 以提升辨識度
          iconAnchor: 'center',
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
    await _iconService.ensureCustomIconLoaded(
      _mapController,
      baseIconKey,
      plate,
      customIconId,
    );
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

    // 2. 由於 Traccar 伺服器通常不帶地址，直接嘗試從 Hive 快取中同步獲取 (避免閃爍 Loading...)
    String? immediateAddress;

    if (position.latitude != null && position.longitude != null) {
      // 嘗試從 Hive 快取中同步獲取 (1毫秒內)
      immediateAddress = OfflineAddressService.getAddressFromCache(
        position.latitude!.toDouble(),
        position.longitude!.toDouble(),
      );
    }

    // 更新狀態
    setState(() {
      _currentAddress = immediateAddress ?? "Loading...";
    });

    // 3. 立即顯示面板 (以最快速度渲染)
    _showDeviceDetailPanel(device, position);

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

      // 4. 如果快取沒有命中，才發起異步地址查詢
      if (immediateAddress == null) {
        try {
          String addr = await OfflineAddressService.getAddress(
            position.latitude!.toDouble(),
            position.longitude!.toDouble(),
          );

          if (mounted) {
             setState(() {
               _currentAddress = addr;
             });
             _showDeviceDetailPanel(device, position);
          }
        } catch (e) {
          debugPrint("Geocoder error: $e");
          if (mounted) {
            setState(() => _currentAddress = "Location: ${position.latitude!.toStringAsFixed(4)}, ${position.longitude!.toStringAsFixed(4)}");
            _showDeviceDetailPanel(device, position);
          }
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _currentAddress = "No GPS Signal";
        });
        _showDeviceDetailPanel(device, position);
      }
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

    _bottomSheetController = _scaffoldKey.currentState!.showBottomSheet((context) {
      final position = Provider.of<TraccarProvider>(context, listen: false)
          .positions
          .firstWhere((p) => p.deviceId == device.id, orElse: () => api.Position());

      return DeviceDetailPanel(
        device: device,
        position: position,
        address: _currentAddress,
        formattedDate: _formatDate(position.fixTime),
        onMoreOptionsPressed: () => _showMoreOptionsDialog(device, position),
        onDeletePressed: () {
          _bottomSheetController?.close();
          _showDeleteConfirmationDialog(device);
        },
        onRefresh: () async {
          final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
          await traccarProvider.fetchInitialData();
        },
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
                // 修正：移除 Builder hack，改用 addPostFrameCallback 處理反應式更新
                if (_isStyleLoaded)
                  _DataUpdateListener(
                    data: traccarProvider.positions,
                    onUpdate: () => _updateAllMarkers(traccarProvider),
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

// 輔助組件：監聽數據變化並觸發回呼，規避 build phase 副作用
class _DataUpdateListener extends StatefulWidget {
  final List<api.Position> data;
  final VoidCallback onUpdate;

  const _DataUpdateListener({required this.data, required this.onUpdate});

  @override
  _DataUpdateListenerState createState() => _DataUpdateListenerState();
}

class _DataUpdateListenerState extends State<_DataUpdateListener> {
  @override
  void didUpdateWidget(_DataUpdateListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果數據發生變化（這裏簡化比較），則觸發更新
    if (widget.data != oldWidget.data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onUpdate();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onUpdate();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
