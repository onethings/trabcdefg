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
import 'package:trabcdefg/screens/settings/add_device_screen.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

// 1. Create a container class for all necessary future data
class DeviceData {
  final api.Device device;
  final List<api.Position>? positions;

  DeviceData(this.device, this.positions);
}

class DeviceDetailsScreen extends StatefulWidget {
  const DeviceDetailsScreen({super.key});

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  api.Device? _updatedDevice;

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

  Future<void> _editDevice(api.Device device) async {
    final updatedDevice = await Navigator.of(context).push<api.Device>(MaterialPageRoute(builder: (_) => AddDeviceScreen(device: device)));
    if (updatedDevice == null || !mounted) return;

    context.read<TraccarProvider>().updateDevice(updatedDevice);
    setState(() => _updatedDevice = updatedDevice);
    if (updatedDevice.name != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedDeviceName', updatedDevice.name!);
    }
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
              middle: Text('${_updatedDevice?.name ?? deviceName} - ${'deviceSecondaryInfo'.tr}'),
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
                  final device = _updatedDevice ?? dataSnapshot.data!.device;
                  final positions = dataSnapshot.data!.positions;
                  final position = (positions != null && positions.isNotEmpty) ? positions.first : null;

                  final positionRows = position == null ? <Widget>[] : _buildPositionRows(position);
                  final attributeRows = position == null ? <Widget>[] : _buildAttributeRows(_asAttributeMap(position.attributes));
                  final bottomNavigationSpace = MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + bottomNavigationSpace),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOverviewCard(context, device, position, deviceName),
                        if (positionRows.isNotEmpty) ...[const SizedBox(height: 24), _buildDetailSection(context, 'reportPositions'.tr, CupertinoIcons.location, positionRows)],
                        if (attributeRows.isNotEmpty) ...[const SizedBox(height: 24), _buildDetailSection(context, 'sharedAttributes'.tr, CupertinoIcons.slider_horizontal_3, attributeRows)],
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

