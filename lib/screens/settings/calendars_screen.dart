// calendars_screen.dart

import 'package:flutter/material.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/screens/settings/add_calendar_screen.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

class CalendarsScreen extends StatefulWidget {
  const CalendarsScreen({super.key});

  @override
  _CalendarsScreenState createState() => _CalendarsScreenState();
}

class _CalendarsScreenState extends State<CalendarsScreen> {
  late Future<List<api.Calendar>?> _calendarsFuture;

  @override
  void initState() {
    super.initState();
    _fetchCalendars();
  }

  void _fetchCalendars() {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    // Correct way to instantiate CalendarsApi with the authenticated client
    final calendarsApi = api.CalendarsApi(traccarProvider.apiClient);
    setState(() {
      _calendarsFuture = calendarsApi.calendarsGet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('sharedCalendars'.tr),
      ),
      body: FutureBuilder<List<api.Calendar>?>(
        future: _calendarsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('${'errorGeneral'.tr}: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('sharedNoData'.tr));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final calendar = snapshot.data![index];
                return ListTile(
                  title: Text(calendar.name ?? 'sharedNoData'.tr),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newCalendar = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddCalendarScreen(),
            ),
          );
          if (newCalendar != null) {
            _fetchCalendars();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}