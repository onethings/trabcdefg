// lib/screens/monthly_mileage_screen.dart
// A screen that displays the monthly mileage of a selected device.
import 'dart:developer' as developer;

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
        developer.log(
          'Failed to initialize date formatting for $localeString: $e',
          name: 'MonthlyMileageScreen',
        );
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

    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final reportsApi = api.ReportsApi(traccarProvider.apiClient);
    final dailyBox = await Hive.openBox<ReportSummaryHive>('daily_summaries');

    // Step 1: Load from cache (Hive)
    _dailySummaries.clear();
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    for (
      var date = firstDayOfMonth;
      date.isBefore(lastDayOfMonth.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))
    ) {
      final dayUtc = DateTime.utc(date.year, date.month, date.day);
      final String hiveKey =
          '${_selectedDeviceId}_${DateFormat('yyyy-MM-dd').format(dayUtc)}';
      final cachedSummary = dailyBox.get(hiveKey);

      if (cachedSummary != null) {
        _dailySummaries[dayUtc] = api.ReportSummary(
          distance: cachedSummary.distance,
          averageSpeed: cachedSummary.averageSpeed,
          maxSpeed: cachedSummary.maxSpeed,
          spentFuel: cachedSummary.spentFuel,
          engineHours: cachedSummary.engineHours,
        );
      }
    }

    // This initial setState will show any cached data immediately
    setState(() {
      _isLoading = false;
    });

    // Step 2: Fetch data from the network concurrently and update cache
    final List<Future<void>> fetchTasks = [];

    for (
      var date = firstDayOfMonth;
      date.isBefore(lastDayOfMonth.add(const Duration(days: 1)));
      date = date.add(const Duration(days: 1))
    ) {
      final dayUtc = DateTime.utc(date.year, date.month, date.day);
      final from = DateTime(date.year, date.month, date.day, 0, 0, 0).toUtc();
      final to = DateTime(date.year, date.month, date.day, 23, 59, 59).toUtc();
      final String hiveKey =
          '${_selectedDeviceId}_${DateFormat('yyyy-MM-dd').format(dayUtc)}';

      fetchTasks.add(() async {
        try {
          final summary = await reportsApi.reportsSummaryGet(
            from,
            to,
            deviceId: [_selectedDeviceId!],
          );
          if (summary != null && summary.isNotEmpty) {
            final dailySummary = summary.first;

            _dailySummaries[dayUtc] = dailySummary;

            final newSummaryHive = ReportSummaryHive.fromApi(dailySummary);
            await dailyBox.put(hiveKey, newSummaryHive);
          }
        } catch (e) {
          developer.log(
            'Failed to fetch data for day $date: $e',
            name: 'MonthlyMileageScreen',
          );
        }
      }());
    }

    // Wait for all concurrent fetch requests to finish
    await Future.wait(fetchTasks);

    // Update the UI with any newly fetched data
    if (mounted) {
      setState(() {
        if (_selectedDay != null) {
          final selectedDayUtc = DateTime.utc(
            _selectedDay!.year,
            _selectedDay!.month,
            _selectedDay!.day,
          );
          _selectedDaySummary = _dailySummaries[selectedDayUtc];
        }
      });
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      final selectedDayUtc = DateTime.utc(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
      );
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
        final parts = key.split(
          '_',
        ); // Fixed pattern split based on Hive key definitions
        if (parts.length > 1) {
          final dateString = parts[1];
          try {
            final date = DateFormat('yyyy-MM-dd').parse(dateString);
            if (date.isBefore(sixMonthsAgo)) {
              keysToDelete.add(key);
            }
          } catch (e) {
            developer.log(
              'Invalid key format: $key',
              name: 'MonthlyMileageScreen',
            );
          }
        }
      }
    }

    await dailyBox.deleteAll(keysToDelete);
    developer.log(
      'Deleted ${keysToDelete.length} old entries from Hive.',
      name: 'MonthlyMileageScreen',
    );
  }

  void _onPlayTapped() async {
    if (_selectedDay == null || _selectedDeviceId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final fromDate = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
      0,
      0,
      0,
    );
    final toDate = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
      23,
      59,
      59,
    );

    await prefs.setString('historyFrom', fromDate.toUtc().toIso8601String());
    await prefs.setString('historyTo', toDate.toUtc().toIso8601String());

    if (!mounted) return; // Guard cross-async context navigation

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HistoryRouteScreen()),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_selectedDeviceName ?? 'Monthly Mileage')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedDeviceId == null
          ? const Center(
              child: Text('Please select a device on the map screen first.'),
            )
          : Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      TableCalendar(
                        locale: Get.locale?.languageCode,
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
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
                        eventLoader: (day) {
                          final dayUtc = DateTime.utc(
                            day.year,
                            day.month,
                            day.day,
                          );
                          if (_dailySummaries.containsKey(dayUtc)) {
                            return [true];
                          }
                          return [];
                        },
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            final dayUtc = DateTime.utc(
                              date.year,
                              date.month,
                              date.day,
                            );
                            if (_dailySummaries.containsKey(dayUtc)) {
                              final summary = _dailySummaries[dayUtc]!;
                              final distanceInKm =
                                  (summary.distance ?? 0.0) / 1000;
                              final engineHoursInHours =
                                  (summary.engineHours ?? 0) / 3600000;

                              return Positioned(
                                bottom: -3.1,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${distanceInKm.toStringAsFixed(0)}km',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    Text(
                                      '${engineHoursInHours.toStringAsFixed(1)}h',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      if (_selectedDaySummary != null)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${'Date'.tr}: ${DateFormat('yyyy-MM-dd').format(_selectedDay!)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${'sharedDistance'.tr}: ${((_selectedDaySummary!.distance ?? 0.0) / 1000).toStringAsFixed(2)} ${'sharedKm'.tr}',
                                ),
                                Text(
                                  '${'reportEngineHours'.tr}: ${_formatDuration(_selectedDaySummary!.engineHours)}',
                                ),
                                Text(
                                  '${'reportAverageSpeed'.tr}: ${(_selectedDaySummary!.averageSpeed ?? 0.0).toStringAsFixed(2)} ${'sharedKmh'.tr}',
                                ),
                                Text(
                                  '${'reportMaximumSpeed'.tr}: ${(_selectedDaySummary!.maxSpeed ?? 0.0).toStringAsFixed(2)} ${'sharedKmh'.tr}',
                                ),
                                Text(
                                  '${'reportSpentFuel'.tr}: ${(_selectedDaySummary!.spentFuel ?? 0.0).toStringAsFixed(2)} ${'sharedLiter'.tr}',
                                ),
                                const SizedBox(height: 50),
                                ElevatedButton.icon(
                                  onPressed: _onPlayTapped,
                                  icon: const Icon(Icons.play_arrow),
                                  label: Text('reportReplay'.tr),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_selectedDaySummary == null)
                        Expanded(child: Center(child: Text('sharedNoData'.tr))),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
