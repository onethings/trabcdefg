// devices_screen.dart
// A screen to display and manage devices in the TracDefg app.
import 'package:flutter/material.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/screens/settings/add_device_screen.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import 'package:trabcdefg/screens/settings/connections_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  _DevicesScreenState createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  late Future<List<api.Device>?> _devicesFuture;
  final TextEditingController _searchController = TextEditingController();
  List<api.Device> _allDevices = [];
  List<api.Device> _filteredDevices = [];

  @override
  void initState() {
    super.initState();
    _fetchDevices();
  }

  void _fetchDevices() {
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    // Correct way to instantiate GeofencesApi with the authenticated client
    final devicesApi = api.DevicesApi(traccarProvider.apiClient);
    setState(() {
      _devicesFuture = devicesApi.devicesGet().then((devices) {
        _allDevices = devices ?? [];
        _filteredDevices = _allDevices;
        return _filteredDevices;
      });
    });
  }

  void _filterDevices(String query) {
    setState(() {
      _filteredDevices = _allDevices
          .where(
            (device) =>
                device.name!.toLowerCase().contains(query.toLowerCase()) ||
                device.uniqueId!.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    });
  }

  void _deleteDevice(int deviceId) async {
    try {
      final traccarProvider = Provider.of<TraccarProvider>(
        context,
        listen: false,
      );
      final apiClient = traccarProvider.apiClient;

      // Manually construct the DELETE request
      final path = '/devices/$deviceId';
      final response = await apiClient.invokeAPI(
        path,
        'DELETE',
        [], // queryParams - empty
        {}, // postBody - send an empty body as an object
        <String, String>{}, // headerParams - empty
        <String, String>{}, // formParams - empty
        'application/json', // contentType - send this to match the body
      );

      if (response.statusCode == 204) {
        // 204 No Content is the correct response for a successful DELETE
        _fetchDevices();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('deviceDeleteSuccess'.tr)));
      } else {
        // Any other status code indicates a failure
        print('Server responded with status code: ${response.statusCode}');
        print('Server response body: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'deviceDeleteFailed'.trParams({
                'error':
                    'Server responded with status code: ${response.statusCode}',
              }),
            ),
          ),
        );
      }
    } catch (e) {
      print('Caught an exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('deviceDeleteFailed'.trParams({'error': e.toString()})),
        ),
      );
    }
  }

  void _editDevice(api.Device device) async {
    final updatedDevice = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDeviceScreen(device: device),
      ),
    );

    if (updatedDevice != null) {
      try {
        final traccarProvider = Provider.of<TraccarProvider>(
          context,
          listen: false,
        );
        final devicesApi = api.DevicesApi(traccarProvider.apiClient);
        await devicesApi.devicesIdPut(updatedDevice.id!, updatedDevice);
        _fetchDevices();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('deviceUpdateSuccess'.tr)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('deviceUpdateFailed'.trParams({'error': e.toString()}))),
        );
      }
    }
  }

  void _exportDevicesToCsv() async {
    if (_allDevices.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('sharedNoData'.tr)));
      return;
    }

    List<List<dynamic>> rows = [];
    rows.add(['ID', 'sharedName'.tr, 'deviceIdentifier'.tr]);

    for (var device in _allDevices) {
      rows.add([device.id, device.name, device.uniqueId]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/devices.csv';
    final file = File(path);
    await file.writeAsString(csv);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('sharedSaved'.trParams({'path': path}))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('deviceTitle'.tr),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'sharedSearch'.tr,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: _filterDevices,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportDevicesToCsv,
          ),
        ],
      ),
      body: FutureBuilder<List<api.Device>?>(
        future: _devicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'errorGeneral'.trParams({'error': snapshot.error.toString()}),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('sharedNoData'.tr));
          } else {
            return ListView.builder(
              itemCount: _filteredDevices.length,
              itemBuilder: (context, index) {
                final device = _filteredDevices[index];
                return ListTile(
                  title: Text(device.name ?? 'unnamedDevice'.tr),
                  subtitle: Text(device.uniqueId ?? 'noUniqueId'.tr),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editDevice(device),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteDevice(device.id!),
                      ),
                      IconButton(
                        icon: const Icon(Icons.link),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConnectionsScreen(deviceId: device.id!),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newDevice = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDeviceScreen()),
          );
          if (newDevice != null) {
            _fetchDevices();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
