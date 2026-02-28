// lib/screens/reports/reports_screen.dart
//  A screen to select and configure reports in the TracDefg app.
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

  @override
  void initState() {
    super.initState();
    _loadLastDevice();
  }

  Future<void> _loadLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDeviceId = prefs.getInt('selectedDeviceId');
    if (lastDeviceId != null && lastDeviceId != 0) {
      if (!mounted) return;
      final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
      final device = traccarProvider.devices.firstWhereOrNull((d) => d.id == lastDeviceId);
      if (device != null) {
        setState(() {
          _selectedDevice = device;
        });
      }
    }
  }

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
                  selected: _selectedDevice?.id == device.id,
                  onTap: () async {
                    setState(() {
                      _selectedDevice = device;
                    });
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('selectedDeviceId', device.id ?? 0);
                    if (!mounted) return;
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
    if (_selectedDevice == null) {
      _showDeviceSelectionDialog(context);
      return;
    }

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
    await prefs.setString('selectedDeviceName', _selectedDevice!.name.toString());

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
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(
                      Icons.directions_car,
                      color: _selectedDevice != null ? Theme.of(context).primaryColor : Colors.grey,
                    ),
                    title: Text(
                      _selectedDevice?.name ?? 'reportDevice'.tr,
                      style: TextStyle(
                        fontWeight: _selectedDevice != null ? FontWeight.bold : FontWeight.normal,
                        color: _selectedDevice != null ? Colors.black : Colors.redAccent,
                      ),
                    ),
                    subtitle: _selectedDevice == null ? Text('pleaseSelectDevice'.tr) : null,
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showDeviceSelectionDialog(context),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today, color: Colors.blue),
                    title: Text(
                      '${'reportFrom'.tr}: ${_selectedDate.toString().split(' ')[0]}',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _selectDate(context),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          _buildReportItem('reportCombined'.tr, 'combined', Icons.show_chart),
          _buildReportItem('reportSummary'.tr, 'summary', Icons.summarize),
          _buildReportItem('reportStops'.tr, 'stops', Icons.pause_circle_outline),
          _buildReportItem('reportReplay'.tr, 'route', Icons.replay),
          _buildReportItem('reportTrips'.tr, 'trips', Icons.route),
          _buildReportItem('reportEvents'.tr, 'events', Icons.event_note),
        ],
      ),
    );
  }

  Widget _buildReportItem(String title, String type, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueGrey),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _navigateToReport(type),
    );
  }
}