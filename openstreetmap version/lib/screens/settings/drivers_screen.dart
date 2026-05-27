// drivers_screen.dart
// A screen to display and manage drivers in the TracDefg app.
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/screens/settings/add_driver_screen.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState(); // <-- FIXED HERE
}

class _DriversScreenState extends State<DriversScreen> {
  late Future<List<api.Driver>?> _driversFuture;

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
  }

  void _fetchDrivers() {
    final traccarProvider = Provider.of<TraccarProvider>(
      context,
      listen: false,
    );
    // Correct way to instantiate DriversApi with the authenticated client
    final driversApi = api.DriversApi(traccarProvider.apiClient);
    setState(() {
      _driversFuture = driversApi.driversGet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('sharedDrivers'.tr)),
      body: FutureBuilder<List<api.Driver>?>(
        future: _driversFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('${'errorGeneral'.tr}: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('sharedNoData'.tr));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final driver = snapshot.data![index];
                return ListTile(
                  title: Text(driver.name ?? 'sharedNoData'.tr),
                  subtitle: Text(driver.uniqueId ?? 'sharedNoData'.tr),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          final updatedDriver = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AddDriverScreen(driver: driver),
                            ),
                          );

                          if (updatedDriver != null && mounted) {
                            _fetchDrivers();
                          }
                        },
                      ), // Added missing comma divider here
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          // FIX: Capture dependencies from BuildContext BEFORE the async gaps
                          final traccarProvider = Provider.of<TraccarProvider>(
                            context,
                            listen: false,
                          );

                          final bool? confirm = await Get.dialog<bool>(
                            AlertDialog(
                              title: const Text('Delete Driver?'),
                              content: Text(
                                'Are you sure you want to delete ${driver.name}?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Get.back(result: false),
                                  child: Text('sharedCancel'.tr),
                                ),
                                TextButton(
                                  onPressed: () => Get.back(result: true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && driver.id != null) {
                            try {
                              // Uses the safely predefined variable instead of 'context' across the gap
                              final driversApi = api.DriversApi(
                                traccarProvider.apiClient,
                              );
                              await driversApi.driversIdDelete(driver.id!);

                              // FIX: Ensure the widget is still in the tree before setting state/refreshing
                              if (!mounted) return;
                              _fetchDrivers();

                              Get.snackbar(
                                'Success',
                                'Driver deleted successfully',
                              );
                            } catch (e) {
                              Get.snackbar(
                                'Error',
                                'Failed to delete driver: $e',
                              );
                            }
                          }
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
          final newDriver = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDriverScreen()),
          );
          if (newDriver != null) {
            _fetchDrivers();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
