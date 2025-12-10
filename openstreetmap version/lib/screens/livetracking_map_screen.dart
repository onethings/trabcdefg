// lib/screens/livetracking_map_screen.dart
// LiveTrackingMapScreen with OpenStreetMap and Tile Caching

import 'dart:async';
import 'package:flutter/material.dart';
// REMOVED: import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart'; // Primary map package for OpenStreetMap
import 'package:latlong2/latlong.dart' as latlong; // LatLong for FlutterMap coordinates
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
// REMOVED: import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'dart:typed_data';
import 'package:hive/hive.dart'; // For Caching
import 'package:http/http.dart' as http; // For Caching
import 'dart:math'; // Required for math operations like pi/radians in marker rotation
import 'dart:convert'; // ADDED for JSON decoding
import 'package:timeago/timeago.dart' as timeago; // ADDED: Timeago import
// REMOVED: import 'package:shared_preferences/shared_preferences.dart'; // Removed: Email now from API

// ADDED: Enum for managing map types
enum AppMapType {
  openStreetMap,
  satellite,
}

// --- Tile Caching Implementation using Hive ---

class _TileCacheService {
  late Box<Uint8List> _tileBox;
  static const String boxName = 'mapTilesCache';

  Future<void> init() async {
    _tileBox = await Hive.openBox<Uint8List>(boxName);
  }

  String _generateKey(String url) {
    return url.hashCode.toString();
  }

  Future<Uint8List?> getTile(String url) async {
    return _tileBox.get(_generateKey(url));
  }

  Future<void> saveTile(String url, Uint8List tileData) async {
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

  @override
  Future<CachedNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
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
        throw Exception(
            'Failed to load tile from network: ${response.statusCode}');
      }
    } catch (e) {
      // If network fails, rethrow, or you could try a local fallback tile.
      rethrow;
    }
  }
}

// --- End of Tile Caching Implementation ---


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

  // Key is the rounded lat,lon string (e.g., '40.758,-73.985')
  String _generateKey(double lat, double lon) {
    // Rounding to 3 decimal places for ~100m precision
    final roundedLat = lat.toStringAsFixed(3);
    final roundedLon = lon.toStringAsFixed(3);
    return '$roundedLat,$roundedLon';
  }

  // MODIFIED: Added appName and userEmail parameters
  Future<String> fetchStreetName({
    required double lat,
    required double lon,
    required String defaultValue,
    required String langCode,
    required String appName, // NEW: Device name (or app name)
    required String userEmail, // NEW: User's email
  }) async {
    final key = _generateKey(lat, lon);

    // 1. Check Hive Cache (always)
    String? cachedAddress = _geocodeBox.get(key);
    if (cachedAddress != null) {
      return cachedAddress;
    }

    // 2. Fetch from Nominatim Network
    // IMPORTANT: Note the use of the full lat/lon in the request, but the rounded key for caching.
    final url = Uri.parse(
        '$_nominatimBaseUrl?lat=$lat&lon=$lon&format=json&zoom=18&addressdetails=1');

    try {
      final response = await _httpClient.get(
        url,
        headers: {
          // MODIFIED: Use dynamic appName and userEmail as requested
          'User-Agent': '$appName/1.0 ($userEmail)', 
          // NEW: Accept-Language header to request names in the user's language
          'Accept-Language': langCode,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> result =
            json.decode(response.body) as Map<String, dynamic>;
        
        // Try to extract a specific street-level name (road, footway, cycleway)
        final address = result['address'] as Map<String, dynamic>?;
        final streetName = address?['road'] as String? ??
            address?['footway'] as String? ??
            address?['cycleway'] as String? ??
            result['display_name'] as String? ?? // Fallback to full display name
            defaultValue;

        // 3. Save to Cache (Hive)
        await _geocodeBox.put(key, streetName);
        return streetName;
      } else {
        throw Exception(
            'Failed to load address from Nominatim: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Nominatim Service Error: $e');
      }
      return 'Geocoding Failed'.tr;
    }
  }
}

// --- End of Reverse Geocoding Service Implementation ---


class LiveTrackingMapScreen extends StatefulWidget {
  final Device selectedDevice;
  const LiveTrackingMapScreen({super.key, required this.selectedDevice});

  @override
  State<LiveTrackingMapScreen> createState() => _LiveTrackingMapScreenState();
}

class _LiveTrackingMapScreenState extends State<LiveTrackingMapScreen> {
  final MapController _flutterMapController = MapController();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<latlong.LatLng> _polylineCoordinates = [];
  AppMapType _mapType = AppMapType.openStreetMap;

