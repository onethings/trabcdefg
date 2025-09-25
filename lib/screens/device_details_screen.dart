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
                    if (date == null) return 'N/A';
                    return DateFormat('MM/dd/yyyy, hh:mm:ss a').format(date.toLocal());
                  }

                  String formatDistance(num? distance) {
                    if (distance == null) return 'N/A';
                    return '${(distance / 1000).toStringAsFixed(2)} km';
                  }

                  String formatSpeed(num? speed) {
                    if (speed == null) return 'N/A';
                    return '${speed.toStringAsFixed(2)} kn';
                  }

                  String formatCourse(num? course) {
                    if (course == null) return 'N/A';
                    return '↑';
                  }

                  String formatHours(num? hours) {
                    if (hours == null) return 'N/A';
                    return (hours / 3600000).toStringAsFixed(2);
                  }

                  String formatBoolValue(bool? value) {
                    if (value == null) return 'N/A';
                    return value ? 'sharedYes'.tr : 'sharedNo'.tr;
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Identifier', position.id?.toString() ?? 'N/A'),
                        _buildDetailRow('Device ID', position.deviceId?.toString() ?? 'N/A'),
                        _buildDetailRow('Protocol', position.protocol ?? 'N/A'),
                        _buildDetailRow('Server Time', formatDate(position.serverTime)),
                        _buildDetailRow('Device Time', formatDate(position.deviceTime)),
                        _buildDetailRow('Fix Time', formatDate(position.fixTime)),
                        _buildDetailRow('Valid', formatBoolValue(position.valid)),
                        _buildDetailRow(
                            'Latitude', position.latitude != null ? '${position.latitude!.toStringAsFixed(6)}°' : 'N/A'),
                        _buildDetailRow(
                            'Longitude', position.longitude != null ? '${position.longitude!.toStringAsFixed(6)}°' : 'N/A'),
                        _buildDetailRow(
                            'Altitude', position.altitude != null ? '${position.altitude!.toStringAsFixed(2)} m' : 'N/A'),
                        _buildDetailRow('Speed', formatSpeed(position.speed)),
                        _buildDetailRow('Course', formatCourse(position.course)),
                        _buildDetailRow('Address', position.address ?? 'N/A'),
                        _buildDetailRow('Accuracy', position.accuracy?.toString() ?? 'N/A'),
                        _buildDetailRow('Network', position.network?.toString() ?? 'N/A'),
                        _buildDetailRow('Geofences', position.geofenceIds?.toString() ?? 'N/A'),
                        const SizedBox(height: 20),
                        const Text(
                          'Attributes',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        _buildDetailRow('Type', attributes?['type']?.toString() ?? 'N/A'),
                        _buildDetailRow('Status', attributes?['status']?.toString() ?? 'N/A'),
                        _buildDetailRow('Ignition', formatBoolValue(attributes?['ignition'])),
                        _buildDetailRow('Charge', formatBoolValue(attributes?['charge'])),
                        _buildDetailRow('Blocked', formatBoolValue(attributes?['blocked'])),
                        _buildDetailRow('Battery Level',
                            attributes?['batteryLevel'] != null ? '${attributes!['batteryLevel']}%' : 'N/A'),
                        _buildDetailRow('RSSI', attributes?['rssi']?.toString() ?? 'N/A'),
                        _buildDetailRow('Distance (Trip)', formatDistance(attributes?['distance'])),
                        _buildDetailRow('Total Distance', formatDistance(attributes?['totalDistance'])),
                        _buildDetailRow('Hours', formatHours(attributes?['hours'])),
                        _buildDetailRow('Motion', formatBoolValue(attributes?['motion'])),
                      ],
                    ),
                  );
                } else {
                  return const Center(child: Text('No data available.'));
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