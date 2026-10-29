// lib/screens/reports/stops_report_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
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

class StopReport {
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
  final int positionId;
  final double latitude;
  final double longitude;
  final String? address;
  final int duration;
  final int? engineHours;

  StopReport({
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
    required this.positionId,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.duration,
    this.engineHours,
  });

  factory StopReport.fromJson(Map<String, dynamic> json) {
    return StopReport(
      deviceId: json['deviceId'] as int,
      deviceName: json['deviceName'] as String,
      distance: (json['distance'] as num).toDouble(),
      averageSpeed: (json['averageSpeed'] as num).toDouble(),
      maxSpeed: (json['maxSpeed'] as num).toDouble(),
      spentFuel: (json['spentFuel'] as num).toDouble(),
      startOdometer: (json['startOdometer'] as num).toDouble(),
      endOdometer: (json['endOdometer'] as num).toDouble(),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      positionId: json['positionId'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      duration: json['duration'] as int,
      engineHours: json['engineHours'] as int?,
    );
  }

  factory StopReport.fromAnalyzed(AnalyzedStop stop, {required int deviceId, required String deviceName}) {
    return StopReport(
      deviceId: deviceId,
      deviceName: deviceName,
      distance: 0,
      averageSpeed: 0,
      maxSpeed: 0,
      spentFuel: 0,
      startOdometer: 0,
      endOdometer: 0,
      startTime: stop.startTime,
      endTime: stop.endTime,
      positionId: 0,
      latitude: stop.latitude,
      longitude: stop.longitude,
      duration: stop.durationMs,
    );
  }
}

class StopsReportScreen extends StatefulWidget {
  const StopsReportScreen({super.key});

  @override
  State<StopsReportScreen> createState() => _StopsReportScreenState();
}

class _StopsReportScreenState extends State<StopsReportScreen> {
  List<StopReport> _stopsReport = [];
  bool _isLoading = true;
  String? _deviceName;
  maplibre.MapLibreMapController? _mapController;
  final Set<String> _loadedIcons = {};
  final Map<String, Uint8List> _iconBytes = {};
  bool _isStyleLoaded = false;
  bool _isDrawing = false;
  bool _pendingDraw = false;
  int? _selectedStopIndex;

  // 用來控制底部拖曳面板的收合與展開
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _fetchStopsReport();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _fetchStopsReport() async {
    setState(() => _isLoading = true);

    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getInt('selectedDeviceId');
    final fromDateString = prefs.getString('historyFrom');
    final toDateString = prefs.getString('historyTo');

    if (deviceId == null || fromDateString == null || toDateString == null) {
      setState(() => _isLoading = false);
      return;
    }

    final fromDate = DateTime.tryParse(fromDateString);
    final toDate = DateTime.tryParse(toDateString);

    if (fromDate == null || toDate == null) {
      setState(() => _isLoading = false);
      return;
    }

    final bool isSingleDayRange = fromDate.year == toDate.year && fromDate.month == toDate.month && fromDate.day == toDate.day;
    final CachedRoutePositions? cachedRoute = isSingleDayRange ? await RouteHistoryCache.load(deviceId: deviceId, day: fromDate) : null;
    final bool hasCachedRoute = cachedRoute != null && cachedRoute.positions.length >= 2;
    final String deviceName = prefs.getString('selectedDeviceName') ?? '';

    if (hasCachedRoute && cachedRoute.isFreshFor(fromDate)) {
      _applyCachedStops(cachedRoute.positions, deviceId, deviceName);
      return;
    }

    try {
      final apiClient = traccarProvider.apiClient;
      final queryParams = [api.QueryParam('from', fromDate.toIso8601String()), api.QueryParam('to', toDate.toIso8601String()), api.QueryParam('deviceId', deviceId.toString())];

      final http.Response response = await apiClient.invokeAPI('/reports/stops', 'GET', queryParams, null, {'Accept': 'application/json'}, {}, 'application/json');

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final contentType = response.headers['content-type'];
        if (contentType != null && contentType.contains('application/json')) {
          final decodedData = json.decode(response.body);

          if (decodedData is List && decodedData.isNotEmpty) {
            _stopsReport = decodedData.map((e) => StopReport.fromJson(e as Map<String, dynamic>)).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
            if (_stopsReport.isNotEmpty) {
              _deviceName = _stopsReport.first.deviceName;
              _createMapElements();
            }
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load stops report. The server returned a file instead of JSON. Please check the Traccar server settings for reports.'.tr)));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load stops report.'.tr)));
    } finally {
      setState(() => _isLoading = false);
    }