  Position? _currentDevicePosition; 
  
  bool _isCameraLocked = true;

  // Placeholder for marker icon loading state
  bool _customIconsLoaded = false;

  // Caching variables
  final _TileCacheService _cacheService = _TileCacheService();
  final http.Client _httpClient = http.Client();
  late _HiveTileProvider _tileProvider;
  bool _isCacheInitialized = false;

  // ADDED: Geocoding Service variables
  late NominatimService _nominatimService;
  String _currentStreetName = 'Fetching Address...'.tr;
  bool _isGeocodeServiceInitialized = false;

  // NEW: Rate limiting for Nominatim network calls. Initialized to epoch to allow the first fetch.
  DateTime _lastNominatimNetworkFetch = DateTime.fromMillisecondsSinceEpoch(0);

  // NEW: Cached user email for the User-Agent header (fetched once from API)
  String _cachedUserEmail = 'kevin16iwin@gmail.com';

  // --- Tile URLs for different map types ---
  static const String _osmUrlTemplate =
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _satelliteUrlTemplate =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const List<String> _osmSubdomains = ['a', 'b', 'c'];

  // NEW: Function to register the timeago locale messages
  void _setupTimeagoLocales() {
    // The 'en' (English) and 'es' (Spanish) messages are loaded by default.
    // Register other languages your app supports here by calling the class directly 
    // from the timeago alias.
    
   // Afrikaans
    // timeago.setLocaleMessages('af', timeago.AfMessages());
    // Arabic
    // 'ar' and 'ar_SA' often use the same message class if not distinguished
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    // Azerbaijani
    timeago.setLocaleMessages('az', timeago.AzMessages());
    // Bulgarian
    // timeago.setLocaleMessages('bg', timeago.BgMessages());
    // Bengali
    timeago.setLocaleMessages('bn', timeago.BnMessages());
    // Catalan
    timeago.setLocaleMessages('ca', timeago.CaMessages());
    // Czech
    timeago.setLocaleMessages('cs', timeago.CsMessages());
    // Danish
    timeago.setLocaleMessages('da', timeago.DaMessages());
    // German (de)
    timeago.setLocaleMessages('de', timeago.DeMessages());
    // Greek
    // timeago.setLocaleMessages('el', timeago.ElMessages());
    // English Short (en_short is used for 'en_US' if en_USMessages is not available)
    timeago.setLocaleMessages('en_short', timeago.EnShortMessages());
    // Estonian
    timeago.setLocaleMessages('et', timeago.EtMessages());
    // Farsi / Persian
    timeago.setLocaleMessages('fa', timeago.FaMessages());
    // Finnish
    timeago.setLocaleMessages('fi', timeago.FiMessages());
    // French
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    // Galician
    // timeago.setLocaleMessages('gl', timeago.GlMessages());
    // Hebrew
    timeago.setLocaleMessages('he', timeago.HeMessages());
    // Hindi
    timeago.setLocaleMessages('hi', timeago.HiMessages());
    // Croatian
    timeago.setLocaleMessages('hr', timeago.HrMessages());
    // Hungarian
    timeago.setLocaleMessages('hu', timeago.HuMessages());
    // Armenian
    // timeago.setLocaleMessages('hy', timeago.HyMessages());
    // Indonesian
    timeago.setLocaleMessages('id', timeago.IdMessages());
    // Italian
    timeago.setLocaleMessages('it', timeago.ItMessages());
    // Japanese
    timeago.setLocaleMessages('ja', timeago.JaMessages());
    // Georgian
    // timeago.setLocaleMessages('ka', timeago.KaMessages());
    // Kazakh
    // timeago.setLocaleMessages('kk', timeago.KkMessages());
    // Khmer
    timeago.setLocaleMessages('km', timeago.KmMessages());
    // Korean
    timeago.setLocaleMessages('ko', timeago.KoMessages());
    // Lao
    // timeago.setLocaleMessages('lo', timeago.LoMessages());
    // Lithuanian
    // timeago.setLocaleMessages('lt', timeago.LtMessages());
    // Latvian
    timeago.setLocaleMessages('lv', timeago.LvMessages());
    // Macedonian
    // timeago.setLocaleMessages('mk', timeago.MkMessages());
    // Malayalam
    // timeago.setLocaleMessages('ml', timeago.MlMessages());
    // Mongolian
    timeago.setLocaleMessages('mn', timeago.MnMessages());
    // Malay (ms)
    // timeago.setLocaleMessages('ms', timeago.MsMessages());
    // Norwegian Bokmål
    // timeago.setLocaleMessages('nb', timeago.NbMessages());
    // Nepali
    // timeago.setLocaleMessages('ne', timeago.NeMessages());
    // Dutch
    timeago.setLocaleMessages('nl', timeago.NlMessages());
    // Norwegian Nynorsk
    // timeago.setLocaleMessages('nn', timeago.NnMessages());
    // Polish
    timeago.setLocaleMessages('pl', timeago.PlMessages());
    // Portuguese (Brazil)
    timeago.setLocaleMessages('pt_BR', timeago.PtBrMessages());
    // Portuguese (Portugal/General)
    // timeago.setLocaleMessages('pt', timeago.PtMessages());
    // Romanian
    timeago.setLocaleMessages('ro', timeago.RoMessages());
    // Russian
    timeago.setLocaleMessages('ru', timeago.RuMessages());
    // Sinhala
    // timeago.setLocaleMessages('si', timeago.SiMessages());
    // Slovak
    // timeago.setLocaleMessages('sk', timeago.SkMessages());
    // Slovenian
    // timeago.setLocaleMessages('sl', timeago.SlMessages());
    // Albanian
    // timeago.setLocaleMessages('sq', timeago.SqMessages());
    // Serbian
    timeago.setLocaleMessages('sr', timeago.SrMessages());
    // Swedish
    timeago.setLocaleMessages('sv', timeago.SvMessages());
    // Swahili
    // timeago.setLocaleMessages('sw', timeago.SwMessages());
    // Tamil
    timeago.setLocaleMessages('ta', timeago.TaMessages());
    // Thai
    timeago.setLocaleMessages('th', timeago.ThMessages());
    // Turkmen
    timeago.setLocaleMessages('tk', timeago.TkMessages());
    // Turkish
    timeago.setLocaleMessages('tr', timeago.TrMessages());
    // Ukrainian
    timeago.setLocaleMessages('uk', timeago.UkMessages());
    // Uzbek
    // timeago.setLocaleMessages('uz', timeago.UzMessages());
    // Vietnamese
    timeago.setLocaleMessages('vi', timeago.ViMessages());
    // Simplified Chinese
    timeago.setLocaleMessages('zh', timeago.ZhMessages());
    // Traditional Chinese
    // timeago.setLocaleMessages('zh_TW', timeago.ZhTwMessages());
  }


