// lib/screens/reports/summary_report_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/models/report_summary_hive.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/screens/reports/trips_report_screen.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class DailySummaryItem {
  final int deviceId;
  final String deviceName;
  final String dateStr; // 格式: yyyy-MM-dd
  final double distanceKm;

  DailySummaryItem({required this.deviceId, required this.deviceName, required this.dateStr, required this.distanceKm});

  factory DailySummaryItem.fromJson(Map<String, dynamic> json) {
    final startTimeStr = json['startTime'] as String? ?? DateTime.now().toIso8601String();
    final dateOnly = startTimeStr.substring(0, 10);
    final distanceMeters = (json['distance'] as num?)?.toDouble() ?? 0.0;

    return DailySummaryItem(deviceId: json['deviceId'] as int, deviceName: json['deviceName'] as String? ?? '', dateStr: dateOnly, distanceKm: distanceMeters / 1000.0);
  }
}

class SummaryReportScreen extends StatefulWidget {
  const SummaryReportScreen({super.key});

  @override
  State<SummaryReportScreen> createState() => _SummaryReportScreenState();
}

class _SummaryReportScreenState extends State<SummaryReportScreen> {
  bool _isLoading = true;
  String _titleName = '';

  Map<int, Map<String, dynamic>> _matrixData = {};
  List<String> _daysList = [];

  @override
  void initState() {
    super.initState();
    // 進入時設為橫屏
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _fetchSummaryReport();
  }

  @override
  void dispose() {
    // 離開報表總覽時恢復全方向
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    super.dispose();
  }

  List<String> _generateDateList(DateTime from, DateTime to) {
    final List<String> days = [];
    DateTime curr = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    while (!curr.isAfter(end)) {
      days.add(DateFormat('yyyy-MM-dd').format(curr));
      curr = curr.add(const Duration(days: 1));
    }
    return days;
  }

