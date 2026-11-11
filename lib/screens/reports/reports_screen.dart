// lib/screens/reports/reports_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/src/utils/cupertino_pickers.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

enum DateRangePreset { custom, today, thisWeek, thisMonth, lastMonth }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  api.Device? _selectedDevice;
  bool _selectAllDevices = false;
  DateRangePreset _selectedPreset = DateRangePreset.custom;

  static const _basicReports = {'summary', 'stops', 'route', 'trips', 'events', 'chart'};

  @override
  void initState() {
    super.initState();
    _loadLastDevice();
    _applyPreset(DateRangePreset.today); // 預設進來選今天
  }

  void _applyPreset(DateRangePreset preset) {
    final now = DateTime.now();
    setState(() {
      _selectedPreset = preset;
      if (preset == DateRangePreset.today) {
        _fromDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
        _toDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (preset == DateRangePreset.thisWeek) {
        // 以週一作為每週第一天
        int weekday = now.weekday;
        DateTime startOfWeek = now.subtract(Duration(days: weekday - 1));
        _fromDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day, 0, 0, 0);
        _toDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (preset == DateRangePreset.thisMonth) {
        _fromDate = DateTime(now.year, now.month, 1, 0, 0, 0);
        _toDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      } else if (preset == DateRangePreset.lastMonth) {
        // 直接以當前日期手動往回推算上個月，絕對不會抓錯
        int year = now.year;
        int month = now.month - 1;
        if (month == 0) {
          month = 12;
          year -= 1;
        }
        // 上個月 1 號
        _fromDate = DateTime(year, month, 1, 0, 0, 0);

        // 上個月最後一天 (利用當前年份、當前月份的 0 號)
        _toDate = DateTime(now.year, now.month, 0, 23, 59, 59);

        print('【強制修正】上個月區間 -> From: $_fromDate, To: $_toDate');
      }
    });
  }

  bool _isReportAvailable(TraccarProvider provider, String type) {
    if (provider.serverVersion == null) return true;
    return provider.isVersionAtLeast('5.0') || _basicReports.contains(type);
  }

  Future<void> _loadLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final isAll = prefs.getBool('selectAllDevices') ?? false;
    if (isAll) {
      setState(() {
        _selectAllDevices = true;
        _selectedDevice = null;
      });
      return;
    }

    final lastDeviceId = prefs.getInt('selectedDeviceId');
    if (lastDeviceId != null && lastDeviceId != 0) {
      if (!mounted) return;
      final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
      final device = traccarProvider.devices.firstWhereOrNull((d) => d.id == lastDeviceId);
      if (device != null) {
        setState(() {
          _selectedDevice = device;
          _selectAllDevices = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final initial = isFrom ? _fromDate : _toDate;
    final picked = await showCupertinoDatePickerSheet(context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 1)));

    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
        // 手動調整日期後，將預設切換為自訂日期 (custom)
        _selectedPreset = DateRangePreset.custom;
      });
    }
  }

  void _showDeviceSelectionDialog(BuildContext context) {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 420,
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: Theme.of(context).colorScheme.surface,
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('sharedDevice'.tr, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.devices_other),
                        title: Text('deviceStatusAll'.tr),
                        selected: _selectAllDevices,
                        onTap: () async {
                          setState(() {
                            _selectAllDevices = true;
                            _selectedDevice = null;
                          });
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('selectAllDevices', true);
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                      const Divider(),
                      ...traccarProvider.devices.map((device) {
                        return ListTile(
                          title: Text(device.name ?? 'sharedNoData'.tr),
                          selected: !_selectAllDevices && _selectedDevice?.id == device.id,
                          onTap: () async {
                            setState(() {
                              _selectedDevice = device;
                              _selectAllDevices = false;
                            });
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('selectAllDevices', false);
                            await prefs.setInt('selectedDeviceId', device.id ?? 0);
                            if (context.mounted) Navigator.pop(context);
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToReport(String reportType) async {
    final prefs = await SharedPreferences.getInstance();

    final fromUtc = DateTime.utc(_fromDate.year, _fromDate.month, _fromDate.day, _fromDate.hour, _fromDate.minute, _fromDate.second);
    final toUtc = DateTime.utc(_toDate.year, _toDate.month, _toDate.day, _toDate.hour, _toDate.minute, _toDate.second);

    await prefs.setBool('selectAllDevices', _selectAllDevices);
    if (!_selectAllDevices && _selectedDevice != null) {
      await prefs.setInt('selectedDeviceId', _selectedDevice!.id ?? 0);
      await prefs.setString('selectedDeviceName', _selectedDevice!.name.toString());
    } else {
      await prefs.remove('selectedDeviceId');
      await prefs.setString('selectedDeviceName', 'deviceStatusAll'.tr);
    }

    await prefs.setString('historyFrom', fromUtc.toIso8601String());
    await prefs.setString('historyTo', toUtc.toIso8601String());

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushNamed('/reports/$reportType');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(middle: Text('reportTitle'.tr), automaticallyImplyLeading: true),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('reportConfigure'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(CupertinoIcons.car_fill, color: (_selectedDevice != null || _selectAllDevices) ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                    title: Text(_selectAllDevices ? 'deviceStatusAll'.tr : (_selectedDevice?.name ?? 'reportDevice'.tr), style: TextStyle(fontWeight: (_selectedDevice != null || _selectAllDevices) ? FontWeight.bold : FontWeight.normal)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showDeviceSelectionDialog(context),
                  ),
                ),
                const SizedBox(height: 12),
                // 日期快捷切換按鈕列 (加入 Today, This Week, This Month, Last Month, Custom)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(label: Text('reportToday'.tr), selected: _selectedPreset == DateRangePreset.today, onSelected: (_) => _applyPreset(DateRangePreset.today)),
                      const SizedBox(width: 8),
                      FilterChip(label: Text('reportThisWeek'.tr), selected: _selectedPreset == DateRangePreset.thisWeek, onSelected: (_) => _applyPreset(DateRangePreset.thisWeek)),
                      const SizedBox(width: 8),
                      FilterChip(label: Text('reportThisMonth'.tr), selected: _selectedPreset == DateRangePreset.thisMonth, onSelected: (_) => _applyPreset(DateRangePreset.thisMonth)),
                      const SizedBox(width: 8),
                      FilterChip(label: Text('reportPreviousMonth'.tr), selected: _selectedPreset == DateRangePreset.lastMonth, onSelected: (_) => _applyPreset(DateRangePreset.lastMonth)),
                      const SizedBox(width: 8),
                      FilterChip(label: Text('reportCustom'.tr), selected: _selectedPreset == DateRangePreset.custom, onSelected: (_) => _applyPreset(DateRangePreset.custom)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(CupertinoIcons.calendar),
                        title: Text('${'reportFrom'.tr}: ${DateFormat('yyyy-MM-dd HH:mm').format(_fromDate)}'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _selectDate(context, true),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(CupertinoIcons.calendar),
                        title: Text('${'reportTo'.tr}: ${DateFormat('yyyy-MM-dd HH:mm').format(_toDate)}'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _selectDate(context, false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ..._buildReportSection(context, [
            _ReportDef('reportCombined'.tr, 'combined', Icons.show_chart),
            _ReportDef('reportSummary'.tr, 'summary', Icons.summarize),
            _ReportDef('reportStops'.tr, 'stops', Icons.pause_circle_outline),
            _ReportDef('reportReplay'.tr, 'route', Icons.replay),
            _ReportDef('reportTrips'.tr, 'trips', Icons.route),
            _ReportDef('reportEvents'.tr, 'events', Icons.event_note),
          ]),
          const Divider(),
          ..._buildReportSection(context, [
            _ReportDef('reportGeofences'.tr, 'geofences', Icons.fence),
            _ReportDef('reportChart'.tr, 'chart', Icons.bar_chart),
            _ReportDef('reportPositions'.tr, 'positions', Icons.list_alt),
            _ReportDef('reportLogs'.tr, 'logs', Icons.article),
            _ReportDef('reportScheduled'.tr, 'scheduled', Icons.schedule_send),
          ]),
        ],
      ),
    );
  }

  List<Widget> _buildReportSection(BuildContext context, List<_ReportDef> defs) {
    final provider = Provider.of<TraccarProvider>(context, listen: false);
    return defs.where((d) => _isReportAvailable(provider, d.type)).map((d) {
      return ListTile(
        leading: Icon(d.icon, color: Theme.of(context).colorScheme.primary),
        title: Text(d.title),
        trailing: const Icon(CupertinoIcons.chevron_right),
        onTap: () => _navigateToReport(d.type),
      );
    }).toList();
  }
}

class _ReportDef {
  final String title;
  final String type;
  final IconData icon;
  const _ReportDef(this.title, this.type, this.icon);
}
