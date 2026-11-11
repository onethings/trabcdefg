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

/// Filter 可選欄位枚舉
enum SummaryFieldOption { km, engineHours, averageSpeed, odometer }

class DailySummaryItem {
  final int deviceId;
  final String deviceName;
  final String dateStr; // 格式: yyyy-MM-dd
  final double distanceKm;
  final double? engineHours; // 單位: 小時
  final double? averageSpeed; // 平均速度
  final double? startOdometer;
  final double? endOdometer;

  DailySummaryItem({required this.deviceId, required this.deviceName, required this.dateStr, required this.distanceKm, this.engineHours, this.averageSpeed, this.startOdometer, this.endOdometer});

  factory DailySummaryItem.fromJson(Map<String, dynamic> json) {
    final startTimeStr = json['startTime'] as String? ?? DateTime.now().toIso8601String();
    final dateOnly = startTimeStr.substring(0, 10);
    final distanceMeters = (json['distance'] as num?)?.toDouble() ?? 0.0;

    // 檢查是否有 engineHours 數據 (毫秒轉小時)
    double? hours;
    if (json.containsKey('engineHours') && json['engineHours'] != null) {
      final engineMs = (json['engineHours'] as num).toDouble();
      hours = engineMs / 3600000.0;
    }

    final avgSpd = (json['averageSpeed'] as num?)?.toDouble();
    final startOdo = (json['startOdometer'] as num?)?.toDouble();
    final endOdo = (json['endOdometer'] as num?)?.toDouble();

    return DailySummaryItem(
      deviceId: json['deviceId'] as int,
      deviceName: json['deviceName'] as String? ?? '',
      dateStr: dateOnly,
      distanceKm: distanceMeters / 1000.0,
      engineHours: hours,
      averageSpeed: avgSpd,
      startOdometer: startOdo,
      endOdometer: endOdo,
    );
  }
}

class DailyMetric {
  double km;
  double? engineHours;
  double? averageSpeed;
  double? startOdometer;
  double? endOdometer;

  DailyMetric({required this.km, this.engineHours, this.averageSpeed, this.startOdometer, this.endOdometer});
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

  // 用戶選擇顯示的數據欄位 (預設顯示 Km 與 EngH)
  Set<SummaryFieldOption> _selectedFields = {SummaryFieldOption.km, SummaryFieldOption.engineHours};

  static const String _hiveFilterBoxName = 'user_preferences';
  static const String _hiveFilterKey = 'summary_report_selected_fields';

  @override
  void initState() {
    super.initState();
    // 進入時設為橫屏
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _loadUserFilterPreference().then((_) => _fetchSummaryReport());
  }

  @override
  void dispose() {
    // 離開報表總覽時恢復全方向
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    super.dispose();
  }

  /// 從 Hive 載入用戶上次習慣的 Filter 偏好
  Future<void> _loadUserFilterPreference() async {
    try {
      final box = await Hive.openBox(_hiveFilterBoxName);
      final List<dynamic>? savedIndexes = box.get(_hiveFilterKey);
      if (savedIndexes != null && savedIndexes.isNotEmpty) {
        setState(() {
          _selectedFields = savedIndexes.map((idx) => SummaryFieldOption.values[idx as int]).toSet();
        });
      }
    } catch (e) {
      debugPrint('Error loading Hive preferences: $e');
    }
  }

  /// 將用戶選擇的 Filter 保存至 Hive
  Future<void> _saveUserFilterPreference() async {
    try {
      final box = await Hive.openBox(_hiveFilterBoxName);
      final indexes = _selectedFields.map((e) => e.index).toList();
      await box.put(_hiveFilterKey, indexes);
    } catch (e) {
      debugPrint('Error saving Hive preferences: $e');
    }
  }

