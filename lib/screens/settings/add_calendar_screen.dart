// add_calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

class AddCalendarScreen extends StatefulWidget {
  const AddCalendarScreen({super.key});

  @override
  _AddCalendarScreenState createState() => _AddCalendarScreenState();
}

class _AddCalendarScreenState extends State<AddCalendarScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _name;
  String _type = 'calendarSimple'.tr;
  String _recurrence = 'calendarDaily'.tr;
  DateTime? _fromDate;
  DateTime? _toDate;
  TimeOfDay? _fromTime;
  TimeOfDay? _toTime;

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isFromTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFromTime) {
          _fromTime = picked;
        } else {
          _toTime = picked;
        }
      });
    }
  }

  void _saveCalendar() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final newCalendar = api.Calendar(
        name: _name,
      );
      try {
        final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
        final calendarsApi = api.CalendarsApi(traccarProvider.apiClient);
        await calendarsApi.calendarsPost(newCalendar);
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('sharedSaved'.tr)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add calendar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('sharedAdd'.tr + ' ' + 'sharedCalendar'.tr),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  decoration: InputDecoration(labelText: 'sharedName'.tr + ' (' + 'sharedRequired'.tr + ')'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name.'.tr;
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _name = value;
                  },
                ),
                const SizedBox(height: 20),
                Text('sharedType'.tr),
                DropdownButtonFormField<String>(
                  value: _type,
                  items: <String>['calendarSimple'.tr, 'calendarRecurrence'.tr].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _type = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 20),
                Text('calendarRecurrence'.tr),
                DropdownButtonFormField<String>(
                  value: _recurrence,
                  items: <String>['calendarDaily'.tr, 'calendarOnce'.tr, 'calendarWeekly'.tr, 'calendarMonthly'.tr].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _recurrence = newValue!;
                    });
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text('reportFrom'.tr),
                        subtitle: Text(_fromDate == null ? 'sharedNoData'.tr : _fromDate.toString().split(' ')[0]),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _selectDate(context, true),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: Text('reportTo'.tr),
                        subtitle: Text(_toDate == null ? 'sharedNoData'.tr : _toDate.toString().split(' ')[0]),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _selectDate(context, false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text('reportStartTime'.tr),
                        subtitle: Text(_fromTime == null ? 'sharedNoData'.tr : _fromTime!.format(context)),
                        trailing: const Icon(Icons.access_time),
                        onTap: () => _selectTime(context, true),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: Text('reportEndTime'.tr),
                        subtitle: Text(_toTime == null ? 'sharedNoData'.tr : _toTime!.format(context)),
                        trailing: const Icon(Icons.access_time),
                        onTap: () => _selectTime(context, false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('sharedCancel'.tr),
            ),
            ElevatedButton(
              onPressed: _saveCalendar,
              child: Text('sharedSave'.tr),
            ),
          ],
        ),
      ),
    );
  }
}