// lib/screens/map_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

const double _kControlSize = 44;
const double _kControlRadius = 12;
const double _kPillRadius = 22;
const double _kEdgeInset = 16;
const double _kControlGap = 12;
const double _kGlassBlurSigma = 10;
const double _kMaxMapZoom = 19.0;
const double _kMarkerSelectionRadius = 64.0;
const Duration _kSymbolTapGuard = Duration(milliseconds: 300);
const Duration _kCameraEventGrace = Duration(milliseconds: 250);
const int _kMaxTrailPoints = 3000;
const double _kAddressRefreshMeters = 50;

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

  maplibre.Line? _trailLine;
  String? _trailColorHex;
  final List<maplibre.LatLng> _trailPoints = [];
  int? _trailDeviceId;

  maplibre.LatLng? _lastAddressLookupPoint;

  bool _isCameraAnimating = false;
  Timer? _cameraAnimationGraceTimer;

  DateTime? _lastSymbolTapAt;

  final ValueNotifier<api.Device?> _selectedDeviceNotifier = ValueNotifier(null);
  final ValueNotifier<api.Position?> _selectedPositionNotifier = ValueNotifier(null);
  final ValueNotifier<String> _selectedAddressNotifier = ValueNotifier("");
  int _deviceSelectionGeneration = 0;

  bool _isCacheInitialized = false;
  Timer? _zoomDebounce;

  final TextEditingController _drawerSearchController = TextEditingController();
  String _drawerSearchQuery = '';

  static const String _kDrawerSortModeKey = 'drawer_device_sort_mode';
  _DrawerSortMode _drawerSortMode = _DrawerSortMode.favorite;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _drawerSearchController.addListener(() {
      final String query = _drawerSearchController.text;
      if (query == _drawerSearchQuery) return;
      _safeSetState(() => _drawerSearchQuery = query);
    });

    _loadDrawerSortMode();

    _iconService = MarkerIconService(loadedIcons: _loadedIcons);
    _cacheService.init().then((_) {
      OfflineAddressService.initDatabase();

      if (mounted) {
        _safeSetState(() {
          _isCacheInitialized = true;
        });
      }
    });

    _currentDevice = widget.selectedDevice;

    if (_currentDevice == null) {
      _loadLastSelectedDevice();
    }
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

  Future<void> _loadLastSelectedDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDeviceId = prefs.getInt('selectedDeviceId');

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
        final traccarProvider = context.read<TraccarProvider>();
        traccarProvider
            .fetchInitialData()
            .then((_) {
              if (mounted) {
                _scheduleMarkerUpdate(traccarProvider);
              }
            })
            .catchError((error) {
              debugPrint("Session validation failed on resume: $error");
              if (mounted && AuthSessionStore.instance.sessionId == null) {
                Get.offAllNamed('/login');
              }
            });
      }
    }
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
    if (device.id == null || traccarProvider.getPosition(device.id!) == null) return;
    _onDeviceSelected(device, forceShowPanel: true);
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

  int _deviceIndexIn(List<api.Device> devices, api.Device? device) {
    final index = devices.indexWhere((d) => d.id == device?.id);
    return index < 0 ? 1 : index + 1;
  }

  api.Device? _switcherDevice(List<api.Device> devices, api.Device? currentDevice) {
    if (devices.isEmpty) return null;
    final index = devices.indexWhere((d) => d.id == currentDevice?.id);
    return devices[index < 0 ? 0 : index];
  }

  Widget _buildBottomControls(TraccarProvider traccarProvider, api.Device? currentDevice) {
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
                    onPlateTap: switcherDevice == null ? null : () => _onDeviceSelected(switcherDevice, forceShowPanel: true, zoomToMax: true),
                  )
                : const SizedBox.shrink(),
          ),
        ),
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
      final bool labelChanged = previousState == null || previousState.labelImage != customLabelId || previousState.latitude != latLng.latitude || previousState.longitude != latLng.longitude;

      if (_deviceSymbols[deviceId] == null || previousState?.iconImage != baseIconKey) {
        await _iconService.ensureIconLoaded(controller, baseIconKey);
      }
      if (_labelSymbols[deviceId] == null || previousState?.labelImage != customLabelId) {
        await _iconService.ensureLabelIconLoaded(controller, plate, customLabelId, isSelected: isSelected);
      }
      if (!mounted || !identical(_mapController, controller) || !_isStyleLoaded) return;

      final deviceData = {'deviceId': deviceId.toString()};

      final iconSymbol = _deviceSymbols[deviceId];
      if (iconSymbol == null) {
        _deviceSymbols[deviceId] = await controller.addSymbol(maplibre.SymbolOptions(geometry: latLng, iconImage: baseIconKey, iconRotate: course, iconSize: iconSize, iconAnchor: 'center', zIndex: 10), deviceData);
      } else if (iconChanged) {
        await controller.updateSymbol(iconSymbol, maplibre.SymbolOptions(geometry: latLng, iconImage: baseIconKey, iconRotate: course, iconSize: iconSize, iconAnchor: 'center', zIndex: 10));
      }

      final labelSymbol = _labelSymbols[deviceId];
      final int labelZIndex = isSelected ? 6 : 5;
      if (labelSymbol == null) {
        _labelSymbols[deviceId] = await controller.addSymbol(maplibre.SymbolOptions(geometry: latLng, iconImage: customLabelId, iconRotate: 0.0, iconOffset: const Offset(0, 15), iconSize: 1.2, iconAnchor: 'top', zIndex: labelZIndex), deviceData);
      } else if (labelChanged) {
        await controller.updateSymbol(labelSymbol, maplibre.SymbolOptions(geometry: latLng, iconImage: customLabelId, iconRotate: 0.0, iconOffset: const Offset(0, 15), iconSize: 1.2, iconAnchor: 'top', zIndex: labelZIndex));
      }

      _markerRenderStates[deviceId] = _MarkerRenderState(latitude: latLng.latitude, longitude: latLng.longitude, course: course, iconSize: iconSize, iconImage: baseIconKey, labelImage: customLabelId);
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
    }

    _trailPoints.add(point);
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
    final traccarProvider = context.read<TraccarProvider>();
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

  void _onDeviceSelected(api.Device device, {bool forceShowPanel = false, bool follow = true, bool zoomToMax = false}) async {
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

    await _syncSheetContentInset(animated: false);
    if (!mounted || selectionGeneration != _deviceSelectionGeneration) return;
    await _animateCamera(zoomToMax ? maplibre.CameraUpdate.newLatLngZoom(latLng, _kMaxMapZoom) : maplibre.CameraUpdate.newLatLng(latLng));
    if (!mounted || selectionGeneration != _deviceSelectionGeneration) return;
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
                                final traccarProvider = context.read<TraccarProvider>();
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
        return Theme.of(context).colorScheme.onSurface;
    }
  }

  Future<void> _loadDrawerSortMode() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_kDrawerSortModeKey);
    final mode = _DrawerSortMode.values.firstWhereOrNull((m) => m.name == stored);
    if (mode != null && mounted) {
      _safeSetState(() => _drawerSortMode = mode);
    }
  }

  void _setDrawerSortMode(_DrawerSortMode mode) {
    if (mode == _drawerSortMode) return;
    _safeSetState(() => _drawerSortMode = mode);
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_kDrawerSortModeKey, mode.name));
  }

  Widget _buildDeviceListDrawer(BuildContext context, TraccarProvider traccarProvider) {
    final String query = _drawerSearchQuery.trim().toLowerCase();

    final devices = traccarProvider.devices.where((device) {
      if (query.isEmpty) return true;
      final String name = (device.name ?? '').toLowerCase();
      final String uniqueId = (device.uniqueId ?? '').toLowerCase();
      final String deviceId = (device.id ?? '').toString();
      return name.contains(query) || uniqueId.contains(query) || deviceId.contains(query);
    }).toList();

    final Map<int, double> speedByDeviceId = {
      for (final device in devices)
        if (device.id != null) device.id!: (_positionForDevice(traccarProvider, device.id)?.speed ?? 0.0).toDouble(),
    };

    devices.sort((a, b) {
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

      return (a.name ?? '').compareTo(b.name ?? '');
    });

    return Drawer(
      child: Column(
        children: [
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

                    if (_isCameraAnimating) return;

                    if (_isFollowingDevice) {
                      _safeSetState(() {
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
                if (_isStyleLoaded)
                  _DataUpdateListener(
                    data: Object.hash(traccarProvider.positionsRevision, traccarProvider.devicesRevision),
                    onUpdate: () {
                      _syncSelectedDeviceFromProvider(traccarProvider);
                      _scheduleMarkerUpdate(traccarProvider);
                    },
                  ),
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

class _GlassPalette {
  final Color fill;
  final Color border;
  final List<BoxShadow> shadows;

  const _GlassPalette({required this.fill, required this.border, required this.shadows});

  factory _GlassPalette.of(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return _GlassPalette(
      fill: (isDark ? colorScheme.surfaceContainerHighest : colorScheme.surface).withValues(alpha: 0.94),
      border: colorScheme.outlineVariant.withValues(alpha: 0.5),
      shadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.32),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.2),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}

class _GlassSurface extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const _GlassSurface({required this.child, this.borderRadius = _kControlRadius, this.padding});

  @override
  Widget build(BuildContext context) {
    final _GlassPalette palette = _GlassPalette.of(context);

    return Container(
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
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ),
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

enum _DrawerSortMode {
  favorite('sharedPriority', Icons.star_rounded),

  online('dashboardOnline', Icons.wifi_tethering_rounded),

  speed('positionSpeed', Icons.speed_rounded);

  const _DrawerSortMode(this.labelKey, this.icon);

  final String labelKey;

  final IconData icon;
}

// 改進：直接輸出完整 8 位數 ARGB 十六進位碼（#AARRGGBB），完美支援 MapLibre 軌跡透明度渲染
String _toHexColor(Color color) => '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
