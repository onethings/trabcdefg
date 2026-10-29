// lib/screens/reports/chart_report_screen.dart
// Modernized Chart Report Screen with dynamic attributes, clean Material 3 UI, dynamic legend, and statistics dashboard.
import 'dart:convert';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/services/route_history_cache.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class ChartReportScreen extends StatefulWidget {
  const ChartReportScreen({super.key});

  @override
  State<ChartReportScreen> createState() => _ChartReportScreenState();
}

class _ChartReportScreenState extends State<ChartReportScreen> {
  List<Map<String, dynamic>> _rawItems = [];
  bool _isLoading = true;
  String? _deviceName;

  // Dynamically detected numeric keys from position data
  final List<String> _availableKeys = [];
  final Set<String> _selectedKeys = {'speed'};
  String _timeType = 'fixTime';

  // Preset Color Palette for Chart Lines
  static const List<Color> _chartColors = [
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
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

    if (hasCachedRoute && cachedRoute.isFreshFor(fromDate)) {
      _applyCachedChart(cachedRoute.positions, prefs.getString('selectedDeviceName'));
      return;
    }

    try {
      final response = await traccarProvider.apiClient.invokeAPI(
        '/reports/route',
        'GET',
        [api.QueryParam('from', fromDate.toIso8601String()), api.QueryParam('to', toDate.toIso8601String()), api.QueryParam('deviceId', deviceId.toString())],
        null,
        {'Accept': 'application/json'},
        {},
        'application/json',
      );
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body) as List? ?? [];
        if (data.isNotEmpty) {
          _rawItems = data.map<Map<String, dynamic>>((pos) {
            final m = <String, dynamic>{};
            final p = pos as Map<String, dynamic>;
            for (final timeKey in ['fixTime', 'deviceTime', 'serverTime']) {
              if (p[timeKey] != null) {
                m[timeKey] = DateTime.parse(p[timeKey] as String).millisecondsSinceEpoch.toDouble();
              }
            }
            for (final key in ['speed', 'altitude', 'course', 'accuracy', 'bearing']) {
              if (p[key] != null && p[key] is num) {
                m[key] = (p[key] as num).toDouble();
              }
            }
            if (p['attributes'] is Map) {
              for (final entry in (p['attributes'] as Map).entries) {
                if (entry.value is num) {
                  m[entry.key.toString()] = (entry.value as num).toDouble();
                }
              }
            }
            m['id'] = p['id'];
            m['latitude'] = (p['latitude'] as num?)?.toDouble() ?? 0;
            m['longitude'] = (p['longitude'] as num?)?.toDouble() ?? 0;
            return m;
          }).toList();

          _detectAvailableKeys();
          final device = traccarProvider.devices.firstWhere((d) => d.id == deviceId, orElse: () => api.Device());
          _deviceName = device.name;
        }
      }
    } catch (e) {
      debugPrint('Chart fetch error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load chart data.'.tr)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (_rawItems.isEmpty && hasCachedRoute) {
      _applyCachedChart(cachedRoute.positions, prefs.getString('selectedDeviceName'));
    }
  }

  void _applyCachedChart(List<api.Position> positions, String? deviceName) {
    _rawItems = positions.map(_cachedPositionToItem).toList();
    _detectAvailableKeys();
    _deviceName = deviceName;
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _detectAvailableKeys() {
    final keySet = <String>{};
    const skipKeys = {'id', 'deviceId', 'fixTime', 'deviceTime', 'serverTime', 'latitude', 'longitude'};
    for (final item in _rawItems) {
      for (final key in item.keys) {
        if (!skipKeys.contains(key) && item[key] is num) {
          keySet.add(key);
        }
      }
    }
    _availableKeys
      ..clear()
      ..addAll(['speed', 'altitude', ...keySet.where((k) => k != 'speed' && k != 'altitude')]);
  }

  Map<String, dynamic> _cachedPositionToItem(api.Position position) {
    final item = <String, dynamic>{};
    final fixTime = position.fixTime?.millisecondsSinceEpoch.toDouble();
    final deviceTime = position.deviceTime?.millisecondsSinceEpoch.toDouble();
    final serverTime = position.serverTime?.millisecondsSinceEpoch.toDouble();
    if (fixTime != null) item['fixTime'] = fixTime;
    if (deviceTime != null) item['deviceTime'] = deviceTime;
    if (serverTime != null) item['serverTime'] = serverTime;
    if (position.speed != null) item['speed'] = position.speed!.toDouble();
    if (position.altitude != null) item['altitude'] = position.altitude!.toDouble();
    if (position.course != null) item['course'] = position.course!.toDouble();
    if (position.accuracy != null) item['accuracy'] = position.accuracy!.toDouble();
    final attributes = position.attributes;
    if (attributes is Map) {
      for (final entry in attributes.entries) {
        if (entry.value is num) {
          item[entry.key.toString()] = (entry.value as num).toDouble();
        }
      }
    }
    item['id'] = position.id;
    item['latitude'] = position.latitude?.toDouble() ?? 0;
    item['longitude'] = position.longitude?.toDouble() ?? 0;
    return item;
  }

  String _keyLabel(String key) {
    final labels = <String, String>{
      'speed': '${'positionSpeed'.tr} (${'sharedKmh'.tr})',
      'altitude': '${'positionAltitude'.tr} (${'sharedMeters'.tr})',
      'course': '${'positionCourse'.tr} (°)',
      'accuracy': '${'positionAccuracy'.tr} (${'sharedMeters'.tr})',
      'bearing': 'Bearing (°)',
      'odometer': 'positionOdometer'.tr,
      'distance': 'positionDistance'.tr,
      'totalDistance': 'deviceTotalDistance'.tr,
      'hours': 'positionHours'.tr,
    };
    return labels[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('reportChart'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_deviceName != null && _deviceName!.isNotEmpty) Text(_deviceName!, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
          ],
        ),
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData, tooltip: 'Refresh')],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rawItems.isEmpty
          ? _buildEmptyState()
          : SafeArea(
              child: Column(
                children: [
                  // Filter bar
                  _buildFilterHeader(),

                  // Chart Card
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
                        ),
                        color: colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
                          child: Column(
                            children: [
                              _buildLegendBar(),
                              const SizedBox(height: 16),
                              Expanded(child: _buildChart()),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Stats Section
                  _buildStatsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart_rounded, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'sharedNoData'.tr,
            style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedText = _selectedKeys.isEmpty ? 'reportChartType'.tr : _selectedKeys.map((k) => _keyLabel(k)).join(', ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Dynamic Metrics Selector
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: _showMultiSelectBottomSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedText,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Time Type Dropdown
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _timeType,
                  icon: Icon(Icons.access_time_rounded, size: 18, color: colorScheme.primary),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  dropdownColor: colorScheme.surfaceContainerHigh,
                  items: [
                    DropdownMenuItem(value: 'fixTime', child: Text('positionFixTime'.tr)),
                    DropdownMenuItem(value: 'deviceTime', child: Text('positionDeviceTime'.tr)),
                    DropdownMenuItem(value: 'serverTime', child: Text('positionServerTime'.tr)),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _timeType = val);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMultiSelectBottomSheet() {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.65),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'reportChartType'.tr,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedKeys.clear());
                          setSheetState(() {});
                        },
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _availableKeys.length,
                      itemBuilder: (context, index) {
                        final key = _availableKeys[index];
                        final checked = _selectedKeys.contains(key);
                        return CheckboxListTile(
                          value: checked,
                          activeColor: colorScheme.primary,
                          title: Text(_keyLabel(key), style: const TextStyle(fontSize: 14)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (_) {
                            setState(() {
                              if (checked) {
                                _selectedKeys.remove(key);
                              } else {
                                _selectedKeys.add(key);
                              }
                            });
                            setSheetState(() {});
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('sharedAccept'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegendBar() {
    if (_selectedKeys.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _selectedKeys.toList().asMap().entries.map((entry) {
          final idx = entry.key;
          final key = entry.value;
          final color = _chartColors[idx % _chartColors.length];

          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  _keyLabel(key),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChart() {
    if (_rawItems.isEmpty || _selectedKeys.isEmpty) {
      return Center(
        child: Text('sharedNoData'.tr, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }

    final lineBars = <LineChartBarData>[];
    int ci = 0;

    for (final key in _selectedKeys) {
      final spots = <FlSpot>[];
      for (int i = 0; i < _rawItems.length; i++) {
        final val = _rawItems[i][key];
        final time = _rawItems[i][_timeType];
        if (val != null && time != null) {
          spots.add(FlSpot(time as double, val as double));
        }
      }
      if (spots.isEmpty) continue;

      final convertedSpots = (key == 'speed') ? spots.map((s) => FlSpot(s.x, s.y * 1.852)).toList() : spots;
      final barColor = _chartColors[ci % _chartColors.length];

      lineBars.add(
        LineChartBarData(
          spots: convertedSpots,
          isCurved: true,
          curveSmoothness: 0.2,
          color: barColor,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true, color: barColor.withOpacity(0.08)),
        ),
      );
      ci++;
    }

    if (lineBars.isEmpty) return Center(child: Text('sharedNoData'.tr));

    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;

    for (final bar in lineBars) {
      for (final s in bar.spots) {
        if (s.x < minX) minX = s.x;
        if (s.x > maxX) maxX = s.x;
        if (s.y < minY) minY = s.y;
        if (s.y > maxY) maxY = s.y;
      }
    }
    if (minX == double.infinity) minX = 0;
    if (maxX == double.negativeInfinity) maxX = 1;
    if (minY == double.infinity) minY = 0;
    if (maxY == double.negativeInfinity) maxY = 100;
    final yPad = (maxY - minY) == 0 ? 10.0 : (maxY - minY) * 0.15;

    final colorScheme = Theme.of(context).colorScheme;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: ((maxY - minY + yPad) / 4).clamp(1.0, double.infinity),
          getDrawingHorizontalLine: (v) => FlLine(color: colorScheme.outlineVariant.withOpacity(0.3), strokeWidth: 1, dashArray: [4, 4]),
          getDrawingVerticalLine: (v) => FlLine(color: colorScheme.outlineVariant.withOpacity(0.3), strokeWidth: 1, dashArray: [4, 4]),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: ((maxX - minX) / 4).clamp(1.0, double.infinity),
              getTitlesWidget: (v, m) => SideTitleWidget(
                meta: m,
                child: Text(
                  _fmtTime(v),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, m) => SideTitleWidget(
                meta: m,
                child: Text(
                  v.toStringAsFixed(0),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: minX,
        maxX: maxX,
        minY: (minY - yPad).clamp(0, double.infinity),
        maxY: maxY + yPad,
        lineBarsData: lineBars,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
            getTooltipItems: (spots) => spots.map((s) {
              final idx = lineBars.indexOf(s.bar);
              final label = idx >= 0 && idx < _selectedKeys.length ? _keyLabel(_selectedKeys.elementAt(idx)) : '';
              return LineTooltipItem('$label\n${s.y.toStringAsFixed(1)}', TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 12));
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _fmtTime(double ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildStatsSection() {
    if (_rawItems.isEmpty) return const SizedBox.shrink();

    final speeds = _rawItems.map((m) => (m['speed'] as double?)?.let((v) => v * 1.852) ?? 0.0).toList();
    final maxS = speeds.isNotEmpty ? speeds.reduce(max) : 0.0;
    final avgS = speeds.isNotEmpty ? speeds.reduce((a, b) => a + b) / speeds.length : 0.0;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'reportSummary'.tr,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(icon: Icons.speed_rounded, iconColor: Colors.orange, title: 'reportMaximumSpeed'.tr, value: '${maxS.toStringAsFixed(1)} ${'sharedKmh'.tr}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(icon: Icons.av_timer_rounded, iconColor: Colors.blue, title: 'reportAverageSpeed'.tr, value: '${avgS.toStringAsFixed(1)} ${'sharedKmh'.tr}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(icon: Icons.pin_drop_rounded, iconColor: Colors.teal, title: 'reportPositions'.tr, value: '${_rawItems.length}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({required IconData icon, required Color iconColor, required String title, required String value}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

extension _NumOp<T extends num> on T {
  R let<R>(R Function(T) f) => f(this);
}
