// lib/screens/history_route_screen.dart

import 'package:flutter/material.dart';
// REMOVED: import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart'; // Equivalent to LatLng in google_maps_flutter
import 'package:flutter_map/flutter_map.dart'; // NEW: OpenStreetMap map widget
// import 'package:flutter_map/flutter_map.dart' as fm; // Alias for clarity
// REMOVED: The following two imports caused 'uri_does_not_exist' error and are not needed in public code:
// import 'package:flutter_map/src/geo/crs/crs.dart';
// import 'package:flutter_map/src/map/camera/camera_fit.dart';

import 'dart:async';
import 'package:get/get.dart';
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
import 'dart:typed_data'; // For Uint8List
import 'package:http/http.dart' as http; // For fetching tiles
import 'dart:io'; // For checking network status (optional, but good practice for caching)

// NEW: Custom Tile Provider for Hive Caching
class HiveTileProvider extends TileProvider {
  static const String boxName = 'mapTilesCache';
  late Box<Uint8List> _tileBox;
  final String userAgent;

  HiveTileProvider({required this.userAgent})
    : super(headers: {'User-Agent': userAgent});

  Future<void> init() async {
    // Open the Hive box for storing map tiles.
    _tileBox = await Hive.openBox<Uint8List>(boxName);
  }

  // Closes the Hive box to release resources
  Future<void> dispose() async {
    if (_tileBox.isOpen) {
      await _tileBox.close();
    }
  }

  String _getTileKey(String url) {
    // Generate a unique key from the tile URL
    return url.replaceAll(RegExp(r'[^\w]'), '_');
  }

  @override
  ImageProvider getImage(
    TileCoordinates coordinates, // Renamed from Coords<num> coords
    TileLayer options, // Renamed from TileLayer options
  ) {
    final tileUrl = getTileUrl(
      coordinates,
      options,
    ); // This function internally uses TileCoordinates
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

  // This function performs the network fetch and cache write asynchronously.
  Future<void> _cacheTile(String tileUrl, String hiveKey) async {
    try {
      final response = await http.get(Uri.parse(tileUrl), headers: headers);
      if (response.statusCode == 200) {
        // Cache the tile data (Uint8List)
        await _tileBox.put(hiveKey, response.bodyBytes);
      }
    } catch (e) {
      // print('Failed to cache tile: $e'); // Debug
    }
  }
}

// NEW: Enum for Map Types
enum OSMMapType { normal, satellite }

class HistoryRouteScreen extends StatefulWidget {
  const HistoryRouteScreen({super.key});

  @override
  State<HistoryRouteScreen> createState() => _HistoryRouteScreenState();
}

class _HistoryRouteScreenState extends State<HistoryRouteScreen> {
  // REPLACED: GoogleMapController? mapController;
  MapController? mapController = MapController(); // NEW: FlutterMap controller
  // REPLACED: Set<Polyline> _polylines = {};
  List<Polyline> _polylines = []; // NEW: List of FlutterMap Polylines
  // REPLACED: Set<Marker> _markers = {};
  List<Marker> _markers = []; // NEW: List of FlutterMap Markers
  List<api.Position> _positions = [];
  List<api.Position> _movingPositions = [];
  double _playbackPosition = 0.0;
  // REPLACED: Marker? _playbackMarker;
  Marker? _playbackMarker; // NEW: FlutterMap Marker
  bool _isPlaying = false;
  Timer? _playbackTimer;
  bool _isTileProviderReady = false;

  // FIX: Replaced BitmapDescriptor with Uint8List for marker icons
  Uint8List? _playbackMarkerIconBytes;
  Uint8List? _redDotMarkerIconBytes;
  Uint8List? _startMarkerIconBytes;
  Uint8List? _parkingMarkerIconBytes;
  Uint8List? _destinationMarkerIconBytes;

  final double _customMarkerTargetSize = 24.0;
  final double _arrowMarkerTargetSize = 48.0;

  // REPLACED: MapType _mapType = MapType.normal;
  OSMMapType _mapType = OSMMapType.normal; // NEW: OSM Map Type
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
    _initHiveTileProvider(); // NEW: Initialize the Hive Tile Provider
    _loadCustomMarkerIcons();
    _createDotMarkerIcon(Colors.red).then((bytes) {
      // FIX: Store bytes instead of BitmapDescriptor
      _redDotMarkerIconBytes = bytes;
    });
    _loadInitialParamsAndFetch();
  }

