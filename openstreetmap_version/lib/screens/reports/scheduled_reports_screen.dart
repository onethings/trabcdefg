// lib/screens/reports/scheduled_reports_screen.dart
// Scheduled reports using /api/reports endpoint (traccar-web style).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';

class ScheduledReport {
  final int id;
  final String type;
  final String? description;
  final int? calendarId;
  final Map<String, dynamic> attributes;

  ScheduledReport({required this.id, required this.type, this.description, this.calendarId, this.attributes = const {}});

  factory ScheduledReport.fromJson(Map<String, dynamic> json) {
    return ScheduledReport(id: json['id'] as int, type: json['type'] as String, description: json['description'] as String?, calendarId: json['calendarId'] as int?, attributes: json['attributes'] as Map<String, dynamic>? ?? {});
  }
}

class ScheduledReportsScreen extends StatefulWidget {
  const ScheduledReportsScreen({super.key});

  @override
  State<ScheduledReportsScreen> createState() => _ScheduledReportsScreenState();
}

class _ScheduledReportsScreenState extends State<ScheduledReportsScreen> {
  List<ScheduledReport> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    try {
      final response = await traccarProvider.apiClient.invokeAPI('/reports', 'GET', [], null, {'Accept': 'application/json'}, {}, 'application/json');
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body) as List? ?? [];
        _items = data.map((e) => ScheduledReport.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Scheduled reports error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load scheduled reports.'.tr)));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(int id) async {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    try {
      await traccarProvider.apiClient.invokeAPI('/reports/$id', 'DELETE', [], null, {}, {}, null);
      _fetch();
    } catch (e) {
      debugPrint('Delete error: $e');
    }
  }

  String _fmtType(String type) {
    switch (type) {
      case 'events':
        return 'reportEvents'.tr;
      case 'route':
        return 'reportPositions'.tr;
      case 'summary':
        return 'reportSummary'.tr;
      case 'trips':
        return 'reportTrips'.tr;
      case 'stops':
        return 'reportStops'.tr;
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('reportScheduled'.tr)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule_send, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('No scheduled reports configured.'.tr, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(
                    'Create one from a report using the Schedule option.'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final item = _items[i];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(Icons.schedule_send, color: Theme.of(context).colorScheme.primary),
                    title: Text(
                      _fmtType(item.type),
                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                    ),
                    subtitle: Text(item.description ?? 'reportSchedule'.tr, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('sharedRemoveConfirm'.tr),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('sharedCancel'.tr)),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _delete(item.id);
                                },
                                child: Text('sharedRemove'.tr),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
