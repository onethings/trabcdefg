// lib/screens/reports/trips_report_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/map_style_provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/services/route_history_cache.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/src/utils/route_history_analyzer.dart';
import 'package:trabcdefg/widgets/offline_address_service.dart';

const double _knotsToKmh = 1.852;

class TripReport {
  final int deviceId;
  final String deviceName;
  final double distance;
  final double averageSpeed;
  final double maxSpeed;
  final double spentFuel;
  final double startOdometer;
  final double endOdometer;
  final DateTime startTime;
  final DateTime endTime;
  final int startPositionId;
  final int endPositionId;
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  final String? startAddress;
  final String? endAddress;
  final int duration;
  final String? driverUniqueId;
  final String? driverName;

  TripReport({
    required this.deviceId,
    required this.deviceName,
    required this.distance,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.spentFuel,
    required this.startOdometer,
    required this.endOdometer,
    required this.startTime,
    required this.endTime,
    required this.startPositionId,
    required this.endPositionId,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    this.startAddress,
    this.endAddress,
    required this.duration,
    this.driverUniqueId,
    this.driverName,
  });

  factory TripReport.fromJson(Map<String, dynamic> json) {
    return TripReport(
      deviceId: json['deviceId'] as int,
      deviceName: json['deviceName'] as String,
      distance: (json['distance'] as num).toDouble(),
      averageSpeed: (json['averageSpeed'] as num).toDouble() * _knotsToKmh,
      maxSpeed: (json['maxSpeed'] as num).toDouble() * _knotsToKmh,
      spentFuel: (json['spentFuel'] as num).toDouble(),
      startOdometer: (json['startOdometer'] as num).toDouble(),
      endOdometer: (json['endOdometer'] as num).toDouble(),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      startPositionId: json['startPositionId'] as int,
      endPositionId: json['endPositionId'] as int,
      startLat: (json['startLat'] as num).toDouble(),
      startLon: (json['startLon'] as num).toDouble(),
      endLat: (json['endLat'] as num).toDouble(),
      endLon: (json['endLon'] as num).toDouble(),
      startAddress: json['startAddress'] as String?,
      endAddress: json['endAddress'] as String?,
      duration: json['duration'] as int,
      driverUniqueId: json['driverUniqueId'] as String?,
      driverName: json['driverName'] as String?,
    );
  }

  factory TripReport.fromAnalyzed(AnalyzedTrip trip, {required int deviceId, required String deviceName}) {
    return TripReport(
      deviceId: deviceId,
      deviceName: deviceName,
      distance: trip.distanceMeters,
      averageSpeed: trip.averageSpeedKmh,
      maxSpeed: trip.maxSpeedKmh,
      spentFuel: 0,
      startOdometer: 0,
      endOdometer: 0,
      startTime: trip.startTime,
      endTime: trip.endTime,
      startPositionId: 0,
      endPositionId: 0,
      startLat: trip.startLat,
      startLon: trip.startLon,
      endLat: trip.endLat,
      endLon: trip.endLon,
      duration: trip.durationMs,
    );
  }
}

class TripsReportScreen extends StatefulWidget {
  const TripsReportScreen({super.key});

  @override
  State<TripsReportScreen> createState() => _TripsReportScreenState();
}

