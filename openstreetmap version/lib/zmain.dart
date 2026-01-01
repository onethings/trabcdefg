// lib/screens/history_route_screen.dart //3 weak ago
// HistoryRouteScreen with OpenStreetMap, Hive Tile Caching, and Reactive Playback Controls

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:async';
import 'package:get/get.dart'; // NEW: Used for reactive programming
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
// *** CALENDAR AND HIVE IMPORTS ***
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trabcdefg/models/report_summary_hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:trabcdefg/models/route_positions_hive.dart'; // Assuming you put the model here

// NEW: Custom Tile Provider for Hive Caching (Unchanged)
class HiveTileProvider extends TileProvider {
  static const String boxName = 'mapTilesCache';
  late Box<Uint8List> _tileBox;
  final String userAgent;

  HiveTileProvider({required this.userAgent})
    : super(headers: {'User-Agent': userAgent});

  Future<void> init() async {
    _tileBox = await Hive.openBox<Uint8List>(boxName);
  }

  Future<void> dispose() async {
    if (_tileBox.isOpen) {
      await _tileBox.close();
    }
  }

  String _getTileKey(String url) {
    return url.replaceAll(RegExp(r'[^\w]'), '_');
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final tileUrl = getTileUrl(coordinates, options);
    final hiveKey = _getTileKey(tileUrl);

    // 1. Check Hive Cache
    final cachedData = _tileBox.get(hiveKey);
    if (cachedData != null) {
      return MemoryImage(cachedData);
    }

    // 2. Fetch from Network
    _cacheTile(tileUrl, hiveKey);

    return NetworkImage(tileUrl, headers: headers);
  }

  Future<void> _cacheTile(String tileUrl, String hiveKey) async {
    try {
      final response = await http.get(Uri.parse(tileUrl), headers: headers);
      if (response.statusCode == 200) {
        await _tileBox.put(hiveKey, response.bodyBytes);
      }
    } catch (e) {
      // print('Failed to cache tile: $e');
    }
  }
}

// Utility function to be called once on app startup or screen load
Future<void> cleanExpiredRouteHistory() async {
  final routeBox = await Hive.openBox<RoutePositionsHive>('route_positions');
  const cacheDuration = Duration(days: 60);
  final DateTime expiryThreshold = DateTime.now().subtract(cacheDuration);

  final List<dynamic> expiredKeys = [];

  // Iterate over all keys in the box
  for (final key in routeBox.keys) {
    // Retrieve the entry directly using the key
    final entry = routeBox.get(key);

    // Check if the cache date is older than 60 days
    if (entry != null && entry.cachedAt.isBefore(expiryThreshold)) {
      expiredKeys.add(key);
    }
  }

  if (expiredKeys.isNotEmpty) {
    print('Deleting ${expiredKeys.length} expired route entries.');
    // Delete all expired entries in one batch operation
    await routeBox.deleteAll(expiredKeys);
  }
}

// NEW: Enum for Map Types (Unchanged)
enum OSMMapType { normal, satellite }

class HistoryRouteScreen extends StatefulWidget {
  const HistoryRouteScreen({super.key});

  @override
  State<HistoryRouteScreen> createState() => _HistoryRouteScreenState();
}

class _HistoryRouteScreenState extends State<HistoryRouteScreen> {
  MapController? mapController = MapController();

  final MapController _mapController = MapController();

  bool _isLatLngVisible(LatLng latLng, [double marginFraction = 0.1]) {
    // Check if mapController and its camera are available
    if (mapController == null || mapController!.camera.center == null)
      return false;

    // CORRECTED TYPE: MapCamera holds the current view state
    final MapCamera mapCamera = mapController!.camera;

    // visibleBounds is a property of MapCamera
    final LatLngBounds currentBounds = mapCamera.visibleBounds;

    final double minLat = currentBounds.south;
    final double maxLat = currentBounds.north;
    final double minLon = currentBounds.west;
    final double maxLon = currentBounds.east;

    final double latSpan = maxLat - minLat;
    final double lonSpan = maxLon - minLon;

    // Define the margin based on the span
    final double marginLat = latSpan * marginFraction;
    final double marginLon = lonSpan * marginFraction;

    // Check if the LatLng is within the bounds, MINUS the margin
    // If latLng is outside the margin area, the function returns false, triggering a pan.
    final bool isVisible =
        latLng.latitude >= minLat + marginLat &&
        latLng.latitude <= maxLat - marginLat &&
        latLng.longitude >= minLon + marginLon &&
        latLng.longitude <= maxLon - marginLon;

    return isVisible;
  }

  // REPLACED: List<Polyline> _polylines = []; (for main state management)
  // NEW: Reactive variables for isolated updates
  final RxList<Polyline> _polylinesRx = <Polyline>[].obs;

