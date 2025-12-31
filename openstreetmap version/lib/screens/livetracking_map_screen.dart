// lib/screens/livetracking_map_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'dart:convert';
import 'package:timeago/timeago.dart' as timeago;

// ... (NominatimService class remains the same)

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
      '$_nominatimBaseUrl?lat=$lat&lon=$lon&format=json&zoom=18&addressdetails=1',
    );

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
        final streetName =
            address?['road'] as String? ??
            address?['footway'] as String? ??
            address?['cycleway'] as String? ??
            result['display_name']
                as String? ?? // Fallback to full display name
            defaultValue;

        // 3. Save to Cache (Hive)
        await _geocodeBox.put(key, streetName);
        return streetName;
      } else {
        throw Exception(
          'Failed to load address from Nominatim: ${response.statusCode}',
        );
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
  MapLibreMapController? _mapController;
  Position? _currentDevicePosition;
  bool _isCameraLocked = true;
  bool _isGeocodeServiceInitialized = false;
  bool _isStyleLoaded = false; // TRACK STYLE LOAD STATE
  bool _isSatelliteMode = false;
  double _mapCenterOffset = 0.007; //0.005
  double _mapCenterOnset = 0.008;

  late NominatimService _nominatimService;
  String _currentStreetName = 'Fetching Address...'.tr;
  DateTime _lastNominatimNetworkFetch = DateTime.fromMillisecondsSinceEpoch(0);
  String _cachedUserEmail = 'kevin16iwin@gmail.com';
  final http.Client _httpClient = http.Client();
  final Set<String> _loadedIcons = {}; // Cache for your 224 png markers
  static const String _streetStyle =
      "https://tiles.openfreemap.org/styles/liberty";
  // OpenFreeMap doesn't host raw satellite imagery directly for free without keys,
  // so we use a public MapLibre-compatible imagery URL if you have one,
  // OR we switch between OpenFreeMap Liberty and OpenFreeMap Positron.
  // If you want actual Satellite, you can use this public ESRI one (No Key needed):
  static const String _satelliteStyle =
      '{"version": 8, "sources": {"raster-tiles": {"type": "raster", "tiles": ["https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"], "tileSize": 256, "attribution": "Tiles &copy; Esri"}}, "layers": [{"id": "simple-tiles", "type": "raster", "source": "raster-tiles", "minzoom": 0, "maxzoom": 18}]}';
  static const String _openFreeMapStyle =
      "https://tiles.openfreemap.org/styles/liberty";

  @override
  void initState() {
    super.initState();
    _setupTimeagoLocales();
    _nominatimService = NominatimService(httpClient: _httpClient);
    _nominatimService.init().then((_) {
      if (mounted) setState(() => _isGeocodeServiceInitialized = true);
    });
    _fetchUserEmailFromApi();
  }

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

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    _mapController!.onSymbolTapped.add(_onSymbolTapped);
  }

  void _onStyleLoaded() async {
    setState(() => _isStyleLoaded = true);
    // Initial draw
    _updateMapMarkers();
  }

  // Load specific PNG from your 224 items only when needed
  Future<void> _ensureIconLoaded(String iconKey) async {
    if (_mapController == null || _loadedIcons.contains(iconKey)) return;

    try {
      final String assetPath = 'assets/images/$iconKey.png';
      debugPrint("🔍 Attempting to load asset: $assetPath");
      final ByteData bytes = await rootBundle.load(assetPath);
      final Uint8List list = bytes.buffer.asUint8List();

      // Confirm bytes are not empty
      debugPrint("📊 Asset loaded successfully: ${list.length} bytes");

      // MapLibre requires the image to be added to the style
      await _mapController!.addImage(iconKey, list);
      _loadedIcons.add(iconKey);

      debugPrint(
        "✅ Icon '$iconKey' successfully registered in MapLibre style.",
      );

      // Small delay to ensure the GPU/engine registers the new sprite
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      debugPrint("❌ Failed to load icon '$iconKey': $e");
      debugPrint("Could not load icon $iconKey: $e. Falling back to default.");
      if (iconKey != 'marker_default_unknown') {
        await _ensureIconLoaded('marker_default_unknown');
      }
    }
  }

  void _updateMapMarkers() async {
    if (_mapController == null ||
        _currentDevicePosition == null ||
        !_isStyleLoaded) {
      debugPrint("🕒 Map or position not ready for marker update.");
      return;
    }

    final String category = widget.selectedDevice.category ?? 'default';
    final String status = widget.selectedDevice.status ?? 'unknown';
    final String iconKey =
        'marker_${category.toLowerCase()}_${status.toLowerCase()}';

    await _ensureIconLoaded(iconKey);

    final String finalKey = _loadedIcons.contains(iconKey)
        ? iconKey
        : 'marker_default_unknown';
    debugPrint("📍 Adding symbol to map using key: $finalKey");

    await _mapController!.clearSymbols();
    await _mapController!.addSymbol(
      SymbolOptions(
        geometry: LatLng(
          _currentDevicePosition!.latitude!.toDouble(),
          _currentDevicePosition!.longitude!.toDouble(),
        ),
        iconImage: finalKey,
        iconRotate: _currentDevicePosition!.course?.toDouble() ?? 0.0,
        iconSize: 3, // Slightly larger for better visibility
        iconOpacity: 1.0,
        // // Added text styling to ensure visibility
        // textField: widget.selectedDevice.name,
        // textOffset: const Offset(0, 2.5),
        // textSize: 14.0,
        // textColor: '#FF0000', // Red text for debugging
        // textHaloColor: '#FFFFFF',
        // textHaloWidth: 2.0,
      ),
    );

    if (_isCameraLocked) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(
            _currentDevicePosition!.latitude!.toDouble() -
                _mapCenterOffset, // APPLY OFFSET HERE
            _currentDevicePosition!.longitude!.toDouble(),
          ),
        ),
      );
    } else {
      debugPrint("🔓 Camera is UNLOCKED. Skipping movement.");
    }
  }

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

      if (cachedAddress != null &&
          mounted &&
          cachedAddress != _currentStreetName) {
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
      userEmail: userEmail, // Pass dynamic user email
    );

    // 4. Update state with result
    if (mounted && resultAddress != _currentStreetName) {
      setState(() {
        _currentStreetName = resultAddress;
      });
    }
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

          // IMPORTANT: If position changed, update the marker
          if (_currentDevicePosition?.latitude != lastPosition.latitude ||
              _currentDevicePosition?.longitude != lastPosition.longitude) {
            _currentDevicePosition = lastPosition;

            // Schedule update after the frame to avoid build-phase errors
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateMapMarkers();
              if (lastPosition.latitude != null) {
                _fetchStreetName(
                  lastPosition.latitude!.toDouble(),
                  lastPosition.longitude!.toDouble(),
                );
              }
            });
          }

          return Stack(
            children: [
              MapLibreMap(
                key: ValueKey(_isSatelliteMode),
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    (lastPosition.latitude?.toDouble() ?? 0.0) -
                        _mapCenterOffset, // APPLY OFFSET HERE
                    lastPosition.longitude?.toDouble() ?? 0.0,
                  ),
                  zoom: 14.0,
                ),
                //styleString: _openFreeMapStyle,
                styleString: _isSatelliteMode ? _satelliteStyle : _streetStyle,
                onMapCreated: _onMapCreated,
                // onStyleLoadedCallback: _onStyleLoaded,
                onStyleLoadedCallback: () {
                  _isStyleLoaded = true;
                  _loadedIcons
                      .clear(); // Clear icon cache to force reload on new style
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
                    setState(() {
                      _isSatelliteMode = !_isSatelliteMode;
                      _isStyleLoaded =
                          false; // Reset flag to trigger marker reload
                      _loadedIcons.clear();
                    });
                  },
                  child: Icon(
                    _isSatelliteMode ? Icons.map : Icons.satellite_alt,
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
                    setState(() {
                      _isCameraLocked = true;
                    });
                    // Force an immediate camera move to the last known position
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

  // ... (Rest of your helper methods like _fetchUserEmailFromApi, _buildBottomSheet, etc.)
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
            ? ' • ${timeago.format(
                widget.selectedDevice.lastUpdate!,
                // Use Get.locale?.languageCode to get the active language code
                // Default to 'en' if Get.locale is null
                locale: Get.locale?.languageCode ?? 'en',
              )}'
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
                crossAxisAlignment:
                    CrossAxisAlignment.start, // Align items to the top
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
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withOpacity(0.6),
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

  void _onSymbolTapped(Symbol symbol) {
    debugPrint("🎯 Symbol Tapped: ${symbol.id}");

    // This replaces the Google Maps "InfoWindow"
    // It opens the bottom detail sheet when the icon is clicked
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildBottomSheet(context),
      );
    }
  }

  // NEW: Dedicated method to fetch user email using the API client
  Future<void> _fetchUserEmailFromApi() async {
    try {
      final traccarProvider = Provider.of<TraccarProvider>(
        context,
        listen: false,
      );
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
}
