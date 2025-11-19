// lib/screens/device_list_screen.dart
// DeviceListScreen with Search, Status Filtering, and Enhanced Device Info

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart';
import 'package:trabcdefg/screens/livetracking_map_screen.dart'; // Import the new screen name
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedStatus = 0; // 0: All, 1: Online, 2: Offline, 3: Unknown

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('deviceTitle'.tr),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'sharedSearchDevices'.tr,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(25.0)),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatusTab('deviceStatusAll'.tr, 0),
                  _buildStatusTab('deviceStatusOnline'.tr, 1),
                  _buildStatusTab('deviceStatusOffline'.tr, 2),
                  _buildStatusTab('deviceStatusUnknown'.tr, 3),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Consumer<TraccarProvider>(
        builder: (context, traccarProvider, child) {
          final allDevices = traccarProvider.devices;
          final filteredDevices = allDevices.where((device) {
            final matchesQuery = (device.name ?? 'unknown')
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
            final matchesStatus =
                _selectedStatus == 0 ||
                _getStatusText(_selectedStatus) == (device.status ?? 'unknown');
            return matchesQuery && matchesStatus;
          }).toList();

          if (traccarProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (filteredDevices.isEmpty) {
            return Center(child: Text('sharedNoData'.tr));
          }

          return ListView.builder(
            itemCount: filteredDevices.length,
            itemBuilder: (context, index) {
              final device = filteredDevices[index];
              return ListTile(
                onTap: () {
                  // Navigate to the LiveTrackingMapScreen
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          LiveTrackingMapScreen(selectedDevice: device),
                    ),
                  );
                },
                leading: Consumer<TraccarProvider>(
                  builder: (context, traccarProvider, child) {
                    final position = traccarProvider.positions.firstWhereOrNull(
                      (p) => p.id == device.positionId,
                    );

                    // Check if a valid position and speed exist
                    if (position != null && position.speed != null) {
                      // Convert speed from knots to km/h for display
                      final speedKmh = (position.speed! * 1.852)
                          .toStringAsFixed(0);

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            backgroundColor: _getStatusColor(device.status),
                            radius: 20, // Adjust size as needed
                          ),
                          Text(
                            speedKmh,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Fallback to a simple CircleAvatar if no speed is available
                      return CircleAvatar(
                        backgroundColor: _getStatusColor(device.status),
                      );
                    }
                  },
                ),
                title: Text(device.name ?? 'sharedUnknown'.tr),
                subtitle: Text(
                  '${_getStatusTextForDisplay(device.status)}'
                  '${device.lastUpdate != null ? ' • ${timeago.format(device.lastUpdate!)}' : ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (device.positionId != null)
                      Consumer<TraccarProvider>(
                        builder: (context, traccarProvider, child) {
                          final position = traccarProvider.positions
                              .firstWhereOrNull(
                                (p) => p.id == device.positionId,
                              );

                          if (position?.attributes != null) {
                            final attributes = position!.attributes as Map;

                            return Row(
                              children: [
                                // Ignition Icon
                                if (attributes['ignition'] != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                    ),
                                    child: Icon(
                                      Icons.key,
                                      color: attributes['ignition']
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),

                                // Battery Icon with Percentage
                                if (attributes['batteryLevel'] != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(
                                          Icons.battery_full,
                                          color: _getBatteryColor(
                                            (attributes['batteryLevel'] as int)
                                                .toDouble(), // Cast to double
                                          ),
                                        ),
                                        Text(
                                          '${attributes['batteryLevel']}',
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
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusTab(String label, int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = index;
        });
      },
      child: Chip(
        label: Text(label),
        backgroundColor: _selectedStatus == index
            ? Colors.blue[100]
            : Colors.grey[200],
      ),
    );
  }

  String? _getStatusText(int index) {
    switch (index) {
      case 1:
        return 'online';
      case 2:
        return 'offline';
      case 3:
        return 'unknown';
      default:
        return null;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'online':
        return Colors.green;
      case 'offline':
        return Colors.red;
      case 'unknown':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  String _getStatusTextForDisplay(String? status) {
    switch (status) {
      case 'online':
        return 'deviceStatusOnline'.tr;
      case 'offline':
        return 'deviceStatusOffline'.tr;
      case 'unknown':
        return 'deviceStatusUnknown'.tr;
      default:
        return status ?? 'N/A';
    }
  }

  Color _getBatteryColor(double batteryLevel) {
    if (batteryLevel > 75) {
      return Colors.green;
    } else if (batteryLevel > 25) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
