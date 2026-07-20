import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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

class MapScreen extends StatefulWidget {
  final api.Device? selectedDevice;

  const MapScreen({super.key, this.selectedDevice});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  Key _mapKey = UniqueKey();

  maplibre.MapLibreMapController? _mapController;
  maplibre.CameraPosition? _lastCameraPosition;
  bool _isStyleLoaded = false;
  bool _hasInitialZoomed = false;
  final Set<String> _loadedIcons = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  api.Device? _currentDevice;
  final TileCacheService _cacheService = TileCacheService();
  late MarkerIconService _iconService;
  final http.Client _httpClient = http.Client();

  final ValueNotifier<bool> _panelOpenNotifier = ValueNotifier(false);
  bool get _isPanelOpen => _panelOpenNotifier.value;
  bool _isFollowingDevice = false;

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
                _updateAllMarkers(traccarProvider);
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

    if (!mounted) return;
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    await _mapController!.setSymbolIconAllowOverlap(true);
    await _mapController!.setSymbolIconIgnorePlacement(true);
    await _mapController!.setSymbolTextAllowOverlap(true);
    await _mapController!.setSymbolTextIgnorePlacement(true);

    await _updateAllMarkers(traccarProvider);

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
      if ((maxLat - minLat).abs() < 0.0001 && (maxLng - minLng).abs() < 0.0001) {
        _mapController!.animateCamera(maplibre.CameraUpdate.newLatLngZoom(maplibre.LatLng(minLat, minLng), 14.0));
      } else {
        _mapController!.animateCamera(maplibre.CameraUpdate.newLatLngBounds(maplibre.LatLngBounds(southwest: maplibre.LatLng(minLat, minLng), northeast: maplibre.LatLng(maxLat, maxLng)), left: 50, right: 50, top: 100, bottom: 100));
      }
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
        _mapController?.animateCamera(maplibre.CameraUpdate.newLatLng(maplibre.LatLng(currentPos.latitude!.toDouble(), currentPos.longitude!.toDouble())));
      }
    }

    await _mapController!.clearSymbols();

    for (final device in provider.devices) {
      final pos = _findPositionOrNull(provider.positions, device.id);
      if (pos == null || pos.latitude == null) continue;

      final String category = device.category ?? 'default';
      final String status = device.status ?? 'unknown';
      final String baseIconKey = 'marker_${category.toLowerCase()}_${status.toLowerCase()}';

      final String plate = device.name ?? '';
      final String customLabelId = "label_$plate";

      await _iconService.ensureIconLoaded(_mapController, baseIconKey);
      await _iconService.ensureLabelIconLoaded(_mapController, plate, customLabelId);

      final latLng = maplibre.LatLng(pos.latitude!.toDouble(), pos.longitude!.toDouble());

      final deviceData = {'deviceId': device.id.toString()};

      await _mapController!.addSymbol(
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

      await _mapController!.addSymbol(maplibre.SymbolOptions(geometry: latLng, iconImage: customLabelId, iconRotate: 0.0, iconOffset: const Offset(0, 15), iconSize: 1.2, iconAnchor: 'top', zIndex: 5), deviceData);
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
          content: Text('Are you sure you want to delete the device "${device.name}"?'.tr),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'.tr),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text('Delete'.tr, style: const TextStyle(color: Colors.red)),
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
      _mapController!.animateCamera(maplibre.CameraUpdate.newLatLng(maplibre.LatLng(position.latitude!.toDouble(), position.longitude!.toDouble())));

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
        );
      },
    );
  }

  void _showDeviceDetailPanel(api.Device device, api.Position? currentPosition) {
    if (_isPanelOpen && _bottomSheetController != null) {
      return;
    }

    setState(() {
      _panelOpenNotifier.value = true;
    });
    _bottomSheetController = _scaffoldKey.currentState!.showBottomSheet((context) {
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
                      final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
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
                  trailing: const Icon(Icons.chevron_right),
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
    return Consumer<TraccarProvider>(
      builder: (context, traccarProvider, child) {
        if (traccarProvider.isLoading && traccarProvider.devices.isEmpty) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!_isCacheInitialized) {
          return const Scaffold(body: Center(child: Text('Initializing Map Assets...')));
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

        final mapStyleProvider = Provider.of<MapStyleProvider>(context);

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
                    initialCameraPosition: _lastCameraPosition ?? maplibre.CameraPosition(target: maplibre.LatLng(initialLat, initialLng), zoom: initialZoom),
                    styleString: mapStyleProvider.styleString,
                    compassEnabled: false,
                    onCameraMove: (position) {
                      _zoomDebounce?.cancel();
                      _zoomDebounce = Timer(const Duration(milliseconds: 300), () {
                        SharedPreferences.getInstance().then((prefs) {
                          prefs.setDouble('map_zoom_level', position.zoom);
                        });
                      });
                    },
                    onStyleLoadedCallback: _onStyleLoaded,
                    onMapCreated: (controller) {
                      _mapController = controller;

                      _mapController!.onSymbolTapped.add((symbol) {
                        final deviceIdString = symbol.data?['deviceId'];
                        final deviceId = int.tryParse(deviceIdString ?? '');

                        if (deviceId != null && mounted) {
                          final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
                          _onDeviceSelected(traccarProvider.devices.firstWhere((d) => d.id == deviceId), traccarProvider.positions, forceShowPanel: true);
                        }
                      });
                    },
                    onMapClick: (point, latLng) {
                      if (_bottomSheetController != null) {
                        _bottomSheetController!.close();
                        _bottomSheetController = null;
                        _isFollowingDevice = false;
                      }
                    },
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12, //12
                  right: 16,
                  child: Column(
                    children: [
                      _buildMapControl(mapStyleProvider.isSatelliteMode ? Icons.satellite_alt : Icons.map, () => mapStyleProvider.toggleMapType(), "btn_style", isActive: mapStyleProvider.isSatelliteMode),
                      const SizedBox(height: 12),
                      _buildMapControl(Icons.explore_rounded, () => _mapController?.animateCamera(maplibre.CameraUpdate.bearingTo(0)), "btn_compass"),
                      const SizedBox(height: 12),
                      _buildMapControl(Icons.my_location_rounded, () {
                        if (_currentDevice != null) {
                          final pos = traccarProvider.getPosition(_currentDevice!.id!);
                          if (pos != null) {
                            _onDeviceSelected(_currentDevice!, traccarProvider.positions, forceShowPanel: true);
                          }
                        }
                      }, "btn_myloc"),
                      const SizedBox(height: 12),
                      _buildMapControl(Icons.zoom_out_map_rounded, () => _zoomToFitAll(traccarProvider), "btn_zoom"),
                    ],
                  ),
                ),
                if (_isStyleLoaded) _DataUpdateListener(data: traccarProvider.positions, onUpdate: () => _updateAllMarkers(traccarProvider)),
                if (traccarProvider.isLoading && traccarProvider.devices.isEmpty) const Center(child: CircularProgressIndicator()),

                // Device navigation bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.of(context).padding.bottom + (_panelOpenNotifier.value ? 230 : 30), //280 : 80
                  child: Material(
                    color: Colors.transparent,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildMapControl(Icons.chevron_left_rounded, () => _navigateToDevice(-1, traccarProvider.devices, traccarProvider.positions), "btn_prev_device"),
                              const SizedBox(width: 28),
                              _buildMapControl(Icons.chevron_right_rounded, () => _navigateToDevice(1, traccarProvider.devices, traccarProvider.positions), "btn_next_device"),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildMapControl(Icons.add_rounded, () => _mapController?.animateCamera(maplibre.CameraUpdate.zoomIn()), "btn_zoom_in"),
                              const SizedBox(height: 14),//4
                              _buildMapControl(Icons.remove_rounded, () => _mapController?.animateCamera(maplibre.CameraUpdate.zoomOut()), "btn_zoom_out"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapControl(IconData icon, VoidCallback onTap, String heroTag, {bool isActive = false, bool isToggle = false}) {
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
            color: isActive ? colorScheme.primary.withValues(alpha: 0.85) : (isDark ? Colors.black.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.7)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05), width: 0.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              splashColor: colorScheme.primary.withValues(alpha: 0.1),
              highlightColor: colorScheme.primary.withValues(alpha: 0.05),
              child: Center(
                child: Hero(
                  tag: heroTag,
                  child: Icon(icon, color: isActive ? colorScheme.onPrimary : (isDark ? Colors.white70 : Colors.black87), size: isToggle ? 24 : 20),
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
