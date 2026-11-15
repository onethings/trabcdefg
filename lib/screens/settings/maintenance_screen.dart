// maintenance_screen.dart
// A screen to display and manage maintenance schedules in the TracDefg app.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/screens/settings/add_maintenance_screen.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/widgets/state_views.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState(); // FIXED: Changed return type to State<MaintenanceScreen>
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  late Future<List<api.Maintenance>?> _maintenanceFuture;

  @override
  void initState() {
    super.initState();
    _fetchMaintenance();
  }

  Future<void> _fetchMaintenance() {
    final traccarProvider = Provider.of<TraccarProvider>(context, listen: false);
    // Correct way to instantiate MaintenanceApi with the authenticated client
    final maintenanceApi = api.MaintenanceApi(traccarProvider.apiClient);
    setState(() {
      _maintenanceFuture = maintenanceApi.getMaintenance();
    });
    return _maintenanceFuture.then((_) {}).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(middle: Text('sharedMaintenance'.tr)),
      body: FutureBuilder<List<api.Maintenance>?>(
        future: _maintenanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return RefreshIndicator(
              onRefresh: _fetchMaintenance,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 160),
                  ErrorState(message: 'errorUnexpected'.trParams({'error': snapshot.error.toString()}), retryLabel: 'sharedRetry'.tr, onRetry: _fetchMaintenance),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return RefreshIndicator(
              onRefresh: _fetchMaintenance,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 160),
                  EmptyState(icon: CupertinoIcons.wrench, title: 'sharedNoData'.tr, hint: 'sharedRefresh'.tr),
                ],
              ),
            );
          } else {
            return RefreshIndicator(
              onRefresh: _fetchMaintenance,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final maintenance = snapshot.data![index];
                  return ListTile(
                    title: Text(maintenance.name ?? 'sharedName'.tr),
                    subtitle: Text('${'sharedType'.tr}: ${maintenance.type ?? 'N/A'} | ${'maintenanceStart'.tr}: ${maintenance.start ?? 'N/A'} | ${'maintenancePeriod'.tr}: ${maintenance.period ?? 'N/A'}'),
                  );
                },
              ),
            );
          }
        },
      ),
      floatingActionButton: Padding(
        // 用 Padding 上移：Transform 只改變繪製位置，會讓可點擊區域與畫面位置錯開。
        padding: const EdgeInsets.only(bottom: 45),
        child: FloatingActionButton(
          onPressed: () async {
            final newMaintenance = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddMaintenanceScreen()));
            if (newMaintenance != null) {
              _fetchMaintenance();
            }
          },
          child: const Icon(CupertinoIcons.add),
        ),
      ),
    );
  }
}
