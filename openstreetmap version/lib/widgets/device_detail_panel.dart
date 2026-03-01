import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/screens/monthly_mileage_screen.dart';
import 'package:trabcdefg/screens/command_screen.dart';
import 'package:trabcdefg/screens/settings/add_device_screen.dart';
import 'package:trabcdefg/screens/device_details_screen.dart';

class DeviceDetailPanel extends StatelessWidget {
  final api.Device device;
  final api.Position position;
  final String address;
  final String formattedDate;
  final VoidCallback onMoreOptionsPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onRefresh;

  const DeviceDetailPanel({
    super.key,
    required this.device,
    required this.position,
    required this.address,
    required this.formattedDate,
    required this.onMoreOptionsPressed,
    required this.onDeletePressed,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(28.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        device.name ?? 'Unknown Device'.tr,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.info, color: Color(0xFF5B697B)),
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setInt('selectedDeviceId', device.id!);
                          await prefs.setString('selectedDeviceName', device.name!);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DeviceDetailsScreen(),
                            ),
                          );
                        },
                      ),
                      if (_getDistance(position) > 0.0)
                        Text(
                          '${_getDistance(position).toStringAsFixed(0)} ${'sharedKm'.tr}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      if (position.speed != null && position.speed != 0.0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            '${position.speed?.toStringAsFixed(0)} km/h',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (_getAttribute(position, 'ignition') != null)
                        Icon(
                          Icons.key,
                          color: _getAttribute(position, 'ignition') == true
                              ? Colors.green
                              : Colors.red,
                        ),
                      if (_getAttribute(position, 'batteryLevel') != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.battery_full,
                                color: _getBatteryColor(
                                    (_getAttribute(position, 'batteryLevel') as num)
                                        .toDouble()),
                              ),
                              Text(
                                '${_getAttribute(position, 'batteryLevel')}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.red[400]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address == "Myanmar Road"
                          ? "Myanmar (Street name unlisted)"
                          : address,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blueGrey[800],
                        fontStyle: address == "Myanmar Road"
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            _buildDetailsSection(context),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  double _getDistance(api.Position pos) {
    return (_getAttribute(pos, 'distance') as num?)?.toDouble() ?? 0.0;
  }

  dynamic _getAttribute(api.Position pos, String key) {
    return (pos.attributes as Map<String, dynamic>?)?[key];
  }

  Color _getBatteryColor(double batteryLevel) {
    if (batteryLevel > 75) return Colors.green;
    if (batteryLevel > 25) return Colors.orange;
    return Colors.red;
  }

  Widget _buildDetailsSection(BuildContext context) {
    String totalDist = _getAttribute(position, 'totalDistance') != null
        ? '${(_getAttribute(position, 'totalDistance') / 1000).toStringAsFixed(0)} ${'sharedKm'.tr}'
        : 'N/A';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('deviceLastUpdate'.tr, formattedDate),
          const SizedBox(height: 4),
          _buildInfoRow('deviceTotalDistance'.tr, totalDist),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        const SizedBox(width: 8),
        Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(value),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          icon: const Icon(Icons.more_horiz, color: Color(0xFF5B697B)),
          onPressed: onMoreOptionsPressed,
        ),
        IconButton(
          icon: const Icon(Icons.route, color: Color(0xFF5B697B)),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('selectedDeviceId', device.id!);
            await prefs.setString('selectedDeviceName', device.name!);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MonthlyMileageScreen()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF246BFD)),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CommandScreen()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, color: Color(0xFF5B697B)),
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddDeviceScreen(device: device)),
            );
            if (result != null) onRefresh();
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onDeletePressed,
        ),
      ],
    );
  }
}
