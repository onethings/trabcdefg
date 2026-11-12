// lib/screens/reports/geofences_report_screen.dart
// A screen to display geofence enter/exit intervals report.
// Based on traccar-web GeofenceReportPage.

import 'package:flutter/cupertino.dart';
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

  factory GeofenceItem.fromApi(api.ReportGeofences item) {
    final start = item.startTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    return GeofenceItem(
      deviceId: item.deviceId ?? 0,
      deviceName: item.deviceName ?? '',
      geofenceId: item.geofenceId ?? 0,
      startTime: start,
      endTime: item.endTime ?? start,
    );
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
      final geofences = await api.GeofencesApi(traccarProvider.apiClient).getGeofences() ?? [];
      if (!mounted) return;
      setState(() {
        _allGeofences = geofences;
        _geofenceNames
          ..clear()
          ..addEntries(geofences.where((g) => g.id != null && g.name != null).map((g) => MapEntry(g.id!, g.name!)));
      });
    } catch (e) {
      debugPrint('Error fetching geofences: $e');
    }
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
      final reportsApi = api.ReportsApi(traccarProvider.apiClient);
      final typedItems = await reportsApi.getReportsGeofences(
        fromDate,
        toDate,
        deviceId: [deviceId],
        geofenceId: _selectedGeofenceId != null ? [_selectedGeofenceId!] : null,
      ) ?? [];
      if (mounted) {
        setState(() => _items = typedItems.map(GeofenceItem.fromApi).toList());
      }
    } catch (e) {
      debugPrint('Error fetching geofences report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('reportGeofencesLoadFailed'.tr)));
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
      appBar: CupertinoNavigationBar(
        middle: Text('reportGeofences'.tr),
        trailing: PopupMenuButton<String>(
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