  // REPLACED: List<Marker> _markers = [];
  final RxList<Marker> _staticMarkersRx = <Marker>[].obs;

  List<api.Position> _positions = [];
  // MODIFIED: This is now a reactive list
  final RxList<api.Position> _movingPositionsRx = <api.Position>[].obs;

  // REPLACED: double _playbackPosition = 0.0;
  final RxDouble _playbackPositionRx = 0.0.obs;

  // REPLACED: Marker? _playbackMarker;
  final Rx<Marker?> _playbackMarkerRx = Rx<Marker?>(null);

  void _resetRotation() {
    if (mapController != null) {
      // Animate the rotation reset for a smooth transition back to North (0 degrees)
      mapController!.rotate(0.0);
    }
  }

  bool _isPlaying = false;
  Timer? _playbackTimer;
  bool _isTileProviderReady = false;

  Uint8List? _playbackMarkerIconBytes;
  Uint8List? _redDotMarkerIconBytes;
  Uint8List? _startMarkerIconBytes;
  Uint8List? _parkingMarkerIconBytes;
  Uint8List? _destinationMarkerIconBytes;
  final List<Uint8List?> _parkingMarkerIconBytesList = [];
  final double _customMarkerTargetSize = 24.0;
  final double _arrowMarkerTargetSize = 48.0;

  OSMMapType _mapType = OSMMapType.normal;
  double _currentZoomLevel = 15.0;

  // Device & Date State
  int? _deviceId;
  DateTime? _historyFrom;
  DateTime? _historyTo;
  String? _selectedDeviceName;

  // Calendar State
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedCalendarDay = DateTime.now();
  final Map<DateTime, api.ReportSummary> _dailySummaries = {};
  bool _isCalendarLoading = true;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  // Speed control
  double _playbackSpeed = 0.5;

  // NEW: Hive Tile Provider
  late HiveTileProvider _hiveTileProvider;
  static const String _userAgent =
      'TraccarClientApp'; // User agent for tile requests

  @override
  void initState() {
    super.initState();
    _initHiveTileProvider();

    Future.microtask(() async {
      await _loadCustomMarkerIcons(); // NOW AWAITED!

      // Also await the red dot creation if needed, though not essential for this bug
      _redDotMarkerIconBytes = await _createDotMarkerIcon(Colors.red);

      _loadInitialParamsAndFetch(); // This will now run AFTER icons are loaded
    });

    //   _loadCustomMarkerIcons();
    cleanExpiredRouteHistory();
    // Keep this for now, even though we remove dot markers from route,
    // it's a good utility function.
    // _createDotMarkerIcon(Colors.red).then((bytes) {
    //   _redDotMarkerIconBytes = bytes;
    // });
    // _loadInitialParamsAndFetch();
  }

  Future<void> _initHiveTileProvider() async {
    _hiveTileProvider = HiveTileProvider(userAgent: _userAgent);
    await _hiveTileProvider.init();
    if (mounted) {
      setState(() {
        _isTileProviderReady = true;
      });
    }
  }

  void _updateZoomLevel() async {
    if (mapController != null && mapController!.camera.zoom != null) {
      final zoom = mapController!.camera.zoom;
      if (mounted) {
        setState(() {
          _currentZoomLevel = zoom;
        });
      }
    }
  }

  void _zoom(double amount) {
    if (mapController != null) {
      final newZoom = mapController!.camera.zoom + amount;
      mapController!.move(
        mapController!.camera.center,
        newZoom.clamp(3.0, 18.0),
      );
    }
  }

  void _zoomIn() {
    if (_isPlaying) {
      _playbackTimer?.cancel();
    }

    _zoom(1.0);
    _updateZoomLevel();

    if (_isPlaying) {
      _togglePlayback();
      _togglePlayback();
    }
  }

  void _zoomOut() {
    if (_isPlaying) {
      _playbackTimer?.cancel();
    }

    _zoom(-1.0);
    _updateZoomLevel();

    if (_isPlaying) {
      _togglePlayback();
      _togglePlayback();
    }
  }

