// lib/screens/share_device_screen.dart
//This screen provides a clean interface for generating a temporary, shareable access link for a specific GPS device tracked by a Traccar server.
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trabcdefg/src/utils/cupertino_pickers.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/services/api_config.dart';
import 'package:trabcdefg/services/feedback.dart';

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
    final DateTime? pickedDate = await showCupertinoDatePickerSheet(context, initialDate: _selectedDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? pickedTime = await showCupertinoTimePickerSheet(context, initialTime: _selectedTime ?? TimeOfDay.now());
    if (pickedTime != null && pickedTime != _selectedTime) {
      setState(() {
        _selectedTime = pickedTime;
      });
    }
  }

  Future<void> _shareDevice() async {
    if (_selectedDate == null || _selectedTime == null || _deviceId == null) {
      FeedbackService.error('shareSelectDateTime'.tr, context: context);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final expiration = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute).toUtc();

    final traccarProvider = context.read<TraccarProvider>();
    final apiConfig = ApiConfig.fromApiClient(traccarProvider.apiClient);
    final url = apiConfig.uri('/devices/share');
    final headers = {'Content-Type': 'application/x-www-form-urlencoded', HttpHeaders.cookieHeader: 'JSESSIONID=${traccarProvider.sessionId}'};
    final requestBody = {'deviceId': _deviceId.toString(), 'expiration': expiration.toIso8601String()};

    try {
      final response = await http.post(url, headers: headers, body: requestBody);

      // Servers without POST /devices/share answer 405 (the path matches
      // /devices/{id}); share the current position locally instead of failing.
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _shareDeviceLocally();
        return;
      }

      // Use the raw response body as the token string directly
      final String token = response.body.trim();
      if (token.isEmpty) {
        await _shareDeviceLocally();
        return;
      }
      final String link = '${apiConfig.serverUrl}?token=$token';
      if (!mounted) return;
      setState(() {
        _shareLink = link;
        _linkController.text = _shareLink!;
      });
      FeedbackService.success('shareSuccess'.tr, context: context);
    } catch (e) {
      debugPrint('share link request failed: $e');
      await _shareDeviceLocally();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Fallback when the server cannot mint a share token: share the device's
  /// latest known position as a Google Maps link through the system sheet.
  Future<void> _shareDeviceLocally() async {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    final int? deviceId = _deviceId;
    if (deviceId == null) return;

    final position = context.read<TraccarProvider>().getPosition(deviceId);
    final num? latitude = position?.latitude;
    final num? longitude = position?.longitude;
    if (latitude == null || longitude == null) {
      if (mounted) FeedbackService.error('sharedNoData'.tr, context: context);
      return;
    }

    final String mapLink = 'https://maps.google.com/?q=$latitude,$longitude';
    final String text = 'shareLocalShareText'.trParams({'name': _deviceName ?? '', 'link': mapLink, 'time': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())});
    await SharePlus.instance.share(ShareParams(text: text));
    if (mounted) FeedbackService.info('shareLocalInfo'.tr, context: context);
  }

  void _copyToClipboard() {
    if (_shareLink != null) {
      Clipboard.setData(ClipboardData(text: _shareLink!));
      FeedbackService.info('shareLinkCopied'.tr, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(middle: Text('deviceShareName'.trParams({'name': _deviceName ?? ''}))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(title: Text('shareSelectDate'.trParams({'date': _selectedDate != null ? DateFormat('yyyy-MM-dd').format(_selectedDate!) : 'sharedNotApplicable'.tr})), trailing: const Icon(CupertinoIcons.calendar_today), onTap: () => _selectDate(context)),
            ListTile(title: Text('shareSelectTime'.trParams({'time': _selectedTime != null ? _selectedTime!.format(context) : 'sharedNotApplicable'.tr})), trailing: const Icon(CupertinoIcons.clock), onTap: () => _selectTime(context)),
            const SizedBox(height: 20),
            if (_shareLink != null)
              TextField(
                controller: _linkController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'shareLinkTitle'.tr,
                  suffixIcon: IconButton(icon: const Icon(Icons.copy), onPressed: _copyToClipboard),
                ),
              )
            else
              _isLoading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _shareDevice, child: Text('sharedShare'.tr)),
          ],
        ),
      ),
    );
  }
}
