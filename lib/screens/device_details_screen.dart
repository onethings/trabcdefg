import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:get/get.dart';

class DeviceDetailsScreen extends StatelessWidget {
  const DeviceDetailsScreen({super.key});

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

          final traccarProvider =
              Provider.of<TraccarProvider>(context, listen: false);
          final positionsApi = api.PositionsApi(traccarProvider.apiClient);

          return Scaffold(
            appBar: AppBar(
              title: Text(deviceName),
            ),
            body: FutureBuilder<List<api.Position>?>(
              future: positionsApi.positionsGet(deviceId: deviceId),
              builder: (context, positionsSnapshot) {
                if (positionsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (positionsSnapshot.hasError) {
                  return Center(child: Text('Error: ${positionsSnapshot.error}'));
                } else if (positionsSnapshot.hasData &&
                    positionsSnapshot.data != null &&
                    positionsSnapshot.data!.isNotEmpty) {
                  final position = positionsSnapshot.data!.first;
                  final attributes = position.attributes as Map<String, dynamic>?;

                  String formatDate(DateTime? date) {
                    if (date == null) return 'sharedNoData'.tr;
                    return DateFormat('MM/dd/yyyy, hh:mm:ss a').format(date.toLocal());
                  }

                  String formatDistance(num? distance) {
                    if (distance == null) return 'sharedNoData'.tr;
                    return '${(distance / 1000).toStringAsFixed(2)} km';
                  }

                  String formatSpeed(num? speed) {
                    if (speed == null) return 'sharedNoData'.tr;
                    return '${speed.toStringAsFixed(2)} kn';
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

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('deviceIdentifier'.tr, position.id?.toString() ?? 'sharedNoData'.tr),
                        _buildDetailRow('Device ID', position.deviceId?.toString() ?? 'sharedNoData'.tr),
                        _buildDetailRow('positionProtocol'.tr, position.protocol ?? 'sharedNoData'.tr),
                        _buildDetailRow('positionServerTime'.tr, formatDate(position.serverTime)),
                        _buildDetailRow('positionDeviceTime'.tr, formatDate(position.deviceTime)),
                        _buildDetailRow('positionFixTime'.tr, formatDate(position.fixTime)),
                        _buildDetailRow('positionValid'.tr, formatBoolValue(position.valid)),
                        _buildDetailRow(
                            'positionLatitude'.tr, position.latitude != null ? '${position.latitude!.toStringAsFixed(6)}°' : 'sharedNoData'.tr),
                        _buildDetailRow(
                            'positionLongitude'.tr, position.longitude != null ? '${position.longitude!.toStringAsFixed(6)}°' : 'sharedNoData'.tr),
                        _buildDetailRow(
                            'positionAltitude'.tr, position.altitude != null ? '${position.altitude!.toStringAsFixed(2)} m' : 'sharedNoData'.tr),
                        _buildDetailRow('positionSpeed'.tr, formatSpeed(position.speed)),
                        _buildDetailRow('positionCourse'.tr, formatCourse(position.course)),
                        _buildDetailRow('positionAddress'.tr, position.address ?? 'sharedNoData'.tr),
                        _buildDetailRow('positionAccuracy'.tr, position.accuracy?.toString() ?? 'sharedNoData'.tr),
                        _buildDetailRow('Network'.tr, position.network?.toString() ?? 'sharedNoData'.tr),
                        _buildDetailRow('sharedGeofences'.tr, position.geofenceIds?.toString() ?? 'sharedNoData'.tr),
                        const SizedBox(height: 20),
                        Text(
                          'sharedAttributes'.tr,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        _buildDetailRow('sharedType'.tr, attributes?['type']?.toString() ?? 'sharedNoData'.tr),
                        _buildDetailRow('deviceStatus'.tr, attributes?['status']?.toString() ?? 'sharedNoData'.tr),
                        _buildDetailRow('positionIgnition'.tr, formatBoolValue(attributes?['ignition'])),
                        _buildDetailRow('positionCharge'.tr, formatBoolValue(attributes?['charge'])),
                        _buildDetailRow('positionBlocked'.tr, formatBoolValue(attributes?['blocked'])),
                        _buildDetailRow('positionBatteryLevel'.tr,
                            attributes?['batteryLevel'] != null ? '${attributes!['batteryLevel']}%' : 'sharedNoData'.tr),
                        _buildDetailRow('positionRssi'.tr, attributes?['rssi']?.toString() ?? 'sharedNoData'.tr),
                        _buildDetailRow('positionDistance'.tr, formatDistance(attributes?['distance'])),
                        _buildDetailRow('deviceTotalDistance'.tr, formatDistance(attributes?['totalDistance'])),
                        _buildDetailRow('reportEngineHours'.tr, formatHours(attributes?['hours'])),
                        _buildDetailRow('positionMotion'.tr, formatBoolValue(attributes?['motion'])),
                      ],
                    ),
                  );
                } else {
                  return Center(child: Text('sharedNoData'.tr));
                }
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