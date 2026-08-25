// lib/screens/reports/chart_report_screen.dart
// Chart report with dynamic attribute detection, multiple lines, time type selection.
// Based on traccar-web ChartReportPage.
import 'dart:convert';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
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
          // Build flattened data with timestamps as ms
          _rawItems = data.map<Map<String, dynamic>>((pos) {
            final m = <String, dynamic>{};
            final p = pos as Map<String, dynamic>;
            for (final timeKey in ['fixTime', 'deviceTime', 'serverTime']) {
              if (p[timeKey] != null) {
                m[timeKey] = DateTime.parse(p[timeKey] as String).millisecondsSinceEpoch.toDouble();
              }
            }
            // Copy numeric fields (speed as knots, convert to kmh for display)
            for (final key in ['speed', 'altitude', 'course', 'accuracy', 'bearing']) {
              if (p[key] != null && p[key] is num) {
                m[key] = (p[key] as num).toDouble();
              }
            }
            // Copy attributes
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

          // Detect available numeric keys (skip id, time fields)
          final keySet = <String>{};
          final skipKeys = {'id', 'deviceId', 'fixTime', 'deviceTime', 'serverTime', 'latitude', 'longitude'};
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
      setState(() => _isLoading = false);
    }
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
    return Scaffold(
      appBar: AppBar(title: Text('${'reportChart'.tr}: ${_deviceName ?? ''}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rawItems.isEmpty
          ? Center(child: Text('sharedNoData'.tr))
          : Column(
              children: [
                // Filters row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: _buildMultiSelect()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTimeTypeSelect()),
                    ],
                  ),
                ),
                // Chart
                Expanded(
                  child: Padding(padding: const EdgeInsets.fromLTRB(8, 8, 16, 8), child: _buildChart()),
                ),
                // Stats
                _buildStatsCard(),
              ],
            ),
    );
  }

  Widget _buildMultiSelect() {
    final color = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (ctx) {
            return StatefulBuilder(
              builder: (ctx, setSheetState) {
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'reportChartType'.tr,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color.onSurface),
                      ),
                      const Divider(),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: _availableKeys.map((key) {
                            final checked = _selectedKeys.contains(key);
                            return CheckboxListTile(
                              value: checked,
                              title: Text(_keyLabel(key)),
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
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: Text('sharedAccept'.tr)),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: color.onSurface.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedKeys.isEmpty ? 'reportChartType'.tr : _selectedKeys.map((k) => _keyLabel(k)).join(', '),
                style: TextStyle(fontSize: 13, color: _selectedKeys.isEmpty ? color.onSurfaceVariant : color.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: color.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeTypeSelect() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        value: _timeType,
        dropdownColor: Theme.of(context).colorScheme.surface,
        items: [
          DropdownMenuItem(value: 'fixTime', child: Text('positionFixTime'.tr)),
          DropdownMenuItem(value: 'deviceTime', child: Text('positionDeviceTime'.tr)),
          DropdownMenuItem(value: 'serverTime', child: Text('positionServerTime'.tr)),
        ],
        onChanged: (val) => setState(() => _timeType = val!),
      ),
    );
  }

  Widget _buildChart() {
    if (_rawItems.isEmpty) return Center(child: Text('sharedNoData'.tr));

    final colorPalette = [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary, Theme.of(context).colorScheme.error, Colors.orange, Colors.teal, Colors.purple];

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

      // Convert speed from knots to km/h
      final convertedSpots = (key == 'speed') ? spots.map((s) => FlSpot(s.x, s.y * 1.852)).toList() : spots;

      lineBars.add(
        LineChartBarData(
          spots: convertedSpots,
          isCurved: true,
          color: colorPalette[ci % colorPalette.length],
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: lineBars.isEmpty, color: colorPalette[ci % colorPalette.length].withValues(alpha: 0.1)),
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
    final yPad = (maxY - minY) * 0.1;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (v) => FlLine(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08), strokeWidth: 1),
          getDrawingVerticalLine: (v) => FlLine(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, m) => SideTitleWidget(
                meta: m,
                child: Text(_fmtTime(v), style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurface)),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, m) => SideTitleWidget(
                meta: m,
                child: Text(v.toStringAsFixed(0), style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurface)),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Theme.of(context).colorScheme.onSurface),
            bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        minX: minX,
        maxX: maxX,
        minY: (minY - yPad).clamp(0, double.infinity),
        maxY: maxY + yPad,
        lineBarsData: lineBars,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              final idx = lineBars.indexOf(s.bar);
              final label = idx >= 0 && idx < _selectedKeys.length ? _keyLabel(_selectedKeys.elementAt(idx)) : '';
              return LineTooltipItem('$label: ${s.y.toStringAsFixed(1)}', TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold));
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

  Widget _buildStatsCard() {
    if (_rawItems.isEmpty) return const SizedBox.shrink();
    final speeds = _rawItems.map((m) => (m['speed'] as double?)?.let((v) => v * 1.852) ?? 0.0);
    final maxS = speeds.reduce(max);
    final avgS = speeds.reduce((a, b) => a + b) / speeds.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'reportSummary'.tr,
                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
              ),
              const Divider(height: 8),
              _statRow('reportMaximumSpeed'.tr, '${maxS.toStringAsFixed(1)} ${'sharedKmh'.tr}'),
              _statRow('reportAverageSpeed'.tr, '${avgS.toStringAsFixed(1)} ${'sharedKmh'.tr}'),
              _statRow('reportPositions'.tr, '${_rawItems.length}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

extension _NumOp<T extends num> on T {
  R let<R>(R Function(T) f) => f(this);
}
