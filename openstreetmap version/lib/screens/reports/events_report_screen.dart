// lib/screens/reports/events_report_screen.dart
// A screen to display events report in the TracDefg app.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class EventReport {
  final int id;
  final int deviceId;
  final String type;
  final DateTime eventTime;
  final int positionId;
  final int geofenceId;
  final int maintenanceId;
  final Map<String, dynamic> attributes;

  EventReport({required this.id, required this.deviceId, required this.type, required this.eventTime, required this.positionId, required this.geofenceId, required this.maintenanceId, required this.attributes});

  factory EventReport.fromJson(Map<String, dynamic> json) {
    // v4.4 uses "serverTime", newer versions use "eventTime"
    final timeField = (json['eventTime'] ?? json['serverTime']) as String;
    return EventReport(
      id: json['id'] as int,
      deviceId: json['deviceId'] as int,
      type: json['type'] as String? ?? '',
      eventTime: DateTime.parse(timeField),
      positionId: json['positionId'] as int? ?? 0,
      geofenceId: json['geofenceId'] as int? ?? 0,
      maintenanceId: json['maintenanceId'] as int? ?? 0,
      attributes: json['attributes'] as Map<String, dynamic>? ?? {},
    );
  }
}

class EventsReportScreen extends StatefulWidget {
  const EventsReportScreen({super.key});

  @override
  State<EventsReportScreen> createState() => _EventsReportScreenState();
}

class _EventsReportScreenState extends State<EventsReportScreen> {
  List<EventReport> _eventsReport = [];
  bool _isLoading = true;
  String? _deviceName;
  String _selectedEventType = 'eventAll';

  final List<String> _eventTypes = [
    'eventAll',
    'eventDeviceOnline',
    'eventDeviceUnknown',
    'eventDeviceOffline',
    'eventDeviceInactive',
    'eventQueuedCommandSent',
    'eventDeviceMoving',
    'eventDeviceStopped',
    'eventDeviceOverspeed',
    'eventDeviceFuelDrop',
    'eventDeviceFuelIncrease',
    'eventCommandResult',
    'eventGeofenceEnter',
    'eventGeofenceExit',
    'eventAlarm',
    'eventIgnitionOn',
    'eventIgnitionOff',
    'eventMaintenance',
    'eventTextMessage',
    'eventDriverChanged',
    'eventMedia',
  ];

  @override
  void initState() {
    super.initState();
    _fetchEventsReport();
  }

  Future<void> _fetchEventsReport() async {
    setState(() {
      _isLoading = true;
    });

    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);

    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getInt('selectedDeviceId');
    final fromDateString = prefs.getString('historyFrom');
    final toDateString = prefs.getString('historyTo');
    debugPrint('Fetched from SharedPreferences: deviceId=$deviceId, fromDate=$fromDateString, toDate=$toDateString');

    if (deviceId == null || fromDateString == null || toDateString == null) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Missing device ID or date range from SharedPreferences.');
      return;
    }

    final fromDate = DateTime.tryParse(fromDateString);
    final toDate = DateTime.tryParse(toDateString);

    if (fromDate == null || toDate == null) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Failed to parse date strings.');
      return;
    }

    try {
      final apiClient = traccarProvider.apiClient;
      final queryParams = [api.QueryParam('from', fromDate.toIso8601String()), api.QueryParam('to', toDate.toIso8601String()), api.QueryParam('deviceId', deviceId.toString())];

      if (_selectedEventType != 'eventAll') {
        queryParams.add(api.QueryParam('type', _selectedEventType));
      }

      final path = '/reports/events';
      final headerParams = {'Accept': 'application/json'};

      final http.Response response = await apiClient.invokeAPI(
        path,
        'GET',
        queryParams,
        null, // body
        headerParams, // headerParams
        {}, // formParams
        'application/json', // contentType
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final contentType = response.headers['content-type'];
        if (contentType != null && contentType.contains('application/json')) {
          final decodedData = json.decode(response.body);

          if (decodedData is List && decodedData.isNotEmpty) {
            _eventsReport = decodedData.map((e) => EventReport.fromJson(e as Map<String, dynamic>)).toList();

            if (_eventsReport.isNotEmpty) {
              final device = traccarProvider.devices.firstWhere((d) => d.id == _eventsReport.first.deviceId, orElse: () => api.Device());
              _deviceName = device.name;
            }
          }
        } else {
          debugPrint('Warning: Expected JSON, but received content type: $contentType');
          if (!mounted) return; // Added mounted check guard
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load events report. The server returned a file instead of JSON.'.tr)));
        }
      }
    } catch (e) {
      debugPrint('Error fetching events report: $e');
      if (!mounted) return; // Added mounted check guard
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load events report.'.tr)));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${'reportEvents'.tr}: ${_deviceName ?? ''}')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedEventType,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedEventType = newValue!;
                        _fetchEventsReport();
                      });
                    },
                    items: _eventTypes.map((type) => DropdownMenuItem(value: type, child: Text(type.tr))).toList(),
                  ),
                ),
                Expanded(
                  child: _eventsReport.isEmpty
                      ? Center(child: Text('sharedNoData'.tr))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _eventsReport.length,
                          itemBuilder: (context, index) {
                            final event = _eventsReport[index];
                            // Swapped string concatenation for standard string interpolation
                            final translatedEventKey = 'event${event.type[0].toUpperCase()}${event.type.substring(1)}';
                            return Card(
                              elevation: 4,
                              margin: const EdgeInsets.only(bottom: 16.0),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${'positionEvent'.tr}: ${translatedEventKey.tr}',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                                    ),
                                    const Divider(),
                                    _buildEventDetailRow('positionServerTime'.tr, DateFormat('yyyy-MM-dd HH:mm').format(event.eventTime.toLocal())),
                                    // Removed redundant '.toList()' call from inside the spread array context
                                    ...event.attributes.entries.map((entry) {
                                      return _buildEventDetailRow(entry.key, entry.value.toString());
                                    }),
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

  Widget _buildEventDetailRow(String title, String value) {
    return ListTile(
      title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      trailing: Text(
        value,
        style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}
