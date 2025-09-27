// lib/screens/history_route_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
// *** NEW/REQUIRED IMPORTS FOR CALENDAR AND HIVE ***
import 'package:table_calendar/table_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:trabcdefg/models/report_summary_hive.dart'; // REQUIRED MODEL
import 'package:intl/date_symbol_data_local.dart';

class HistoryRouteScreen extends StatefulWidget {
  const HistoryRouteScreen({super.key});

  @override
  State<HistoryRouteScreen> createState() => _HistoryRouteScreenState();
}

class _HistoryRouteScreenState extends State<HistoryRouteScreen> {
  GoogleMapController? mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  List<api.Position> _positions = [];
  List<api.Position> _movingPositions = [];
  double _playbackPosition = 0.0;
  Marker? _playbackMarker;
  bool _isPlaying = false;
  Timer? _playbackTimer;
  BitmapDescriptor? _playbackMarkerIcon;
  BitmapDescriptor? _redDotMarkerIcon;
  BitmapDescriptor? _startMarkerIcon;
  BitmapDescriptor? _parkingMarkerIcon;
  BitmapDescriptor? _destinationMarkerIcon;
  // NEW: Constant for marker sizing
  final double _customMarkerTargetSize = 90.0; // Bigger size for custom icons
  final double _arrowMarkerTargetSize = 70.0; // Vehicle arrow marker size
  PolylineId _fullRoutePolylineId = PolylineId('full_route');
  PolylineId _playedRoutePolylineId = PolylineId('played_route');
  MapType _mapType = MapType.normal;
  double _currentZoomLevel = 15.0;

  // Device & Date State
  int? _deviceId;
  DateTime? _historyFrom;
  DateTime? _historyTo;
  String? _selectedDeviceName;

  // Calendar State (NEW)
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedCalendarDay = DateTime.now();
  final Map<DateTime, api.ReportSummary> _dailySummaries = {};
  bool _isCalendarLoading = true;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  // Speed control
  double _playbackSpeed = 0.5; //1.0x speed

  @override
  void initState() {
    super.initState();
    _loadCustomMarkerIcons(); // Load all custom icons
    _createDotMarkerIcon(Colors.red).then((icon) {
      _redDotMarkerIcon = icon;
    });
    _loadInitialParamsAndFetch(); // Renamed to handle both initial route and calendar data
  }

  void _updateZoomLevel() async {
    if (mapController != null) {
      final zoom = await mapController!.getZoomLevel();
      if (mounted) {
        setState(() {
          _currentZoomLevel = zoom;
        });
      }
    }
  }

  void _zoom(double amount) {
    if (mapController != null) {
      // 1. Temporarily pause continuous camera animation during playback
      //    This is the key fix. The next playback update will re-center,
      //    but the manual zoom will be executed immediately.
      mapController!.animateCamera(CameraUpdate.zoomBy(amount));
    }
  }

  void _zoomIn() {
    // If the route is playing, cancel the playback timer for a moment
    // and force the next _updatePlaybackMarker call to NOT animate the camera.
    if (_isPlaying) {
      _playbackTimer?.cancel();
    }

    _zoom(2.0);
    _updateZoomLevel();
    // Resume playback if it was playing
    if (_isPlaying) {
      // Restarting playback will automatically re-engage the camera animation
      _togglePlayback();
      _togglePlayback();
    }
  }

  void _zoomOut() {
    // If the route is playing, cancel the playback timer for a moment
    if (_isPlaying) {
      _playbackTimer?.cancel();
    }

    _zoom(-2.0);
    _updateZoomLevel();
    // Resume playback if it was playing
    if (_isPlaying) {
      // Restarting playback will automatically re-engage the camera animation
      _togglePlayback();
      _togglePlayback();
    }
  }