  Widget _buildOverviewCard(BuildContext context, api.Device device, api.Position? position, String fallbackName) {
    final colors = Theme.of(context).colorScheme;
    final positionValues = position?.toJson() ?? const <String, dynamic>{};
    final address = positionValues['address']?.toString();
    final fixTime = positionValues['fixTime'];
    final formattedFixTime = _hasAttributeValue(fixTime) ? _formatPositionValue('fixTime', fixTime) : null;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(18)),
                  child: Icon(CupertinoIcons.location_fill, color: colors.onPrimaryContainer, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name ?? fallbackName, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text('reportPositions'.tr, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'sharedEdit'.tr,
                  onPressed: () => _editDevice(device),
                  icon: Icon(CupertinoIcons.pencil, color: colors.primary),
                ),
              ],
            ),
            if (_hasAttributeValue(address) || formattedFixTime != null || _hasAttributeValue(device.category) || _hasAttributeValue(device.phone)) ...[
              const SizedBox(height: 18),
              Divider(color: colors.outlineVariant.withValues(alpha: 0.5)),
              if (_hasAttributeValue(address)) _buildOverviewMeta(context, CupertinoIcons.map_pin_ellipse, address!),
              if (_hasAttributeValue(address) && (formattedFixTime != null || _hasAttributeValue(device.category) || _hasAttributeValue(device.phone))) const SizedBox(height: 12),
              if (formattedFixTime != null) _buildOverviewMeta(context, CupertinoIcons.clock, formattedFixTime),
              if (_hasAttributeValue(device.category)) ...[if (_hasAttributeValue(address) || formattedFixTime != null) const SizedBox(height: 12), _buildEditableCopyRow(context, 'deviceCategory'.tr, _categoryDisplayName(device.category!), device)],
              if (_hasAttributeValue(device.phone)) ...[
                if (_hasAttributeValue(address) || formattedFixTime != null || _hasAttributeValue(device.category)) const SizedBox(height: 12),
                _buildEditableCopyRow(context, 'sharedPhone'.tr, device.phone!, device),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _categoryDisplayName(String category) {
    final translationKey = 'category${category[0].toUpperCase()}${category.substring(1)}';
    final translated = translationKey.tr;
    return translated == translationKey ? category : translated;
  }

  Widget _buildEditableCopyRow(BuildContext context, String label, String value, api.Device device) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 3),
              SelectableText(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        IconButton(
          tooltip: 'sharedCopy'.tr,
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label: ${'sharedCopy'.tr}'), duration: const Duration(seconds: 1)));
          },
          icon: Icon(CupertinoIcons.doc_on_doc, size: 19, color: colors.onSurfaceVariant),
        ),
        IconButton(
          tooltip: 'sharedEdit'.tr,
          visualDensity: VisualDensity.compact,
          onPressed: () => _editDevice(device),
          icon: Icon(CupertinoIcons.pencil, size: 19, color: colors.primary),
        ),
      ],
    );
  }

  Widget _buildOverviewMeta(BuildContext context, IconData icon, String value) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: colors.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.4)),
        ),
      ],
    );
  }

  Widget _buildDetailSection(BuildContext context, String title, IconData icon, List<Widget> rows) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: colors.primary),
              const SizedBox(width: 9),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var index = 0; index < rows.length; index++) ...[if (index > 0) Divider(color: colors.outlineVariant.withValues(alpha: 0.5)), rows[index]],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Attribute keys Traccar reports for most protocols. They keep a stable
  /// order and a translated label; everything else is appended afterwards.
  static const List<String> _primaryAttributeKeys = ['type', 'status', 'ignition', 'charge', 'blocked', 'batteryLevel', 'rssi', 'distance', 'totalDistance', 'hours', 'motion'];

  static const List<String> _positionFieldOrder = ['id', 'deviceId', 'protocol', 'deviceTime', 'fixTime', 'serverTime', 'valid', 'latitude', 'longitude', 'altitude', 'speed', 'course', 'address', 'accuracy', 'network', 'geofenceIds'];

  static const Map<String, String> _positionFieldTranslationKeys = {
    'protocol': 'positionProtocol',
    'deviceTime': 'positionDeviceTime',
    'fixTime': 'positionFixTime',
    'serverTime': 'positionServerTime',
    'valid': 'positionValid',
    'latitude': 'positionLatitude',
    'longitude': 'positionLongitude',
    'altitude': 'positionAltitude',
    'speed': 'positionSpeed',
    'course': 'positionCourse',
    'address': 'positionAddress',
    'accuracy': 'positionAccuracy',
    'geofenceIds': 'sharedGeofences',
  };

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
  static const Map<String, String> _attributeDisplayNames = {'iccid': 'ICCID', 'imei': 'IMEI', 'imsi': 'IMSI', 'vin': 'VIN', 'rpm': 'RPM'};

  /// Traccar stores these attributes in meters.
  static const Set<String> _meterAttributes = {'distance', 'totalDistance', 'odometer', 'obdOdometer', 'odometerTrip'};

  Map<String, dynamic> _asAttributeMap(Object? attributes) {
    if (attributes is Map<String, dynamic>) return attributes;
    if (attributes is Map) {
      return attributes.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  List<Widget> _buildPositionRows(api.Position position) {
    final values = position.toJson()..remove('attributes');
    final keys = values.keys.toSet();
    final orderedKeys = <String>[..._positionFieldOrder.where(keys.contains), ...keys.where((key) => !_positionFieldOrder.contains(key)).toList()..sort()];

    return orderedKeys.where((key) => _hasAttributeValue(values[key])).map((key) => _buildAttributeRow(_positionFieldLabel(key), _formatPositionValue(key, values[key]))).toList();
  }

  String _positionFieldLabel(String key) {
    if (key == 'id') return 'Position ID';
    if (key == 'deviceId') return 'Device ID';
    final translationKey = _positionFieldTranslationKeys[key];
    if (translationKey != null) return translationKey.tr;
    return _humanizeKey(key);
  }

  String _formatPositionValue(String key, Object? value) {
    if (value is bool) return value ? 'sharedYes'.tr : 'sharedNo'.tr;
    if (value is String && const {'deviceTime', 'fixTime', 'serverTime'}.contains(key)) {
      final date = DateTime.tryParse(value);
      if (date != null) {
        return DateFormat('MM/dd/yyyy, hh:mm:ss a').format(date.toLocal());
      }
    }
    if (value is num) {
      if (key == 'latitude' || key == 'longitude' || key == 'course') {
        return '$value°';
      }
      if (key == 'altitude' || key == 'accuracy') {
        return '$value ${'sharedMeters'.tr}';
      }
      if (key == 'speed') {
        return '$value ${'sharedKn'.tr}';
      }
    }
    return _formatAttributeValue(key, value);
  }

  List<Widget> _buildAttributeRows(Map<String, dynamic> attributes) {
    final rows = <Widget>[];
    final remainingKeys = attributes.keys.toSet();

    for (final key in _primaryAttributeKeys) {
      remainingKeys.remove(key);
      final value = attributes[key];
      if (!_hasAttributeValue(value)) continue;
      rows.add(_buildAttributeRow(_attributeLabel(key), _formatAttributeValue(key, value)));
    }

    for (final key in remainingKeys.toList()..sort()) {
      final value = attributes[key];
      if (!_hasAttributeValue(value)) continue;
      rows.add(_buildAttributeRow(_attributeLabel(key), _formatAttributeValue(key, value)));
    }

    return rows;
  }

  bool _hasAttributeValue(Object? value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  String _attributeLabel(String key) {
    final translationKey = _attributeTranslationKeys[key];
    if (translationKey != null) return translationKey.tr;
    return _attributeDisplayNames[key] ?? _humanizeKey(key);
  }

  String _humanizeKey(String key) {
    if (key.isEmpty) return key;
    final translationKey = 'position${key[0].toUpperCase()}${key.substring(1)}';
    final translated = translationKey.tr;
    if (translated != translationKey) return translated;
    return key.replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (match) => '${match[1]} ${match[2]}');
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
      final text = value is double && value == value.roundToDouble() ? value.toInt().toString() : value.toString();
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
          Expanded(flex: 3, child: SelectableText(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
