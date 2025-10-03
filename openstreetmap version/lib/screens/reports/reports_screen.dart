// lib/screens/reports/reports_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:get/get.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _selectedDate = DateTime.now();
  api.Device? _selectedDevice;

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showDeviceSelectionDialog(BuildContext context) {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('sharedDevice'.tr),
          content: SingleChildScrollView(
            child: ListBody(
              children: traccarProvider.devices.map((device) {
                return ListTile(
                  title: Text(device.name ?? 'sharedNoData'.tr),
                  onTap: () {
                    setState(() {
                      _selectedDevice = device;
                    });
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _navigateToReport(String reportType) async {
    final prefs = await SharedPreferences.getInstance();

     final fromDate = DateTime.utc(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
  );

  // Create a DateTime for the end of the selected day in UTC
  final toDate = fromDate.add(const Duration(days: 1)).subtract(
    const Duration(milliseconds: 1),
  );
    await prefs.setInt('selectedDeviceId', _selectedDevice?.id ?? 0);
  await prefs.setString('historyFrom', fromDate.toIso8601String());
  await prefs.setString('historyTo', toDate.toIso8601String());
  await prefs.setString('selectedDeviceName', _selectedDevice!.name.toString() );

    Navigator.pushNamed(context, '/reports/$reportType');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('reportTitle'.tr),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'reportConfigure'.tr,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(
                    '${'sharedDevice'.tr}: ${_selectedDevice?.name ?? 'reportDevice'.tr}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showDeviceSelectionDialog(context),
                ),
                ListTile(
                  title: Text(
                    'reportFrom'.tr + ': ${_selectedDate.toString().split(' ')[0]}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: Text('reportCombined'.tr),
            onTap: _selectedDevice != null ? () => _navigateToReport('combined') : null,
          ),
          ListTile(
            title: Text('reportSummary'.tr),
            onTap: _selectedDevice != null ? () => _navigateToReport('summary') : null,
          ),
          ListTile(
            title: Text('reportStops'.tr),
            onTap: _selectedDevice != null ? () => _navigateToReport('stops') : null,
          ),
          ListTile(
            title: Text('reportReplay'.tr),
            onTap: _selectedDevice != null ? () => _navigateToReport('route') : null,
          ),
          ListTile(
            title: Text('reportTrips'.tr),
            onTap: _selectedDevice != null ? () => _navigateToReport('trips') : null,
          ),
          ListTile(
            title: Text('reportEvents'.tr),
            onTap: _selectedDevice != null ? () => _navigateToReport('events') : null,
          ),
        ],
      ),
    );
  }
}