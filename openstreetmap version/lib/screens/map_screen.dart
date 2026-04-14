import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
// import 'package:flutter_map/flutter_map.dart'; // Primary map package for OpenStreetMap
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:flutter_map/flutter_map.dart' hide LatLng, LatLngBounds;
import 'package:latlong2/latlong.dart'
    as latlong; // LatLong for FlutterMap coordinates
// ALIAS: Required for Satellite view, Marker, BitmapDescriptor - REMOVED: google_maps_flutter is gone
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/providers/settings_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
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
import 'package:trabcdefg/screens/settings/geofences_screen.dart'
    hide AppMapType;
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

class MapScreen extends StatefulWidget {
  final api.Device? selectedDevice;

  const MapScreen({super.key, this.selectedDevice});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  Key _mapKey = UniqueKey();
  bool _isSatelliteMode = false;

  static const String _satelliteStyle = "assets/styles/aws-hybrid.json";

  static const String _brightStyle = "assets/styles/streets-v4.json";

  // 1. Positron (簡潔淺色模式) - 非常適合用來凸顯彩色車輛圖標

  maplibre.MapLibreMapController? _mapController;
  maplibre.CameraPosition? _lastCameraPosition;
  bool _isStyleLoaded = false;
  bool _hasInitialZoomed = false;
  final Set<String> _loadedIcons = {};
  // REMOVED: final Map<String, gmap.BitmapDescriptor> _markerIcons = {};
  bool _markersLoaded = false;
  // MapType moved to provider
  MapController flutterMapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  api.Device? _currentDevice;
  double _currentZoom = 16.0;
  final TileCacheService _cacheService = TileCacheService();
  late MarkerIconService _iconService;
  final http.Client _httpClient = http.Client();
  bool _isControlsExpanded = true;
  bool _showGeofences = true;
  final String _controlsExpandedKey = 'isMapControlsExpanded';
  double _mapCenterOffset = 0.001;
  // final OfflineGeocoder _geocoder = OfflineGeocoder();
  bool _isPanelOpen = false;
  bool _isFollowingDevice = false;
  String _currentAddress = "";

  // Reactive notifiers for seamless detail panel updates
  final ValueNotifier<api.Device?> _selectedDeviceNotifier = ValueNotifier(null);
  final ValueNotifier<api.Position?> _selectedPositionNotifier = ValueNotifier(null);
  final ValueNotifier<String> _selectedAddressNotifier = ValueNotifier("");

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
    WidgetsBinding.instance.addObserver(this);

    // Initial preference loading from Hive
    _loadUIPreferences();
    // Initialize cache service and then the tile provider
    _iconService = MarkerIconService(loadedIcons: _loadedIcons);
    _cacheService.init().then((_) {
      _tileProvider = HiveTileProvider(
        cacheService: _cacheService,
        httpClient: _httpClient,
      );
      
      // OPTIMIZATION: Warm up OfflineAddressService early on map screen arrival
      OfflineAddressService.initDatabase();

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
    } else {
      _loadLastSelectedDevice();
    }
  }

  Future<void> _loadLastSelectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDeviceId = prefs.getInt('selectedDeviceId');
    final lastZoom = prefs.getDouble('map_zoom_level');
    
    if (lastZoom != null) {
      _currentZoom = lastZoom;
    }

