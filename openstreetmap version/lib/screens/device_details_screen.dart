// lib/screens/device_details_screen.dart
// DeviceDetailsScreen displaying detailed device info and latest position
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- ADD THIS IMPORT for Clipboard
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:get/get.dart';

// 1. Create a container class for all necessary future data
class DeviceData {
  final api.Device device;
  final List<api.Position>? positions;

  DeviceData(this.device, this.positions);
}

class DeviceDetailsScreen extends StatelessWidget {
  const DeviceDetailsScreen({super.key});

  // 2. Define a function to fetch all required data
  Future<DeviceData> _fetchDeviceAndPositions(
      BuildContext context, int deviceId) async {
    final traccarProvider =
        Provider.of<TraccarProvider>(context, listen: false);
    final devicesApi = api.DevicesApi(traccarProvider.apiClient);
    final positionsApi = api.PositionsApi(traccarProvider.apiClient);

    // Fetch the device details
    final deviceList = await devicesApi.devicesGet(id: deviceId);
    final device = deviceList!.first; // Assuming the ID is unique and returns one device

    // Fetch the latest position
    final positions = await positionsApi.positionsGet(deviceId: deviceId);

    return DeviceData(device, positions);
  }

  // 3. A dedicated row for copyable content (the phone number)
  Widget _buildCopyableDetailRow(
      BuildContext context, String label, String value) {
    // Only allow copying if the value is meaningful (not the 'sharedNoData' string)
    final bool isCopyable = value.isNotEmpty && value != 'sharedNoData'.tr;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                if (isCopyable)
                  // The copy icon wrapped in a tap detector
                  InkWell(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: value));
                      
                      // FIX APPLIED HERE in previous step: calculate the dynamic string first
                      final String confirmationText =
                          // Assuming 'copiedToClipboard' is a translation key
                          '$label ${'copiedToClipboard'.tr}';

