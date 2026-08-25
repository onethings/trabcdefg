// lib/screens/reports/geofences_report_screen.dart
// A screen to display geofence enter/exit intervals report.
// Based on traccar-web GeofenceReportPage.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class GeofenceItem {
  final int deviceId;
  final String deviceName;
  final int geofenceId;
  final DateTime startTime;
  final DateTime endTime;

  GeofenceItem({required this.deviceId, required this.deviceName, required this.geofenceId, required this.startTime, required this.endTime});

  factory GeofenceItem.fromJson(Map<String, dynamic> json) {
    return GeofenceItem(deviceId: json['deviceId'] as int, deviceName: json['deviceName'] as String, geofenceId: json['geofenceId'] as int, startTime: DateTime.parse(json['startTime'] as String), endTime: DateTime.parse(json['endTime'] as String));
  }

  Duration get duration => endTime.difference(startTime);
}

class GeofencesReportScreen extends StatefulWidget {
  const GeofencesReportScreen({super.key});

  @override
  State<GeofencesReportScreen> createState() => _GeofencesReportScreenState();
}

class _GeofencesReportScreenState extends State<GeofencesReportScreen> {
  List<GeofenceItem> _items = [];
  bool _isLoading = true;
  int? _selectedGeofenceId;
  final Map<int, String> _geofenceNames = {};
  List<api.Geofence> _allGeofences = [];
  bool _showDuration = false;

  @override
  void initState() {
    super.initState();
    _fetchGeofences();
    _fetchReport();
  }

  Future<void> _fetchGeofences() async {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    try {
      final response = await traccarProvider.apiClient.invokeAPI('/geofences', 'GET', [], null, {'Accept': 'application/json'}, {}, 'application/json');
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);
        if (data is List) {
          _allGeofences = data.map((g) => api.Geofence.fromJson(g)).whereType<api.Geofence>().toList();
          for (final gf in _allGeofences) {
            final id = gf.id;
            final name = gf.name;
            if (id != null && name != null) {
              _geofenceNames[id] = name;
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchReport() async {
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
      final queryParams = [api.QueryParam('from', fromDate.toIso8601String()), api.QueryParam('to', toDate.toIso8601String()), api.QueryParam('deviceId', deviceId.toString())];
      if (_selectedGeofenceId != null) {
        queryParams.add(api.QueryParam('geofenceId', _selectedGeofenceId.toString()));
      }
      final response = await traccarProvider.apiClient.invokeAPI('/reports/geofences', 'GET', queryParams, null, {'Accept': 'application/json'}, {}, 'application/json');
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body);
        if (data is List) {
          _items = data.map((e) => GeofenceItem.fromJson(e as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching geofences report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load geofences report.'.tr)));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _fmtDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('reportGeofences'.tr),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.view_column),
            onSelected: (_) => setState(() => _showDuration = !_showDuration),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'duration',
                child: Row(
                  children: [
                    Checkbox(value: _showDuration, onChanged: null, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    const SizedBox(width: 8),
                    Text('reportDuration'.tr),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_allGeofences.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  isExpanded: true,
                  value: _selectedGeofenceId,
                  hint: Text('sharedGeofences'.tr),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  items: [
                    DropdownMenuItem(value: null, child: Text('eventAll'.tr)),
                    ..._allGeofences.map((gf) {
                      final id = gf.id;
                      return DropdownMenuItem(value: id, child: Text(gf.name ?? 'Geofence #$id'));
                    }),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedGeofenceId = val);
                    _fetchReport();
                  },
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? Center(child: Text('sharedNoData'.tr))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      final name = _geofenceNames[item.geofenceId] ?? 'Geofence #${item.geofenceId}';
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.fence, size: 20, color: Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 12),
                              _row('reportDevice'.tr, item.deviceName),
                              _row('reportStartTime'.tr, DateFormat('yyyy-MM-dd HH:mm').format(item.startTime.toLocal())),
                              _row('reportEndTime'.tr, DateFormat('yyyy-MM-dd HH:mm').format(item.endTime.toLocal())),
                              if (_showDuration) _row('reportDuration'.tr, _fmtDuration(item.duration)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