  @override
  void initState() {
    super.initState();

        // NEW: Register locales once when the state is initialized
    _setupTimeagoLocales(); 

    // Initialize Tile Cache Service
    _cacheService.init().then((_) {
      _tileProvider = _HiveTileProvider(
        cacheService: _cacheService,
        httpClient: _httpClient,
      );
      if (mounted) {
        setState(() {
          _isCacheInitialized = true;
        });
      }
    });
    
    // ADDED: Initialize Geocoding Service
    _nominatimService = NominatimService(httpClient: _httpClient);
    _nominatimService.init().then((_) {
      if (mounted) {
        setState(() {
          _isGeocodeServiceInitialized = true;
        });
        
        // **FIX: Trigger initial fetch only when service is ready**
        if (_currentDevicePosition?.latitude != null &&
            _currentDevicePosition?.longitude != null) {
          _fetchStreetName(
            _currentDevicePosition!.latitude!.toDouble(),
            _currentDevicePosition!.longitude!.toDouble(),
          );
        }
      }
    });

    _loadMarkerIcons(); // Re-called to set the flag
    _fetchUserEmailFromApi(); // NEW: Fetch email right away

    // Initial position lookup (only sets the variable, no fetch)
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    _currentDevicePosition = traccarProvider.positions.firstWhere(
      (pos) => pos.deviceId == widget.selectedDevice.id,
      orElse: () => Position(),
    );
  }

  @override
  void didUpdateWidget(covariant LiveTrackingMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );

    final newPosition = traccarProvider.positions.firstWhere(
      (pos) => pos.deviceId == widget.selectedDevice.id,
      orElse: () => Position(),
    );