    if (_stopsReport.isEmpty && hasCachedRoute) {
      _applyCachedStops(cachedRoute.positions, deviceId, deviceName);
    }
  }

  void _applyCachedStops(List<api.Position> positions, int deviceId, String deviceName) {
    final analysis = RouteHistoryAnalyzer.analyze(positions);
    _stopsReport = analysis.stops.map((stop) => StopReport.fromAnalyzed(stop, deviceId: deviceId, deviceName: deviceName)).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
    _deviceName = deviceName;
    if (!mounted) return;
    setState(() => _isLoading = false);
    _createMapElements();
  }

  Future<void> _onStyleLoaded() async {
    _isStyleLoaded = true;
    _loadedIcons.clear();
    if (_stopsReport.isNotEmpty) {
      await _preloadIcons();
      await _createMapElements();
    }
  }

  Future<void> _preloadIcons() async {
    final controller = _mapController;
    if (controller == null) return;
    final iconIds = <String>{for (var i = 0; i < _stopsReport.length; i++) "p_${(i % 50) + 1}"};
    await Future.wait(iconIds.map((iconId) => _ensureIcon(iconId, 'assets/images/$iconId.png')));
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
    if (controller == null || !_isStyleLoaded || _stopsReport.isEmpty) return;

    if (_isDrawing) {
      _pendingDraw = true;
      return;
    }

    _isDrawing = true;
    try {
      await controller.clearSymbols();
      final List<maplibre.LatLng> points = [];

      for (var i = 0; i < _stopsReport.length; i++) {
        final stop = _stopsReport[i];
        final point = maplibre.LatLng(stop.latitude, stop.longitude);
        points.add(point);
        final iconId = "p_${(i % 50) + 1}";
        await _addMarker(point, iconId, "assets/images/$iconId.png");
      }

      if (points.isNotEmpty) {
        _zoomToFitAll();
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
    await _ensureIcon(iconId, assetPath);
    await controller.addSymbol(maplibre.SymbolOptions(geometry: point, iconImage: iconId, iconSize: 3.0, iconAnchor: "bottom"));
  }

  void _zoomToFitAll() {
    if (_stopsReport.isEmpty) return;
    final points = _stopsReport.map((s) => maplibre.LatLng(s.latitude, s.longitude)).toList();
    double minLat = points.map((p) => p.latitude).reduce(min);
    double maxLat = points.map((p) => p.latitude).reduce(max);
    double minLng = points.map((p) => p.longitude).reduce(min);
    double maxLng = points.map((p) => p.longitude).reduce(max);

    _mapController?.animateCamera(maplibre.CameraUpdate.newLatLngBounds(maplibre.LatLngBounds(southwest: maplibre.LatLng(minLat, minLng), northeast: maplibre.LatLng(maxLat, maxLng)), left: 60, right: 60, top: 80, bottom: 250));
  }

  void _animateToPosition(maplibre.LatLng position, int index) {
    setState(() => _selectedStopIndex = index);

    if (_sheetController.isAttached && _sheetController.size > 0.4) {
      _sheetController.animateTo(0.3, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }

    _mapController?.animateCamera(maplibre.CameraUpdate.newLatLngZoom(position, 16.0));
  }

  static String formatDuration(int milliseconds) {
    int seconds = (milliseconds / 1000).round();
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      );
    }

    if (_stopsReport.isEmpty) {
      return Scaffold(
        appBar: CupertinoNavigationBar(middle: Text(_deviceName ?? 'reportStops'.tr)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off_outlined, size: 64, color: colorScheme.outline),
              const SizedBox(height: 16),
              Text('sharedNoData'.tr, style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.outline)),
            ],
          ),
        ),
      );
    }

    final mapProvider = Provider.of<MapStyleProvider>(context);
    final initialCenter = maplibre.LatLng(_stopsReport.first.latitude, _stopsReport.first.longitude);

    return Scaffold(
      body: Stack(
        children: [
          maplibre.MapLibreMap(
            key: ValueKey(mapProvider.isSatelliteMode),
            onMapCreated: (c) {
              _mapController = c;
              _isStyleLoaded = false;
              _loadedIcons.clear();
            },
            onStyleLoadedCallback: _onStyleLoaded,
            initialCameraPosition: maplibre.CameraPosition(target: initialCenter, zoom: 14.0),
            styleString: mapProvider.getStyle(theme.brightness),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('reportStops'.tr, style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.secondary)),
                          Text(
                            _deviceName ?? '',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        '${_stopsReport.length} ${'stops'.tr}',
                        style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 80,
            right: 16,
            child: Column(
              children: [
                _MapControlButton(icon: mapProvider.isSatelliteMode ? Icons.map_outlined : Icons.satellite_alt_outlined, onPressed: () => mapProvider.toggleMapType()),
                const SizedBox(height: 8),
                _MapControlButton(icon: Icons.center_focus_strong, onPressed: _zoomToFitAll),
              ],
            ),
          ),
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.35,
            minChildSize: 0.15,
            maxChildSize: 0.85,
            snap: true,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, -4))],
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 6),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: colorScheme.onSurfaceVariant.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('historyStopsCount'.trParams({'count': '${_stopsReport.length}'}), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('Tap item to locate'.tr, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _stopsReport.length,
                        itemBuilder: (context, index) {
                          final stop = _stopsReport[index];
                          final isSelected = _selectedStopIndex == index;
                          return _StopTimelineTile(index: index + 1, stop: stop, isSelected: isSelected, isLast: index == _stopsReport.length - 1, onTap: () => _animateToPosition(maplibre.LatLng(stop.latitude, stop.longitude), index));
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MapControlButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface.withOpacity(0.9),
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Icon(icon, color: colorScheme.onSurface, size: 22),
        ),
      ),
    );
  }
}

