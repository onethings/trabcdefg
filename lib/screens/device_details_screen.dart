// lib/screens/device_details_screen.dart
// DeviceDetailsScreen displaying detailed device info and latest position
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- ADD THIS IMPORT for Clipboard
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

// 1. Create a container class for all necessary future data
class DeviceData {
  final api.Device device;
  final List<api.Position>? positions;

  DeviceData(this.device, this.positions);
}

class DeviceDetailsScreen extends StatelessWidget {
  const DeviceDetailsScreen({super.key});

  // 2. Define a function to fetch all required data
  Future<DeviceData> _fetchDeviceAndPositions(BuildContext context, int deviceId) async {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);

    // Resolve the device, preferring the list the provider already loaded at
    // login / over the WebSocket. Traccar 4.x does not support all `/devices`
    // query parameters, so the cached list is the most reliable source.
    api.Device? device = _findDevice(traccarProvider.devices, deviceId);

    if (device == null) {
      final devicesApi = api.DevicesApi(traccarProvider.apiClient);
      final deviceList = await devicesApi.getDevices(id: deviceId);
      device = deviceList == null ? null : _findDevice(deviceList, deviceId);
    }

    if (device == null) {
      throw Exception('Device $deviceId not found');
    }

    // Fetch the latest position in a server-version-safe way. Traccar 4.x
    // rejects `/positions?deviceId=...` without `from`/`to` with a 400
    // (NullPointerException in DateUtil.parseDate).
    final position = await traccarProvider.fetchLatestPosition(deviceId);