  Future<void> _fetchSummaryReport() async {
    setState(() => _isLoading = true);

    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();

    final selectAll = prefs.getBool('selectAllDevices') ?? false;
    final deviceId = prefs.getInt('selectedDeviceId');
    final fromDateString = prefs.getString('historyFrom');
    final toDateString = prefs.getString('historyTo');
    _titleName = prefs.getString('selectedDeviceName') ?? '';

    if (fromDateString == null || toDateString == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final DateTime fromDt = DateTime.parse(fromDateString).toLocal();
      final DateTime toDt = DateTime.parse(toDateString).toLocal();

      final targetDays = _generateDateList(fromDt, toDt);

      final box = Hive.isBoxOpen('summary_reports') ? Hive.box<ReportSummaryHive>('summary_reports') : await Hive.openBox<ReportSummaryHive>('summary_reports');

      final List<api.Device> targetDevices = selectAll ? traccarProvider.devices.where((d) => d.id != null).toList() : traccarProvider.devices.where((d) => d.id == deviceId).toList();

      final Map<int, Map<String, dynamic>> matrix = {};
      final Set<String> daysSet = Set.from(targetDays);
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final List<String> missingDays = [];
      for (var day in targetDays) {
        bool dayHasDataInCache = false;
        for (var dev in targetDevices) {
          final cacheKey = '${dev.id}_$day';
          final cachedItem = box.get(cacheKey);
          if (cachedItem != null && cachedItem.distance != null) {
            dayHasDataInCache = true;
            if (!matrix.containsKey(dev.id)) {
              matrix[dev.id!] = {'deviceName': dev.name ?? '', 'days': <String, double>{}};
            }
            var daysMap = matrix[dev.id!]!['days'] as Map<String, double>;

            double km = (cachedItem.distance! / 1000.0);
            daysMap[day] = km;
          }
        }
        if (!dayHasDataInCache || day == todayStr) {
          if (!missingDays.contains(day)) {
            missingDays.add(day);
          }
        }
      }

      if (missingDays.isNotEmpty) {
        missingDays.sort();
        final reqFrom = '${missingDays.first}T00:00:00Z';
        final reqTo = '${missingDays.last}T23:59:59Z';

        final apiClient = traccarProvider.apiClient;
        final queryParams = <api.QueryParam>[api.QueryParam('from', reqFrom), api.QueryParam('to', reqTo), api.QueryParam('daily', true.toString())];

        for (var dev in targetDevices) {
          queryParams.add(api.QueryParam('deviceId', dev.id.toString()));
        }

        final response = await apiClient.invokeAPI('/reports/summary', 'GET', queryParams, null, {}, {}, 'application/json');
        final decodedData = json.decode(response.body);

        if (decodedData is List) {
          final fetchedItems = decodedData.map((e) => DailySummaryItem.fromJson(e as Map<String, dynamic>)).toList();

          for (var item in fetchedItems) {
            if (!matrix.containsKey(item.deviceId)) {
              matrix[item.deviceId] = {'deviceName': item.deviceName, 'days': <String, double>{}};
            }
            var daysMap = matrix[item.deviceId]!['days'] as Map<String, double>;

            daysMap[item.dateStr] = item.distanceKm;

            final cacheKey = '${item.deviceId}_${item.dateStr}';
            await box.put(cacheKey, ReportSummaryHive(distance: item.distanceKm * 1000.0, deviceId: item.deviceId, dateStr: item.dateStr));
          }
        }
      }

      for (var dev in targetDevices) {
        if (!matrix.containsKey(dev.id)) {
          matrix[dev.id!] = {'deviceName': dev.name ?? '', 'days': <String, double>{}};
        }
      }

      final sortedDays = daysSet.toList()..sort();

      setState(() {
        _matrixData = matrix;
        _daysList = sortedDays;
      });
    } catch (e) {
      debugPrint('Error fetching summary report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('errorGeneral'.tr)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportCSV() async {
    if (_matrixData.isEmpty) return;

    List<String> csvRows = [];
    List<String> header = ['No.', 'Vehicle Number (km)', ..._daysList.map((d) => d.substring(8))];
    csvRows.add(header.join(','));

    int index = 1;
    _matrixData.forEach((deviceId, data) {
      String vehicleName = data['deviceName'] ?? '';
      Map<String, double> daysMap = data['days'];

      List<String> row = [index.toString(), '"$vehicleName"'];
      for (var day in _daysList) {
        double km = daysMap[day] ?? 0.0;
        // 匯出時同樣四捨五入無小數
        row.add(km.round().toString());
      }
      csvRows.add(row.join(','));
      index++;
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/summary_report_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvRows.join('\n'));

      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'Monthly Summary Report CSV');
    } catch (e) {
      debugPrint('Export/Share CSV failed: $e');
    }
  }

  Future<void> _exportPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(841.89, 595.27),
        build: (pw.Context context) {
          List<String> headers = ['No.', 'Vehicle (km)', ..._daysList.map((d) => d.substring(8))];

          int index = 1;
          List<List<String>> data = [];
          _matrixData.forEach((deviceId, info) {
            String name = info['deviceName'];
            Map<String, double> daysMap = info['days'];
            List<String> row = [index.toString(), name];
            for (var day in _daysList) {
              row.add((daysMap[day] ?? 0.0).round().toString());
            }
            data.add(row);
            index++;
          });

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Monthly Summary Report - $_titleName (km)', style: const pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: headers,
                data: data,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                cellStyle: const pw.TextStyle(fontSize: 7),
                cellAlignment: pw.Alignment.center,
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.dividerColor;

    return Scaffold(
      appBar: CupertinoNavigationBar(
        middle: Text('${'reportSummary'.tr}: $_titleName (${'sharedKm'.tr})'),
        trailing: PopupMenuButton<String>(
          icon: const Icon(CupertinoIcons.share),
          onSelected: (value) {
            if (value == 'csv') _exportCSV();
            if (value == 'pdf') _exportPDF();
          },
          itemBuilder: (BuildContext context) => [PopupMenuItem(value: 'csv', child: Text('reportExport'.tr)), PopupMenuItem(value: 'pdf', child: Text('reportPrint'.tr))],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : _matrixData.isEmpty
          ? Center(child: Text('sharedNoData'.tr))
          : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 1.0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DataTable(
                    horizontalMargin: 6,
                    columnSpacing: 8,
                    dataRowMinHeight: 30,
                    dataRowMaxHeight: 34,
                    headingRowHeight: 34,
                    headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)),
                    border: TableBorder(
                      horizontalInside: BorderSide(color: borderColor, width: 0.5),
                      verticalInside: BorderSide(color: borderColor, width: 0.5),
                    ),
                    columns: [
                      const DataColumn(
                        label: SizedBox(
                          width: 22,
                          child: Text(
                            'No.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ),
                      DataColumn(
                        label: SizedBox(
                          width: 80,
                          child: Text(
                            '${'reportDevice'.tr} (${'sharedKm'.tr})',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ),
                      ..._daysList.map(
                        (day) => DataColumn(
                          label: SizedBox(
                            width: 24,
                            child: Text(
                              day.substring(8),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                    ],
                    rows: _matrixData.entries.toList().asMap().entries.map((entry) {
                      int index = entry.key + 1;
                      var mapEntry = entry.value;
                      int deviceId = mapEntry.key;
                      String deviceName = mapEntry.value['deviceName'];
                      Map<String, double> daysMap = mapEntry.value['days'];

                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 22,
                              child: Text(index.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 80,
                              child: Text(
                                deviceName,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
                              ),
                            ),
                          ),
                          ..._daysList.map((day) {
                            double km = daysMap[day] ?? 0.0;
                            int roundedKm = km.round(); // 四捨五入取整數

                            return DataCell(
                              SizedBox(
                                width: 24,
                                child: roundedKm > 0
                                    ? InkWell(
                                        onTap: () async {
                                          final prefs = await SharedPreferences.getInstance();
                                          await prefs.setInt('selectedDeviceId', deviceId);
                                          await prefs.setString('selectedDeviceName', deviceName);

                                          // 使用標準 UTC ISO8601 時間字串
                                          final startTime = DateTime.parse('${day}T00:00:00Z').toIso8601String();
                                          final endTime = DateTime.parse('${day}T23:59:59Z').toIso8601String();

                                          await prefs.setString('historyFrom', startTime);
                                          await prefs.setString('historyTo', endTime);

                                          // 1. 跳轉至 TripsReportScreen 並等待其關閉返回
                                          await Get.to(() => const TripsReportScreen());

                                          // 2. 當從 TripsReportScreen 返回 SummaryReportScreen 的瞬間，立刻重新強制設回橫屏！
                                          if (mounted) {
                                            SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
                                          }
                                        },
                                        child: Center(
                                          child: Text(
                                            '$roundedKm', // 顯示不帶小數點的整數公里數
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 10, color: theme.colorScheme.primary, decoration: TextDecoration.underline),
                                          ),
                                        ),
                                      )
                                    : Text(
                                        '-',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 10, color: theme.disabledColor),
                                      ),
                              ),
                            );
                          }),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
    );
  }
}
