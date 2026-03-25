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

class _MapScreenState extends State<MapScreen> {
  bool _isSatelliteMode = false;

  static const String _satelliteStyle = "assets/styles/aws-hybrid.json";

  static const String _brightStyle = "assets/styles/aws-standard.json";

  // 1. Positron (簡潔淺色模式) - 非常適合用來凸顯彩色車輛圖標

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
  bool _showGeofences = true;
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
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    await _updateAllMarkers(traccarProvider);
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

  Future<void> _updateAllMarkers(TraccarProvider provider) async {
    if (_mapController == null || !_isStyleLoaded) return;
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
    });

    _onDeviceSelected(nextDevice, positions);
  }

  void _onDeviceSelected(
    api.Device device,
    List<api.Position> allPositions,
  ) async {
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
    _showDeviceDetailPanel(device, position);
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
        _showDeviceDetailPanel(device, position);
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
    _bottomSheetController?.close();

    _bottomSheetController = _scaffoldKey.currentState!.showBottomSheet((
      context,
    ) {
      final position = Provider.of<TraccarProvider>(context, listen: false)
          .positions
          .firstWhere(
            (p) => p.deviceId == device.id,
            orElse: () => api.Position(),
          );

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
          final traccarProvider = Provider.of<TraccarProvider>(
            context,
            listen: false,
          );
          await traccarProvider.fetchInitialData();
        },
      );
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
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    color:
                        (Theme.of(context).brightness == Brightness.dark
                                ? Colors.black
                                : Colors.white)
                            .withOpacity(0.2),
                  ),
                ),
              ),
              title: Text(
                'mapTitle'.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            drawer: _buildDeviceListDrawer(context, traccarProvider),
            body: Stack(
              children: [
                maplibre.MapLibreMap(
                  key: ValueKey(Provider.of<MapStyleProvider>(context).mapType),
                  initialCameraPosition: maplibre.CameraPosition(
                    target: maplibre.LatLng(
                      initialFlutterLatLng.latitude,
                      initialFlutterLatLng.longitude,
                    ),
                    zoom: initialZoom,
                  ),
                  styleString: Provider.of<MapStyleProvider>(
                    context,
                  ).styleString,
                  onStyleLoadedCallback: _onStyleLoaded,
                  onMapCreated: (controller) {
                    _mapController = controller;

                    // Automatic Map Style Switching based on Theme
                    final isDarkMode =
                        Theme.of(context).brightness == Brightness.dark;
                    final styleProvider = Provider.of<MapStyleProvider>(
                      context,
                      listen: false,
                    );
                    if (isDarkMode &&
                        styleProvider.mapType == AppMapType.bright) {
                      styleProvider.setMapType(AppMapType.dark);
                    } else if (!isDarkMode &&
                        styleProvider.mapType == AppMapType.dark) {
                      styleProvider.setMapType(AppMapType.bright);
                    }

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
                        );
                      }
                    });
                  },
                ),

                // Map Controls (Right Side)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 70,
                  right: 16,
                  child: Column(
                    children: [
                      _buildMapControl(
                        Icons.explore_rounded,
                        () => _mapController?.animateCamera(
                          maplibre.CameraUpdate.bearingTo(0),
                        ),
                        "btn_compass",
                      ),
                      const SizedBox(height: 12),
                      _buildMapControl(Icons.my_location_rounded, () {
                        // Center on specific location or user
                        if (_currentDevice != null) {
                          final pos = traccarProvider.getPosition(
                            _currentDevice!.id!,
                          );
                          if (pos != null)
                            _onDeviceSelected(
                              _currentDevice!,
                              traccarProvider.positions,
                            );
                        }
                      }, "btn_myloc"),
                      const SizedBox(height: 12),
                      _buildMapControl(
                        _showGeofences
                            ? Icons.layers_rounded
                            : Icons.layers_outlined,
                        () => setState(() => _showGeofences = !_showGeofences),
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
                        () => _navigateToDevice(-1, traccarProvider.devices, traccarProvider.positions),
                        "btn_prev",
                      ),
                      const SizedBox(height: 12),
                      _buildMapControl(
                        Icons.arrow_downward_rounded,
                        () => _navigateToDevice(1, traccarProvider.devices, traccarProvider.positions),
                        "btn_next",
                      ),
                      const SizedBox(height: 12),
                      _buildMapControl(
                        Icons.zoom_out_map_rounded,
                        () => _zoomToFitAll(traccarProvider),
                        "btn_zoom",
                      ),
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
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onTap,
      mini: true,
      backgroundColor: isActive
          ? Theme.of(context).primaryColor
          : (isDark ? Colors.grey[850] : Colors.white),
      child: Icon(
        icon,
        color: isActive
            ? Colors.white
            : (isDark ? Colors.white70 : Colors.black87),
        size: 20,
      ),
    );
  }
}

class _DataUpdateListener extends StatefulWidget {
  final dynamic data;
  final VoidCallback onUpdate;

  const _DataUpdateListener({
    required this.data,
    required this.onUpdate,
  });

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