  // NEW: Hive Tile Provider Initialization
  Future<void> _initHiveTileProvider() async {
    _hiveTileProvider = HiveTileProvider(userAgent: _userAgent);
    await _hiveTileProvider.init(); // Wait for Hive box to open
    if (mounted) {
      setState(() {
        _isTileProviderReady = true; // Set state to true once ready
      });
    }
  }

  void _updateZoomLevel() async {
    // FIX: MapController.ready is removed. Use MapController.camera.zoom
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
    // FIX: Use mapController for zoom
    if (mapController != null) {
      final newZoom = mapController!.camera.zoom + amount;
      mapController!.move(
        mapController!.camera.center,
        newZoom.clamp(3.0, 18.0),
      ); // Zoom limit 3-18
    }
  }

  void _zoomIn() {
    if (_isPlaying) {
      _playbackTimer?.cancel();
    }

    _zoom(1.0); // Use 1.0 for a standard zoom level increment
    _updateZoomLevel();

    if (_isPlaying) {
      // Restarting playback will automatically re-engage the camera movement
      _togglePlayback();
      _togglePlayback();
    }
  }

  void _zoomOut() {
    if (_isPlaying) {
      _playbackTimer?.cancel();
    }

    _zoom(-1.0); // Use -1.0 for a standard zoom level decrement
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
      // FIX: Return Uint8List bytes
      return byteDataResized!.buffer.asUint8List();
    } catch (e) {
      print('Error loading marker icon $assetPath: $e');
      return null;
    }
  }

  Future<void> _loadCustomMarkerIcons() async {
    // Playback arrow icon
    _playbackMarkerIconBytes = await _loadAssetIcon(
      'assets/images/arrow.png',
      _arrowMarkerTargetSize,
    );
    // Start icon
    _startMarkerIconBytes = await _loadAssetIcon(
      'assets/images/start.png',
      _customMarkerTargetSize,
    );
    // Parking/Stop icon
    _parkingMarkerIconBytes = await _loadAssetIcon(
      'assets/images/parking.png',
      _customMarkerTargetSize,
    );
    // Destination/End icon
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

      // If history params exist, use them. Otherwise, default to today.
      if (fromString != null && toString != null) {
        _historyFrom = DateTime.tryParse(fromString)?.toLocal();
        _historyTo = DateTime.tryParse(toString)?.toLocal();
        // If a date was loaded from prefs, make it the default selected calendar day
        if (_historyFrom != null) {
          _selectedCalendarDay = DateTime(
            _historyFrom!.year,
            _historyFrom!.month,
            _historyFrom!.day,
          );
        }
      } else {
        // Set today's date range
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
      // Fetch initial route (using local state _historyFrom, _historyTo)
      _fetchHistoryRoute();
      // Fetch monthly data for the calendar
      await _fetchMonthlyData(_focusedDay);
    } else {
      print('Missing device ID for history route.');
    }
  }

  Future<void> _fetchHistoryRoute({DateTime? selectedDay}) async {
    if (selectedDay != null) {
      // Update local state if a new day was selected from the calendar
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
    setState(() {
      _isPlaying = false;
      _positions = [];
      _polylines = []; // Reset Polylines
      _markers.removeWhere(
        (m) => (m.key as ValueKey<String>).value == 'playback_marker',
      ); // Remove playback marker using key
      _playbackPosition = 0.0;
    });

    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final positionsApi = api.PositionsApi(traccarProvider.apiClient);

    // API call uses the updated _historyFrom and _historyTo
    final positions = await positionsApi.positionsGet(
      deviceId: _deviceId,
      from: _historyFrom!.toUtc(), // Use UTC as Traccar typically expects it
      to: _historyTo!.toUtc(),
    );

    setState(() {
      _positions = positions ?? [];

      // NEW: Create the filtered list for smooth playback
      _movingPositions = _positions
          .where((p) => (p.speed ?? 0.0) > 2.0) //.where((p) => (p.speed ?? 0.0) > 0.0) are zero skipped
          .toList();

      _drawFullRoute();
      if (_positions.isNotEmpty) {
        _updatePlaybackMarker(animateCamera: true);
      }
    });
  }

  Future<void> _fetchMonthlyData(DateTime month) async {
    if (_deviceId == null) return;

    // Only proceed if the month has changed or if we are loading for the first time
    if (_dailySummaries.isNotEmpty &&
        month.month == _focusedDay.month &&
        month.year == _focusedDay.year)
      return;

    // Set loading state and update focused day
    setState(() {
      _isCalendarLoading = true;
      _focusedDay = month;
    });

    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final reportsApi = api.ReportsApi(traccarProvider.apiClient);
    // OPEN HIVE BOX
    final dailyBox = await Hive.openBox<ReportSummaryHive>('daily_summaries');

    // Step 1: Load from cache (Hive)
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

    // Initial setState to show cached data immediately
    setState(() {
      _isCalendarLoading = false;
    });

    // Step 2: Fetch data from the network in the background and update cache
    for (
      var date = firstDayOfMonth;
      date.isBefore(lastDayOfMonth.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))
    ) {
      final dayUtc = DateTime.utc(date.year, date.month, date.day);

      // Optimization: skip API call if data is already in the map
      if (_dailySummaries.containsKey(dayUtc)) continue;

      final from = DateTime(date.year, date.month, date.day, 0, 0, 0);
      final to = DateTime(date.year, date.month, date.day, 23, 59, 59);
      final String hiveKey =
          '$_deviceId-${DateFormat('yyyy-MM-dd').format(dayUtc)}';

      try {
        // Fetching reports summary
        final summary = await reportsApi.reportsSummaryGet(
          from.toUtc(), // Use UTC here
          to.toUtc(),
          deviceId: [_deviceId!],
        );

        if (summary != null && summary.isNotEmpty) {
          final dailySummary = summary.first;

          // FIX: Use dayUtc (the date queried) as the key instead of summary.startTime
          _dailySummaries[dayUtc] = dailySummary;

          // Step 3: Update Hive cache with fresh data
          final newSummaryHive = ReportSummaryHive.fromApi(dailySummary);
          await dailyBox.put(hiveKey, newSummaryHive);

          // Update UI state for the calendar markers
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

    // Check if the date is today or in the past
    if (selectedDay.isBefore(DateTime.now().add(const Duration(days: 1))) &&
        _deviceId != null) {
      // Directly fetch the route for the selected day
      _fetchHistoryRoute(selectedDay: selectedDay);
      Navigator.pop(context); // Close the dialog
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
      // Await the initialization
      await initializeDateFormatting(localeString, null);
    }
    // Ensure data for the current focused month is loaded before showing
    // This call is now non-blocking as _fetchMonthlyData handles its own loading state.
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
                // Fetch data for the new month asynchronously
                _fetchMonthlyData(focusedDay);
              }

              return SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Use local state _isCalendarLoading to show spinner in the dialog
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
                                // Call the main screen's function which handles navigation/route fetch
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

  // FIX: Refactored to return Uint8List bytes instead of BitmapDescriptor
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
    // FIX: Return Uint8List bytes
    return byteData!.buffer.asUint8List();
  }

  Color _getSpeedColor(double speed) {
    if (speed <= 10) {
      return Colors.green;
    } else if (speed > 10 && speed <= 50) {
      return Colors.yellow;
    } else {
      return Colors.red;
    }
  }

  // NEW: Helper to create the marker widget from Uint8List bytes
  Widget _markerIconWidget(Uint8List bytes, double size, Offset anchor) {
    // Anchor is relative to the size of the icon (e.g., 0.5, 0.9 is center x, 90% down y)
    final anchorX = anchor.dx * size;
    final anchorY = anchor.dy * size;

    // FIX: Use Transform.translate to apply the anchor offset
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
  void _drawFullRoute() async {
    if (_positions.isEmpty) {
      setState(() {
        _polylines = [];
        _markers = [];
      });
      return;
    }

    final points = _positions
        .map(
          (pos) => LatLng(pos.latitude!.toDouble(), pos.longitude!.toDouble()),
        )
        .toList();

    // FlutterMap Polyline
    final fullRoutePolyline = Polyline(
      points: points,
      color: Colors.grey.withOpacity(0.5),
      strokeWidth: 5,
    );

    // FIX: 1. Preserve the existing playback marker before clearing.
    // Use firstWhereOrNull to safely find the existing playback marker
    final existingPlaybackMarker = _markers.firstWhereOrNull(
      (m) => (m.key as ValueKey<String>).value == 'playback_marker',
    );

    List<Marker> customMarkers = [];
    final int totalPositions = _positions.length;

    // 2. Build the list of static route markers (Start, End, Parking/Dots)
    for (int i = 0; i < totalPositions; i++) {
      final pos = _positions[i];
      final LatLng position = LatLng(
        pos.latitude!.toDouble(),
        pos.longitude!.toDouble(),
      );

      Uint8List? iconBytes;
      String id = 'point_$i'; // Ensure unique ID for every position marker
      Offset anchor = const Offset(0.5, 0.5); // Default center anchor
      double size = _customMarkerTargetSize;

      if (i == 0 && _startMarkerIconBytes != null) {
        // Start Marker
        iconBytes = _startMarkerIconBytes;
        id = 'start_point';
        anchor = const Offset(0.5, 0.9);
        size = _customMarkerTargetSize;
      } else if (i == totalPositions - 1 &&
          _destinationMarkerIconBytes != null) {
        // End Marker
        iconBytes = _destinationMarkerIconBytes;
        id = 'end_point';
        anchor = const Offset(0.5, 0.9);
        size = _customMarkerTargetSize;
      } else {
        // Intermediate Markers
        final speed = pos.speed ?? 0.0;
        if (speed <= 0.0 && _parkingMarkerIconBytes != null) {
          // Parking/Stop Marker
          iconBytes = _parkingMarkerIconBytes;
          id = 'stop_point_$i'; // Ensure unique ID for stop markers
          anchor = const Offset(0.5, 0.9);
          size = _customMarkerTargetSize;
        } else {
          // Moving (Use speed-colored dot)
          final color = _getSpeedColor(speed.toDouble());
          // FIX: Use the refactored dot icon creation (await is necessary)
          iconBytes = await _createDotMarkerIcon(color);
          id = 'move_dot_$i'; // Ensure unique ID for moving dots
          size = 1.0; // Dot marker is smaller //10.0
          anchor = const Offset(0.5, 0.5); // Dot is usually centered
        }
      }

      if (iconBytes != null) {
        // FlutterMap Marker creation
        customMarkers.add(
          Marker(
            key: ValueKey<String>(id),
            point: position,
            width: size,
            height: size,
            // FIX: Replaced 'builder' with 'child' and use the helper widget
            child: _markerIconWidget(iconBytes, size, anchor),
            // The anchor property is removed as it's handled in the child widget
          ),
        );
      }
    }

    // FIX: 2. Re-initialize _markers list by adding the preserved marker first, 
    // then the newly built custom markers. This prevents key duplication
    // by ensuring a fresh list.
    List<Marker> newMarkers = [];
    if (existingPlaybackMarker != null) {
      newMarkers.add(existingPlaybackMarker);
    }
    newMarkers.addAll(customMarkers);

    setState(() {
      _polylines = [fullRoutePolyline]; // Start with the full route
      _markers = newMarkers; // Assign the clean list
    });

    _animateCameraToRoute();
  }

  void _togglePlayback() {
    if (_movingPositions.isEmpty) return;

    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _playbackTimer?.cancel();

        final int intervalMs = (1000 / (10 * _playbackSpeed)).round();
        _updatePlaybackMarker(animateCamera: true, forceZoom: true);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!_isPlaying || !mounted) return;

          _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (
            timer,
          ) {
            final stepIncrement = 0.5 * _playbackSpeed;
            final maxIndex = _movingPositions.length - 1;

            if (_playbackPosition >= maxIndex) {
              _playbackTimer?.cancel();
              setState(() {
                _isPlaying = false;
                _playbackPosition = 0.0;
                _updatePlaybackMarker(animateCamera: true);
              });
            } else {
              setState(() {
                _playbackPosition += stepIncrement;
                _playbackPosition = min(_playbackPosition, maxIndex.toDouble());
                _updatePlaybackMarker(animateCamera: true);
              });
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
      _togglePlayback();
      _togglePlayback();
    }
  }

  // MODIFIED: _updatePlaybackMarker for FlutterMap
  void _updatePlaybackMarker({
    bool animateCamera = false,
    bool forceZoom = false,
  }) {
    final listForPlayback = _movingPositions;
    if (listForPlayback.isEmpty || _playbackMarkerIconBytes == null) return;

    final int index1 = _playbackPosition.floor().clamp(
      0,
      listForPlayback.length - 1,
    );
    final int index2 = _playbackPosition.ceil().clamp(
      0,
      listForPlayback.length - 1,
    );
    final double fraction = _playbackPosition - index1;

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
    } else if (_playbackMarker != null) {
      // For simplicity, we just use the calculated bearing from interpolation.
    }

    // NEW: Playback marker widget
    Widget playbackMarkerWidget() {
      // Anchor is center (0.5, 0.5) for the arrow icon
      final size = _arrowMarkerTargetSize;
      final anchorX = 0.5 * size;
      final anchorY = 0.5 * size;

      // FIX: Use Transform.translate and Transform.rotate
      return Transform.translate(
        offset: Offset(-anchorX, -anchorY),
        child: Transform.rotate(
          angle: bearing * (pi / 180), // Convert degrees to radians
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
    _playbackMarker = Marker(
      key: const ValueKey<String>('playback_marker'),
      point: newLatLng,
      width: _arrowMarkerTargetSize,
      height: _arrowMarkerTargetSize,
      // FIX: Replaced 'builder' with 'child'
      child: playbackMarkerWidget(),
      // FIX: The 'anchor' parameter is REMOVED, as anchoring is handled via Transform.translate in the child widget.
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

    // FIX: Check if mapController is available
    if (animateCamera && mapController != null) {
      if (forceZoom) {
        // FIX: Used mapController.move
        mapController!.move(newLatLng, 15.7);
      } else {
        // Subsequent movements just move the center, maintaining the current zoom.
        // FIX: Used mapController.camera.zoom to access current zoom
        mapController!.move(newLatLng, mapController!.camera.zoom);
      }
    }

    setState(() {
      _markers.removeWhere(
        (marker) => (marker.key as ValueKey<String>).value == 'playback_marker',
      );
      _markers.add(_playbackMarker!);

      // Update polylines list
      _polylines.removeWhere(
        (polyline) => polyline.color == const Color(0xFF0F53FE),
      ); // Remove old played route
      _polylines.add(playedRoutePolyline);
      if (_polylines.length < 2) {
        // Re-add the full route if it was accidentally removed
        _drawFullRoute();
      }
    });
  }

  // MODIFIED: _animateCameraToRoute for FlutterMap
  void _animateCameraToRoute() {
    // FIX: Check if mapController is available
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

      // FIX: Use fitCamera with CameraFit.bounds
      mapController!.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          // FIX: Use padding property on CameraFit.bounds
          padding: const EdgeInsets.all(50),
        ),
      );
    }
  }

  // MODIFIED: _toggleMapType for OSM
  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == OSMMapType.normal
          ? OSMMapType.satellite
          : OSMMapType.normal;
    });
  }

  // NEW: Helper to get the correct tile URL
  String _getTileUrl() {
    switch (_mapType) {
      case OSMMapType.normal:
        // Standard OpenStreetMap tiles
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case OSMMapType.satellite:
        // Example of a free satellite tile provider (e.g., Esri World Imagery)
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      default:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _hiveTileProvider.dispose(); // Close Hive box on dispose
    super.dispose();
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm:ss').format(time.toLocal());
  }

  String get time {
    if (_movingPositions.isEmpty) return 'N/A';
    // Clamp the playback position index to the moving positions list
    final index = _playbackPosition.toInt().clamp(
      0,
      _movingPositions.length - 1,
    );
    return _formatTime(_movingPositions[index].serverTime!);
  }

  String get speed {
    if (_movingPositions.isEmpty) return 'N/A';
    // Clamp the playback position index to the moving positions list
    final index = _playbackPosition.toInt().clamp(
      0,
      _movingPositions.length - 1,
    );
    final speed = _movingPositions[index].speed ?? 0.0;
    return '${speed.toStringAsFixed(2)} km/h';
  }

  String get distanceText {
    if (_positions.isEmpty) return 'N/A';
    double totalDistance = 0.0;
    for (int i = 0; i < _positions.length - 1; i++) {
      // NOTE: LatLng usage here is from latlong2 library now
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
    final maxSliderValue = _movingPositions.isNotEmpty
        ? (_movingPositions.length - 1).toDouble()
        : 0.0;

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
          // REPLACED: GoogleMap with FlutterMap
          _isTileProviderReady
    ? FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: const LatLng(0, 0), // Default center
              initialZoom: 15,
              onMapReady: () {
                // Equivalent to onMapCreated
                _animateCameraToRoute();
                _updateZoomLevel();
              },
              onPositionChanged: (position, hasGesture) {
                // Equivalent to onCameraMove
                if (position.zoom != _currentZoomLevel) {
                  _updateZoomLevel();
                }
              },
              // FIX: Replaced rotation/initialRotate with initialRotation
              initialRotation: 0,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              // NEW: Tile Layer with Hive Caching Tile Provider
              TileLayer(
                urlTemplate: _getTileUrl(),
                userAgentPackageName: _userAgent,
                // Use the custom Hive Tile Provider
                tileProvider: _hiveTileProvider,
              ),

              // NEW: Polyline Layer
              PolylineLayer(polylines: _polylines),

              // NEW: Marker Layer
              MarkerLayer(markers: _markers),
            ],
          ): const Center(
        child: CircularProgressIndicator(),
      ),

          // Map Type Toggle Button
          Positioned(
            top: 10,
            right: 10,
            child: Column(
              children: [
                // 1. Map Type Toggle Button
                FloatingActionButton(
                  onPressed: _toggleMapType,
                  mini: true,
                  heroTag: 'mapTypeToggle',
                  child: Icon(
                    _mapType == OSMMapType.normal ? Icons.satellite : Icons.map,
                  ),
                ),

                const SizedBox(height: 10),

                // 2. Zoom In Button
                FloatingActionButton(
                  onPressed: _zoomIn,
                  mini: true,
                  heroTag: 'zoomInButton',
                  child: const Icon(Icons.add),
                ),

                const SizedBox(height: 10),

                // 3. Zoom Out Button
                FloatingActionButton(
                  onPressed: _zoomOut,
                  mini: true,
                  heroTag: 'zoomOutButton',
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // Calendar/Date Selection Button
          Positioned(
            top: 10,
            right: 70,
            child: FloatingActionButton(
              onPressed: _showCalendarDialog,
              mini: true,
              heroTag: 'calendarButton',
              child: const Icon(Icons.calendar_month),
            ),
          ),

          // Playback Control Panel
          Positioned(
            bottom: 20,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
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
                  // Playback and Speed Controls Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Play/Pause Button
                      IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 30,
                          color: _positions.isNotEmpty
                              ? Colors.black
                              : Colors.grey,
                        ),
                        onPressed: _positions.isNotEmpty
                            ? _togglePlayback
                            : null,
                      ),

                      // Speed Controls (0.5x, 1x, 2x, 3x, 4x, 5x, 6x)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: speedOptions.map((speed) {
                            final isSelected = _playbackSpeed == speed;
                            return GestureDetector(
                              onTap: _positions.isNotEmpty
                                  ? () => _onSpeedSelected(speed)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  speed == 0.5 ? '0.5x' : '${speed.toInt()}x',
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
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: const Color(0xFF0F53FE),
                      activeTrackColor: const Color(0xFF0F53FE),
                      inactiveTrackColor: Colors.grey.withOpacity(0.5),
                      overlayColor: const Color(0xFF0F53FE).withOpacity(0.2),
                      trackHeight: 4.0,
                    ),
                    child: Slider(
                      value: _playbackPosition,
                      min: 0,
                      max: maxSliderValue,
                      onChanged: (newValue) {
                        setState(() {
                          _playbackTimer?.cancel();
                          _isPlaying = false;
                          _playbackPosition = newValue;
                          _updatePlaybackMarker();
                        });
                      },
                      onChangeEnd: (newValue) {
                        _updatePlaybackMarker(animateCamera: true);
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Info Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoColumn('Time', time),
                        _buildInfoColumn('Speed', speed),
                        _buildInfoColumn('Distance', distanceText),
                      ],
                    ),
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