class _TripsReportScreenState extends State<TripsReportScreen> {
  List<TripReport> _tripsReport = [];
  bool _isLoading = true;
  String? _deviceName;
  maplibre.MapLibreMapController? _mapController;
  final Set<String> _loadedIcons = {};
  final Map<String, Uint8List> _iconBytes = {};
  bool _isStyleLoaded = false;
  bool _isDrawing = false;
  bool _pendingDraw = false;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _fetchTripsReport();
  }

  Future<void> _fetchTripsReport() async {
    setState(() => _isLoading = true);

    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getInt('selectedDeviceId');
    final fromDateString = prefs.getString('historyFrom');
    final toDateString = prefs.getString('historyTo');

    if (deviceId == null || fromDateString == null || toDateString == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final fromDate = DateTime.tryParse(fromDateString);
    final toDate = DateTime.tryParse(toDateString);

    if (fromDate == null || toDate == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final bool isSingleDayRange = fromDate.year == toDate.year && fromDate.month == toDate.month && fromDate.day == toDate.day;
    final CachedRoutePositions? cachedRoute = isSingleDayRange ? await RouteHistoryCache.load(deviceId: deviceId, day: fromDate) : null;
    final bool hasCachedRoute = cachedRoute != null && cachedRoute.positions.length >= 2;
    final String deviceName = prefs.getString('selectedDeviceName') ?? '';

    if (hasCachedRoute && cachedRoute.isFreshFor(fromDate)) {
      _applyCachedTrips(cachedRoute.positions, deviceId, deviceName);
      return;
    }

    try {
      final apiClient = traccarProvider.apiClient;
      final queryParams = [api.QueryParam('from', fromDate.toIso8601String()), api.QueryParam('to', toDate.toIso8601String()), api.QueryParam('deviceId', deviceId.toString())];
      const path = '/reports/trips';
      final headerParams = {'Accept': 'application/json'};

      final http.Response response = await apiClient.invokeAPI(path, 'GET', queryParams, null, headerParams, {}, 'application/json');

      if (!mounted) return;

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final contentType = response.headers['content-type'];
        if (contentType != null && contentType.contains('application/json')) {
          final decodedData = json.decode(response.body);

          if (decodedData is List && decodedData.isNotEmpty) {
            _tripsReport = decodedData.map((e) => TripReport.fromJson(e as Map<String, dynamic>)).toList();
            if (_tripsReport.isNotEmpty) {
              _deviceName = _tripsReport.first.deviceName;
              _createMapElements();
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load trips report. The server returned a file instead of JSON. Please check the Traccar server settings for reports.'.tr)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load trips report.'.tr)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (_tripsReport.isEmpty && hasCachedRoute) {
      _applyCachedTrips(cachedRoute.positions, deviceId, deviceName);
    }
  }

  void _applyCachedTrips(List<api.Position> positions, int deviceId, String deviceName) {
    final analysis = RouteHistoryAnalyzer.analyze(positions);
    _tripsReport = analysis.trips.map((trip) => TripReport.fromAnalyzed(trip, deviceId: deviceId, deviceName: deviceName)).toList();
    _deviceName = deviceName;
    if (mounted) setState(() => _isLoading = false);
    _createMapElements();
  }

  Future<void> _onStyleLoaded() async {
    _isStyleLoaded = true;
    _loadedIcons.clear();
    if (_tripsReport.isNotEmpty) {
      await _preloadIcons();
      await _createMapElements();
    }
  }

  Future<void> _preloadIcons() async {
    await Future.wait([_ensureIcon("start_pin", "assets/images/start.png"), _ensureIcon("end_pin", "assets/images/destination.png")]);
  }

  Future<void> _ensureIcon(String iconId, String assetPath) async {
    final controller = _mapController;
    if (controller == null || _loadedIcons.contains(iconId)) return;
    _loadedIcons.add(iconId);
    try {
      final Uint8List bytes = _iconBytes[iconId] ??= (await rootBundle.load(assetPath)).buffer.asUint8List();
      await controller.addImage(iconId, bytes);
    } catch (e) {
      debugPrint('addImage failed for $iconId: $e');
    }
  }

  Future<void> _createMapElements() async {
    final controller = _mapController;
    if (controller == null || !_isStyleLoaded || _tripsReport.isEmpty) return;

    if (_isDrawing) {
      _pendingDraw = true;
      return;
    }

    _isDrawing = true;
    try {
      await controller.clearSymbols();
      await controller.clearLines();

      final List<maplibre.LatLng> allPoints = [];
      if (!mounted) return;
      final String primaryColorHex = Theme.of(context).colorScheme.primary.toHex();

      for (var i = 0; i < _tripsReport.length; i++) {
        final trip = _tripsReport[i];
        final start = maplibre.LatLng(trip.startLat, trip.startLon);
        final end = maplibre.LatLng(trip.endLat, trip.endLon);

        allPoints.add(start);
        allPoints.add(end);

        final bool isSelected = _selectedIndex == i;
        await controller.addLine(maplibre.LineOptions(geometry: [start, end], lineColor: isSelected ? Theme.of(context).colorScheme.error.toHex() : primaryColorHex, lineWidth: isSelected ? 6.0 : 3.5, lineOpacity: isSelected ? 1.0 : 0.7));

        await _addMarker(start, "start_$i", "assets/images/start.png");
        await _addMarker(end, "end_$i", "assets/images/destination.png");
      }

      if (allPoints.isNotEmpty && _selectedIndex == null) {
        _zoomToFit(allPoints);
      }
    } finally {
      _isDrawing = false;
      if (_pendingDraw) {
        _pendingDraw = false;
        await _createMapElements();
      }
    }
  }

  Future<void> _addMarker(maplibre.LatLng point, String iconId, String assetPath) async {
    final controller = _mapController;
    if (controller == null) return;
    final baseIconId = assetPath.contains("start") ? "start_pin" : "end_pin";
    await _ensureIcon(baseIconId, assetPath);
    await controller.addSymbol(maplibre.SymbolOptions(geometry: point, iconImage: baseIconId, iconSize: 1.2, iconAnchor: "bottom"));
  }

  void _zoomToFit(List<maplibre.LatLng> points) {
    if (points.isEmpty) return;
    double minLat = points.map((p) => p.latitude).reduce(min);
    double maxLat = points.map((p) => p.latitude).reduce(max);
    double minLng = points.map((p) => p.longitude).reduce(min);
    double maxLng = points.map((p) => p.longitude).reduce(max);

    _mapController?.animateCamera(maplibre.CameraUpdate.newLatLngBounds(maplibre.LatLngBounds(southwest: maplibre.LatLng(minLat, minLng), northeast: maplibre.LatLng(maxLat, maxLng)), left: 60, right: 60, top: 60, bottom: 60));
  }

  void _onTripSelected(int index, TripReport trip) {
    setState(() {
      _selectedIndex = index;
    });
    _createMapElements();

    // 平移並放大至該行程起終點範圍
    final start = maplibre.LatLng(trip.startLat, trip.startLon);
    final end = maplibre.LatLng(trip.endLat, trip.endLon);
    _zoomToFit([start, end]);
  }

  String _formatDuration(int milliseconds) {
    int seconds = (milliseconds / 1000).round();
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m ${seconds % 60}s';
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} ${'sharedKm'.tr}';
    }
    return '${meters.toStringAsFixed(0)} ${'sharedMeters'.tr}';
  }

  double get _totalDistance => _tripsReport.fold<double>(0, (sum, trip) => sum + trip.distance);
  int get _totalDuration => _tripsReport.fold<int>(0, (sum, trip) => sum + trip.duration);
  double get _maxSpeedKmh => _tripsReport.isEmpty ? 0 : _tripsReport.map((trip) => trip.maxSpeed).reduce(max);
  double get _averageSpeedKmh => _totalDuration <= 0 ? 0 : _totalDistance / (_totalDuration / 1000) * 3.6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapProvider = Provider.of<MapStyleProvider>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('reportTrips'.tr)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_tripsReport.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_deviceName ?? 'reportTrips'.tr)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_car_outlined, size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text('sharedNoData'.tr, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ),
      );
    }

    final initialCenter = maplibre.LatLng(_tripsReport.first.startLat, _tripsReport.first.startLon);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('reportTrips'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_deviceName != null) Text(_deviceName!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: Column(
        children: [
          // 地圖展示區域
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.35,
            child: Stack(
              children: [
                maplibre.MapLibreMap(
                  key: ValueKey(mapProvider.isSatelliteMode),
                  onMapCreated: (c) {
                    _mapController = c;
                    _isStyleLoaded = false;
                    _loadedIcons.clear();
                  },
                  onStyleLoadedCallback: _onStyleLoaded,
                  initialCameraPosition: maplibre.CameraPosition(target: initialCenter, zoom: 13.0),
                  styleString: mapProvider.getStyle(theme.brightness),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    heroTag: "btn_style_trip",
                    elevation: 3,
                    backgroundColor: theme.colorScheme.surface,
                    onPressed: () => mapProvider.toggleMapType(),
                    child: Icon(mapProvider.isSatelliteMode ? Icons.map_outlined : Icons.satellite_alt_outlined, color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),

          // 報表總覽與列表
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -3))],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  itemCount: _tripsReport.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildSummaryHeader(theme);
                    }
                    final tripIndex = index - 1;
                    final trip = _tripsReport[tripIndex];
                    final isSelected = _selectedIndex == tripIndex;

                    return _buildTripCard(theme, trip, tripIndex, isSelected);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 頂部數據總覽 Dashboard 卡片
  Widget _buildSummaryHeader(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'historyTripsSummary'.tr,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildKpiTile(theme, Icons.route, 'historyTotalDistance'.tr, _formatDistance(_totalDistance)),
              _buildKpiTile(theme, Icons.timer_outlined, 'historyTotalDuration'.tr, _formatDuration(_totalDuration)),
              _buildKpiTile(theme, Icons.speed, 'historyMaxSpeed'.tr, '${_maxSpeedKmh.toStringAsFixed(1)} ${'sharedKmh'.tr}'),
              _buildKpiTile(theme, Icons.functions, 'historyAverageSpeed'.tr, '${_averageSpeedKmh.toStringAsFixed(1)} ${'sharedKmh'.tr}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTile(ThemeData theme, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 單筆行程卡片 (時間軸設計)
  /// 單筆行程卡片 (時間軸設計)
  Widget _buildTripCard(ThemeData theme, TripReport trip, int index, bool isSelected) {
    final String startTimeStr = DateFormat('HH:mm').format(trip.startTime.toLocal());
    final String endTimeStr = DateFormat('HH:mm').format(trip.endTime.toLocal());
    final String dateStr = DateFormat('yyyy-MM-dd').format(trip.startTime.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.15) : theme.colorScheme.surface,
        // 移除這裡原本的 borderRadius: BorderRadius.circular(16)，改由 shape 統一控制
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant.withOpacity(0.5), width: isSelected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onTripSelected(index, trip),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 卡片頁眉：行程編號、日期、距離標籤
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            '#${index + 1}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(dateStr, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        _formatDistance(trip.distance),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 時間軸 (起點與終點)
                _buildTimelineNode(theme, isStart: true, timeStr: startTimeStr, lat: trip.startLat, lon: trip.startLon, providedAddress: trip.startAddress),
                _buildTimelineConnector(theme, duration: _formatDuration(trip.duration)),
                _buildTimelineNode(theme, isStart: false, timeStr: endTimeStr, lat: trip.endLat, lon: trip.endLon, providedAddress: trip.endAddress),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // 速度細節
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSpeedStat(theme, 'historyMaxSpeed'.tr, '${trip.maxSpeed.toStringAsFixed(1)} ${'sharedKmh'.tr}'),
                    Container(height: 16, width: 1, color: theme.colorScheme.outlineVariant),
                    _buildSpeedStat(theme, 'reportAverageSpeed'.tr, '${trip.averageSpeed.toStringAsFixed(1)} ${'sharedKmh'.tr}'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineNode(ThemeData theme, {required bool isStart, required String timeStr, required double lat, required double lon, String? providedAddress}) {
    final color = isStart ? Colors.green : Colors.red;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 45,
          child: Text(
            timeStr,
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
        ),
        Icon(isStart ? Icons.circle : Icons.location_on, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: FutureBuilder<String>(
            future: (providedAddress != null && providedAddress.isNotEmpty) ? Future.value(providedAddress) : OfflineAddressService.getAddress(lat, lon),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? '...',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineConnector(ThemeData theme, {required String duration}) {
    return Padding(
      padding: const EdgeInsets.only(left: 45 + 7), // 避開時間寬度與點
      child: Row(
        children: [
          Container(width: 2, height: 24, color: theme.colorScheme.outlineVariant),
          const SizedBox(width: 12),
          Icon(Icons.schedule, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(duration, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildSpeedStat(ThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
      ],
    );
  }
}

extension ColorToHex on Color {
  String toHex() => '#${toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
}
