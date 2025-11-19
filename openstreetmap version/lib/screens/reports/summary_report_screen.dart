// lib/screens/reports/summary_report_screen.dart
// A screen to display summary report in the TracDefg app.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';

class SummaryReport {
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
  final int engineHours;

  SummaryReport({
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
    required this.engineHours,
  });

  factory SummaryReport.fromJson(Map<String, dynamic> json) {
    return SummaryReport(
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
      engineHours: json['engineHours'] as int,
    );
  }
}

class SummaryReportScreen extends StatefulWidget {
  const SummaryReportScreen({super.key});

  @override
  State<SummaryReportScreen> createState() => _SummaryReportScreenState();
}

class _SummaryReportScreenState extends State<SummaryReportScreen> {
  SummaryReport? _summaryReport;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSummaryReport();
  }

  Future<void> _fetchSummaryReport() async {
    setState(() {
      _isLoading = true;
    });

    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );

    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getInt('selectedDeviceId');
    final fromDateString = prefs.getString('historyFrom');
    final toDateString = prefs.getString('historyTo');
    print('Fetched from SharedPreferences: deviceId=$deviceId, fromDate=$fromDateString, toDate=$toDateString');

    if (deviceId == null || fromDateString == null || toDateString == null) {
      setState(() {
        _isLoading = false;
      });
      print('Missing device ID or date range from SharedPreferences.');
      return;
    }

    final fromDate = DateTime.tryParse(fromDateString);
    final toDate = DateTime.tryParse(toDateString);

    if (fromDate == null || toDate == null) {
      setState(() {
        _isLoading = false;
      });
      print('Failed to parse date strings.');
      return;
    }

    try {
      final apiClient = traccarProvider.apiClient;

      final response = await apiClient.invokeAPI(
        '/reports/summary',
        'GET',
        [
          api.QueryParam('from', fromDate.toIso8601String()),
          api.QueryParam('to', toDate.toIso8601String()),
          api.QueryParam('deviceId', deviceId.toString()),
          api.QueryParam('daily', false.toString()),
        ],
        null, // body
        {}, // headerParams
        {}, // formParams
        'application/json', // contentType
      );

      final decodedData = json.decode(response.body);

      if (decodedData is List && decodedData.isNotEmpty) {
        _summaryReport = SummaryReport.fromJson(decodedData.first as Map<String, dynamic>);
      }
    } catch (e) {
      print('Error fetching summary report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('errorGeneral'.tr)),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatEngineHours(int milliseconds) {
    int seconds = (milliseconds / 1000).round();
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: Text('sharedLoading'.tr)));
    }

    if (_summaryReport == null) {
      return Scaffold(
        appBar: AppBar(title: Text('reportSummary'.tr)),
        body: Center(
          child: Text('sharedNoData'.tr),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('reportSummary'.tr + ': ${_summaryReport!.deviceName}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('sharedName'.tr + ': ${_summaryReport!.deviceName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    ListTile(
                      title: Text('deviceTotalDistance'.tr),
                      trailing: Text('${(_summaryReport!.distance / 1000).toStringAsFixed(2)} ' + 'sharedKm'.tr),
                    ),
                    ListTile(
                      title: Text('reportAverageSpeed'.tr),
                      trailing: Text('${_summaryReport!.averageSpeed.toStringAsFixed(2)} ' + 'sharedKmh'.tr),
                    ),
                    ListTile(
                      title: Text('reportMaximumSpeed'.tr),
                      trailing: Text('${_summaryReport!.maxSpeed.toStringAsFixed(2)} ' + 'sharedKmh'.tr),
                    ),
                    ListTile(
                      title: Text('reportSpentFuel'.tr),
                      trailing: Text('${_summaryReport!.spentFuel.toStringAsFixed(2)} ' + 'sharedLiter'.tr),
                    ),
                    ListTile(
                      title: Text('reportStartOdometer'.tr),
                      trailing: Text('${(_summaryReport!.startOdometer / 1000).toStringAsFixed(2)} ' + 'sharedKm'.tr),
                    ),
                    ListTile(
                      title: Text('reportEndOdometer'.tr),
                      trailing: Text('${(_summaryReport!.endOdometer / 1000).toStringAsFixed(2)} ' + 'sharedKm'.tr),
                    ),
                    ListTile(
                      title: Text('reportStartTime'.tr),
                      trailing: Text(DateFormat('yyyy-MM-dd HH:mm').format(_summaryReport!.startTime.toLocal())),
                    ),
                    ListTile(
                      title: Text('reportEndTime'.tr),
                      trailing: Text(DateFormat('yyyy-MM-dd HH:mm').format(_summaryReport!.endTime.toLocal())),
                    ),
                    ListTile(
                      title: Text('reportEngineHours'.tr),
                      trailing: Text(_formatEngineHours(_summaryReport!.engineHours)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}