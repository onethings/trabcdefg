// maintenance_screen.dart

import 'package:flutter/material.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/screens/settings/add_maintenance_screen.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  _MaintenanceScreenState createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  late Future<List<api.Maintenance>?> _maintenanceFuture;

  @override
  void initState() {
    super.initState();
    _fetchMaintenance();
  }

  void _fetchMaintenance() {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    // Correct way to instantiate MaintenanceApi with the authenticated client
    final maintenanceApi = api.MaintenanceApi(traccarProvider.apiClient);
    setState(() {
      _maintenanceFuture = maintenanceApi.maintenanceGet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('sharedMaintenance'.tr),
      ),
      body: FutureBuilder<List<api.Maintenance>?>(
        future: _maintenanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('errorGeneral'.tr + ': ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('sharedNoData'.tr));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final maintenance = snapshot.data![index];
                return ListTile(
                  title: Text(maintenance.name ?? 'sharedName'.tr),
                  subtitle: Text(
                      '${'sharedType'.tr}: ${maintenance.type ?? 'N/A'} | ${'maintenanceStart'.tr}: ${maintenance.start ?? 'N/A'} | ${'maintenancePeriod'.tr}: ${maintenance.period ?? 'N/A'}'),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newMaintenance = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddMaintenanceScreen(),
            ),
          );
          if (newMaintenance != null) {
            _fetchMaintenance();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}