// lib/screens/reports/logs_report_screen.dart
// Audit log viewer with column selection (based on traccar-web AuditPage).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class AuditEntry {
  final int id;
  final DateTime actionTime;
  final String? address;
  final int userId;
  final String? userEmail;
  final String? actionType;
  final String? objectType;
  final int? objectId;
  final Map<String, dynamic> attributes;

  AuditEntry({required this.id, required this.actionTime, this.address, required this.userId, this.userEmail, this.actionType, this.objectType, this.objectId, required this.attributes});

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    return AuditEntry(
      id: json['id'] as int,
      actionTime: DateTime.parse(json['actionTime'] as String),
      address: json['address'] as String?,
      userId: json['userId'] as int,
      userEmail: json['userEmail'] as String?,
      actionType: json['actionType'] as String?,
      objectType: json['objectType'] as String?,
      objectId: json['objectId'] as int?,
      attributes: json['attributes'] as Map<String, dynamic>? ?? {},
    );
  }
}

class LogsReportScreen extends StatefulWidget {
  const LogsReportScreen({super.key});

  @override
  State<LogsReportScreen> createState() => _LogsReportScreenState();
}

class _LogsReportScreenState extends State<LogsReportScreen> {
  List<AuditEntry> _items = [];
  bool _isLoading = true;

  // Column visibility toggles (like traccar-web ColumnSelect)
  final Map<String, bool> _columns = {'actionTime': true, 'address': false, 'userId': true, 'actionType': true, 'objectType': true, 'objectId': false};
  final _columnLabels = <String, String>{'actionTime': 'positionServerTime', 'address': 'positionAddress', 'userId': 'settingsUser', 'actionType': 'sharedActionType', 'objectType': 'sharedQbjectType', 'objectId': 'deviceIdentifier'};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final fromDateString = prefs.getString('historyFrom');
    final toDateString = prefs.getString('historyTo');
    if (fromDateString == null || toDateString == null) {
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
      final response = await traccarProvider.apiClient.invokeAPI('/audit', 'GET', [api.QueryParam('from', fromDate.toIso8601String()), api.QueryParam('to', toDate.toIso8601String())], null, {'Accept': 'application/json'}, {}, 'application/json');
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = json.decode(response.body) as List? ?? [];
        _items = data.map((e) => AuditEntry.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Audit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load audit logs.'.tr)));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColumns = _columns.entries.where((e) => e.value).map((e) => e.key).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('reportAudit'.tr),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.view_column),
            onSelected: (key) => setState(() => _columns[key] = !(_columns[key] ?? false)),
            itemBuilder: (_) => _columns.keys.map((key) {
              return PopupMenuItem(
                value: key,
                child: Row(
                  children: [
                    Checkbox(value: _columns[key] ?? false, onChanged: null, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    const SizedBox(width: 8),
                    Text(_columnLabels[key]?.tr ?? key),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(child: Text('sharedNoData'.tr))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final item = _items[i];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (activeColumns.contains('actionTime')) _row(_columnLabels['actionTime']!.tr, DateFormat('yyyy-MM-dd HH:mm').format(item.actionTime.toLocal())),
                        if (activeColumns.contains('userId')) _row(_columnLabels['userId']!.tr, item.userEmail ?? '#${item.userId}'),
                        if (activeColumns.contains('actionType')) _row(_columnLabels['actionType']!.tr, item.actionType ?? '-'),
                        if (activeColumns.contains('objectType')) _row(_columnLabels['objectType']!.tr, '${item.objectType ?? '-'}${item.objectId != null ? ' #${item.objectId}' : ''}'),
                        if (activeColumns.contains('address') && item.address != null) _row(_columnLabels['address']!.tr, item.address!),
                        if (activeColumns.contains('objectId') && item.objectId != null) _row(_columnLabels['objectId']!.tr, '#${item.objectId}'),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
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
