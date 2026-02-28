// lib/screens/livetracking_map_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/providers/map_style_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // Required for the specific date format
import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'dart:convert';
import 'package:timeago/timeago.dart' as timeago;
import 'package:trabcdefg/widgets/OfflineAddressService.dart';

// --- Reverse Geocoding Service Implementation using Hive and Nominatim ---
class NominatimService {
  late Box<String> _geocodeBox;
  final http.Client _httpClient;
  static const String boxName = 'geocodeCache';
  static const String _nominatimBaseUrl =
      'https://nominatim.openstreetmap.org/reverse';

  NominatimService({required http.Client httpClient})
    : _httpClient = httpClient;

  Future<void> init() async {
    _geocodeBox = await Hive.openBox<String>(boxName);
  }

  String _generateKey(double lat, double lon) {
    final roundedLat = lat.toStringAsFixed(3);
    final roundedLon = lon.toStringAsFixed(3);
    return '$roundedLat,$roundedLon';
  }

  Future<String> fetchStreetName({
    required double lat,
    required double lon,
    required String defaultValue,
    required String langCode,
    required String appName,
    required String userEmail,
  }) async {
    final key = _generateKey(lat, lon);
    String? cachedAddress = _geocodeBox.get(key);
    if (cachedAddress != null) {
      return cachedAddress;
    }

    final url = Uri.parse(
      '$_nominatimBaseUrl?lat=$lat&lon=$lon&format=json&zoom=18&addressdetails=1',
    );

    try {
      final response = await _httpClient.get(
        url,
        headers: {
          'User-Agent': '$appName/1.0 ($userEmail)',
          'Accept-Language': langCode,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result =
            json.decode(response.body) as Map<String, dynamic>;

        final address = result['address'] as Map<String, dynamic>?;
        final streetName =
            address?['road'] as String? ??
            address?['footway'] as String? ??
            address?['cycleway'] as String? ??
            result['display_name'] as String? ??
            defaultValue;

        await _geocodeBox.put(key, streetName);
        return streetName;
      } else {
        throw Exception('Failed to load address');
      }
    } catch (e) {
      return 'Geocoding Failed'.tr;
    }
  }
}

class LiveTrackingMapScreen extends StatefulWidget {
  final Device selectedDevice;
  const LiveTrackingMapScreen({super.key, required this.selectedDevice});

  @override
  State<LiveTrackingMapScreen> createState() => _LiveTrackingMapScreenState();
}

class _LiveTrackingMapScreenState extends State<LiveTrackingMapScreen> {
  MapLibreMapController? _mapController;
  Position? _currentDevicePosition;
  bool _isCameraLocked = true;
  bool _isGeocodeServiceInitialized = false;
  bool _isStyleLoaded = false;
  double _mapCenterOffset = 0.007;
  double _mapCenterOnset = 0.008;

  late NominatimService _nominatimService;
  
  // Initialize OfflineGeocoder from your service file
  // final OfflineGeocoder _offlineGeocoder = OfflineGeocoder();

  String _currentStreetName = 'Fetching Address...'.tr;
  DateTime _lastNominatimNetworkFetch = DateTime.fromMillisecondsSinceEpoch(0);
  String _cachedUserEmail = 'kevin16iwin@gmail.com';
  final http.Client _httpClient = http.Client();
  final Set<String> _loadedIcons = {};

  // Style strings moved to provider

  @override
  void initState() {
    super.initState();
    _setupTimeagoLocales();

    // Initialize Offline DB on screen load
    OfflineAddressService.initDatabase();

    _nominatimService = NominatimService(httpClient: _httpClient);
    _nominatimService.init().then((_) {
      if (mounted) setState(() => _isGeocodeServiceInitialized = true);
    });
    _fetchUserEmailFromApi();
  }

  bool _checkIsStale(Device device, Position? position) {
    final DateTime now = DateTime.now().toUtc();
    final DateTime? lastUpdate =
        position?.fixTime?.toUtc() ?? device.lastUpdate?.toUtc();
    return lastUpdate == null || now.difference(lastUpdate).inMinutes >= 10;
  }

