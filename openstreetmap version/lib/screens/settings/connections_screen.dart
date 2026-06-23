// connections_screen.dart
// A screen to manage connections between devices and other entities in the TracDefg app.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class ConnectionsScreen extends StatefulWidget {
  final int deviceId;

  const ConnectionsScreen({super.key, required this.deviceId});

  @override
  ConnectionsScreenState createState() => ConnectionsScreenState();
}

class ConnectionsScreenState extends State<ConnectionsScreen> {
  final Map<String, List<int>> _selectedItems = {
    'geofences': [],
    'notifications': [],
    'drivers': [],
    'computedAttributes': [],
    'savedCommands': [],
    'maintenance': [],
  };

  final Map<String, Future<List<dynamic>?>> _itemFutures = {};

  @override
  void initState() {
    super.initState();
    _fetchLinkedItems();
  }

  void _fetchLinkedItems() async {
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final geofencesApi = api.GeofencesApi(traccarProvider.apiClient);
    final notificationsApi = api.NotificationsApi(traccarProvider.apiClient);
    final driversApi = api.DriversApi(traccarProvider.apiClient);
    final computedAttributesApi = api.AttributesApi(traccarProvider.apiClient);
    final commandsApi = api.CommandsApi(traccarProvider.apiClient);
    final maintenanceApi = api.MaintenanceApi(traccarProvider.apiClient);

    try {
      final linkedGeofences = await geofencesApi.getGeofences(
        deviceId: widget.deviceId,
      );
      debugPrint('Linked Geofences: ${linkedGeofences?.map((g) => g.id)}');
      _selectedItems['geofences'] =
          linkedGeofences?.map((g) => g.id!).toList() ?? [];

      final linkedNotifications = await notificationsApi.getNotifications(
        deviceId: widget.deviceId,
      );
      debugPrint(
        'Linked Notifications: ${linkedNotifications?.map((n) => n.id)}',
      );
      _selectedItems['notifications'] =
          linkedNotifications?.map((n) => n.id!).toList() ?? [];

      final linkedDrivers = await driversApi.getDrivers(
        deviceId: widget.deviceId,
      );
      debugPrint('Linked Drivers: ${linkedDrivers?.map((d) => d.id)}');
      _selectedItems['drivers'] =
          linkedDrivers?.map((d) => d.id!).toList() ?? [];

      final linkedComputedAttributes = await computedAttributesApi
          .getAttributesComputed(deviceId: widget.deviceId);
      debugPrint(
        'Linked Computed Attributes: ${linkedComputedAttributes?.map((ca) => ca.id)}',
      );
      _selectedItems['computedAttributes'] =
          linkedComputedAttributes?.map((ca) => ca.id!).toList() ?? [];

      final linkedCommands = await commandsApi.getCommands(
        deviceId: widget.deviceId,
      );
      debugPrint('Linked Commands: ${linkedCommands?.map((c) => c.id)}');
      _selectedItems['savedCommands'] =
          linkedCommands?.map((c) => c.id!).toList() ?? [];

      final linkedMaintenance = await maintenanceApi.getMaintenance(
        deviceId: widget.deviceId,
      );
      debugPrint('Linked Maintenance: ${linkedMaintenance?.map((m) => m.id)}');
      _selectedItems['maintenance'] =
          linkedMaintenance?.map((m) => m.id!).toList() ?? [];

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint("Error fetching linked items: $e");
    }
  }

  Future<List<api.Geofence>?> _fetchGeofences() async {
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final geofencesApi = api.GeofencesApi(traccarProvider.apiClient);
    return await geofencesApi.getGeofences();
  }

  Future<List<api.Notification>?> _fetchNotifications() async {
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final notificationsApi = api.NotificationsApi(traccarProvider.apiClient);
    return await notificationsApi.getNotifications();
  }

  Future<List<api.Driver>?> _fetchDrivers() async {
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final driversApi = api.DriversApi(traccarProvider.apiClient);
    return await driversApi.getDrivers();
  }

  Future<List<api.Attribute>?> _fetchComputedAttributes() async {
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final computedAttributesApi = api.AttributesApi(traccarProvider.apiClient);
    return await computedAttributesApi.getAttributesComputed();
  }

  Future<List<api.Command>?> _fetchSavedCommands() async {
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final commandsApi = api.CommandsApi(traccarProvider.apiClient);
    return await commandsApi.getCommands();
  }

  Future<List<api.Maintenance>?> _fetchMaintenance() async {
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final maintenanceApi = api.MaintenanceApi(traccarProvider.apiClient);
    return await maintenanceApi.getMaintenance();
  }

  void _updatePermission(String category, int itemId, bool isSelected) async {
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    final apiClient = traccarProvider.apiClient;
    final sessionId = traccarProvider.sessionId;

    if (sessionId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication session not found')),
      );
      return;
    }

    final payload = {
      'deviceId': widget.deviceId,
      '${category.substring(0, category.length - 1)}Id': itemId,
    };

    try {
      if (isSelected) {
        final response = await apiClient.invokeAPI(
          '/permissions',
          'POST',
          [],
          jsonEncode(payload),
          <String, String>{},
          <String, String>{},
          'application/json',
        );

        if (!mounted) return;
        if (response.statusCode == 204 || response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission added successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add permission: ${response.statusCode}'),
            ),
          );
        }
      } else {
        final uri = Uri.parse('https://demo3.traccar.org/api/permissions');
        final response = await http.delete(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Cookie': 'JSESSIONID=$sessionId',
          },
          body: jsonEncode(payload),
        );

        if (!mounted) return;
        if (response.statusCode == 204 || response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission deleted successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to delete permission: ${response.statusCode}',
              ),
            ),
          );
        }
      }

      _fetchLinkedItems();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update permission: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Connections'.tr)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildExpansionTile('Geofences', 'geofences', _fetchGeofences),
            _buildExpansionTile(
              'Notifications',
              'notifications',
              _fetchNotifications,
            ),
            _buildExpansionTile('Drivers', 'drivers', _fetchDrivers),
            _buildExpansionTile(
              'Computed Attributes',
              'computedAttributes',
              _fetchComputedAttributes,
            ),
            _buildExpansionTile(
              'Saved Commands',
              'savedCommands',
              _fetchSavedCommands,
            ),
            _buildExpansionTile(
              'Maintenance',
              'maintenance',
              _fetchMaintenance,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpansionTile(
    String title,
    String category,
    Function fetchFunction,
  ) {
    return ExpansionTile(
      title: Text(title),
      children: [
        FutureBuilder<List<dynamic>?>(
          future: _itemFutures[category],
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No items found.'));
            } else {
              return Column(
                children: snapshot.data!.map((item) {
                  final itemId = item.id as int;
                  final itemName = item.name as String? ?? 'Unnamed';
                  final isSelected =
                      _selectedItems[category]?.contains(itemId) ?? false;

                  return CheckboxListTile(
                    title: Text(itemName),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value!) {
                          _selectedItems[category]!.add(itemId);
                        } else {
                          _selectedItems[category]!.remove(itemId);
                        }
                      });
                      _updatePermission(category, itemId, value!);
                    },
                  );
                }).toList(),
              );
            }
          },
        ),
      ],
      onExpansionChanged: (isExpanded) {
        if (isExpanded && !_itemFutures.containsKey(category)) {
          setState(() {
            _itemFutures[category] = fetchFunction();
          });
        }
      },
    );
  }
}
