// lib/screens/map_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Primary map package for OpenStreetMap
import 'package:latlong2/latlong.dart' as latlong; // LatLong for FlutterMap coordinates
// ALIAS: Required for Satellite view, Marker, BitmapDescriptor - REMOVED: google_maps_flutter is gone
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart'
    as api; 
import 'package:trabcdefg/src/generated_api/model/device_extensions.dart';
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
import 'settings/geofences_screen.dart';
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

  _HiveTileProvider({
    required this.cacheService,
    required this.httpClient,
  });

  @override
  ImageProvider getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) {
    // This is the key method to load the image. We return a FutureProvider.
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      cacheService: cacheService,
      httpClient: httpClient,
    );
  }
}

// Custom ImageProvider to handle the cache/network logic
class CachedNetworkImageProvider extends ImageProvider<CachedNetworkImageProvider> {
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
        throw Exception('Failed to load tile from network: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback or error handling for any other failure
      rethrow;
    }
  }
}

// --- End of Tile Caching Implementation ---


// ADDED: Enum for managing map types
enum AppMapType {
  openStreetMap, // Will use standard OSM tiles
  satellite,     // Will use an alternative satellite-like tile layer
}

class MapScreen extends StatefulWidget {
  final api.Device? selectedDevice; 

  const MapScreen({super.key, this.selectedDevice});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // REMOVED: final Map<String, gmap.BitmapDescriptor> _markerIcons = {}; 
  bool _markersLoaded = false;
  AppMapType _mapType = AppMapType.openStreetMap; 
  MapController flutterMapController = MapController(); 
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  api.Device? _currentDevice; 
  final _TileCacheService _cacheService = _TileCacheService(); 
  final http.Client _httpClient = http.Client(); 

  // --- Tile URLs for different map types ---
  static const String _osmUrlTemplate = 
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _satelliteUrlTemplate = 
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const List<String> _osmSubdomains = ['a', 'b', 'c'];

  // Custom Tile Provider 
  late _HiveTileProvider _tileProvider;
  bool _isCacheInitialized = false; // State to track cache/provider initialization


  @override
  void initState() {
    super.initState();
    // Initialize cache service and then the tile provider
    _cacheService.init().then((_) {
      _tileProvider = _HiveTileProvider(
        cacheService: _cacheService,
        httpClient: _httpClient,
      );
      if (mounted) {
        setState(() {
          _isCacheInitialized = true; // Set flag when initialization is complete
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
    final devicesApi = api.DevicesApi(
      traccarProvider.apiClient,
    ); 

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

  void _onDeviceSelected(
    api.Device device,
    List<api.Position> allPositions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedDeviceId', device.id!);
    await prefs.setString('selectedDeviceName', device.name!);

    final position = allPositions.firstWhere(
      (p) => p.deviceId == device.id,
      orElse: () => api.Position(
        deviceId: device.id,
        latitude: 0.0,
        longitude: 0.0,
      ), 
    );

    if (position.latitude != null &&
        position.longitude != null) {
      
      // FIXED: Added .toDouble() to cast nullable num to non-nullable double.
      final double lat = position.latitude!.toDouble(); 
      final double lon = position.longitude!.toDouble();

      final targetLatLng = latlong.LatLng(
        lat, 
        lon,
      );
      
      flutterMapController.move( 
        targetLatLng, 
        15.0, 
      );
    }

    _showDeviceDetailPanel(device, position); 
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
          title:  Text(device.name ?? 'More Options'.tr),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
                            fontSize: 17,
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
                            '${((currentPosition.attributes as Map<String, dynamic>)['distance'] as double).toStringAsFixed(2)} '+'sharedKm'.tr,
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
                              '${currentPosition.speed} km/h',
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
                          '${(currentPosition.attributes as Map<String, dynamic>?)?['totalDistance']?.toStringAsFixed(2) ?? 'N/A'} '+'sharedKm'.tr,
                    ),
                    _buildReportPanel(
                      onRefreshPressed: () {
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
            const Icon(Icons.access_time, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              'deviceLastUpdate'.tr + ':',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text(fixTime),
          ],
        ),
        const SizedBox(height: 8),

        // Address Row
        if (address != 'N/A')
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(child: Text(address)),
            ],
          ),
        const SizedBox(height: 8),

        // Total Distance Row
        Row(
          children: [
            const Icon(Icons.directions_car, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              'deviceTotalDistance'.tr + ':',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Text(totalDistance),
          ],
        ),
        const SizedBox(height: 16), // Separator before the report panel
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
        // Refresh icon
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF5B697B)),
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
                position.longitude!.toDouble()
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
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.location_on),
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
        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: Text('mapTitle'.tr),
            actions: [
              // Map type toggle logic
              IconButton(
                // Show the icon of the map type we will switch TO
                icon: Icon(
                  _mapType == AppMapType.satellite ? Icons.map : Icons.satellite
                ),
                onPressed: () {
                  setState(() {
                    _mapType = _mapType == AppMapType.satellite
                        ? AppMapType.openStreetMap // Switch to OSM (normal)
                        : AppMapType.satellite; // Switch to Satellite
                  });
                },
              ),
            ],
          ),
          // The Drawer
          drawer: _buildDeviceListDrawer(context, traccarProvider),
          body: Stack(
            children: [
              // We now use FlutterMap for both map types
              FlutterMap(
                mapController: flutterMapController,
                options: MapOptions(
                  initialCenter: initialFlutterLatLng,
                  initialZoom: initialZoom,
                  interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate), // Disable rotate by default
                  onTap: (tapPosition, latLng) {
                      _bottomSheetController?.close();
                  },
                ),
                children: [
                  // Tile Layer: Conditional based on map type
                  TileLayer(
                    // Choose URL based on current map type
                    urlTemplate: _mapType == AppMapType.openStreetMap
                        ? _osmUrlTemplate
                        : _satelliteUrlTemplate,
                    // Only use subdomains for OSM. Satellite URL is static.
                    subdomains: _mapType == AppMapType.openStreetMap
                        ? _osmSubdomains
                        : const [],
                    userAgentPackageName: 'com.trabcdefg.app', // IMPORTANT for OpenStreetMap
                    
                    // --- THE IMPLEMENTATION: Use the Custom TileProvider ---
                    tileProvider: _tileProvider, 
                  ),
                  // Marker Layer for FlutterMap
                  MarkerLayer(markers: flutterMarkers.toList()), // Convert set to list
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}