  List<String> _generateDateList(DateTime from, DateTime to) {
    final List<String> days = [];
    DateTime curr = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    
    // 鎖定只能是 from 的那個月份
    final targetMonth = from.month;
    final targetYear = from.year;

    while (!curr.isAfter(end)) {
      // 🛡️ 絕對防護網：只要日期的年月超過了目標年月，立刻停止迴圈！
      if (curr.year > targetYear || (curr.year == targetYear && curr.month > targetMonth)) {
        break;
      }

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
      final DateTime parsedFrom = DateTime.parse(fromDateString).toLocal();
      final DateTime parsedTo = DateTime.parse(toDateString).toLocal();

      // 強制將時分秒歸零，確保只比較年月日，避免時區進位多算一天
      final DateTime fromDt = DateTime(parsedFrom.year, parsedFrom.month, parsedFrom.day);
      final DateTime toDt = DateTime(parsedTo.year, parsedTo.month, parsedTo.day);

      final targetDays = _generateDateList(fromDt, toDt);
      print('Target Days List: $targetDays');
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
              matrix[dev.id!] = {'deviceName': dev.name ?? '', 'days': <String, DailyMetric>{}};
            }
            var daysMap = matrix[dev.id!]!['days'] as Map<String, DailyMetric>;

            double km = (cachedItem.distance! / 1000.0);
            double? enMs = cachedItem.engineHours?.toDouble();
            double? en = enMs != null ? (enMs / 3600000.0) : null;

            daysMap[day] = DailyMetric(km: km, engineHours: en, averageSpeed: cachedItem.averageSpeed);
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
              matrix[item.deviceId] = {'deviceName': item.deviceName, 'days': <String, DailyMetric>{}};
            }
            var daysMap = matrix[item.deviceId]!['days'] as Map<String, DailyMetric>;

            daysMap[item.dateStr] = DailyMetric(km: item.distanceKm, engineHours: item.engineHours, averageSpeed: item.averageSpeed, startOdometer: item.startOdometer, endOdometer: item.endOdometer);