  void _setupTimeagoLocales() {
    timeago.setLocaleMessages('en_short', timeago.EnShortMessages());
    timeago.setLocaleMessages('zh', timeago.ZhMessages());
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    _mapController!.onSymbolTapped.add(_onSymbolTapped);
  }

  Future<void> _ensureIconLoaded(String iconKey) async {
    if (_mapController == null || _loadedIcons.contains(iconKey)) return;
    try {
      final String assetPath = 'assets/images/$iconKey.png';
      final ByteData bytes = await rootBundle.load(assetPath);
      final Uint8List list = bytes.buffer.asUint8List();
      await _mapController!.addImage(iconKey, list);
      _loadedIcons.add(iconKey);
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      if (iconKey != 'marker_default_unknown')
        await _ensureIconLoaded('marker_default_unknown');
    }
  }

  void _updateMapMarkers() async {
    if (_mapController == null ||
        _currentDevicePosition == null ||
        !_isStyleLoaded)
      return;

    final bool isStale = _checkIsStale(
      widget.selectedDevice,
      _currentDevicePosition,
    );
    final String category = widget.selectedDevice.category ?? 'default';
    final String effectiveStatus = isStale
        ? 'offline'
        : (widget.selectedDevice.status ?? 'unknown');
    final String iconKey =
        'marker_${category.toLowerCase()}_${effectiveStatus.toLowerCase()}';

    await _ensureIconLoaded(iconKey);
    await _mapController!.clearSymbols();
    await _mapController!.addSymbol(
      SymbolOptions(
        geometry: LatLng(
          _currentDevicePosition!.latitude!.toDouble(),
          _currentDevicePosition!.longitude!.toDouble(),
        ),
        iconImage: _loadedIcons.contains(iconKey)
            ? iconKey
            : 'marker_default_unknown',
        iconRotate: _currentDevicePosition!.course?.toDouble() ?? 0.0,
        iconSize: 3.2,
      ),
    );

    if (_isCameraLocked) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(
            _currentDevicePosition!.latitude!.toDouble() - _mapCenterOffset,
            _currentDevicePosition!.longitude!.toDouble(),
          ),
        ),
      );
    }
  }

  // UPDATED: Logic to handle street names with Offline Geocoder fallback
  Future<void> _fetchStreetName(
    double lat,
    double lon,
    Position? position,
  ) async {
    // 1. Check Traccar API Address first
    if (position?.address != null && position!.address!.isNotEmpty) {
      if (mounted) setState(() => _currentStreetName = position.address!);
      return;
    }

    // 2. Fallback to your Offline Geocoder (getAddress method)
    try {
      final offlineResult = await OfflineAddressService.getAddress(lat, lon);
      if (offlineResult != "Myanmar Road") {
        if (mounted) setState(() => _currentStreetName = offlineResult);
        return;
      }
    } catch (e) {
      debugPrint("Offline lookup error: $e");
    }

    // 3. Fallback to Nominatim Network if offline fails
    if (!_isGeocodeServiceInitialized) return;
    // Map type moved to provider
    final now = DateTime.now();
    if (now.difference(_lastNominatimNetworkFetch) <
        const Duration(seconds: 30))
      return;
    _lastNominatimNetworkFetch = now;

    final resultAddress = await _nominatimService.fetchStreetName(
      lat: lat,
      lon: lon,
      defaultValue: 'Address not found'.tr,
      langCode: Get.locale?.toLanguageTag() ?? 'en',
      appName: 'TrabcdefgMobileApp',
      userEmail: _cachedUserEmail,
    );

    if (mounted) setState(() => _currentStreetName = resultAddress);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectedDevice.name ?? 'mapLiveRoutes'.tr),
      ),
      body: Consumer<TraccarProvider>(
        builder: (context, traccarProvider, child) {
          final lastPosition = traccarProvider.positions.firstWhere(
            (pos) => pos.deviceId == widget.selectedDevice.id,
            orElse: () => Position(),
          );

          if (_currentDevicePosition?.latitude != lastPosition.latitude ||
              _currentDevicePosition?.longitude != lastPosition.longitude) {
            _currentDevicePosition = lastPosition;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateMapMarkers();
              if (lastPosition.latitude != null) {
                _fetchStreetName(
                  lastPosition.latitude!.toDouble(),
                  lastPosition.longitude!.toDouble(),
                  lastPosition,
                );
              }
            });
          }

          return Stack(
            children: [
              MapLibreMap(
                key: ValueKey(Provider.of<MapStyleProvider>(context).isSatelliteMode),
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    (lastPosition.latitude?.toDouble() ?? 0.0) -
                        _mapCenterOffset,
                    lastPosition.longitude?.toDouble() ?? 0.0,
                  ),
                  zoom: 14.0,
                ),
                styleString: Provider.of<MapStyleProvider>(context).styleString,
                onMapCreated: _onMapCreated,
                onStyleLoadedCallback: () {
                  _isStyleLoaded = true;
                  _loadedIcons.clear();
                  _updateMapMarkers();
                },
                onCameraTrackingDismissed: () =>
                    setState(() => _isCameraLocked = false),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  onPressed: () {
                    Provider.of<MapStyleProvider>(context, listen: false).toggleMapType();
                  },
                  child: Icon(
                    Provider.of<MapStyleProvider>(context).isSatelliteMode ? Icons.map : Icons.satellite_alt,
                    color: Colors.blue,
                  ),
                ),
              ),
              Positioned(
                top: 80,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    setState(() => _isCameraLocked = true);
                    if (_currentDevicePosition != null &&
                        _mapController != null) {
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLng(
                          LatLng(
                            _currentDevicePosition!.latitude!.toDouble() -
                                _mapCenterOnset,
                            _currentDevicePosition!.longitude!.toDouble(),
                          ),
                        ),
                      );
                    }
                  },
                  child: Icon(
                    _isCameraLocked ? Icons.gps_fixed : Icons.gps_not_fixed,
                    color: _isCameraLocked ? Colors.blue : Colors.grey,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomSheet: _buildBottomSheet(context),
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    return Consumer<TraccarProvider>(
      builder: (context, provider, child) {
        final lastPosition = provider.positions.firstWhere(
          (p) => p.deviceId == widget.selectedDevice.id,
          orElse: () => Position(),
        );
        final bool isStale = _checkIsStale(widget.selectedDevice, lastPosition);
        final attributes =
            lastPosition.attributes as Map<String, dynamic>? ?? {};
        final bool isIgnitionOn = attributes['ignition'] == true;

        final Color themeColor = isStale
            ? Colors.blueGrey.shade300
            : (isIgnitionOn
                  ? const Color(0xFF10B981)
                  : const Color(0xFFD97706));

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.selectedDevice.name ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Display either API or Offline street name
                        Text(
                          _currentStreetName,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isStale
                          ? 'deviceStatusOffline'.tr
                          : (isIgnitionOn
                                ? 'positionIgnition'.tr
                                : 'alarmParking'.tr),
                      style: TextStyle(
                        color: themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoItem(
                    Icons.speed,
                    '${((lastPosition.speed ?? 0) * 1.852).toStringAsFixed(1)}',
                    'km/h',
                  ),
                  // UPDATED: Precise Timestamp Formatting
                  _buildInfoItem(
                    Icons.access_time_rounded,
                    widget.selectedDevice.lastUpdate != null
                        ? DateFormat('yyyy-MM-dd HH:mm:ss').format(
                            widget.selectedDevice.lastUpdate!.toLocal(),
                          )
                        : '--',
                    'Last Update',
                  ),
                  if (attributes.containsKey('batteryLevel'))
                    _buildInfoItem(
                      Icons.battery_std,
                      '${attributes['batteryLevel']}%',
                      'Battery',
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label) => Column(
    children: [
      Icon(icon, color: Colors.blueGrey[400], size: 20),
      const SizedBox(height: 8),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
    ],
  );

  void _onSymbolTapped(Symbol symbol) {
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildBottomSheet(context),
      );
    }
  }

  Future<void> _fetchUserEmailFromApi() async {
    try {
      final traccarProvider = Provider.of<TraccarProvider>(
        context,
        listen: false,
      );
      final sessionApi = SessionApi(traccarProvider.apiClient);
      final user = await sessionApi.sessionGet();
      if (mounted) {
        _cachedUserEmail = user?.email ?? _cachedUserEmail;
      }
    } catch (e) {
      debugPrint('Error fetching email: $e');
    }
  }
}