                      // Show confirmation message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(confirmationText),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(
                        Icons.copy,
                        size: 16,
                        color: Colors.grey,
                      ),
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        } else if (snapshot.hasData) {
          final prefs = snapshot.data!;
          final deviceId = prefs.getInt('selectedDeviceId');
          final deviceName = prefs.getString('selectedDeviceName');

          if (deviceId == null || deviceName == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Device Details')),
              body: const Center(child: Text('Device not selected.')),
            );
          }

          // 3. Use the new function to fetch combined data
          return Scaffold(
            appBar: AppBar(
              title: Text(deviceName! + ' - ' + 'deviceSecondaryInfo'.tr),
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
                  final position = (positions != null && positions.isNotEmpty)
                      ? positions.first
                      : null;
                  final attributes =
                      position?.attributes as Map<String, dynamic>?;

                  String formatDate(DateTime? date) {
                    if (date == null) return 'sharedNoData'.tr;
                    return DateFormat('MM/dd/yyyy, hh:mm:ss a')
                        .format(date.toLocal());
                  }

                  String formatDistance(num? distance) {
                    if (distance == null) return 'sharedNoData'.tr;
                    return '${(distance / 1000).toStringAsFixed(2)} ' +
                        'sharedKm'.tr;
                  }

                  String formatSpeed(num? speed) {
                    if (speed == null) return 'sharedNoData'.tr;
                    return '${speed.toStringAsFixed(2)} ' + 'sharedKn'.tr;
                  }

                  String formatCourse(num? course) {
                    if (course == null) return 'sharedNoData'.tr;
                    return '↑';
                  }

                  String formatHours(num? hours) {
                    if (hours == null) return 'sharedNoData'.tr;
                    return (hours / 3600000).toStringAsFixed(2);
                  }

                  String formatBoolValue(bool? value) {
                    if (value == null) return 'sharedNoData'.tr;
                    return value ? 'sharedYes'.tr : 'sharedNo'.tr;
                  }

                  // Check if position data is available to display
                  if (position == null) {
                    // FIX: Remove 'const' here
                    return Center(child: Text('sharedNoData'.tr));
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // USE NEW WIDGET HERE for copyable phone number
                        _buildCopyableDetailRow(
                            context,
                            'sharedPhone'.tr,
                            device.phone ?? 'sharedNoData'.tr),
                        const Divider(height: 25), // Separator

                        // Latest Position Details
                        Text(
                          'reportPositions'.tr,
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        _buildDetailRow('deviceIdentifier'.tr,
                            position.id?.toString() ?? 'sharedNoData'.tr),
                        _buildDetailRow('Device ID',
                            position.deviceId?.toString() ?? 'sharedNoData'.tr),
                        _buildDetailRow('positionProtocol'.tr,
                            position.protocol ?? 'sharedNoData'.tr),
                        _buildDetailRow('positionServerTime'.tr,
                            formatDate(position.serverTime)),
                        _buildDetailRow('positionDeviceTime'.tr,
                            formatDate(position.deviceTime)),
                        _buildDetailRow(
                            'positionFixTime'.tr, formatDate(position.fixTime)),
                        _buildDetailRow(
                            'positionValid'.tr, formatBoolValue(position.valid)),
                        _buildDetailRow(
                            'positionLatitude'.tr,
                            position.latitude != null
                                ? '${position.latitude!.toStringAsFixed(6)}°'
                                : 'sharedNoData'.tr),
                        _buildDetailRow(
                            'positionLongitude'.tr,
                            position.longitude != null
                                ? '${position.longitude!.toStringAsFixed(6)}°'
                                : 'sharedNoData'.tr),
                        _buildDetailRow(
                            'positionAltitude'.tr,
                            position.altitude != null
                                ? '${position.altitude!.toStringAsFixed(2)} ' +
                                    'sharedMeters'.tr
                                : 'sharedNoData'.tr),
                        _buildDetailRow(
                            'positionSpeed'.tr, formatSpeed(position.speed)),
                        _buildDetailRow(
                            'positionCourse'.tr, formatCourse(position.course)),
                        _buildDetailRow('positionAddress'.tr,
                            position.address ?? 'sharedNoData'.tr),
                        _buildDetailRow('positionAccuracy'.tr,
                            position.accuracy?.toString() ?? 'sharedNoData'.tr),
                        _buildDetailRow('Network'.tr,
                            position.network?.toString() ?? 'sharedNoData'.tr),
                        _buildDetailRow('sharedGeofences'.tr,
                            position.geofenceIds?.toString() ?? 'sharedNoData'.tr),
                        const SizedBox(height: 20),
                        Text(
                          'sharedAttributes'.tr,
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        _buildDetailRow('sharedType'.tr,
                            attributes?['type']?.toString() ?? 'sharedNoData'.tr),
                        _buildDetailRow(
                            'deviceStatus'.tr,
                            attributes?['status']?.toString() ??
                                'sharedNoData'.tr),
                        _buildDetailRow('positionIgnition'.tr,
                            formatBoolValue(attributes?['ignition'])),
                        _buildDetailRow('positionCharge'.tr,
                            formatBoolValue(attributes?['charge'])),
                        _buildDetailRow('positionBlocked'.tr,
                            formatBoolValue(attributes?['blocked'])),
                        _buildDetailRow(
                            'positionBatteryLevel'.tr,
                            attributes?['batteryLevel'] != null
                                ? '${attributes!['batteryLevel']}%'
                                : 'sharedNoData'.tr),
                        _buildDetailRow(
                            'positionRssi'.tr,
                            attributes?['rssi']?.toString() ??
                                'sharedNoData'.tr),
                        _buildDetailRow('positionDistance'.tr,
                            formatDistance(attributes?['distance'])),
                        _buildDetailRow('deviceTotalDistance'.tr,
                            formatDistance(attributes?['totalDistance'])),
                        _buildDetailRow(
                            'reportEngineHours'.tr, formatHours(attributes?['hours'])),
                        _buildDetailRow('positionMotion'.tr,
                            formatBoolValue(attributes?['motion'])),
                      ],
                    ),
                  );
                }
                // FIX: Remove 'const' here
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
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}