            final cacheKey = '${item.deviceId}_${item.dateStr}';
            await box.put(
              cacheKey,
              ReportSummaryHive(distance: item.distanceKm * 1000.0, deviceId: item.deviceId, dateStr: item.dateStr, engineHours: item.engineHours != null ? (item.engineHours! * 3600000.0).round() : null, averageSpeed: item.averageSpeed),
            );
          }
        }
      }

      for (var dev in targetDevices) {
        if (!matrix.containsKey(dev.id)) {
          matrix[dev.id!] = {'deviceName': dev.name ?? '', 'days': <String, DailyMetric>{}};
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

  /// 根據用戶選擇的 Filter 格式化文字列
  List<String> _formatMetricLines(DailyMetric? metric) {
    if (metric == null) return ['-'];
    final List<String> lines = [];

    if (_selectedFields.contains(SummaryFieldOption.km)) {
      lines.add('${metric.km.round()} ${'sharedKm'.tr}');
    }
    if (_selectedFields.contains(SummaryFieldOption.engineHours)) {
      if (metric.engineHours != null && metric.engineHours! > 0) {
        lines.add('${metric.engineHours!.toStringAsFixed(1)} ${'sharedHourAbbreviation'.tr}');
      } else {
        lines.add('0 ${'sharedHourAbbreviation'.tr}');
      }
    }
    if (_selectedFields.contains(SummaryFieldOption.averageSpeed)) {
      if (metric.averageSpeed != null && metric.averageSpeed! > 0) {
        lines.add('${metric.averageSpeed!.toStringAsFixed(1)} ${'sharedKn'.tr}');
      } else {
        lines.add('0 ${'sharedKn'.tr}');
      }
    }
    if (_selectedFields.contains(SummaryFieldOption.odometer)) {
      if (metric.startOdometer != null && metric.endOdometer != null) {
        lines.add('${(metric.startOdometer! / 1000).round()}-${(metric.endOdometer! / 1000).round()}k');
      }
    }

    return lines.isEmpty ? ['-'] : lines;
  }

  /// 格式化 Total 統計資料欄位
  List<String> _formatTotalLines(Map<String, DailyMetric> daysMap) {
    double totalKm = 0.0;
    double totalEngineHours = 0.0;
    double totalSpeedSum = 0.0;
    int speedCount = 0;

    daysMap.values.forEach((metric) {
      totalKm += metric.km;
      if (metric.engineHours != null) {
        totalEngineHours += metric.engineHours!;
      }
      if (metric.averageSpeed != null && metric.averageSpeed! > 0) {
        totalSpeedSum += metric.averageSpeed!;
        speedCount++;
      }
    });

    final List<String> lines = [];
    if (_selectedFields.contains(SummaryFieldOption.km)) {
      lines.add('${totalKm.round()} ${'sharedKm'.tr}');
    }
    if (_selectedFields.contains(SummaryFieldOption.engineHours)) {
      lines.add('${totalEngineHours.toStringAsFixed(1)} ${'sharedHourAbbreviation'.tr}');
    }
    if (_selectedFields.contains(SummaryFieldOption.averageSpeed)) {
      double avgSpd = speedCount > 0 ? (totalSpeedSum / speedCount) : 0.0;
      lines.add('${avgSpd.toStringAsFixed(1)} ${'sharedKn'.tr}');
    }
    if (_selectedFields.contains(SummaryFieldOption.odometer)) {
      lines.add('-');
    }

    return lines.isEmpty ? ['-'] : lines;
  }

  /// 匯出 CSV (所見即所得)
  Future<void> _exportCSV() async {
    if (_matrixData.isEmpty) return;

    List<String> csvRows = [];
    List<String> header = ['No.', 'Vehicle Number', ..._daysList.map((d) => d.substring(8)), 'Total'];
    csvRows.add(header.join(','));

    int index = 1;
    _matrixData.forEach((deviceId, data) {
      String vehicleName = data['deviceName'] ?? '';
      Map<String, DailyMetric> daysMap = data['days'];

      List<String> row = [index.toString(), '"$vehicleName"'];
      for (var day in _daysList) {
        DailyMetric? metric = daysMap[day];
        List<String> lines = _formatMetricLines(metric);
        row.add('"${lines.join(' / ')}"');
      }

      // 加上 Total 欄位
      List<String> totalLines = _formatTotalLines(daysMap);
      row.add('"${totalLines.join(' / ')}"');

      csvRows.add(row.join(','));
      index++;
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/summary_report_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvRows.join('\n'));

      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: '${'reportSummary'.tr} CSV');
    } catch (e) {
      debugPrint('Export/Share CSV failed: $e');
    }
  }

  /// 匯出 PDF (所見即所得)
  Future<void> _exportPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(841.89, 595.27),
        build: (pw.Context context) {
          List<String> headers = ['No.', 'Vehicle', ..._daysList.map((d) => d.substring(8)), 'Total'];

          int index = 1;
          List<List<String>> data = [];
          _matrixData.forEach((deviceId, info) {
            String name = info['deviceName'];
            Map<String, DailyMetric> daysMap = info['days'];
            List<String> row = [index.toString(), name];
            for (var day in _daysList) {
              DailyMetric? metric = daysMap[day];
              List<String> lines = _formatMetricLines(metric);
              row.add(lines.join('\n'));
            }

            // 加上 Total 欄位
            List<String> totalLines = _formatTotalLines(daysMap);
            row.add(totalLines.join('\n'));

            data.add(row);
            index++;
          });

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('${'reportSummary'.tr} - $_titleName', style: const pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: headers,
                data: data,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                cellStyle: const pw.TextStyle(fontSize: 6),
                cellAlignment: pw.Alignment.center,
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  /// 彈出 Filter 設定對話框
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              constraints: const BoxConstraints(minWidth: 320, maxWidth: 400),
              title: Row(
                children: [
                  const Icon(CupertinoIcons.slider_horizontal_3, size: 20),
                  const SizedBox(width: 8),
                  Text('reportConfigure'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      title: Text(
                        'distance'.tr,
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                      value: _selectedFields.contains(SummaryFieldOption.km),
                      onChanged: (bool? checked) {
                        setDialogState(() {
                          if (checked == true) {
                            _selectedFields.add(SummaryFieldOption.km);
                          } else if (_selectedFields.length > 1) {
                            _selectedFields.remove(SummaryFieldOption.km);
                          }
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: Text(
                        'reportEngineHours'.tr,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      value: _selectedFields.contains(SummaryFieldOption.engineHours),
                      onChanged: (bool? checked) {
                        setDialogState(() {
                          if (checked == true) {
                            _selectedFields.add(SummaryFieldOption.engineHours);
                          } else if (_selectedFields.length > 1) {
                            _selectedFields.remove(SummaryFieldOption.engineHours);
                          }
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: Text(
                        'reportAverageSpeed'.tr,
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                      value: _selectedFields.contains(SummaryFieldOption.averageSpeed),
                      onChanged: (bool? checked) {
                        setDialogState(() {
                          if (checked == true) {
                            _selectedFields.add(SummaryFieldOption.averageSpeed);
                          } else if (_selectedFields.length > 1) {
                            _selectedFields.remove(SummaryFieldOption.averageSpeed);
                          }
                        });
                      },
                    ),
                    CheckboxListTile(
                      title: Text(
                        'odometer'.tr,
                        style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
                      ),
                      value: _selectedFields.contains(SummaryFieldOption.odometer),
                      onChanged: (bool? checked) {
                        setDialogState(() {
                          if (checked == true) {
                            _selectedFields.add(SummaryFieldOption.odometer);
                          } else if (_selectedFields.length > 1) {
                            _selectedFields.remove(SummaryFieldOption.odometer);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('sharedCancel'.tr, style: TextStyle(color: Colors.grey[700])),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {});
                    _saveUserFilterPreference();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('sharedAccept'.tr),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.dividerColor;

    return Scaffold(
      appBar: CupertinoNavigationBar(
        middle: Text('${'reportSummary'.tr}: $_titleName'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 22), onPressed: _showFilterDialog),
            PopupMenuButton<String>(
              icon: const Icon(CupertinoIcons.share),
              onSelected: (value) {
                if (value == 'csv') _exportCSV();
                if (value == 'pdf') _exportPDF();
              },
              itemBuilder: (BuildContext context) => [PopupMenuItem(value: 'csv', child: Text('reportExport'.tr)), PopupMenuItem(value: 'pdf', child: Text('reportPrint'.tr))],
            ),
          ],
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
                    dataRowMinHeight: 44,
                    dataRowMaxHeight: 60,
                    headingRowHeight: 44,
                    headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)),
                    border: TableBorder(
                      horizontalInside: BorderSide(color: borderColor, width: 0.5),
                      verticalInside: BorderSide(color: borderColor, width: 0.5),
                    ),
                    columns: [
                      const DataColumn(
                        label: SizedBox(
                          width: 24,
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
                            'reportDevice'.tr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                      ),
                      ..._daysList.map(
                        (day) => DataColumn(
                          label: SizedBox(
                            width: 42,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  day.substring(8),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.blue),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 新增 Total 欄位標題
                      const DataColumn(
                        label: SizedBox(
                          width: 48,
                          child: Text(
                            'Total',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.deepOrange),
                          ),
                        ),
                      ),
                    ],
                    rows: _matrixData.entries.toList().asMap().entries.map((entry) {
                      int index = entry.key + 1;
                      var mapEntry = entry.value;
                      int deviceId = mapEntry.key;
                      String deviceName = mapEntry.value['deviceName'];
                      Map<String, DailyMetric> daysMap = mapEntry.value['days'];

                      // 計算全期間累計總額
                      double totalKm = 0.0;
                      double totalEngineHours = 0.0;
                      double totalSpeedSum = 0.0;
                      int speedCount = 0;

                      daysMap.values.forEach((metric) {
                        totalKm += metric.km;
                        if (metric.engineHours != null) {
                          totalEngineHours += metric.engineHours!;
                        }
                        if (metric.averageSpeed != null && metric.averageSpeed! > 0) {
                          totalSpeedSum += metric.averageSpeed!;
                          speedCount++;
                        }
                      });

                      int totalRoundedKm = totalKm.round();
                      bool hasTotalEngineHours = totalEngineHours > 0;
                      double avgSpeed = speedCount > 0 ? (totalSpeedSum / speedCount) : 0.0;

                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 24,
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
                            final metric = daysMap[day];
                            double km = metric?.km ?? 0.0;
                            double? engineHours = metric?.engineHours;
                            double? avgSpeed = metric?.averageSpeed;
                            double? startOdo = metric?.startOdometer;
                            double? endOdo = metric?.endOdometer;

                            int roundedKm = km.round();
                            bool hasEngineHours = engineHours != null && engineHours > 0;
                            bool hasAvgSpeed = avgSpeed != null && avgSpeed > 0;
                            bool hasOdo = startOdo != null && endOdo != null;

                            return DataCell(
                              SizedBox(
                                width: 42,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // 1. 公里數 (Km)
                                    if (_selectedFields.contains(SummaryFieldOption.km))
                                      roundedKm > 0
                                          ? InkWell(
                                              onTap: () async {
                                                final prefs = await SharedPreferences.getInstance();
                                                await prefs.setInt('selectedDeviceId', deviceId);
                                                await prefs.setString('selectedDeviceName', deviceName);

                                                final startTime = DateTime.parse('${day}T00:00:00Z').toIso8601String();
                                                final endTime = DateTime.parse('${day}T23:59:59Z').toIso8601String();

                                                await prefs.setString('historyFrom', startTime);
                                                await prefs.setString('historyTo', endTime);

                                                await Get.to(() => const TripsReportScreen());

                                                if (mounted) {
                                                  SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
                                                }
                                              },
                                              child: Text(
                                                '$roundedKm ${'sharedKm'.tr}',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(fontSize: 8.5, color: Colors.blue, decoration: TextDecoration.underline),
                                              ),
                                            )
                                          : Text(
                                              '-',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(fontSize: 8.5, color: Colors.blue.withOpacity(0.5)),
                                            ),

                                    // 2. 引擎工時 (EngH)
                                    if (_selectedFields.contains(SummaryFieldOption.engineHours))
                                      hasEngineHours
                                          ? Text(
                                              '${engineHours.toStringAsFixed(1)}${'sharedHourAbbreviation'.tr}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 8.5, color: Colors.red, fontWeight: FontWeight.bold),
                                            )
                                          : Text(
                                              '-',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(fontSize: 8.5, color: Colors.red.withOpacity(0.3)),
                                            ),

                                    // 3. 平均車速 (Avg Spd)
                                    if (_selectedFields.contains(SummaryFieldOption.averageSpeed))
                                      hasAvgSpeed
                                          ? Text(
                                              '${avgSpeed.toStringAsFixed(1)}${'sharedKn'.tr}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 8.5, color: Colors.green),
                                            )
                                          : Text(
                                              '-',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(fontSize: 8.5, color: Colors.green.withOpacity(0.3)),
                                            ),

                                    // 4. 里程錶 (Odometer)
                                    if (_selectedFields.contains(SummaryFieldOption.odometer))
                                      hasOdo
                                          ? Text(
                                              '${(startOdo / 1000).round()}-${(endOdo / 1000).round()}k',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 7.5, color: Colors.purple),
                                            )
                                          : Text(
                                              '-',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(fontSize: 7.5, color: Colors.purple.withOpacity(0.3)),
                                            ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          // 總結 (Total) 數據 Cell
                          DataCell(
                            SizedBox(
                              width: 48,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_selectedFields.contains(SummaryFieldOption.km))
                                    Text(
                                      '$totalRoundedKm ${'sharedKm'.tr}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 8.5, color: Colors.blue, fontWeight: FontWeight.bold),
                                    ),
                                  if (_selectedFields.contains(SummaryFieldOption.engineHours))
                                    hasTotalEngineHours
                                        ? Text(
                                            '${totalEngineHours.toStringAsFixed(1)}${'sharedHourAbbreviation'.tr}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 8.5, color: Colors.red, fontWeight: FontWeight.bold),
                                          )
                                        : Text(
                                            '-',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 8.5, color: Colors.red.withOpacity(0.3)),
                                          ),
                                  if (_selectedFields.contains(SummaryFieldOption.averageSpeed))
                                    speedCount > 0
                                        ? Text(
                                            '${avgSpeed.toStringAsFixed(1)}${'sharedKn'.tr}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(fontSize: 8.5, color: Colors.green, fontWeight: FontWeight.bold),
                                          )
                                        : Text(
                                            '-',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 8.5, color: Colors.green.withOpacity(0.3)),
                                          ),
                                  if (_selectedFields.contains(SummaryFieldOption.odometer))
                                    Text(
                                      '-',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 7.5, color: Colors.purple.withOpacity(0.3)),
                                    ),
                                ],
                              ),
                            ),
                          ),
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
