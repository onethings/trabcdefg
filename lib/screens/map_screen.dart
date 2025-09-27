// lib/screens/map_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart'
    as api; // FIX: Added 'as api'
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
import 'share_device_screen.dart'; // Import the new screen
import 'command_screen.dart';
import 'package:trabcdefg/screens/settings/devices_screen.dart';
import 'package:trabcdefg/screens/settings/add_device_screen.dart'; // Import AddDeviceScreen

class MapScreen extends StatefulWidget {
  final api.Device? selectedDevice; // FIX: Use api.Device

  const MapScreen({super.key, this.selectedDevice});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Map<String, BitmapDescriptor> _markerIcons = {};
  bool _markersLoaded = false;
  bool _isSatelliteView = false;
  GoogleMapController? mapController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  api.Device? _currentDevice; // FIX: Use api.Device

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _currentDevice = widget.selectedDevice;
    if (_currentDevice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Your logic for initial state handling
      });
    }
  }

  Future<void> _loadMarkerIcons() async {
    const List<String> categories = [
      'animal',
      'arrow',
      'bicycle',
      'boat',
      'bus',
      'car',
      'crane',
      'default',
      'helicopter',
      'motorcycle',
      'null',
      'offroad',
      'person',
      'pickup',
      'plane',
      'scooter',
      'ship',
      'tractor',
      'train',
      'tram',
      'trolleybus',
      'truck',
      'van',
    ];
    const List<String> statuses = [
      'online',
      'offline',
      'static',
      'idle',
      'unknown',
    ];

    for (var category in categories) {
      for (var status in statuses) {
        final iconPath = 'assets/images/marker_${category}_$status.png';
        try {
          final byteData = await rootBundle.load(iconPath);
          final imageData = byteData.buffer.asUint8List();
          final codec = await ui.instantiateImageCodec(
            imageData,
            targetHeight: 100,
          );
          final frameInfo = await codec.getNextFrame();
          final image = frameInfo.image;
          final byteDataResized = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (byteDataResized != null) {
            final bitmap = BitmapDescriptor.fromBytes(
              byteDataResized.buffer.asUint8List(),
            );
            _markerIcons['$category-$status'] = bitmap;
          }
        } catch (e) {
          print('Could not load icon: $iconPath. Using fallback.'.tr);
        }
      }
    }
    if (mounted) {
      setState(() {
        _markersLoaded = true;
      });
    }
  }

  PersistentBottomSheetController? _bottomSheetController;
  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MM/dd/yyyy, hh:mm:ss a').format(date.toLocal());
  }

  // IMPLEMENTATION: Delete confirmation dialog
  Future<void> _showDeleteConfirmationDialog(api.Device device) async {
    // FIX: Use api.Device
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

  // IMPLEMENTATION: Perform the deletion
  Future<void> _deleteDevice(int deviceId) async {
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final devicesApi = api.DevicesApi(
      traccarProvider.apiClient,
    ); // FIX: Use api.DevicesApi

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
      // FIX: Use api.ApiException
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

  void _onDeviceSelected(
    api.Device device,
    List<api.Position> allPositions,
  ) async {
    // FIX: Use api.Device and api.Position
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedDeviceId', device.id!);
    await prefs.setString('selectedDeviceName', device.name!);

    final position = allPositions.firstWhere(
      (p) => p.deviceId == device.id,
      orElse: () => api.Position(
        // FIX: Use api.Position
        deviceId: device.id,
        latitude: 0.0,
        longitude: 0.0,
      ), // Fallback
    );

    if (position.latitude != null &&
        position.longitude != null &&
        mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude!.toDouble(), position.longitude!.toDouble()),
          15, // A closer zoom level
        ),
      );
      mapController!.showMarkerInfoWindow(MarkerId(device.id.toString()));
    }

    // Show the detail panel for the selected device
    _showDeviceDetailPanel(device, position); // Pass position here
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
    // FIX: Use api.Device and api.Position
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('More Options'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                ListTile(
                  title: const Text('Create Geofence'),
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
                  title: const Text('Google Maps'),
                  onTap: () {
                    Navigator.of(context).pop();
                    // Assuming position variable needs to be currentPosition
                    if (currentPosition?.latitude != null &&
                        currentPosition?.longitude != null) {
                      final url = Uri.parse(
                        'http://maps.google.com/?q=${currentPosition!.latitude},${currentPosition.longitude}',
                      );
                      _launchUrl(url);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Apple Maps'),
                  onTap: () {
                    Navigator.of(context).pop();
                    // Assuming position variable needs to be currentPosition
                    if (currentPosition?.latitude != null &&
                        currentPosition?.longitude != null) {
                      final url = Uri.parse(
                        'https://maps.apple.com/?q=${currentPosition!.latitude},${currentPosition.longitude}',
                      );
                      _launchUrl(url);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Street View'),
                  onTap: () {
                    Navigator.of(context).pop();
                    // Assuming position variable needs to be currentPosition
                    if (currentPosition?.latitude != null &&
                        currentPosition?.longitude != null) {
                      final url = Uri.parse(
                        'google.streetview:cbll=${currentPosition!.latitude},${currentPosition.longitude}',
                      );
                      _launchUrl(url);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Share Device'),
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
    // FIX: Use api.Device and api.Position
    _bottomSheetController?.close();

    // Get the TraccarProvider instance for use outside the inner builder
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );

    _bottomSheetController = _scaffoldKey.currentState!.showBottomSheet((
      context,
    ) {
      // Find the current position for the device
      final currentPosition =
          Provider.of<TraccarProvider>(
            context,
            listen: false,
          ).positions.firstWhere(
            (p) => p.deviceId == device.id,
            orElse: () => api.Position(), // FIX: Use api.Position
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
                            // Handle info button tap
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
                            '${((currentPosition.attributes as Map<String, dynamic>)['distance'] as double).toStringAsFixed(2)} km',
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
                          '${(currentPosition.attributes as Map<String, dynamic>?)?['totalDistance']?.toStringAsFixed(2) ?? 'N/A'} km',
                    ),
                    // const SizedBox(height: 16),
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
                        // The device ID is already in SharedPreferences
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CommandScreen(),
                          ),
                        );
                      },
                      onEditPressed: () async {
                        // EDITED: Wires to Edit Screen
                        _bottomSheetController?.close();

                        final updatedDevice = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            // Assuming AddDeviceScreen handles edit by passing the device
                            builder: (context) =>
                                AddDeviceScreen(device: device),
                          ),
                        );

                        // If device was updated, refresh the map data
                        if (updatedDevice != null) {
                          await traccarProvider.fetchInitialData();
                        }
                      },
                      onDeletePressed: () {
                        // EDITED: Wires to Delete Dialog
                        // Close the detail panel before showing the dialog for better UX
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
              // You should navigate to your Settings screen here
              // Assuming you have a SettingsScreen, otherwise replace with the correct screen
              // Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              Get.snackbar('Coming Soon'.tr, 'Settings screen placeholder');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text('Logout'.tr, style: const TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.of(context).pop(); // Close the drawer

              // // FIX: Changed 'logout()' to the actual method name 'clearSession()'
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
    required VoidCallback onEditPressed, // ADDED: Edit callback
    required VoidCallback onDeletePressed, // ADDED: Delete callback
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
          onPressed: onDeletePressed, // Wires the delete logic
        ),
      ],
    );
  }

  // Helper to safely find a position (since GetX's .firstWhereOrNull is not guaranteed to be globally available)
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

  // Helper method to get status color (ensure this is defined)
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

        // 2. Prepare Markers (Logic preserved from previous fix)
        final markers = <Marker>{};

        if (_markersLoaded) {
          for (final api.Device device in traccarProvider.devices) {
            final api.Position? position = _findPositionOrNull(
              traccarProvider.positions,
              device.id,
            );

            if (position != null &&
                position.latitude != null &&
                position.longitude != null) {
              final LatLng markerPosition = LatLng(
                position.latitude!.toDouble(),
                position.longitude!.toDouble(),
              );
              final String markerId = device.id.toString();

              final String category = device.category ?? 'default';
              final String status = device.status ?? 'unknown';
              final String iconKey = '$category-$status';
              final double course = position.course?.toDouble() ?? 0.0;
              markers.add(
                Marker(
                  markerId: MarkerId(markerId),
                  position: markerPosition,
                  icon:
                      _markerIcons[iconKey] ?? _markerIcons['default-unknown']!,
                  rotation: course,
                  infoWindow: InfoWindow(title: device.name ?? 'Unknown'.tr),
                  onTap: () {
                    _onDeviceSelected(device, traccarProvider.positions);
                  },
                ),
              );
            }
          }
        }

        // 3. Determine Initial Camera Position (Logic preserved from previous fix)
        LatLng initialCameraPosition = const LatLng(0, 0);
        double initialZoom = 2.0;

        if (_currentDevice != null) {
          final initialPosition = _findPositionOrNull(
            traccarProvider.positions,
            _currentDevice!.id,
          );

          if (initialPosition?.latitude != null &&
              initialPosition?.longitude != null) {
            initialCameraPosition = LatLng(
              initialPosition!.latitude!.toDouble(),
              initialPosition.longitude!.toDouble(),
            );
            initialZoom = 15.0;
          }
        } else if (traccarProvider.positions.isNotEmpty) {
          final api.Position firstPosition = traccarProvider.positions.first;
          if (firstPosition.latitude != null &&
              firstPosition.longitude != null) {
            initialCameraPosition = LatLng(
              firstPosition.latitude!.toDouble(),
              firstPosition.longitude!.toDouble(),
            );
            initialZoom = 5.0;
          }
        }

        // 4. Build the Scaffold and Map
        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: Text('mapTitle'.tr),
            actions: [
              IconButton(
                icon: Icon(_isSatelliteView ? Icons.satellite : Icons.map),
                onPressed: () {
                  setState(() {
                    _isSatelliteView = !_isSatelliteView;
                  });
                },
              ),
              // List of devices button
              // IconButton(
              //   icon: const Icon(Icons.list),
              //   onPressed: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(builder: (context) => const DeviceListScreen()),
              //     );
              //   },
              // ),
            ],
          ),
          // ADDED: The Drawer
          drawer: _buildDeviceListDrawer(context, traccarProvider),
          body: Stack(
            children: [
              GoogleMap(
                // Satellite Switch logic
                mapType: _isSatelliteView ? MapType.satellite : MapType.normal,
                initialCameraPosition: CameraPosition(
                  target: initialCameraPosition,
                  zoom: initialZoom,
                ),
                onMapCreated: (GoogleMapController controller) {
                  mapController = controller;
                },
                markers: markers,
                onTap: (LatLng latLng) {
                  _bottomSheetController?.close();
                },
                myLocationButtonEnabled: true,
                myLocationEnabled: true,
              ),
              // Floating action buttons for map type toggle (Satellite Switch)
              // Positioned(
              //   bottom: 80,
              //   right: 16,
              //   child: FloatingActionButton.small(
              //     heroTag: 'mapType',
              //     backgroundColor: Colors.white,
              //     onPressed: () {
              //       setState(() {
              //         _isSatelliteView = !_isSatelliteView;
              //       });
              //     },
              //     child: Icon(
              //       _isSatelliteView ? Icons.layers : Icons.satellite,
              //       color: Colors.blue,
              //     ),
              //   ),
              // ),
            ],
          ),
        );
      },
    );
  }
}
