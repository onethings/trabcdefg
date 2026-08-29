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
    final reportsApi = api.ReportsApi(traccarProvider.apiClient);
    final dailyBox = await Hive.openBox<ReportSummaryHive>('daily_summaries');
    final serverVersion = await traccarProvider.fetchServerVersion();
    final today = DateTime.now();

    developer.log('Server version: $serverVersion — fetching monthly data for ${month.year}-${month.month}', name: 'MonthlyMileageScreen');

    // Step 1: Load from cache (Hive), but skip stale zero-value entries for future dates
    _dailySummaries.clear();
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    for (var date = firstDayOfMonth; date.isBefore(lastDayOfMonth.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      final dayUtc = DateTime.utc(date.year, date.month, date.day);
      final String hiveKey = '${_selectedDeviceId}_${DateFormat('yyyy-MM-dd').format(dayUtc)}';
      final cachedSummary = dailyBox.get(hiveKey);

      if (cachedSummary != null) {
        // ❗ Old API (e.g., v4.4) may have cached zero-value entries for future dates.
        // Skip cached zero entries for dates after today so they get re-fetched later.
        final distance = cachedSummary.distance ?? 0;
        final engineHours = cachedSummary.engineHours ?? 0;
        if (date.isAfter(today) && distance <= 0 && engineHours <= 0) {
          developer.log('Skipping stale zero cache for future date: ${DateFormat('yyyy-MM-dd').format(date)}', name: 'MonthlyMileageScreen');
          await dailyBox.delete(hiveKey);
          continue;
        }
        _dailySummaries[dayUtc] = api.ReportSummary(distance: cachedSummary.distance, averageSpeed: cachedSummary.averageSpeed, maxSpeed: cachedSummary.maxSpeed, spentFuel: cachedSummary.spentFuel, engineHours: cachedSummary.engineHours);
      }
    }

    // This initial setState will show any cached data immediately
    setState(() {
      _isLoading = false;
    });

    // Step 2: Fetch data from the network concurrently and update cache
    final List<Future<void>> fetchTasks = [];

    for (var date = firstDayOfMonth; date.isBefore(lastDayOfMonth.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
      final dayUtc = DateTime.utc(date.year, date.month, date.day);

      // 🔥 Skip future dates — no data exists yet, and old API (v4.4) incorrectly
      // returns zero-value summaries for future dates that would pollute our cache.
      if (date.isAfter(today)) {
        developer.log('Skipping future date (no network fetch): ${DateFormat('yyyy-MM-dd').format(date)}', name: 'MonthlyMileageScreen');
        continue;
      }

      if (_dailySummaries.containsKey(dayUtc)) {
        continue;
      }

      final from = DateTime(date.year, date.month, date.day, 0, 0, 0).toUtc();
      final to = DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc();
      final String hiveKey = '${_selectedDeviceId}_${DateFormat('yyyy-MM-dd').format(dayUtc)}';

      fetchTasks.add(() async {
        try {
          api.ReportSummary? dailySummary;
          try {
            // Try using the generated API first (works on v6.x+)
            final summary = await reportsApi.getReportsSummary(from, to, deviceId: [_selectedDeviceId!]);
            if (summary != null && summary.isNotEmpty) {
              dailySummary = summary.first;
            }
          } catch (e) {
            // Fallback for old API (v4.x) — the generated fromJson may fail
            // on missing fields. Use raw API call with manual parsing instead.
            developer.log('Generated API failed, trying raw API fallback: $e', name: 'MonthlyMileageScreen');
            try {
              final response = await traccarProvider.apiClient.invokeAPI(
                '/reports/summary',
                'GET',
                [api.QueryParam('from', from.toIso8601String()), api.QueryParam('to', to.toIso8601String()), api.QueryParam('deviceId', _selectedDeviceId.toString())],
                null,
                {},
                {},
                'application/json',
              );
              if (response.body.isNotEmpty) {
                final decoded = json.decode(response.body) as List?;
                if (decoded != null && decoded.isNotEmpty) {
                  final raw = decoded.first as Map<String, dynamic>;
                  dailySummary = api.ReportSummary(
                    distance: (raw['distance'] as num?)?.toDouble(),
                    averageSpeed: (raw['averageSpeed'] as num?)?.toDouble(),
                    maxSpeed: (raw['maxSpeed'] as num?)?.toDouble(),
                    spentFuel: (raw['spentFuel'] as num?)?.toDouble(),
                    engineHours: raw['engineHours'] as int?,
                  );
                }
              }
            } catch (e2) {
              developer.log('Raw API fallback also failed for day $date: $e2', name: 'MonthlyMileageScreen');
            }
          }

          if (dailySummary != null) {
            developer.log('Fetched summary for ${DateFormat('yyyy-MM-dd').format(date)}: distance=${dailySummary.distance}, engineHours=${dailySummary.engineHours}, avgSpeed=${dailySummary.averageSpeed}', name: 'MonthlyMileageScreen');
            _dailySummaries[dayUtc] = dailySummary;

            final newSummaryHive = ReportSummaryHive.fromApi(dailySummary);
            await dailyBox.put(hiveKey, newSummaryHive);
          } else {
            developer.log('  → empty result (no data for this day)', name: 'MonthlyMileageScreen');
          }
        } catch (e) {
          developer.log('Failed to fetch data for day $date: $e', name: 'MonthlyMileageScreen');
        }
      }());
    }

    // Wait for all concurrent fetch requests to finish
    if (fetchTasks.isNotEmpty) {
      await Future.wait(fetchTasks);
    }

    // Update the UI with any newly fetched data
    if (mounted) {
      setState(() {
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
        final parts = key.split('_'); // Fixed pattern split based on Hive key definitions
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

    if (!mounted) return; // Guard cross-async context navigation

    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (context) => HistoryRouteScreen()));
  }

  // Helper method to format milliseconds into "Hh Mm" string
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

  // Builds a single inset-grouped detail row (label on the left, value on the right).
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

  // Hairline separator between inset-grouped rows, matching the iOS look.
  Widget _buildSeparator(Color separatorColor) {
    return Container(height: 0.5, margin: const EdgeInsets.only(left: 16), color: separatorColor);
  }

  // The iOS-style "inset grouped" card showing the selected day's stats.
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
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0), //12, 8, 12, 4
                      child: Container(
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                        child: TableCalendar(
                          locale: Get.locale?.languageCode,
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          daysOfWeekHeight: 0,
                          rowHeight: 54,
                          headerStyle: const HeaderStyle(
                            titleCentered: true,
                            leftChevronIcon: Icon(CupertinoIcons.chevron_left, size: 18),
                            rightChevronIcon: Icon(CupertinoIcons.chevron_right, size: 18),
                            titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            formatButtonTextStyle: TextStyle(fontSize: 13, color: CupertinoColors.systemBlue),
                          ),
                          // Align the day number to the top of the cell so the
                          // mileage / engine-hours text below doesn't overlap it.
                          calendarStyle: const CalendarStyle(
                            markersAlignment: Alignment.topCenter,
                            outsideDaysVisible: false,
                            // Smaller gaps between adjacent dates.
                            cellMargin: EdgeInsets.symmetric(horizontal: 1, vertical: 1), //3,2
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

                                // Two lines: mileage on top, engine hours below.
                                // Anchored right under the day number so the gap
                                // stays small no matter what rowHeight is set to.
                                return Positioned(
                                  top: 32, //21
                                  left: 0,
                                  right: 0,
                                  //    bottom: 0,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${distanceInKm.toStringAsFixed(0)}km',
                                        style: const TextStyle(fontSize: 10, color: CupertinoColors.systemBlue, fontWeight: FontWeight.w500),
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
                    const SizedBox(height: 8),
                    if (_selectedDaySummary == null)
                      Expanded(
                        child: Center(
                          child: Text('sharedNoData'.tr, style: TextStyle(color: secondaryLabel)),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 0), //12, 4, 12, 12
                          children: [
                            _buildDetailCard(cardColor, separatorColor, secondaryLabel),
                            const SizedBox(height: 2), //12
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
