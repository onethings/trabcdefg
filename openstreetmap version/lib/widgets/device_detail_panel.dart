import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trabcdefg/screens/monthly_mileage_screen.dart';
import 'package:trabcdefg/screens/command_screen.dart';
import 'package:trabcdefg/screens/settings/add_device_screen.dart';
import 'package:trabcdefg/screens/device_details_screen.dart';
import 'dart:ui';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  height: 4,
                  width: 36,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Header (Name, Info, Status Tags)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name ?? 'Unknown Device'.tr,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.5,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildHeaderActionIcons(context),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Status Row (Speed, Battery, Ignition)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatusItem(
                          context,
                          Icons.speed_rounded,
                          '${position.speed?.toStringAsFixed(0) ?? 0} ${'sharedKmh'.tr}',
                          'positionSpeed'.tr,
                        ),
                        _buildStatusDivider(context),
                        _buildBatteryItem(context),
                        _buildStatusDivider(context),
                        _buildIgnitionItem(context),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Address Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Action Buttons
                _buildAppleActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 24,
      width: 0.5,
      color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
    );
  }

  Widget _buildStatusItem(BuildContext context, IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildBatteryItem(BuildContext context) {
    final battery = _getAttribute(position, 'batteryLevel') as num?;
    final val = battery?.toDouble() ?? 0.0;
    return _buildStatusItem(
      context,
      Icons.battery_charging_full_rounded,
      battery != null ? '$battery%' : '--',
      'positionBattery'.tr,
    );
  }

  Widget _buildIgnitionItem(BuildContext context) {
    final isOn = _getAttribute(position, 'ignition') == true;
    return _buildStatusItem(
      context,
      Icons.power_settings_new_rounded,
      isOn ? 'sharedOn'.tr : 'sharedOff'.tr,
      'positionIgnition'.tr,
    );
  }

  Widget _buildHeaderActionIcons(BuildContext context) {
    return Row(
      children: [
        _buildCircleIcon(
          context,
          Icons.info_outline_rounded,
          () => _navigateToDetails(context),
        ),
        const SizedBox(width: 8),
        _buildCircleIcon(
          context,
          Icons.refresh_rounded,
          onRefresh,
        ),
        const SizedBox(width: 8),
        Consumer<TraccarProvider>(
          builder: (context, provider, child) {
            final isFavorite = provider.isFavorite(device.id!);
            return _buildCircleIcon(
              context,
              isFavorite ? Icons.favorite : Icons.favorite_border,
              () => provider.toggleFavorite(device.id!),
              color: isFavorite ? Colors.red : null,
            );
          },
        ),
      ],
    );
  }

  Widget _buildCircleIcon(BuildContext context, IconData icon, VoidCallback onTap, {Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color ?? Theme.of(context).colorScheme.onSurface),
      ),
    );
  }

  void _navigateToDetails(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedDeviceId', device.id!);
    await prefs.setString('selectedDeviceName', device.name!);
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DeviceDetailsScreen()),
      );
    }
  }

  Widget _buildAppleActionButtons(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionItem(context, Icons.more_horiz_rounded, onMoreOptionsPressed),
          _buildActionItem(context, Icons.route_rounded, () => _navigateToMileage(context)),
          _buildActionItem(context, Icons.send_rounded, () => _navigateToCommand(context)),
          _buildActionItem(context, Icons.edit_outlined, () => _navigateToEdit(context)),
          _buildActionItem(context, Icons.delete_outline_rounded, onDeletePressed, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, IconData icon, VoidCallback onTap, {Color? color}) {
    return IconButton(
      icon: Icon(icon, size: 22, color: color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
      onPressed: onTap,
    );
  }

  void _navigateToMileage(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedDeviceId', device.id!);
    await prefs.setString('selectedDeviceName', device.name!);
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => MonthlyMileageScreen()));
    }
  }

  void _navigateToCommand(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const CommandScreen()));
  }

  void _navigateToEdit(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddDeviceScreen(device: device)),
    );
    if (result != null) onRefresh();
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
    return const SizedBox.shrink(); // Integrated into status row
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return const SizedBox.shrink();
  }

  Widget _buildActionButtons(BuildContext context) {
    return const SizedBox.shrink();
  }
}
