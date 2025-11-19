// notification_page.dart
// A page to create or edit notifications in the TracDefg app.
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:trabcdefg/constants.dart';
import 'package:trabcdefg/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

class NotificationPage extends StatefulWidget {
  final int? notificationId;

  const NotificationPage({super.key, this.notificationId});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  bool _always = false;
  bool _priority = false;

  bool _isLoading = true;
  List<dynamic> _notificationTypes = [];
  List<dynamic> _notificatorTypes = [];
  List<dynamic> _commands = [];
  List<dynamic> _calendars = [];
  String? _selectedNotificationType;
  List<String> _selectedNotificators = [];
  int? _selectedCommandId;
  int? _selectedCalendarId;
  String? _jSessionId;

  // Define the mapping from API types to localization keys
  static const Map<String, String> notificatorKeys = {
    'firebase': 'notificatorFirebase',
    'mail': 'notificatorMail',
    'sms': 'notificatorSms',
    'web': 'notificatorWeb',
    'command':'notificatorCommand'
  };

  // Define a new mapping for notification types
  static const Map<String, String> notificationTypeKeys = {
    'allEvents': 'eventAll',
    'deviceOnline': 'eventDeviceOnline',
    'deviceUnknown': 'eventDeviceUnknown',
    'deviceOffline': 'eventDeviceOffline',
    'deviceInactive': 'eventDeviceInactive',
    'queuedCommandSent': 'eventQueuedCommandSent',
    'deviceMoving': 'eventDeviceMoving',
    'deviceStopped': 'eventDeviceStopped',
    'deviceOverspeed': 'eventDeviceOverspeed',
    'deviceFuelDrop': 'eventDeviceFuelDrop',
    'deviceFuelIncrease': 'eventDeviceFuelIncrease',
    'commandResult': 'eventCommandResult',
    'geofenceEnter': 'eventGeofenceEnter',
    'geofenceExit': 'eventGeofenceExit',
    'alarm': 'eventAlarm',
    'ignitionOn': 'eventIgnitionOn',
    'ignitionOff': 'eventIgnitionOff',
    'maintenance': 'eventMaintenance',
    'textMessage': 'eventTextMessage',
    'driverChanged': 'eventDriverChanged',
    'media': 'eventMedia',
  };

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _jSessionId = prefs.getString('jSessionId');
      if (_jSessionId == null) {
        throw Exception('Session not found');
      }

      Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Cookie': 'JSESSIONID=$_jSessionId',
      };

      final typesResponse = await http.get(
        Uri.parse('${AppConstants.traccarApiUrl}/notifications/types'),
        headers: headers,
      );
      if (typesResponse.statusCode == 200) {
        _notificationTypes = json.decode(typesResponse.body);
      }

      final notificatorsResponse = await http.get(
        Uri.parse('${AppConstants.traccarApiUrl}/notifications/notificators'),
        headers: headers,
      );
      if (notificatorsResponse.statusCode == 200) {
        _notificatorTypes = json.decode(notificatorsResponse.body);
      }

      final commandsResponse = await http.get(
        Uri.parse('${AppConstants.traccarApiUrl}/commands'),
        headers: headers,
      );
      if (commandsResponse.statusCode == 200) {
        _commands = json.decode(commandsResponse.body);
      }

      final calendarsResponse = await http.get(
        Uri.parse('${AppConstants.traccarApiUrl}/calendars'),
        headers: headers,
      );
      if (calendarsResponse.statusCode == 200) {
        _calendars = json.decode(calendarsResponse.body);
      }

      if (widget.notificationId != null) {
        final notificationResponse = await http.get(
          Uri.parse('${AppConstants.traccarApiUrl}/notifications/${widget.notificationId}'),
          headers: headers,
        );
        if (notificationResponse.statusCode == 200) {
          final data = json.decode(notificationResponse.body);
          _descriptionController.text = data['description'] ?? '';
          _selectedNotificationType = data['type'];
          _selectedNotificators = data['notificators']?.split(',') ?? [];
          _selectedCommandId = data['commandId'];
          _selectedCalendarId = data['calendarId'];
          _always = data['always'] ?? false;
          _priority = data['attributes']?['priority'] ?? false;
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch initial data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveNotification() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState!.save();
      final body = {
        'description': _descriptionController.text,
        'type': _selectedNotificationType,
        'notificators': _selectedNotificators.join(','),
        'always': _always,
        if (_selectedNotificators.contains('command'))
          'commandId': _selectedCommandId,
        'calendarId': _selectedCalendarId,
        'attributes': {'priority': _priority},
      };

      try {
        http.Response response;
        Map<String, String> headers = {
          'Content-Type': 'application/json',
          'Cookie': 'JSESSIONID=$_jSessionId',
        };

        if (widget.notificationId == null) {
          response = await http.post(
            Uri.parse('${AppConstants.traccarApiUrl}/notifications'),
            headers: headers,
            body: json.encode(body),
          );
        } else {
          response = await http.put(
            Uri.parse('${AppConstants.traccarApiUrl}/notifications/${widget.notificationId}'),
            headers: headers,
            body: json.encode(body),
          );
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          Navigator.pop(context);
        } else {
          debugPrint('Failed to save notification: ${response.body}');
        }
      } catch (e) {
        debugPrint('An error occurred while saving: $e');
      }
    }
  }

  Future<void> _testNotificators() async {
    final body = {
      'type': _selectedNotificationType,
      'notificators': _selectedNotificators.join(','),
      'description': _descriptionController.text,
      'attributes': {'priority': _priority},
    };

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.traccarApiUrl}/notifications/test'),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'JSESSIONID=$_jSessionId',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('testNotificationSuccess'.tr)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('testNotificationFailed'.tr)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('testNotificatorsError'.tr)),
      );
    }
  }

  void _showNotificatorSelection() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('notificationType'.tr),
              content: SingleChildScrollView(
                child: ListBody(
                  children: _notificatorTypes.map((notificator) {
                    final isSelected = _selectedNotificators.contains(notificator['type']);
                    final String? localizationKey = notificatorKeys[notificator['type']];
                    final String displayValue = localizationKey != null ? localizationKey.tr : notificator['type'];
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(displayValue),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedNotificators.add(notificator['type']);
                          } else {
                            _selectedNotificators.remove(notificator['type']);
                          }
                          this.setState(() {}); // Update parent state
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('sharedSave'.tr),
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('sharedNotification'.tr)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('sharedNotification'.tr),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Required Section
              ExpansionTile(
                initiallyExpanded: true,
                title: Text('sharedRequired'.tr),
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'sharedType'.tr),
                    value: _selectedNotificationType,
                    items: _notificationTypes.map<DropdownMenuItem<String>>((type) {
                      final String? localizationKey = notificationTypeKeys[type['type']];
                      final String displayValue = localizationKey != null ? localizationKey.tr : type['type'];
                      return DropdownMenuItem<String>(
                        value: type['type'],
                        child: Text(displayValue),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedNotificationType = value;
                      });
                    },
                    validator: (value) => value == null ? 'sharedRequired'.tr : null,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text('sharedNotifications'.tr),
                    subtitle: Text(
                      _selectedNotificators
                          .map((type) => notificatorKeys[type] != null ? notificatorKeys[type]!.tr : type)
                          .join(', '),
                    ),
                    trailing: const Icon(Icons.arrow_drop_down),
                    onTap: _showNotificatorSelection,
                  ),
                  if (_selectedNotificators.contains('command'))
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(labelText: 'sharedSavedCommand'.tr),
                      value: _selectedCommandId,
                      items: _commands.map<DropdownMenuItem<int>>((command) {
                        return DropdownMenuItem<int>(
                          value: command['id'],
                          child: Text(command['description'] ?? 'unnamedCommand'.tr),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCommandId = value;
                        });
                      },
                      validator: (value) => value == null ? 'requiredForCommand'.tr : null,
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _testNotificators,
                    child: Text('sharedTestNotificators'.tr),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: Text('notificationAlways'.tr),
                    value: _always,
                    onChanged: (bool? value) {
                      setState(() {
                        _always = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Extra Section
              ExpansionTile(
                title: Text('sharedExtra'.tr),
                children: [
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(labelText: 'sharedDescription'.tr),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(labelText: 'sharedCalendar'.tr),
                    value: _selectedCalendarId,
                    items: _calendars.map<DropdownMenuItem<int>>((calendar) {
                      return DropdownMenuItem<int>(
                        value: calendar['id'],
                        child: Text(calendar['name'] ?? 'unnamedCalendar'.tr),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCalendarId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: Text('sharedPriority'.tr),
                    value: _priority,
                    onChanged: (bool? value) {
                      setState(() {
                        _priority = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('sharedCancel'.tr),
                  ),
                  ElevatedButton(
                    onPressed: _saveNotification,
                    child: Text('sharedSave'.tr),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}