import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TraccarProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'notificationsTitle'.tr,
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: (isDark ? Colors.black : Colors.white).withOpacity(0.1),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.08),
                  theme.colorScheme.surface,
                  theme.colorScheme.secondary.withOpacity(0.05),
                ],
              ),
            ),
          ),
          SafeArea(
            child: provider.events.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded, 
                            size: 64, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text('dashboardNoEvents'.tr, 
                            style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: provider.events.length,
                    itemBuilder: (context, index) {
                      // Show latest events first
                      final event = provider.events[provider.events.length - 1 - index];
                      return _buildEventItem(context, event);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem(BuildContext context, api.Event event) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getEventIcon(event.type),
              size: 24,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (event.type ?? 'unknownEvent').tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.yMMMd().add_jm().format(
                        event.eventTime?.toLocal() ?? DateTime.now(),
                      ),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getEventIcon(String? type) {
    switch (type) {
      case 'deviceOnline':
        return Icons.cloud_done_rounded;
      case 'deviceOffline':
        return Icons.cloud_off_rounded;
      case 'deviceMoving':
        return Icons.directions_car_rounded;
      case 'deviceStopped':
        return Icons.stop_circle_rounded;
      case 'geofenceEnter':
        return Icons.login_rounded;
      case 'geofenceExit':
        return Icons.logout_rounded;
      case 'alarm':
        return Icons.warning_amber_rounded;
      default:
        return Icons.event_note_rounded;
    }
  }
}