    // Only update the map if the position data has actually changed
    if (newPosition.id != _currentDevicePosition?.id) {
      _currentDevicePosition = newPosition;
      _updateMap(newPosition);
      // ADDED: Fetch street name when position changes
      if (newPosition.latitude != null && newPosition.longitude != null) {
        _fetchStreetName(
          newPosition.latitude!.toDouble(), // Ensure double
          newPosition.longitude!.toDouble(), // Ensure double
        );
      }
    }
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }
  
  // NEW: Dedicated method to fetch user email using the API client
  Future<void> _fetchUserEmailFromApi() async {
    try {
      final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
      // Use the public apiClient field from the provider
      final sessionApi = SessionApi(traccarProvider.apiClient); 
      
      final user = await sessionApi.sessionGet();
      
      // FIX: Corrected the null access issue on 'user' and 'user.email'
      if (mounted) {
        // Use null-aware operator to safely access email, keeping the old email if the new one is null
        _cachedUserEmail = user?.email ?? _cachedUserEmail; 
        
        if (kDebugMode && user?.email != null) {
          print('Successfully fetched user email: $_cachedUserEmail');
        }
      }
    } on ApiException catch (e) {
      if (kDebugMode) {
        print('Failed to fetch user email from API: ${e.message}');
      }
      // Keep the fallback 'anonymous@example.com'
    } catch (e) {
       if (kDebugMode) {
        print('Unexpected error fetching user email: $e');
      }
    }
  }

  // REINTRODUCED/MODIFIED: Marker icon loading logic
  Future<void> _loadMarkerIcons() async {
    // In a FlutterMap context, this method usually ensures all asset paths
    // are known or performs pre-caching if needed. Here, we just set the flag
    // to signal the assets are ready for use via Image.asset.
    await Future.delayed(Duration.zero); // Simulate an async load operation

    if (mounted) {
      setState(() {
        _customIconsLoaded = true;
      });
    }
  }

  // MODIFIED: Logic now retrieves user email from the cached variable
  Future<void> _fetchStreetName(double lat, double lon) async {
    if (!_isGeocodeServiceInitialized) return;

    final now = DateTime.now();
    const Duration minimumInterval = Duration(seconds: 30);
    
    // 1. Check Rate Limit
    if (now.difference(_lastNominatimNetworkFetch) < minimumInterval) {
      // Rate-limited: check cache for immediate update before skipping network call
      final key = _nominatimService._generateKey(lat, lon);
      // Accessing private member _geocodeBox is necessary here as it is internal to the package/file
      final cachedAddress = await _nominatimService._geocodeBox.get(key);
      
      if (cachedAddress != null && mounted && cachedAddress != _currentStreetName) {
          setState(() {
            _currentStreetName = cachedAddress;
          });
      }
      // Skip network request
      return;
    }

    // 2. Rate limit passed: Update timestamp *before* making the network call
    _lastNominatimNetworkFetch = now;
    
    // Get the current locale code from GetX (e.g., 'en', 'es_419')
    final String langCode = Get.locale?.toLanguageTag() ?? 'en'; 

    // Use the cached email fetched from the Traccar API
    final userEmail = _cachedUserEmail; 
    final deviceName = widget.selectedDevice.name ?? 'TraccarApp'; 
    
    // Use a static, application-wide identifier for Nominatim requests
    const String applicationIdentifier = 'TrabcdefgMobileApp'; 

    final String userAgentString = '$applicationIdentifier/1.0 ($userEmail)';
    
    if (kDebugMode) {
      print('Nominatim Request User-Agent: $userAgentString');
    }

    // 3. Call service
    final resultAddress = await _nominatimService.fetchStreetName(
      lat: lat,
      lon: lon,
      defaultValue: 'Address not found'.tr,
      langCode: langCode,
      appName: applicationIdentifier, // Pass the static identifier
      userEmail: userEmail,           // Pass dynamic user email
    );

    // 4. Update state with result
    if (mounted && resultAddress != _currentStreetName) {
      setState(() {
        _currentStreetName = resultAddress;
      });
    }
  }

  String _getTranslatedStatus(String? status) {
    if (status == null) return 'N/A';

    switch (status.toLowerCase()) {
      case 'online':
        return 'deviceStatusOnline'.tr;
      case 'offline':
      case 'idle':
        return 'alarmIdle'.tr;
      case 'static':
        return 'alarmParking'.tr;
      case 'unknown':
      default:
        return 'deviceStatusUnknown'.tr;
    }
  }

  void _updateMap(Position? currentPosition) {
    // Ensure all prerequisites are met before attempting to update the map
    if (!_isCacheInitialized ||
        !_customIconsLoaded || // Check the icon loading flag
        currentPosition == null ||
        currentPosition.latitude == null ||
        currentPosition.longitude == null) {
      return;
    }

    final newPosition = latlong.LatLng(
      currentPosition.latitude!.toDouble(), // Ensure double
      currentPosition.longitude!.toDouble(), // Ensure double
    );

    setState(() {
      _markers.clear();

      // Add new position to polyline if different from the last point
      if (_polylineCoordinates.isEmpty ||
          _polylineCoordinates.last != newPosition) {
        _polylineCoordinates.add(newPosition);
      }

      final String category = widget.selectedDevice.category ?? 'default';
      final String status = widget.selectedDevice.status ?? 'unknown';
      final double course = currentPosition.course?.toDouble() ?? 0.0;

      // Flutter Map Marker Implementation using Image.asset
      _markers.add(
        Marker(
          width: 50.0,
          height: 50.0,
          point: newPosition,
          // Marker rotation using Transform.rotate
          child: Transform.rotate(
            angle: course * (pi / 180),
            child: Tooltip(
              message: widget.selectedDevice.name ?? 'Device Location',
              child: Image.asset(
                'assets/images/marker_${category}_$status.png',
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.location_on),
              ),
            ),
          ),
        ),
      );

      _polylines.clear(); // Clear old polyline set
      _polylines.add(
        Polyline(
          points: _polylineCoordinates,
          color: Colors.blue,
          strokeWidth: 5,
        ),
      );
    });

    if (_isCameraLocked) {
      // Use MapController to move the map
      _flutterMapController.move(newPosition, _flutterMapController.camera.zoom);
    }
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == AppMapType.openStreetMap
          ? AppMapType.satellite
          : AppMapType.openStreetMap;
    });
  }

  Future<void> _recenter(Position? lastPosition) async {
    if (lastPosition == null ||
        lastPosition.latitude == null ||
        lastPosition.longitude == null) {
      return;
    }

    final position = latlong.LatLng(
      lastPosition.latitude!.toDouble(), // Ensure double
      lastPosition.longitude!.toDouble(), // Ensure double
    );

    setState(() {
      _isCameraLocked = true;
    });

    // Use MapController to move
    _flutterMapController.move(position, 17.0);
  }

  void _zoomIn() {
    // Use MapController to adjust zoom
    final currentZoom = _flutterMapController.camera.zoom;
    _flutterMapController.move(
      _flutterMapController.camera.center,
      currentZoom + 1.0,
    );
  }

  void _zoomOut() {
    // Use MapController to adjust zoom
    final currentZoom = _flutterMapController.camera.zoom;
    _flutterMapController.move(
      _flutterMapController.camera.center,
      currentZoom - 1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selectedDevice.name ?? 'mapLiveRoutes'.tr,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _mapType == AppMapType.satellite ? Icons.map : Icons.satellite,
            ),
            onPressed: _toggleMapType,
          ),
        ],
      ),
      body: Consumer<TraccarProvider>(
        builder: (context, traccarProvider, child) {
          final lastPosition = traccarProvider.positions.firstWhere(
            (pos) => pos.deviceId == widget.selectedDevice.id,
            orElse: () => Position(),
          );

          // Handle initial position
          latlong.LatLng initialLatLng = const latlong.LatLng(0, 0);
          if (lastPosition.latitude != null && lastPosition.longitude != null) {
            initialLatLng = latlong.LatLng(
              lastPosition.latitude!.toDouble(), // Ensure double
              lastPosition.longitude!.toDouble(), // Ensure double
            );
          }

          // Show loading spinner if cache, icons, or initial data is not ready
          if (!_isCacheInitialized ||
              !_customIconsLoaded ||
              !_isGeocodeServiceInitialized || // ADDED: Check geocode service initialization
              (traccarProvider.isLoading && _polylineCoordinates.isEmpty)) {
            return const Center(child: CircularProgressIndicator());
          }

          // Force an update call after build, safe since the initial fetch is linked to init
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateMap(lastPosition);
            // Re-call fetch on subsequent builds if position exists, but it's now guarded by the 30-second limit
            if (lastPosition.latitude != null && lastPosition.longitude != null) {
              _fetchStreetName(
                lastPosition.latitude!.toDouble(), 
                lastPosition.longitude!.toDouble(),
              );
            }
          });


          return Stack(
            children: [
              // REPLACED: GoogleMap with FlutterMap
              FlutterMap(
                mapController: _flutterMapController,
                options: MapOptions(
                  initialCenter: initialLatLng,
                  initialZoom: 14.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture) {
                      setState(() {
                        _isCameraLocked = false;
                      });
                    }
                  },
                  onTap: (tapPosition, latLng) {
                    // Optionally close a bottom sheet if one were present
                  },
                ),
                children: [
                  // Tile Layer with Caching
                  TileLayer(
                    urlTemplate: _mapType == AppMapType.openStreetMap
                        ? _osmUrlTemplate
                        : _satelliteUrlTemplate,
                    subdomains: _mapType == AppMapType.openStreetMap
                        ? _osmSubdomains
                        : const [],
                    userAgentPackageName: 'com.trabcdefg.app',
                    tileProvider: _tileProvider, // Use the custom cached provider
                  ),
                  // Polyline Layer for routes
                  PolylineLayer(polylines: _polylines.toList()),
                  // Marker Layer for device position
                  MarkerLayer(markers: _markers.toList()),
                ],
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: Column(
                  children: [
                    FloatingActionButton(
                      heroTag: "zoomIn",
                      mini: true,
                      onPressed: _zoomIn,
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: "zoomOut",
                      mini: true,
                      onPressed: _zoomOut,
                      child: const Icon(Icons.remove),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: "recenter",
                      mini: true,
                      onPressed: () => _recenter(lastPosition),
                      child: const Icon(Icons.my_location),
                    ),
                  ],
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
          (pos) => pos.deviceId == widget.selectedDevice.id,
          orElse: () => Position(),
        );
        // Traccar speed is in knots (nautical miles per hour). 1 knot = 1.852 km/h
        final speedKmh = lastPosition.speed != null
            ? (lastPosition.speed!.toDouble() * 1.852).toStringAsFixed(2)
            : 'N/A';
        final attributes =
            lastPosition.attributes as Map<String, dynamic>? ?? {};
        final translatedStatus = _getTranslatedStatus(
          widget.selectedDevice.status,
        );

        // START OF USER UPDATE
        // Get time ago string, checking for null lastUpdate
        final timeAgoString = widget.selectedDevice.lastUpdate != null
            ? ' • ${timeago.format(widget.selectedDevice.lastUpdate!,
                        // Use Get.locale?.languageCode to get the active language code
                        // Default to 'en' if Get.locale is null
                        locale: Get.locale?.languageCode ?? 'en',)}'
            : '';
        // END OF USER UPDATE

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                offset: Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.selectedDevice.name ?? 'Unknown Device',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8.0),
              // MODIFIED LINE: Added timeAgoString
              Text('deviceStatus'.tr + ': $translatedStatus$timeAgoString'),
              const SizedBox(height: 4.0),
              Text(
                'deviceLastUpdate'.tr +
                    ': ${lastPosition.deviceTime?.toLocal().toString().split('.').first ?? 'N/A'}',
              ),
              Text('positionSpeed'.tr + ': $speedKmh ' + 'sharedKmh'.tr),
              // ADDED: Street Name below speed with precision note
              Row( 
                crossAxisAlignment: CrossAxisAlignment.start, // Align items to the top
                children: [
                  // FIX: Wrap the Text widget in Expanded to force it to use available space and wrap.
                  Expanded( 
                    child: Text(
                      'positionAddress'.tr + ': $_currentStreetName',
                      // Optional: Set maxLines to 2 for a cleaner look, or leave it off to wrap infinitely.
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // The Tooltip/Icon remains outside the Expanded to preserve its size.
                  Tooltip(
                    message: 'addressPrecisionNote'.tr, 
                    child: Icon(
                      Icons.info_outline,
                      size: 14.0,
                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const Divider(),
              Text(
                'deviceSecondaryInfo'.tr + ':',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (attributes.containsKey('batteryLevel'))
                ListTile(
                  leading: const Icon(Icons.battery_std),
                  title: Text('positionBatteryLevel'.tr),
                  subtitle: Text('${attributes['batteryLevel']}%'),
                ),
              if (attributes.containsKey('totalDistance'))
                ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: Text('deviceTotalDistance'.tr),
                  subtitle: Text(
                    // Check for num type and safely convert
                    '${((attributes['totalDistance'] is num ? attributes['totalDistance'] : 0.0) / 1000).toStringAsFixed(2)} ' +
                        'sharedKm'.tr,
                  ),
                ),
              if (attributes.containsKey('engineHours'))
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: Text('reportEngineHours'.tr),
                  subtitle: Text(
                    // Check for num type and safely convert
                    '${((attributes['engineHours'] is num ? attributes['engineHours'] : 0.0) / 3600).toStringAsFixed(2)} ' +
                        'sharedHourAbbreviation'.tr,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}