    return DeviceData(device, position == null ? null : [position]);
  }

  api.Device? _findDevice(List<api.Device> devices, int deviceId) {
    for (final device in devices) {
      if (device.id == deviceId) return device;
    }
    return null;
  }

  // 3. A dedicated row for copyable content (the phone number)
  Widget _buildCopyableDetailRow(BuildContext context, String label, String value) {
    // Only allow copying if the value is meaningful (not the 'sharedNoData' string)
    final bool isCopyable = value.isNotEmpty && value != 'sharedNoData'.tr;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(value, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, maxLines: 2),
                ),
                if (isCopyable)
                  // The copy icon wrapped in a tap detector
                  InkWell(
                    onTap: () async {
                      // Capture the messenger state BEFORE the async gap
                      final messenger = ScaffoldMessenger.of(context);

                      await Clipboard.setData(ClipboardData(text: value));

                      // FIX APPLIED HERE in previous step: calculate the dynamic string first
                      final String confirmationText =
                          // Assuming 'copiedToClipboard' is a translation key
                          '$label ${'copiedToClipboard'.tr}';

                      // Show confirmation message safely using the captured messenger
                      messenger.showSnackBar(SnackBar(content: Text(confirmationText), duration: const Duration(seconds: 1)));
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.copy, size: 16, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasError) {
          return Scaffold(
            appBar: CupertinoNavigationBar(middle: const Text('Error')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        } else if (snapshot.hasData) {
          final prefs = snapshot.data!;
          final deviceId = prefs.getInt('selectedDeviceId');
          final deviceName = prefs.getString('selectedDeviceName');

          if (deviceId == null || deviceName == null) {
            return Scaffold(
              appBar: CupertinoNavigationBar(middle: const Text('Device Details')),
              body: const Center(child: Text('Device not selected.')),
            );
          }

          // 3. Use the new function to fetch combined data
          return Scaffold(
            appBar: CupertinoNavigationBar(
              // FIX: Removed unnecessary non-null assertion '!' and replaced '+' with interpolation
              middle: Text('$deviceName - ${'deviceSecondaryInfo'.tr}'),
              trailing: Consumer<TraccarProvider>(
                builder: (context, provider, child) {
                  final isFavorite = provider.isFavorite(deviceId);
                  return IconButton(
                    icon: Icon(isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart, color: isFavorite ? Colors.red : null),
                    onPressed: () => provider.toggleFavorite(deviceId),
                  );
                },
              ),
            ),
            body: FutureBuilder<DeviceData>(
              future: _fetchDeviceAndPositions(context, deviceId),
              builder: (context, dataSnapshot) {
                if (dataSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (dataSnapshot.hasError) {
                  return Center(child: Text('Error: ${dataSnapshot.error}'));
                } else if (dataSnapshot.hasData) {
                  final device = dataSnapshot.data!.device;
                  final positions = dataSnapshot.data!.positions;
                  final position = (positions != null && positions.isNotEmpty) ? positions.first : null;

                  String formatDate(DateTime? date) {
                    if (date == null) return 'sharedNoData'.tr;
                    return DateFormat('MM/dd/yyyy, hh:mm:ss a').format(date.toLocal());
                  }

                  String formatSpeed(num? speed) {
                    if (speed == null) return 'sharedNoData'.tr;
                    // FIX: Replaced '+' concatenation with string interpolation
                    return '${speed.toStringAsFixed(2)} ${'sharedKn'.tr}';
                  }

                  String formatCourse(num? course) {
                    if (course == null) return 'sharedNoData'.tr;
                    return '↑';
                  }

                  String formatBoolValue(bool? value) {
                    if (value == null) return 'sharedNoData'.tr;
                    return value ? 'sharedYes'.tr : 'sharedNo'.tr;
                  }

                  // Check if position data is available to display
                  if (position == null) {
                    return Center(child: Text('sharedNoData'.tr));
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // USE NEW WIDGET HERE for copyable phone number
                        _buildCopyableDetailRow(context, 'sharedPhone'.tr, device.phone ?? 'sharedNoData'.tr),
                        const Divider(height: 25), // Separator
                        // Latest Position Details
                        Text('reportPositions'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Divider(),
                        _buildDetailRow('deviceIdentifier'.tr, position.id?.toString() ?? 'sharedNoData'.tr),
                        _buildDetailRow('Device ID', position.deviceId?.toString() ?? 'sharedNoData'.tr),
                        _buildDetailRow('positionProtocol'.tr, position.protocol ?? 'sharedNoData'.tr),
                        _buildDetailRow('positionServerTime'.tr, formatDate(position.serverTime)),
                        _buildDetailRow('positionDeviceTime'.tr, formatDate(position.deviceTime)),
                        _buildDetailRow('positionFixTime'.tr, formatDate(position.fixTime)),
                        _buildDetailRow('positionValid'.tr, formatBoolValue(position.valid)),
                        _buildDetailRow('positionLatitude'.tr, position.latitude != null ? '${position.latitude!.toStringAsFixed(6)}°' : 'sharedNoData'.tr),
                        _buildDetailRow('positionLongitude'.tr, position.longitude != null ? '${position.longitude!.toStringAsFixed(6)}°' : 'sharedNoData'.tr),
                        _buildDetailRow(
                          'positionAltitude'.tr,
                          position.altitude != null
                              // FIX: Replaced '+' concatenation with string interpolation
                              ? '${position.altitude!.toStringAsFixed(2)} ${'sharedMeters'.tr}'
                              : 'sharedNoData'.tr,
                        ),
                        _buildDetailRow('positionSpeed'.tr, formatSpeed(position.speed)),
                        _buildDetailRow('positionCourse'.tr, formatCourse(position.course)),
                        _buildDetailRow('positionAddress'.tr, position.address ?? 'sharedNoData'.tr),
                        _buildDetailRow('positionAccuracy'.tr, position.accuracy?.toString() ?? 'sharedNoData'.tr),
                        _buildAttributeRow('Network'.tr, _formatAttributeValue('network', position.network)),
                        _buildDetailRow('sharedGeofences'.tr, position.geofenceIds.toString()),
                        const SizedBox(height: 20),
                        Text('sharedAttributes'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Divider(),
                        // Attributes differ per protocol, model and firmware (JT808
                        // alone reports iccid, odometer, alarm, ...), so render
                        // whatever the server sent instead of a fixed whitelist.
                        ..._buildAttributeRows(_asAttributeMap(position.attributes)),
                      ],
                    ),
                  );
                }
                return Center(child: Text('sharedNoData'.tr));
              },
            ),
          );
        }
        return const Center(child: Text('Unknown state.'));
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, maxLines: 2),
          ),
        ],
      ),
    );
  }

  /// Attribute keys Traccar reports for most protocols. They keep a stable
  /// order and a translated label; everything else is appended afterwards.
  static const List<String> _primaryAttributeKeys = [
    'type',
    'status',
    'ignition',
    'charge',
    'blocked',
    'batteryLevel',
    'rssi',
    'distance',
    'totalDistance',
    'hours',
    'motion',
  ];

  static const Map<String, String> _attributeTranslationKeys = {
    'type': 'sharedType',
    'status': 'deviceStatus',
    'ignition': 'positionIgnition',
    'charge': 'positionCharge',
    'blocked': 'positionBlocked',
    'batteryLevel': 'positionBatteryLevel',
    'rssi': 'positionRssi',
    'distance': 'positionDistance',
    'totalDistance': 'deviceTotalDistance',
    'hours': 'reportEngineHours',
    'motion': 'positionMotion',
    'alarm': 'positionAlarm',
    'odometer': 'positionOdometer',
  };

  /// Keys that read better as-is than as a raw lowercase server key.
  static const Map<String, String> _attributeDisplayNames = {
    'iccid': 'ICCID',
    'imei': 'IMEI',
    'imsi': 'IMSI',
    'vin': 'VIN',
    'rpm': 'RPM',
  };

  /// Traccar stores these attributes in meters.
  static const Set<String> _meterAttributes = {
    'distance',
    'totalDistance',
    'odometer',
    'obdOdometer',
    'odometerTrip',
  };

  Map<String, dynamic> _asAttributeMap(Object? attributes) {
    if (attributes is Map<String, dynamic>) return attributes;
    if (attributes is Map) {
      return attributes.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  List<Widget> _buildAttributeRows(Map<String, dynamic> attributes) {
    final rows = <Widget>[];
    final remainingKeys = attributes.keys.toSet();

    for (final key in _primaryAttributeKeys) {
      remainingKeys.remove(key);
      rows.add(_buildAttributeRow(_attributeLabel(key), _formatAttributeValue(key, attributes[key])));
    }

    for (final key in remainingKeys.toList()..sort()) {
      final value = attributes[key];
      if (value == null) continue;
      rows.add(_buildAttributeRow(_attributeLabel(key), _formatAttributeValue(key, value)));
    }

    return rows;
  }

  String _attributeLabel(String key) {
    final translationKey = _attributeTranslationKeys[key];
    if (translationKey != null) return translationKey.tr;
    return _attributeDisplayNames[key] ?? key;
  }

  String _formatAttributeValue(String key, Object? value) {
    if (value == null) return 'sharedNoData'.tr;
    if (value is bool) return value ? 'sharedYes'.tr : 'sharedNo'.tr;
    if (value is num) {
      if (_meterAttributes.contains(key)) {
        return '${(value / 1000).toStringAsFixed(2)} ${'sharedKm'.tr}';
      }
      if (key == 'hours') {
        return (value / Duration.millisecondsPerHour).toStringAsFixed(2);
      }
      final text = value is double && value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString();
      if (key == 'batteryLevel') return '$text%';
      return text;
    }
    if (value is Map || value is List) {
      try {
        return const JsonEncoder.withIndent('  ').convert(value);
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }

  /// Attribute rows wrap instead of truncating so long values such as ICCID,
  /// VIN or nested network information stay fully readable.
  Widget _buildAttributeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 3,
            child: SelectableText(value, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
