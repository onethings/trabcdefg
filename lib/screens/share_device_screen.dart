// lib/screens/share_device_screen.dart
//This screen provides a clean interface for generating a temporary, shareable access link for a specific GPS device tracked by a Traccar server.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/constants.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';

class ShareDeviceScreen extends StatefulWidget {
  const ShareDeviceScreen({super.key});

  @override
  State<ShareDeviceScreen> createState() => _ShareDeviceScreenState();
}

class _ShareDeviceScreenState extends State<ShareDeviceScreen> {
  DateTime? _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime = TimeOfDay.now();
  String? _deviceName;
  int? _deviceId;
  bool _isLoading = false;
  String? _shareLink;

  final TextEditingController _linkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDeviceData();
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _deviceName = prefs.getString('sharedDeviceName');
      _deviceId = prefs.getInt('sharedDeviceId');
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (pickedTime != null && pickedTime != _selectedTime) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  Future<void> _shareDevice() async {
    if (_selectedDate == null || _selectedTime == null || _deviceId == null) {
      Get.snackbar('Error', 'Please select a date and time.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final expiration = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    ).toUtc();

    final url = Uri.parse('${AppConstants.traccarApiUrl}/devices/share');
    final traccarProvider = context.read<TraccarProvider>();
    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      HttpHeaders.cookieHeader: 'JSESSIONID=${traccarProvider.sessionId}',
    };
    final requestBody = {
      'deviceId': _deviceId.toString(),
      'expiration': expiration.toIso8601String(),
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: requestBody,
      );

      if (response.statusCode == 200) {
        // Use the raw response body as the token string directly
        final String token = response.body;
        final String link = '${AppConstants.traccarServerUrl}?token=$token';
        setState(() {
          _shareLink = link;
          _linkController.text = _shareLink!;
        });
        Get.snackbar('Success', 'Device shared successfully!');
      } else {
        Get.snackbar('Error',
            'Failed to share device. Status: ${response.statusCode}');
      }
    } catch (e) {
      Get.snackbar('Error', 'An error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard() {
    if (_shareLink != null) {
      Clipboard.setData(ClipboardData(text: _shareLink!));
      Get.snackbar('Copied', 'Link copied to clipboard!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Share $_deviceName'.tr),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              title: Text(
                'Select Expiration Date: ${_selectedDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDate!) : 'N/A'}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context),
            ),
            ListTile(
              title: Text(
                'Select Expiration Time: ${_selectedTime != null ? _selectedTime!.format(context) : 'N/A'}',
              ),
              trailing: const Icon(Icons.access_time),
              onTap: () => _selectTime(context),
            ),
            const SizedBox(height: 20),
            if (_shareLink != null)
              TextField(
                controller: _linkController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Shareable Link',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: _copyToClipboard,
                  ),
                ),
              )
            else
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _shareDevice,
                      child: const Text('Share'),
                    ),
          ],
        ),
      ),
    );
  }
}