class _StopTimelineTile extends StatelessWidget {
  final int index;
  final StopReport stop;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;

  const _StopTimelineTile({required this.index, required this.stop, required this.isSelected, required this.isLast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final durationStr = _StopsReportScreenState.formatDuration(stop.duration);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: colorScheme.onPrimary, width: 2) : null,
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: TextStyle(color: isSelected ? colorScheme.onPrimary : colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: colorScheme.outlineVariant, margin: const EdgeInsets.symmetric(vertical: 4)),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Card(
                elevation: isSelected ? 3 : 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isSelected ? BorderSide(color: colorScheme.primary, width: 1.5) : BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                color: isSelected ? colorScheme.primaryContainer.withOpacity(0.15) : colorScheme.surface,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 16, color: colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(DateFormat('HH:mm').format(stop.startTime.toLocal()), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                Text(' - ${DateFormat('HH:mm').format(stop.endTime.toLocal())}', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                durationStr,
                                style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onTertiaryContainer, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Icon(Icons.location_on_outlined, size: 16, color: colorScheme.outline),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: FutureBuilder<String>(
                                future: stop.address != null && stop.address!.isNotEmpty ? Future.value(stop.address) : OfflineAddressService.getAddress(stop.latitude, stop.longitude),
                                builder: (context, snapshot) {
                                  return Text(
                                    snapshot.data ?? 'Address not available'.tr,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        if (stop.engineHours != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.build_circle_outlined, size: 14, color: colorScheme.outline),
                              const SizedBox(width: 4),
                              Text('${'reportEngineHours'.tr}: ${_StopsReportScreenState.formatDuration(stop.engineHours!)}', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