  // FIX: Refactored to return Uint8List instead of BitmapDescriptor
  Future<Uint8List?> _loadAssetIcon(String assetPath, double targetSize) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final imageData = byteData.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(
        imageData,
        targetHeight: targetSize.toInt(),
        targetWidth: targetSize.toInt(),
      );
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;
      final byteDataResized = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteDataResized!.buffer.asUint8List();
    } catch (e) {
      print('Error loading marker icon $assetPath: $e');
      return null;
    }
  }

  Future<void> _loadCustomMarkerIcons() async {
    _playbackMarkerIconBytes = await _loadAssetIcon(
      'assets/images/arrow.png',
      _arrowMarkerTargetSize,
    );
    _startMarkerIconBytes = await _loadAssetIcon(
      'assets/images/start.png',
      _customMarkerTargetSize,
    );
    // _parkingMarkerIconBytes = await _loadAssetIcon(
    //   'assets/images/parking.png',
    //   _customMarkerTargetSize,
    // );
    for (int i = 1; i <= 50; i++) {
      final assetPath = 'assets/images/p_$i.png';
      final bytes = await _loadAssetIcon(assetPath, _customMarkerTargetSize);
      _parkingMarkerIconBytesList.add(bytes);
    }
    _destinationMarkerIconBytes = await _loadAssetIcon(
      'assets/images/destination.png',
      _customMarkerTargetSize,
    );
  }

  Future<void> _loadInitialParamsAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceName = prefs.getString('selectedDeviceName');
    final deviceId = prefs.getInt('selectedDeviceId');
    final fromString = prefs.getString('historyFrom');
    final toString = prefs.getString('historyTo');

    DateTime defaultDate = DateTime.now();

    setState(() {
      _deviceId = deviceId;
      _focusedDay = defaultDate;
      _selectedCalendarDay = defaultDate;
      _selectedDeviceName = deviceName;

      if (fromString != null && toString != null) {
        _historyFrom = DateTime.tryParse(fromString)?.toLocal();
        _historyTo = DateTime.tryParse(toString)?.toLocal();
        if (_historyFrom != null) {
          _selectedCalendarDay = DateTime(
            _historyFrom!.year,
            _historyFrom!.month,
            _historyFrom!.day,
          );
        }
      } else {
        _historyFrom = DateTime(
          defaultDate.year,
          defaultDate.month,
          defaultDate.day,
          0,
          0,
          0,
        );
        _historyTo = DateTime(
          defaultDate.year,
          defaultDate.month,
          defaultDate.day,
          23,
          59,
          59,
        );
      }
    });

    if (_deviceId != null) {
      _fetchHistoryRoute();
      await _fetchMonthlyData(_focusedDay);
    } else {
      print('Missing device ID for history route.');
    }
  }

  Future<void> _fetchHistoryRoute({DateTime? selectedDay}) async {
    if (selectedDay != null) {
      _historyFrom = DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
        0,
        0,
        0,
      );
      _historyTo = DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
        23,
        59,
        59,
      );
    }

    if (_deviceId == null || _historyFrom == null || _historyTo == null) return;

    // Stop any existing playback and reset state
    _playbackTimer?.cancel();

    // Use setState for simple UI/non-map state changes
    setState(() {
      _isPlaying = false;
      _positions = []; // Non-reactive list cleared
      _playbackPositionRx.value = 0.0;
    });

    // Reset reactive map state
    _polylinesRx.value = [];
    _staticMarkersRx.value = [];
    _playbackMarkerRx.value = null;
    _movingPositionsRx.value = []; // Reactive list cleared

    List<api.Position> fetchedPositions = [];
    final todayKey = DateFormat('yyyy-MM-dd').format(_historyFrom!);
    final hiveKey = '$_deviceId-$todayKey';

    // 1. Open Hive Box and Check Cache
    final routeBox = await Hive.openBox<RoutePositionsHive>('route_positions');
    final cachedRoute = routeBox.get(hiveKey);

    const cacheDuration = Duration(days: 60);
    final isCacheValid =
        cachedRoute != null &&
        DateTime.now().difference(cachedRoute.cachedAt) < cacheDuration;

    if (isCacheValid) {
      // 1A. CACHE HIT: Load from Hive
      print('Loading route from Hive cache: $hiveKey');
      fetchedPositions = RoutePositionsHive.fromJsonList(
        cachedRoute!.positionsJson,
      );
    } else {
      // 1B. CACHE MISS / EXPIRED: Fetch from Network
      print('Fetching route from network: $hiveKey');
      final traccarProvider = Provider.of<TraccarProvider>(
        context,
        listen: false,
      );
      final positionsApi = api.PositionsApi(traccarProvider.apiClient);

      try {
        fetchedPositions =
            await positionsApi.positionsGet(
              deviceId: _deviceId,
              from: _historyFrom!.toUtc(),
              to: _historyTo!.toUtc(),
            ) ??
            [];

        // 2. Cache the new data
        if (fetchedPositions.isNotEmpty) {
          final newCache = RoutePositionsHive(
            dateKey: hiveKey,
            positionsJson: RoutePositionsHive.toJsonList(fetchedPositions),
            cachedAt: DateTime.now(),
          );
          await routeBox.put(hiveKey, newCache);
          print('Route cached successfully.');
        }
      } catch (e) {
        print('Network fetch failed: $e');
        // Optionally show error to user
      }
    }

    // 3. Update state with fetched/cached data
    if (mounted) {
      setState(() {
        _positions = fetchedPositions;
      });

      _movingPositionsRx.value = _positions
          .where((p) => (p.speed ?? 0.0) > 2.0)
          .toList();

      // *** NEW: Deterministic check for MapController readiness ***

      print("Awaiting map controller readiness to animate camera...");
      // This line will pause until the FlutterMap widget has rendered its first frame.

      // *** END NEW ***

      _drawFullRoute();

      if (_positions.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            // This calls the map controller only after the delay
            _animateCameraToRoute();
          }
        });
      }

      if (_positions.isNotEmpty) {
        _updatePlaybackMarker(animateCamera: false);
      }
    }
  }

  Future<void> _fetchMonthlyData(DateTime month) async {
    if (_deviceId == null) return;

    if (_dailySummaries.isNotEmpty &&
        month.month == _focusedDay.month &&
        month.year == _focusedDay.year)
      return;

    setState(() {
      _isCalendarLoading = true;
      _focusedDay = month;
    });

    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final reportsApi = api.ReportsApi(traccarProvider.apiClient);
    final dailyBox = await Hive.openBox<ReportSummaryHive>('daily_summaries');

    _dailySummaries.clear();
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    for (
      var date = firstDayOfMonth;
      date.isBefore(lastDayOfMonth.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))
    ) {
      final dayUtc = DateTime.utc(date.year, date.month, date.day);
      final String hiveKey =
          '$_deviceId-${DateFormat('yyyy-MM-dd').format(dayUtc)}';
      final cachedSummary = dailyBox.get(hiveKey);

      if (cachedSummary != null) {
        _dailySummaries[dayUtc] = api.ReportSummary(
          distance: cachedSummary.distance,
          averageSpeed: cachedSummary.averageSpeed,
          maxSpeed: cachedSummary.maxSpeed,
          spentFuel: cachedSummary.spentFuel,
        );
      }
    }

    setState(() {
      _isCalendarLoading = false;
    });

    for (
      var date = firstDayOfMonth;
      date.isBefore(lastDayOfMonth.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))
    ) {
      final dayUtc = DateTime.utc(date.year, date.month, date.day);

      if (_dailySummaries.containsKey(dayUtc)) continue;

      final from = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final to = DateTime(date.year, date.month, date.day, 23, 59, 59);
      final String hiveKey =
          '$_deviceId-${DateFormat('yyyy-MM-dd').format(dayUtc)}';

      try {
        final summary = await reportsApi.reportsSummaryGet(
          from.toUtc(),
          to.toUtc(),
          deviceId: [_deviceId!],
        );

        if (summary != null && summary.isNotEmpty) {
          final dailySummary = summary.first;

          _dailySummaries[dayUtc] = dailySummary;

          final newSummaryHive = ReportSummaryHive.fromApi(dailySummary);
          await dailyBox.put(hiveKey, newSummaryHive);

          if (mounted) setState(() {});
        }
      } catch (e) {
        print('Failed to fetch data for day $date: $e');
      }
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedCalendarDay = selectedDay;
      _focusedDay = focusedDay;
    });

    if (selectedDay.isBefore(DateTime.now().add(const Duration(days: 1))) &&
        _deviceId != null) {
      _fetchHistoryRoute(selectedDay: selectedDay);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data or future date selected.')),
      );
    }
  }

  void _showCalendarDialog() async {
    if (_deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a device first.')),
      );
      return;
    }

    final currentLocale = Get.locale;
    if (currentLocale != null) {
      final localeString = currentLocale.toString();
      await initializeDateFormatting(localeString, null);
    }
    _fetchMonthlyData(_focusedDay);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Route Date'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter modalSetState) {
              void onPageChanged(DateTime focusedDay) {
                modalSetState(() {
                  _focusedDay = focusedDay;
                });
                _fetchMonthlyData(focusedDay);
              }

              return SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _isCalendarLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : TableCalendar(
                              locale: Get.locale?.languageCode,
                              firstDay: DateTime.utc(2020, 1, 1),
                              lastDay: DateTime.utc(2030, 12, 31),
                              focusedDay: _focusedDay,
                              calendarFormat: _calendarFormat,
                              headerStyle: const HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                              ),
                              selectedDayPredicate: (day) {
                                return isSameDay(_selectedCalendarDay, day);
                              },
                              onDaySelected: (selectedDay, focusedDay) {
                                _onDaySelected(selectedDay, focusedDay);
                              },
                              onPageChanged: onPageChanged,
                              eventLoader: (day) {
                                final dayUtc = DateTime.utc(
                                  day.year,
                                  day.month,
                                  day.day,
                                );
                                if (_dailySummaries.containsKey(dayUtc)) {
                                  return [true];
                                }
                                return [];
                              },
                              calendarBuilders: CalendarBuilders(
                                markerBuilder: (context, date, events) {
                                  final dayUtc = DateTime.utc(
                                    date.year,
                                    date.month,
                                    date.day,
                                  );
                                  if (_dailySummaries.containsKey(dayUtc)) {
                                    final summary = _dailySummaries[dayUtc]!;
                                    final distanceInKm =
                                        (summary.distance ?? 0.0) / 1000;
                                    return Positioned(
                                      bottom: 1,
                                      child: Text(
                                        '${distanceInKm.toStringAsFixed(0)}km',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    );
                                  }
                                  return null;
                                },
                              ),
                            ),

                      const SizedBox(height: 10),
                      Text(
                        'Selected: ${(_selectedCalendarDay != null) ? DateFormat('yyyy-MM-dd').format(_selectedCalendarDay!) : 'None'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<Uint8List> _createDotMarkerIcon(Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final double radius = 5.0;
    final Size size = Size(radius * 2, radius * 2);

    canvas.drawCircle(Offset(radius, radius), radius, paint);

    final ui.Image img = await pictureRecorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final ByteData? byteData = await img.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  // Color check is no longer strictly needed for marker icons but kept as a utility
  Color _getSpeedColor(double speed) {
    if (speed <= 10) {
      return Colors.green;
    } else if (speed > 10 && speed <= 50) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }

  Widget _markerIconWidget(Uint8List bytes, double size, Offset anchor) {
    final anchorX = anchor.dx * size;
    final anchorY = anchor.dy * size;

    return Transform.translate(
      offset: Offset(-anchorX, -anchorY),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }

  // MODIFIED: _drawFullRoute for FlutterMap
  void _drawFullRoute() {
    if (_positions.isEmpty) {
      // Use reactive setters to clear map elements
      _polylinesRx.value = [];
      _staticMarkersRx.value = [];
      return;
    }

    final points = _positions
        .map(
          (pos) => LatLng(pos.latitude!.toDouble(), pos.longitude!.toDouble()),
        )
        .toList();

    final fullRoutePolyline = Polyline(
      points: points,
      color: Colors.grey.withOpacity(0.5),
      strokeWidth: 5,
    );

    // Get the existing playback marker if it exists (for speed change/redraw)
    final existingPlaybackMarker = _playbackMarkerRx.value;

    List<Marker> customMarkers = [];
    final int totalPositions = _positions.length;
    int parkingIconIndex = 0;

    // 2. Build the list of STATIC route markers (Start, End, Parking)
    for (int i = 0; i < totalPositions; i++) {
      final pos = _positions[i];
      final LatLng position = LatLng(
        pos.latitude!.toDouble(),
        pos.longitude!.toDouble(),
      );

      Uint8List? iconBytes;
      String id = 'point_$i';
      Offset anchor = const Offset(0.5, 0.5);
      double size = _customMarkerTargetSize;

      if (i == 0 && _startMarkerIconBytes != null) {
        // Start Marker
        iconBytes = _startMarkerIconBytes;
        id = 'start_point';
        anchor = const Offset(0.5, 0.9);
      } else if (i == totalPositions - 1 &&
          _destinationMarkerIconBytes != null) {
        // End Marker
        iconBytes = _destinationMarkerIconBytes;
        id = 'end_point';
        anchor = const Offset(0.5, 0.9);
      } else {
        // Intermediate Markers - CHECK ONLY FOR STOP/PARKING
        final speed = pos.speed ?? 0.0;
        // MODIFIED: Check the new list instead of the single icon variable
        if (speed <= 2.0 && _parkingMarkerIconBytesList.isNotEmpty) {
          // Parking/Stop Marker (Speed below a small threshold)
          // NEW: Select icon cyclically using modulo operator
          print('Found STOP/PARKING at index $i with speed: $speed');
          iconBytes =
              _parkingMarkerIconBytesList[parkingIconIndex %
                  _parkingMarkerIconBytesList.length];
          parkingIconIndex++; // Increment the counter for the next stop marker

          id = 'stop_point_$i';
          anchor = const Offset(0.5, 0.9);
        } else {
          // SKIP all moving positions (no dot markers)
          continue;
        }
      }

      // *** FIX STARTS HERE ***
      if (iconBytes != null) {
        // The size for the Marker widget must match the size used in _markerIconWidget
        // The anchor logic is handled by the _markerIconWidget's Transform.translate
        customMarkers.add(
          Marker(
            key: ValueKey<String>(id),
            point: position,
            width: size,
            height: size,
            // FIX: This ensures the parking marker icon (iconBytes) is rendered.
            child: _markerIconWidget(iconBytes, size, anchor),
          ),
        );
      }
      // *** FIX ENDS HERE ***
    }

    // NEW: Update reactive lists directly (NO setState)
    _staticMarkersRx.value = customMarkers;

    // Start with the full route (gray line)
    _polylinesRx.value = [fullRoutePolyline];

    // If a playback marker existed, ensure it is preserved/re-rendered
    if (existingPlaybackMarker != null) {
      _playbackMarkerRx.value = existingPlaybackMarker;
    }

    // _animateCameraToRoute();
  }

  void _togglePlayback() {
    // MODIFIED: Use reactive list
    if (_movingPositionsRx.isEmpty) return;

    // Use setState for simple UI state like _isPlaying
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _playbackTimer?.cancel();

        final int intervalMs = (1000 / (10 * _playbackSpeed)).round();
        // MODIFIED: Remove forceZoom parameter. It will now only pan if necessary.
        _updatePlaybackMarker(animateCamera: true);

        Future.delayed(const Duration(milliseconds: 300), () {
          if (!_isPlaying || !mounted) return;

          _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (
            timer,
          ) {
            final stepIncrement = 0.5 * _playbackSpeed;
            // MODIFIED: Use reactive list
            final maxIndex = _movingPositionsRx.length - 1;

            if (_playbackPositionRx.value >= maxIndex) {
              _playbackTimer?.cancel();
              // Use setState for simple UI state change
              setState(() {
                _isPlaying = false;
              });

              // Reset playback position and update marker reactively
              _playbackPositionRx.value = 0.0;
              _updatePlaybackMarker(animateCamera: true);
            } else {
              // Update reactive position (NO setState)
              _playbackPositionRx.value += stepIncrement;
              _playbackPositionRx.value = min(
                _playbackPositionRx.value,
                maxIndex.toDouble(),
              );
              _updatePlaybackMarker(animateCamera: true);
            }
          });
        });
      } else {
        _playbackTimer?.cancel();
        _updatePlaybackMarker(animateCamera: false);
      }
    });
  }

  void _onSpeedSelected(double speed) {
    setState(() {
      _playbackSpeed = speed;
    });
    if (_isPlaying) {
      _togglePlayback(); // Pause
      _togglePlayback(); // Resume with new speed
    }
  }

  // MODIFIED: _updatePlaybackMarker for FlutterMap - NO setState
  void _updatePlaybackMarker({
    bool animateCamera = false,
    bool forceZoom = false,
  }) {
    // MODIFIED: Use reactive list value
    final listForPlayback = _movingPositionsRx.value;
    if (listForPlayback.isEmpty || _playbackMarkerIconBytes == null) return;

    // Use the reactive position value for interpolation
    final double playbackPosition = _playbackPositionRx.value;

    final int index1 = playbackPosition.floor().clamp(
      0,
      listForPlayback.length - 1,
    );
    final int index2 = playbackPosition.ceil().clamp(
      0,
      listForPlayback.length - 1,
    );
    final double fraction = playbackPosition - index1;

    final pos1 = listForPlayback[index1];
    final pos2 = listForPlayback[index2];

    final newLat =
        pos1.latitude! + (pos2.latitude! - pos1.latitude!) * fraction;
    final newLon =
        pos1.longitude! + (pos2.longitude! - pos1.longitude!) * fraction;
    final newLatLng = LatLng(newLat, newLon);

    double bearing = 0.0;
    if (index1 < listForPlayback.length - 1) {
      final lat1 = _degreesToRadians(pos1.latitude!.toDouble());
      final lon1 = _degreesToRadians(pos1.longitude!.toDouble());
      final lat2 = _degreesToRadians(pos2.latitude!.toDouble());
      final lon2 = _degreesToRadians(pos2.longitude!.toDouble());

      final dLon = lon2 - lon1;
      final y = sin(dLon) * cos(lat2);
      final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

      if (y != 0 || x != 0) {
        bearing = atan2(y, x) * (180 / pi);
      }
    } else if (_playbackMarkerRx.value != null) {
      // Use existing bearing if at the last point
    }

    Widget playbackMarkerWidget() {
      final size = _arrowMarkerTargetSize;
      final anchorX = 0.5 * size;
      final anchorY = 0.5 * size;

      return Transform.translate(
        offset: Offset(-anchorX, -anchorY),
        child: Transform.rotate(
          angle: bearing * (pi / 180),
          child: Image.memory(
            _playbackMarkerIconBytes!,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    // FlutterMap Marker
    final newPlaybackMarker = Marker(
      key: const ValueKey<String>('playback_marker'),
      point: newLatLng,
      width: _arrowMarkerTargetSize,
      height: _arrowMarkerTargetSize,
      child: playbackMarkerWidget(),
    );

    final playedPoints = listForPlayback
        .sublist(0, index1 + 1)
        .map(
          (pos) => LatLng(pos.latitude!.toDouble(), pos.longitude!.toDouble()),
        )
        .toList();

    if (fraction > 0 && index1 < listForPlayback.length - 1) {
      playedPoints.add(newLatLng);
    }

    // FlutterMap Polyline
    final playedRoutePolyline = Polyline(
      points: playedPoints,
      color: const Color(0xFF0F53FE),
      strokeWidth: 5,
    );

    if (animateCamera && mapController != null) {
      // NEW LOGIC: Only pan if the new position is NOT visible or near the edge.
      // Use a margin of 0.2 (20%) of the map view size
      if (!_isLatLngVisible(newLatLng, 0.2)) {
        // Use the current zoom level for a natural pan
        mapController!.move(newLatLng, mapController!.camera.zoom);
      }

      // We removed the forceZoom parameter and logic to ensure a more natural zoom experience.
    }

    // UPDATE REACTIVE STATE (NO setState)
    _playbackMarkerRx.value = newPlaybackMarker;

    // Update polylines list reactively
    _polylinesRx.removeWhere(
      (polyline) => polyline.color == const Color(0xFF0F53FE),
    ); // Remove old played route
    _polylinesRx.add(playedRoutePolyline);
    if (_polylinesRx.length < 2) {
      // Re-add the full route if it was accidentally removed
      _drawFullRoute();
    }
  }

  void _animateCameraToRoute() {
    if (mapController != null && _positions.isNotEmpty) {
      double minLat = _positions.first.latitude!.toDouble();
      double maxLat = _positions.first.latitude!.toDouble();
      double minLon = _positions.first.longitude!.toDouble();
      double maxLon = _positions.first.longitude!.toDouble();

      for (var pos in _positions) {
        minLat = min(minLat, pos.latitude!.toDouble());
        maxLat = max(maxLat, pos.latitude!.toDouble());
        minLon = min(minLon, pos.longitude!.toDouble());
        maxLon = max(maxLon, pos.longitude!.toDouble());
      }

      final bounds = LatLngBounds(
        LatLng(minLat, minLon),
        LatLng(maxLat, maxLon),
      );

      mapController!.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    }
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == OSMMapType.normal
          ? OSMMapType.satellite
          : OSMMapType.normal;
    });
  }

  String _getTileUrl() {
    switch (_mapType) {
      case OSMMapType.normal:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case OSMMapType.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      default:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _hiveTileProvider.dispose();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm:ss').format(time.toLocal());
  }

  // REMOVED: Old 'time' and 'speed' getters

  String get distanceText {
    if (_positions.isEmpty) return 'N/A';
    double totalDistance = 0.0;
    for (int i = 0; i < _positions.length - 1; i++) {
      totalDistance += _calculateDistance(
        LatLng(
          _positions[i].latitude!.toDouble(),
          _positions[i].longitude!.toDouble(),
        ),
        LatLng(
          _positions[i + 1].latitude!.toDouble(),
          _positions[i + 1].longitude!.toDouble(),
        ),
      );
    }
    return '${totalDistance.toStringAsFixed(2)} km';
  }

  double _calculateDistance(LatLng latLng1, LatLng latLng2) {
    const double earthRadius = 6371;
    final double dLat = _degreesToRadians(latLng2.latitude - latLng1.latitude);
    final double dLon = _degreesToRadians(
      latLng2.longitude - latLng1.longitude,
    );

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(latLng1.latitude)) *
            cos(_degreesToRadians(latLng2.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  @override
  Widget build(BuildContext context) {
    // REMOVED: maxSliderValue calculation from outside Obx

    final speedOptions = [0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0];
    String devicePart = _selectedDeviceName != null
        ? ' | (${_selectedDeviceName!})'
        : '';
    String datePart = (_historyFrom != null)
        ? DateFormat.yMMMd().format(_historyFrom!.toLocal())
        : 'Select Date'.tr;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'reportReplay'.tr + ': $datePart$devicePart',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: Stack(
        children: [
          _isTileProviderReady
              ? FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(0, 0),
                    initialZoom: 15,
                    onMapReady: () {
                      _animateCameraToRoute();
                      _updateZoomLevel();
                    },
                    onPositionChanged: (position, hasGesture) {
                      if (position.zoom != _currentZoomLevel) {
                        _updateZoomLevel();
                      }
                    },
                    initialRotation: 0,
                    minZoom: 3,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _getTileUrl(),
                      userAgentPackageName: _userAgent,
                      tileProvider: _hiveTileProvider,
                    ),

                    // NEW: Reactive Polyline Layer (Only rebuilds on _polylinesRx changes)
                    Obx(() => PolylineLayer(polylines: _polylinesRx.toList())),

                    // NEW: Reactive Marker Layer (Only rebuilds on _staticMarkersRx or _playbackMarkerRx changes)
                    Obx(() {
                      final allMarkers = _staticMarkersRx.toList();
                      if (_playbackMarkerRx.value != null) {
                        allMarkers.add(_playbackMarkerRx.value!);
                      }
                      return MarkerLayer(markers: allMarkers);
                    }),
                  ],
                )
              : const Center(child: CircularProgressIndicator()),

          Positioned(
            top: 10,
            right: 10,
            child: Column(
              children: [
                // Calendar/Date Selection Button
                FloatingActionButton(
                  onPressed: _showCalendarDialog,
                  mini: true,
                  heroTag: 'calendarButton',
                  child: const Icon(Icons.calendar_month),
                ),
                const SizedBox(height: 10),

                // Map Type Toggle Button
                FloatingActionButton(
                  onPressed: _toggleMapType,
                  mini: true,
                  heroTag: 'mapTypeToggle',
                  child: Icon(
                    _mapType == OSMMapType.normal ? Icons.satellite : Icons.map,
                  ),
                ),
                const SizedBox(height: 10),

                // Reset Rotation Button
                FloatingActionButton(
                  onPressed: _resetRotation,
                  mini: true,
                  heroTag: 'resetRotationButton',
                  child: const Icon(Icons.explore),
                ),
                const SizedBox(height: 10),

                // Zoom In/Out are now grouped
                Column(
                  children: [
                    FloatingActionButton(
                      onPressed: _zoomIn,
                      mini: true,
                      heroTag: 'zoomInButton',
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton(
                      onPressed: _zoomOut,
                      mini: true,
                      heroTag: 'zoomOutButton',
                      child: const Icon(Icons.remove),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Playback Control Panel (MODERN REDESIGN)
          Positioned(
            bottom: 20,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).cardColor, // Use theme color for better contrast
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Info Row (Time, Speed, Distance) - Reactive
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: Obx(() {
                      // Calculate time and speed directly inside the reactive builder
                      String currentTime = 'N/A';
                      String currentSpeed = 'N/A';

                      // Use reactive list value and check
                      if (_movingPositionsRx.isNotEmpty) {
                        final index = _playbackPositionRx.value.toInt().clamp(
                          0,
                          _movingPositionsRx.length - 1,
                        );
                        currentTime = _formatTime(
                          _movingPositionsRx[index].serverTime!,
                        );
                        final speedValue =
                            _movingPositionsRx[index].speed ?? 0.0;
                        currentSpeed = '${speedValue.toStringAsFixed(2)} km/h';
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoColumn('Time', currentTime),
                          _buildInfoColumn('Speed', currentSpeed),
                          // distanceText is safe as it doesn't access Rx variables
                          _buildInfoColumn('Total Distance', distanceText),
                        ],
                      );
                    }),
                  ),

                  const SizedBox(height: 10),

                  // 2. Slider - Reads _playbackPositionRx and _movingPositionsRx
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: const Color(0xFF0F53FE),
                      activeTrackColor: const Color(0xFF0F53FE),
                      inactiveTrackColor: Colors.grey.withOpacity(0.5),
                      overlayColor: const Color(0xFF0F53FE).withOpacity(0.2),
                      trackHeight: 4.0,
                    ),
                    child: Obx(() {
                      final maxSliderValue = _movingPositionsRx.isNotEmpty
                          ? (_movingPositionsRx.length - 1).toDouble()
                          : 0.0;

                      return Slider(
                        value: _playbackPositionRx.value,
                        min: 0,
                        max: maxSliderValue,
                        onChanged: (newValue) {
                          _playbackPositionRx.value = newValue;
                          _playbackTimer?.cancel();
                          _isPlaying = false;
                          // Minimal update for smooth dragging
                          _updatePlaybackMarker(animateCamera: false);
                        },
                        onChangeEnd: (newValue) {
                          // Final update, animate camera to the new position
                          _updatePlaybackMarker(animateCamera: true);
                        },
                      );
                    }),
                  ),

                  // 3. Playback and Speed Controls Row (Redesigned)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Play/Pause Button - Larger and more prominent
                      SizedBox(
                        height: 48,
                        child: FloatingActionButton(
                          heroTag: 'playPauseButton',
                          backgroundColor: const Color(0xFF0F53FE),
                          onPressed: _positions.isNotEmpty
                              ? _togglePlayback
                              : null,
                          child: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // Speed Selector - Segmented Control for clear options
                      // NEW: Wrapped in Flexible to prevent overflow
                      Flexible(
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          // FIX: Wrap the inner Row in SingleChildScrollView to handle overflow
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            // Use reverse to prioritize showing lower speeds (1x, 2x) first
                            reverse: true,
                            child: Row(
                              mainAxisSize: MainAxisSize
                                  .min, // Keep minimal size for compactness
                              children: speedOptions.map((speed) {
                                final isSelected = _playbackSpeed == speed;
                                return GestureDetector(
                                  onTap: _positions.isNotEmpty
                                      ? () => _onSpeedSelected(speed)
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.1,
                                                ),
                                                blurRadius: 2,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        speed == 0.5
                                            ? '0.5x'
                                            : '${speed.toInt()}x',
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? const Color(0xFF0F53FE)
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