    if (lastDeviceId != null) {
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

  void _loadUIPreferences() {
    final box = Hive.box('ui_settings');
    setState(() {
      _isControlsExpanded = box.get(_controlsExpandedKey, defaultValue: false);
    });
  }

  void _toggleMapControls() {
    setState(() {
      _isControlsExpanded = !_isControlsExpanded;
    });
    Hive.box('ui_settings').put(_controlsExpandedKey, _isControlsExpanded);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _httpClient.close();
    _selectedDeviceNotifier.dispose();
    _selectedPositionNotifier.dispose();
    _selectedAddressNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        // Capture current camera position before rebuilding to preserve view
        if (_mapController != null) {
          _lastCameraPosition = _mapController!.cameraPosition;
        }

        setState(() {
          _mapKey = UniqueKey(); // Force MapLibre GL to re-create to prevent blank screen
        });
        
        // Refresh data to ensure WebSocket connection and session are alive
        final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
        traccarProvider.fetchInitialData().catchError((error) {
           debugPrint("Session validation failed on resume: $error");
           if (mounted) {
             Get.offAllNamed('/login'); 
           }
        });
      }
    }
  }

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

  void _onStyleLoaded() async {
    setState(() {
      _isStyleLoaded = true;
    });
    _loadedIcons.clear();
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    await _mapController!.setSymbolIconAllowOverlap(true);
    await _mapController!.setSymbolIconIgnorePlacement(true);
    await _mapController!.setSymbolTextAllowOverlap(true);
    await _mapController!.setSymbolTextIgnorePlacement(true);
    
    await _updateAllMarkers(traccarProvider);

    // Auto zoom to fit all markers if no specific device was requested on load
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
      // Handle edge case where there is only one position or bounds are too small
      if ((maxLat - minLat).abs() < 0.0001 && (maxLng - minLng).abs() < 0.0001) {
        _mapController!.animateCamera(
          maplibre.CameraUpdate.newLatLngZoom(
            maplibre.LatLng(minLat, minLng),
            14.0, // Default zoom for single marker
          ),
        );
      } else {
        _mapController!.animateCamera(
          maplibre.CameraUpdate.newLatLngBounds(
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
  }

  Future<void> _updateAllMarkers(TraccarProvider provider) async {
    if (_mapController == null || !_isStyleLoaded) return;

    // Smart Auto-Follow: 只有在啟用跟隨且有選中車輛時才自動移動相機
    if (_currentDevice != null && _isFollowingDevice) {
      final currentPos = provider.positions.firstWhereOrNull((p) => p.deviceId == _currentDevice!.id);
      if (currentPos != null && currentPos.latitude != null && currentPos.longitude != null) {
        _mapController?.animateCamera(
          maplibre.CameraUpdate.newLatLng(
            maplibre.LatLng(
              currentPos.latitude!.toDouble(),
              currentPos.longitude!.toDouble(),
            ),
          ),
        );
      }
    }

    await _mapController!.clearSymbols();

    for (final device in provider.devices) {
      final pos = _findPositionOrNull(provider.positions, device.id);
      if (pos == null || pos.latitude == null) continue;

      final String category = device.category ?? 'default';
      final String status = device.status ?? 'unknown';
      final String baseIconKey =
          'marker_${category.toLowerCase()}_${status.toLowerCase()}';

      final String plate = device.name ?? '';
      final String customLabelId = "label_$plate";

      // 1. 確保基礎圖標已加載
      await _iconService.ensureIconLoaded(_mapController, baseIconKey);
      
      // 2. 確保獨立車牌標籤已加載 (帶有白色窄背景)
      await _iconService.ensureLabelIconLoaded(_mapController, plate, customLabelId);

      final latLng = maplibre.LatLng(
        pos.latitude!.toDouble(),
        pos.longitude!.toDouble(),
      );

      final deviceData = {'deviceId': device.id.toString()};

      // 3. 添加車輛符號 (會旋轉)
      await _mapController!.addSymbol(
        maplibre.SymbolOptions(
          geometry: latLng,
          iconImage: baseIconKey,
          iconRotate: pos.course?.toDouble() ?? 0.0,
          // 大幅增加車輛圖標尺寸倍率 (從 3.0 -> 4.0)，確保比標籤大且清晰
          iconSize: 4.0 * context.read<SettingsProvider>().markerSizeScale,
          iconAnchor: 'center',
          zIndex: 10,
        ),
        deviceData,
      );

      // 4. 添加標籤符號 (始終垂直，不旋轉)
      await _mapController!.addSymbol(
        maplibre.SymbolOptions(
          geometry: latLng,
          iconImage: customLabelId,
          iconRotate: 0.0,
          // 縮小偏移量 (從 26 -> 15) 讓車牌更靠近車體，增加整體感
          iconOffset: const Offset(0, 15), 
          iconSize: 1.2, // 配合 18 號字體
          iconAnchor: 'top', 
          zIndex: 5,
        ),
        deviceData,
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
      await devicesApi.devicesIdDelete(deviceId);

      _bottomSheetController?.close();

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
    int currentIndex = devices.indexWhere((d) => d.id == _currentDevice?.id);
    int nextIndex = (currentIndex + direction) % devices.length;
    if (nextIndex < 0) nextIndex = devices.length - 1;

    final nextDevice = devices[nextIndex];
    setState(() {
      _currentDevice = nextDevice;
      _isFollowingDevice = true; // Enable follow mode on navigation
    });

    _onDeviceSelected(nextDevice, positions, forceShowPanel: false);
  }

  void _onDeviceSelected(
    api.Device device,
    List<api.Position> allPositions, {
    bool forceShowPanel = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedDeviceId', device.id!);
    await prefs.setString('selectedDeviceName', device.name!);

    final position = allPositions.firstWhere(
      (p) => p.deviceId == device.id,
      orElse: () =>
          api.Position(deviceId: device.id, latitude: 0.0, longitude: 0.0),
    );

    String? immediateAddress;

    if (position.latitude != null && position.longitude != null) {
      immediateAddress = OfflineAddressService.getAddressFromCache(
        position.latitude!.toDouble(),
        position.longitude!.toDouble(),
      );
    }
    setState(() {
      _currentAddress = immediateAddress ?? "Loading...";
    });

    // Update reactive notifiers
    _selectedDeviceNotifier.value = device;
    _selectedPositionNotifier.value = position;
    _selectedAddressNotifier.value = immediateAddress ?? "Loading...";

    if (forceShowPanel) {
      _isFollowingDevice = true; // Enable follow mode on explicit map interaction (marker tap)
    }

    // Only show panel if forced (tap) or already open (habit)
    if (forceShowPanel || _isPanelOpen) {
      _showDeviceDetailPanel(device, position);
    }

    if (device.id != null) {
      Provider.of<TraccarProvider>(
        context,
        listen: false,
      ).prefetchDeviceHistory(device.id!);
    }

    if (position.latitude != null &&
        position.longitude != null &&
        position.latitude != 0.0) {
      
      _mapController!.animateCamera(
        maplibre.CameraUpdate.newLatLng(
          maplibre.LatLng(
            position.latitude!.toDouble(),
            position.longitude!.toDouble(),
          ),
        ),
      );

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
            _selectedAddressNotifier.value = addr;
            
            if (forceShowPanel || _isPanelOpen) {
              _showDeviceDetailPanel(device, position);
            }
          }
        } catch (e) {
          debugPrint("Geocoder error: $e");
          if (mounted) {
            setState(
              () => _currentAddress =
                  "Location: ${position.latitude!.toStringAsFixed(4)}, ${position.longitude!.toStringAsFixed(4)}",
            );
            _showDeviceDetailPanel(device, position);
          }
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _currentAddress = "No GPS Signal";
        });
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
    // If panel is already open, the ValueNotifiers will update the content reactively.
    // We only need to call showBottomSheet if it's currently closed.
    if (_isPanelOpen && _bottomSheetController != null) {
      return; 
    }

    _isPanelOpen = true;
    _bottomSheetController = _scaffoldKey.currentState!.showBottomSheet((
      context,
    ) {
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
                  
                  return DeviceDetailPanel(
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
                      final traccarProvider = Provider.of<TraccarProvider>(
                        context,
                        listen: false,
                      );
                      await traccarProvider.fetchInitialData();
                    },
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
          _isPanelOpen = false;
        });
      }
    });
  }

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
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'trabcdefg',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  traccarProvider.currentUser?.email ?? 'Logged in user'.tr,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Device List
          Expanded(
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
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
                      if (double.parse(speed) > 0.0) Text('$speed km/h'),
                      const SizedBox(width: 12),

                      Icon(
                        Icons.key,
                        color: isIgnitionOn ? Colors.green : Colors.red,
                        size: 16,
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).pop();

                    if (position != null) {
                      _onDeviceSelected(
                        device, 
                        traccarProvider.positions,
                        forceShowPanel: true,
                      );
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
        if (traccarProvider.isLoading && traccarProvider.devices.isEmpty) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!_isCacheInitialized) {
          return const Scaffold(
            body: Center(child: Text('Initializing Map Assets...')),
          );
        }

        final flutterMarkers = <Marker>{};

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
              final latlong.LatLng flutterMarkerPosition = _toFlutterLatLng(
                position.latitude!.toDouble(),
                position.longitude!.toDouble(),
              );

              final String category = device.category ?? 'default';
              final String status = device.status ?? 'unknown';
              final double course = position.course?.toDouble() ?? 0.0;

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

        if (_currentDevice != null) {
          final initialPosition = _findPositionOrNull(
            traccarProvider.positions,
            _currentDevice!.id,
          );

          if (initialPosition?.latitude != null &&
              initialPosition?.longitude != null) {
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
            initialFlutterLatLng = latlong.LatLng(
              firstPosition.latitude!.toDouble(),
              firstPosition.longitude!.toDouble(),
            );
            initialZoom = 5.0;
          }
        }

        return SafeArea(
          top: false,
          child: Scaffold(
            extendBodyBehindAppBar: true,
            key: _scaffoldKey,
            appBar: AppBar(
              // 1. 基本背景設為透明
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,

              // 2. 移除 title 屬性
              title: null,

              // 3. 移除之前的毛玻璃與顏色填充，改為 null 或空的實體
              flexibleSpace: null,

              // 4. 確保圖標顏色在您的背景上清晰可見
              iconTheme: IconThemeData(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),

            drawer: _buildDeviceListDrawer(context, traccarProvider),
            body: Stack(
              children: [
                Listener(
                  onPointerDown: (_) {
                    if (_isFollowingDevice) {
                      setState(() {
                        _isFollowingDevice = false;
                      });
                      debugPrint("Smart Auto-Follow disabled by user gesture");
                    }
                  },
                  child: maplibre.MapLibreMap(
                    key: _mapKey,
                  initialCameraPosition: _lastCameraPosition ?? maplibre.CameraPosition(
                    target: maplibre.LatLng(
                      initialFlutterLatLng.latitude,
                      initialFlutterLatLng.longitude,
                    ),
                    zoom: initialZoom,
                  ),
                  styleString: Provider.of<MapStyleProvider>(
                    context,
                  ).styleString,
                  onCameraMove: (position) {
                    _currentZoom = position.zoom;
                    SharedPreferences.getInstance().then((prefs) {
                      prefs.setDouble('map_zoom_level', position.zoom);
                    });
                  },
                  onStyleLoadedCallback: _onStyleLoaded,
                  onMapCreated: (controller) {
                    _mapController = controller;

                    // Map style is strictly controlled by explicit user toggle now
                    // (Bright or Satellite only)

                    _mapController!.onSymbolTapped.add((symbol) {
                      final deviceIdString = symbol.data?['deviceId'];
                      final deviceId = int.tryParse(deviceIdString ?? '');

                      if (deviceId != null) {
                        final traccarProvider = Provider.of<TraccarProvider>(
                          context,
                          listen: false,
                        );
                        _onDeviceSelected(
                          traccarProvider.devices.firstWhere(
                            (d) => d.id == deviceId,
                          ),
                          traccarProvider.positions,
                          forceShowPanel: true,
                        );
                      }
                    });
                  },
                  onMapClick: (point, latLng) {
                    // Hide the detail panel when clicking on the map (empty space)
                    if (_bottomSheetController != null) {
                      _bottomSheetController!.close();
                      _bottomSheetController = null;
                      _isFollowingDevice = false; // Stop following on empty map click
                    }
                  },
                ),
              ),

                // Map Controls (Right Side)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 70, // Avoid overlap with AppBar hit area
                  right: 16,
                  child: Column(
                    children: [
                      // Toggle Button (Hive Persisted)
                      _buildMapControl(
                        _isControlsExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        _toggleMapControls,
                        "btn_expand_toggle",
                        isActive: _isControlsExpanded,
                        isToggle: true,
                      ),
                      const SizedBox(height: 12),

                      // Primary Controls
                      _buildMapControl(
                        Icons.explore_rounded,
                        () => _mapController?.animateCamera(
                          maplibre.CameraUpdate.bearingTo(0),
                        ),
                        "btn_compass",
                      ),
                      const SizedBox(height: 12),
                      _buildMapControl(Icons.my_location_rounded, () {
                        if (_currentDevice != null) {
                          final pos = traccarProvider.getPosition(
                            _currentDevice!.id!,
                          );
                          if (pos != null)
                            _onDeviceSelected(
                              _currentDevice!,
                              traccarProvider.positions,
                              forceShowPanel: true,
                            );
                        }
                      }, "btn_myloc"),
                      const SizedBox(height: 12),
                      _buildMapControl(
                        Icons.zoom_out_map_rounded,
                        () => _zoomToFitAll(traccarProvider),
                        "btn_zoom",
                      ),

                      // Secondary Controls (Collapsible)
                      if (_isControlsExpanded) ...[
                        const SizedBox(height: 12),
                        _buildMapControl(
                          _showGeofences
                              ? Icons.layers_rounded
                              : Icons.layers_outlined,
                          () =>
                              setState(() => _showGeofences = !_showGeofences),
                          "btn_geofence",
                          isActive: _showGeofences,
                        ),
                        const SizedBox(height: 12),
                        _buildMapControl(
                          Provider.of<MapStyleProvider>(context).isSatelliteMode
                              ? Icons.map
                              : Icons.satellite_alt,
                          () => Provider.of<MapStyleProvider>(
                            context,
                            listen: false,
                          ).toggleMapType(),
                          "btn_style",
                        ),
                        const SizedBox(height: 12),
                        _buildMapControl(
                          Icons.arrow_upward_rounded,
                          () => _navigateToDevice(
                            -1,
                            traccarProvider.devices,
                            traccarProvider.positions,
                          ),
                          "btn_prev",
                        ),
                        const SizedBox(height: 12),
                        _buildMapControl(
                          Icons.arrow_downward_rounded,
                          () => _navigateToDevice(
                            1,
                            traccarProvider.devices,
                            traccarProvider.positions,
                          ),
                          "btn_next",
                        ),
                      ],
                    ],
                  ),
                ),

                if (_isStyleLoaded)
                  _DataUpdateListener(
                    data: traccarProvider.positions,
                    onUpdate: () => _updateAllMarkers(traccarProvider),
                  ),

                if (traccarProvider.isLoading &&
                    traccarProvider.devices.isEmpty)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapControl(
    IconData icon,
    VoidCallback onTap,
    String heroTag, {
    bool isActive = false,
    bool isToggle = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary.withOpacity(0.85)
                : (isDark
                    ? Colors.black.withOpacity(0.4)
                    : Colors.white.withOpacity(0.7)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              width: 0.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              splashColor: colorScheme.primary.withOpacity(0.1),
              highlightColor: colorScheme.primary.withOpacity(0.05),
              child: Center(
                child: Hero(
                  tag: heroTag,
                  child: Icon(
                    icon,
                    color: isActive
                        ? colorScheme.onPrimary
                        : (isDark ? Colors.white70 : Colors.black87),
                    size: isToggle ? 24 : 20,
                  ),
                ),
              ),
            ),
          ),
        ),
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