  Future<BitmapDescriptor?> _loadAssetIcon(
    String assetPath,
    double targetSize,
  ) async {
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
      return BitmapDescriptor.fromBytes(byteDataResized!.buffer.asUint8List());
    } catch (e) {
      print('Error loading marker icon $assetPath: $e');
      return null;
    }
  }

  Future<void> _loadCustomMarkerIcons() async {
    // Playback arrow icon
    _playbackMarkerIcon = await _loadAssetIcon(
      'assets/images/arrow.png',
      _arrowMarkerTargetSize,
    );
    // Start icon
    _startMarkerIcon = await _loadAssetIcon(
      'assets/images/start.png',
      _customMarkerTargetSize,
    );
    // Parking/Stop icon
    _parkingMarkerIcon = await _loadAssetIcon(
      'assets/images/parking.png',
      _customMarkerTargetSize,
    );
    // Destination/End icon
    _destinationMarkerIcon = await _loadAssetIcon(
      'assets/images/destination.png',
      _customMarkerTargetSize,
    );
  }

  // MODIFIED: Load initial route from saved prefs OR default to today, then fetch calendar data
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

  // MODIFIED: Now uses selectedDay and not just local _historyFrom/_historyTo
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
      _polylines = {};
      _markers.removeWhere(
        (m) => m.markerId.value == 'playback_marker',
      ); // Remove playback marker
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
          .where((p) => (p.speed ?? 0.0) > 0.0)
          .toList();

      _drawFullRoute();
      if (_positions.isNotEmpty) {
        _updatePlaybackMarker(animateCamera: true);
      }
    });
  }

  // NEW: Hive and API data fetching logic adapted from monthly_mileage_screen.dart
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

  // NEW: Handles date selection from the calendar
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

  // NEW: Shows the calendar in a clean dialog pop-up
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

  Future<BitmapDescriptor> _createDotMarkerIcon(Color color) async {
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
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
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

  Future<void> _loadPlaybackMarkerIcon() async {
    try {
      final byteData = await rootBundle.load('assets/images/arrow.png');
      final imageData = byteData.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(
        imageData,
        targetHeight: 70,
        targetWidth: 70,
      );
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;
      final byteDataResized = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      _playbackMarkerIcon = BitmapDescriptor.fromBytes(
        byteDataResized!.buffer.asUint8List(),
      );
    } catch (e) {
      print('Error loading playback marker icon: $e');
    }
  }

  void _drawFullRoute() async {
    if (_positions.isEmpty) return;

    final points = _positions
        .map(
          (pos) => LatLng(pos.latitude!.toDouble(), pos.longitude!.toDouble()),
        )
        .toList();
    final fullRoutePolyline = Polyline(
      polylineId: _fullRoutePolylineId,
      points: points,
      color: Colors.grey.withOpacity(0.5),
      width: 5,
    );

    _markers.removeWhere(
      (m) => m.markerId.value != 'playback_marker',
    ); // Keep playback marker if it exists

    List<Marker> customMarkers = [];
    final int totalPositions = _positions.length;

    // 1. Add custom markers
    for (int i = 0; i < totalPositions; i++) {
      final pos = _positions[i];
      final LatLng position = LatLng(
        pos.latitude!.toDouble(),
        pos.longitude!.toDouble(),
      );

      BitmapDescriptor? icon;
      String id = 'point_$i';
      Offset anchor = const Offset(0.5, 0.5); // Default center anchor

      if (i == 0 && _startMarkerIcon != null) {
        // Start Marker
        icon = _startMarkerIcon;
        id = 'start_point';
        anchor = const Offset(0.5, 0.9); // Anchor for bottom alignment
      } else if (i == totalPositions - 1 && _destinationMarkerIcon != null) {
        // End Marker
        icon = _destinationMarkerIcon;
        id = 'end_point';
        anchor = const Offset(0.5, 0.9); // Anchor for bottom alignment
      } else {
        // Intermediate Markers
        final speed = pos.speed ?? 0.0;
        if (speed <= 0.0 && _parkingMarkerIcon != null) {
          // Parking/Stop Marker
          icon = _parkingMarkerIcon;
          anchor = const Offset(0.5, 0.9); // Anchor for bottom alignment
        } else {
          // Moving (Use speed-colored dot)
          final color = _getSpeedColor(speed.toDouble());
          icon = await _createDotMarkerIcon(color);
        }
      }

      if (icon != null) {
        customMarkers.add(
          Marker(
            markerId: MarkerId(id),
            position: position,
            icon: icon,
            anchor: anchor,
          ),
        );
      }
    }

    setState(() {
      _polylines = {fullRoutePolyline};
      // Add all non-playback custom markers
      _markers.addAll(
        customMarkers
            .where((m) => m.markerId.value != 'playback_marker')
            .toSet(),
      );
    });

    _animateCameraToRoute();
  }

  // MODIFIED: Added playback speed logic
  void _togglePlayback() {
    // Use the moving positions for the playback check
    if (_movingPositions.isEmpty) return;

    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        // mapController?.animateCamera(CameraUpdate.zoomTo(20.0)); //17.0 Zoom in for better view //now 18.0
        _playbackTimer?.cancel();

        // Calculate interval based on the required speed/smoothness
        final int intervalMs = (1000 / (10 * _playbackSpeed)).round();
        _updatePlaybackMarker(
          animateCamera: true,
          forceZoom: true,
        ); // Force zoom on first update
       Future.delayed(const Duration(milliseconds: 300), () {
          // Check if we are still in the playing state after the delay
          if (!_isPlaying || !mounted) return;
          
          _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (
            timer,
          ) {
            // The rest of the timer logic runs here as before
            final stepIncrement = 0.5 * _playbackSpeed; //0.5
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
    // Restart playback to apply new speed
    if (_isPlaying) {
      _togglePlayback();
      _togglePlayback();
    }
  }

  void _updatePlaybackMarker({
    bool animateCamera = false,
    bool forceZoom = false,
  }) {
    // Use the filtered list for indexing
    final listForPlayback = _movingPositions;
    if (listForPlayback.isEmpty) return;

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

    // Calculate bearing (rotation) remains the same, using pos1 and pos2 from the filtered list
    double bearing = 0.0;
    if (index1 < listForPlayback.length - 1) {
      // ... (bearing calculation logic remains the same, using pos1/pos2 derived from listForPlayback)
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
      bearing = _playbackMarker!.rotation;
    }

    _playbackMarker = Marker(
      markerId: const MarkerId('playback_marker'),
      position: newLatLng,
      icon: _playbackMarkerIcon ?? BitmapDescriptor.defaultMarker,
      rotation: bearing,
      anchor: const Offset(0.5, 0.5),
    );

    // To draw the *played* polyline, we must find the corresponding points
    // in the ORIGINAL list to ensure it connects correctly to the full route.
    // This requires a more complex mapping (e.g., finding the index of pos1 in _positions),
    // but for simplicity and better UX, we will draw the *played* polyline only
    // between the points in the *filtered* list, giving a direct "movement path."

    // Simpler Played Polyline (draws the path of movement only)
    final playedPoints = listForPlayback
        .sublist(0, index1 + 1)
        .map(
          (pos) => LatLng(pos.latitude!.toDouble(), pos.longitude!.toDouble()),
        )
        .toList();

    if (fraction > 0 && index1 < listForPlayback.length - 1) {
      playedPoints.add(newLatLng);
    }

    final playedRoutePolyline = Polyline(
      polylineId: _playedRoutePolylineId,
      points: playedPoints,
      color: const Color(0xFF0F53FE),
      width: 5,
    );

    if (animateCamera) {
      if (forceZoom) {
        // Use CameraUpdate.newLatLngZoom to center AND set the zoom in one shot.
        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            newLatLng,
            15.7,
          ), // Set preferred zoom (15.7 is a good balance), after tap play force to 15.7 zoom level.
        );
      } else {
        // Subsequent movements just center the camera, maintaining the current zoom.
        mapController?.animateCamera(CameraUpdate.newLatLng(newLatLng));
      }

      // if (_isPlaying) {
      //   mapController?.getZoomLevel().then((currentZoom) {
      //     // Only zoom if the current level is significantly different
      //     if (currentZoom < 16.9) {
      //       mapController?.animateCamera(CameraUpdate.zoomTo(17.0));
      //     }
      //   });}
    }

    setState(() {
      _markers.removeWhere(
        (marker) => marker.markerId.value == 'playback_marker',
      );
      _markers.add(_playbackMarker!);

      _polylines.removeWhere(
        (polyline) => polyline.polylineId.value == 'played_route',
      );
      // Add both the full route (grey) and the played route (blue)
      _polylines.add(playedRoutePolyline);
      if (!_polylines.any((p) => p.polylineId == _fullRoutePolylineId)) {
        // Re-add the full route if it was accidentally removed
        _drawFullRoute();
      }
    });
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
        southwest: LatLng(minLat, minLon),
        northeast: LatLng(maxLat, maxLon),
      );
      // Future.delayed(const Duration(milliseconds: 100), () {
      //   mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      // });
      mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    // Ensure time is converted to local time before formatting for display
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
    // Helper variable for the title construction
    String devicePart = _selectedDeviceName != null
        ? ' | (${_selectedDeviceName!})'
        : '';
    String datePart = (_historyFrom != null)
        ? DateFormat.yMMMd().format(_historyFrom!.toLocal())
        : 'Select Date'.tr;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          //'Route History: ${(_historyFrom != null) ? DateFormat('yyyy-MM-dd').format(_historyFrom!.toLocal()) : 'Select Date'}',
          'reportReplay'.tr + ': $datePart$devicePart',
          style: const TextStyle(
            fontSize: 16, // Reduced font size (e.g., from default 20 to 16)
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              mapController = controller;
              _animateCameraToRoute();
              _updateZoomLevel();
            },
            onCameraMove: (position) {
              if (position.zoom != _currentZoomLevel) {
                _updateZoomLevel();
              }
            },
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: 15,
            ),
            mapType: _mapType,
            markers: _markers,
            polylines: _polylines,
            rotateGesturesEnabled: false,
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
                  child: const Icon(Icons.layers),
                ),

                const SizedBox(height: 10),

                // 2. Zoom In Button (NEW)
                FloatingActionButton(
                  onPressed: _zoomIn,
                  mini: true,
                  heroTag: 'zoomInButton',
                  child: const Icon(Icons.add),
                ),

                const SizedBox(height: 10),

                // 3. Zoom Out Button (NEW)
                FloatingActionButton(
                  onPressed: _zoomOut,
                  mini: true,
                  heroTag: 'zoomOutButton',
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // Calendar/Date Selection Button (NEW)
          Positioned(
            top: 10,
            right: 70,
            child: FloatingActionButton(
              onPressed: _showCalendarDialog, // Calls the dialog function
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

                      // Speed Controls (1x, 2x, 3x, 4x, 5x, 6x)
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
                        // _buildInfoColumn(
                        //   'Zoom',
                        //   _currentZoomLevel.toStringAsFixed(1), // Display zoom level, e.g., 15.7 after playback start, on production you can hide it.
                        // ),
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
