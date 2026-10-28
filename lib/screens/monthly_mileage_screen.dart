// lib/screens/monthly_mileage_screen.dart
// A screen that displays the monthly mileage of a selected device.
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart'; // Import for locale data
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:trabcdefg/models/report_summary_hive.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

import 'history_route_screen.dart';

class MonthlyMileageScreen extends StatefulWidget {
  const MonthlyMileageScreen({super.key});

  @override
  State<MonthlyMileageScreen> createState() => _MonthlyMileageScreenState();
}

class _MonthlyMileageScreenState extends State<MonthlyMileageScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, api.ReportSummary> _dailySummaries = {};
  api.ReportSummary? _selectedDaySummary;
  bool _isLoading = true;
  int? _selectedDeviceId;
  String? _selectedDeviceName;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _loadDeviceIdAndFetchData();
  }

  Future<void> _loadDeviceIdAndFetchData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedDeviceId = prefs.getInt('selectedDeviceId');
      _selectedDeviceName = prefs.getString('selectedDeviceName');
    });

    final currentLocale = Get.locale;
    if (currentLocale != null) {
      final localeString = currentLocale.toString();
      try {
        await initializeDateFormatting(localeString, null);
      } catch (e) {
        developer.log('Failed to initialize date formatting for $localeString: $e', name: 'MonthlyMileageScreen');
      }
    }

    // Call the cleanup method before fetching new data
    await _deleteOldMileageData();

    if (_selectedDeviceId != null) {
      await _fetchMonthlyData(_focusedDay);
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMonthlyData(DateTime month) async {
    if (_selectedDeviceId == null) return;

    setState(() {
      _isLoading = true;
    });

    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    final dailyBox = await Hive.openBox<ReportSummaryHive>('daily_summaries');
    final today = DateTime.now();

    developer.log('Fetching monthly data for ${month.year}-${month.month}', name: 'MonthlyMileageScreen');

    _dailySummaries.clear();
    final firstDayOfMonth = DateTime(month.year, month.month, 1);

    // 決定查詢的結束日期（若為當月則取至今天，若為過去月份則取至該月底）
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final effectiveLastDay = lastDayOfMonth.isAfter(today) ? (DateTime(today.year, today.month, today.day).isBefore(firstDayOfMonth) ? firstDayOfMonth : DateTime(today.year, today.month, today.day)) : lastDayOfMonth;

    // 1. 先從 Hive 快取載入現有數據
    for (var date = firstDayOfMonth; !date.isAfter(lastDayOfMonth); date = date.add(const Duration(days: 1))) {
      final dayUtc = DateTime.utc(date.year, date.month, date.day);
      final String hiveKey = '${_selectedDeviceId}_${DateFormat('yyyy-MM-dd').format(dayUtc)}';
      final cachedSummary = dailyBox.get(hiveKey);

      if (cachedSummary != null) {
        final distance = cachedSummary.distance ?? 0;
        final engineHours = cachedSummary.engineHours ?? 0;
        if (date.isAfter(today) && distance <= 0 && engineHours <= 0) {
          await dailyBox.delete(hiveKey);
          continue;
        }
        _dailySummaries[dayUtc] = api.ReportSummary(distance: cachedSummary.distance, averageSpeed: cachedSummary.averageSpeed, maxSpeed: cachedSummary.maxSpeed, spentFuel: cachedSummary.spentFuel, engineHours: cachedSummary.engineHours);
      }
    }

    // 2. 一次性發送帶有 daily=true 的完整區間請求
    final from = DateTime(firstDayOfMonth.year, firstDayOfMonth.month, firstDayOfMonth.day, 0, 0, 0).toUtc();
    final to = DateTime(effectiveLastDay.year, effectiveLastDay.month, effectiveLastDay.day, 23, 59, 59).toUtc();

    try {
      final response = await traccarProvider.apiClient.invokeAPI(
        '/reports/summary',
        'GET',
        [api.QueryParam('from', from.toIso8601String()), api.QueryParam('to', to.toIso8601String()), api.QueryParam('deviceId', _selectedDeviceId.toString()), api.QueryParam('daily', 'true')],
        null,
        {},
        {},
        'application/json',
      );

      if (response.body.isNotEmpty) {
        final decoded = json.decode(response.body) as List?;
        if (decoded != null) {
          for (final raw in decoded) {
            final map = raw as Map<String, dynamic>;
            final startTimeStr = map['startTime'] as String?;

            if (startTimeStr != null) {
              final startTime = DateTime.parse(startTimeStr);
              final dayUtc = DateTime.utc(startTime.year, startTime.month, startTime.day);
              final String hiveKey = '${_selectedDeviceId}_${DateFormat('yyyy-MM-dd').format(dayUtc)}';

              final summary = api.ReportSummary(
                distance: (map['distance'] as num?)?.toDouble(),
                averageSpeed: (map['averageSpeed'] as num?)?.toDouble(),
                maxSpeed: (map['maxSpeed'] as num?)?.toDouble(),
                spentFuel: (map['spentFuel'] as num?)?.toDouble(),
                engineHours: map['engineHours'] as int?,
              );

              _dailySummaries[dayUtc] = summary;
              final newSummaryHive = ReportSummaryHive.fromApi(summary);
              await dailyBox.put(hiveKey, newSummaryHive);
            }
          }
        }
      }
    } catch (e) {
      developer.log('Failed to fetch monthly summary batch: $e', name: 'MonthlyMileageScreen');
    }

    // 更新 UI
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (_selectedDay != null) {
          final selectedDayUtc = DateTime.utc(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
          _selectedDaySummary = _dailySummaries[selectedDayUtc];
        }
      });
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      final selectedDayUtc = DateTime.utc(selectedDay.year, selectedDay.month, selectedDay.day);
      _selectedDaySummary = _dailySummaries[selectedDayUtc];
    });
  }

  void _onPageChanged(DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
    });
    _fetchMonthlyData(focusedDay);
  }

  Future<void> _deleteOldMileageData() async {
    final dailyBox = await Hive.openBox<ReportSummaryHive>('daily_summaries');
    final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));

    final keysToDelete = <String>[];
    for (var key in dailyBox.keys) {
      if (key is String) {
        final parts = key.split('_');
        if (parts.length > 1) {
          final dateString = parts[1];
          try {
            final date = DateFormat('yyyy-MM-dd').parse(dateString);
            if (date.isBefore(sixMonthsAgo)) {
              keysToDelete.add(key);
            }
          } catch (e) {
            developer.log('Invalid key format: $key', name: 'MonthlyMileageScreen');
          }
        }
      }
    }

    await dailyBox.deleteAll(keysToDelete);
    developer.log('Deleted ${keysToDelete.length} old entries from Hive.', name: 'MonthlyMileageScreen');
  }

  void _onPlayTapped() async {
    if (_selectedDay == null || _selectedDeviceId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final fromDate = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day, 0, 0, 0);
    final toDate = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day, 23, 59, 59);

    await prefs.setString('historyFrom', fromDate.toUtc().toIso8601String());
    await prefs.setString('historyTo', toDate.toUtc().toIso8601String());

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (context) => HistoryRouteScreen()));
  }

  String _formatDuration(int? milliseconds) {
    final hourAbbr = 'sharedHourAbbreviation'.tr;
    final minAbbr = 'sharedMinuteAbbreviation'.tr;

    if (milliseconds == null || milliseconds <= 0) {
      return '0$hourAbbr 0$minAbbr';
    }

    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return '$hours$hourAbbr $minutes$minAbbr';
  }

  Widget _buildDetailRow(String label, String value, Color secondaryLabel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: TextStyle(fontSize: 16, color: secondaryLabel)),
        ],
      ),
    );
  }

  Widget _buildSeparator(Color separatorColor) {
    return Container(height: 0.5, margin: const EdgeInsets.only(left: 16), color: separatorColor);
  }

  Widget _buildDetailCard(Color cardColor, Color separatorColor, Color secondaryLabel) {
    final summary = _selectedDaySummary!;
    final distanceInKm = ((summary.distance ?? 0.0) / 1000).toStringAsFixed(2);
    final averageSpeed = (summary.averageSpeed ?? 0.0).toStringAsFixed(2);
    final maxSpeed = (summary.maxSpeed ?? 0.0).toStringAsFixed(2);
    final spentFuel = (summary.spentFuel ?? 0.0).toStringAsFixed(2);

    return Container(
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          _buildDetailRow('Date'.tr, DateFormat('yyyy-MM-dd').format(_selectedDay!), secondaryLabel),
          _buildSeparator(separatorColor),
          _buildDetailRow('sharedDistance'.tr, '$distanceInKm ${'sharedKm'.tr}', secondaryLabel),
          _buildSeparator(separatorColor),
          _buildDetailRow('reportEngineHours'.tr, _formatDuration(summary.engineHours), secondaryLabel),
          _buildSeparator(separatorColor),
          _buildDetailRow('reportAverageSpeed'.tr, '$averageSpeed ${'sharedKmh'.tr}', secondaryLabel),
          _buildSeparator(separatorColor),
          _buildDetailRow('reportMaximumSpeed'.tr, '$maxSpeed ${'sharedKmh'.tr}', secondaryLabel),
          _buildSeparator(separatorColor),
          _buildDetailRow('reportSpentFuel'.tr, '$spentFuel ${'sharedLiter'.tr}', secondaryLabel),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedBackground = CupertinoDynamicColor.resolve(CupertinoColors.systemGroupedBackground, context);
    final cardColor = CupertinoDynamicColor.resolve(CupertinoColors.systemBackground, context);
    final separatorColor = CupertinoDynamicColor.resolve(CupertinoColors.separator, context);
    final secondaryLabel = CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context);

    return CupertinoTheme(
      data: CupertinoThemeData(brightness: Theme.of(context).brightness),
      child: Theme(
        data: Theme.of(context).copyWith(textTheme: Theme.of(context).textTheme.apply(fontFamily: '.SF Pro Text')),
        child: Scaffold(
          backgroundColor: groupedBackground,
          appBar: CupertinoNavigationBar(
            middle: Text(_selectedDeviceName ?? 'Monthly Mileage', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          body: _isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : _selectedDeviceId == null
              ? Center(
                  child: Text('Please select a device on the map screen first.', style: TextStyle(color: secondaryLabel)),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 10, 10),
                      child: Container(
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                        child: TableCalendar(
                          locale: Get.locale?.languageCode,
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          daysOfWeekHeight: 0,
                          rowHeight: 55,
                          headerStyle: const HeaderStyle(
                            titleCentered: true,
                            leftChevronIcon: Icon(CupertinoIcons.chevron_left, size: 18),
                            rightChevronIcon: Icon(CupertinoIcons.chevron_right, size: 18),
                            titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            formatButtonTextStyle: TextStyle(fontSize: 13, color: CupertinoColors.systemBlue),
                          ),
                          calendarStyle: const CalendarStyle(
                            markersAlignment: Alignment.topCenter,
                            outsideDaysVisible: false,
                            cellMargin: EdgeInsets.symmetric(horizontal: 1, vertical: 1),
                            defaultTextStyle: TextStyle(fontSize: 15),
                            weekendTextStyle: TextStyle(fontSize: 15, color: CupertinoColors.systemRed),
                            todayTextStyle: TextStyle(color: CupertinoColors.white, fontSize: 15, fontWeight: FontWeight.w600),
                            todayDecoration: BoxDecoration(color: CupertinoColors.systemRed, shape: BoxShape.circle),
                            selectedTextStyle: TextStyle(color: CupertinoColors.white, fontSize: 15, fontWeight: FontWeight.w600),
                            selectedDecoration: BoxDecoration(color: CupertinoColors.systemBlue, shape: BoxShape.circle),
                          ),
                          calendarFormat: _calendarFormat,
                          onFormatChanged: (format) {
                            setState(() {
                              _calendarFormat = format;
                            });
                          },
                          selectedDayPredicate: (day) {
                            return isSameDay(_selectedDay, day);
                          },
                          onDaySelected: _onDaySelected,
                          onPageChanged: _onPageChanged,
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: TextStyle(color: secondaryLabel, fontSize: 12),
                            weekendStyle: TextStyle(color: CupertinoColors.systemRed.withValues(alpha: 0.7), fontSize: 12),
                          ),
                          eventLoader: (day) {
                            final dayUtc = DateTime.utc(day.year, day.month, day.day);
                            if (_dailySummaries.containsKey(dayUtc)) {
                              return [true];
                            }
                            return [];
                          },
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, date, events) {
                              final dayUtc = DateTime.utc(date.year, date.month, date.day);
                              if (_dailySummaries.containsKey(dayUtc)) {
                                final summary = _dailySummaries[dayUtc]!;
                                final distanceInKm = (summary.distance ?? 0.0) / 1000;
                                final engineHoursInHours = (summary.engineHours ?? 0) / 3600000;
                                final isSelected = isSameDay(date, _selectedDay);

                                return Positioned(
                                  top: 30,
                                  left: 0,
                                  right: 0,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${distanceInKm.toStringAsFixed(0)}km',
                                        style: TextStyle(fontSize: 10, color: isSelected ? CupertinoColors.white : CupertinoColors.systemBlue, fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        '${engineHoursInHours.toStringAsFixed(1)}h',
                                        style: const TextStyle(fontSize: 10, color: CupertinoColors.systemOrange, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_selectedDaySummary == null)
                      Expanded(
                        child: Center(
                          child: Text('sharedNoData'.tr, style: TextStyle(color: secondaryLabel)),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                          children: [
                            _buildDetailCard(cardColor, separatorColor, secondaryLabel),
                            const SizedBox(height: 2),
                            CupertinoButton.filled(
                              onPressed: _onPlayTapped,
                              borderRadius: BorderRadius.circular(12),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(CupertinoIcons.play_fill, size: 16), const SizedBox(width: 6), Text('reportReplay'.tr)]),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
