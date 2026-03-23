import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import '../notifications_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TraccarProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final onlineCount = provider.devices.where((d) => d.status == 'online').length;
    final movingCount = provider.positions.where((p) => (p.speed ?? 0.0) > 1.0).length;
    final offlineCount = provider.devices.where((d) => d.status == 'offline').length;
    final totalCount = provider.devices.length;

    // Calculate total distance for today (ideally from reports, but using current totalDistance for display)
    double totalDistanceMeters = 0;
    for (var pos in provider.positions) {
      final attr = pos.attributes as Map<String, dynamic>?;
      totalDistanceMeters += (attr?['totalDistance'] ?? 0.0);
    }
    double totalKm = totalDistanceMeters / 1000;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
        title: Text(
          'dashboardTitle'.tr,
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => Get.to(() => const NotificationsScreen()),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBackground(theme),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => provider.fetchInitialData(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGreeting(provider, theme),
                    const SizedBox(height: 24),
                    _buildStatusSection(context, onlineCount, movingCount, offlineCount, totalCount),
                    const SizedBox(height: 24),
                    _buildSummaryCard(
                      context,
                      'dashboardTotalDistance'.tr,
                      '${totalKm.toStringAsFixed(1)} km',
                      Icons.auto_graph_rounded,
                      theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'dashboardRecentActivity'.tr,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildRecentEventsList(context, provider.events),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(ThemeData theme) {
    return Container(
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
    );
  }

  Widget _buildGreeting(TraccarProvider provider, ThemeData theme) {
    final name = provider.currentUser?.name ?? 'Admin';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${'dashboardHello'.tr}, $name 👋',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -1),
        ),
        Text(
          'dashboardWelcomeBack'.tr,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildStatusSection(BuildContext context, int online, int moving, int offline, int total) {
    return Row(
      children: [
        Expanded(child: _buildSmallStatusCard(context, 'dashboardOnline'.tr, online.toString(), Colors.green)),
        const SizedBox(width: 12),
        Expanded(child: _buildSmallStatusCard(context, 'dashboardMoving'.tr, moving.toString(), Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildSmallStatusCard(context, 'dashboardOffline'.tr, offline.toString(), Colors.grey)),
      ],
    );
  }

  Widget _buildSmallStatusCard(BuildContext context, String title, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEventsList(BuildContext context, List<api.Event> events) {
    if (events.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Text('dashboardNoEvents'.tr, style: const TextStyle(color: Colors.grey)),
      );
    }

    final latestEvents = events.reversed.take(5).toList();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: latestEvents.length,
      itemBuilder: (context, index) {
        final event = latestEvents[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(_getEventIcon(event.type), size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (event.type ?? 'unknownEvent').tr,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      DateFormat.yMMMd().add_jm().format(event.eventTime?.toLocal() ?? DateTime.now()),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getEventIcon(String? type) {
    switch (type) {
      case 'deviceOnline': return Icons.cloud_done_rounded;
      case 'deviceOffline': return Icons.cloud_off_rounded;
      case 'deviceMoving': return Icons.directions_car_rounded;
      case 'deviceStopped': return Icons.stop_circle_rounded;
      case 'geofenceEnter': return Icons.login_rounded;
      case 'geofenceExit': return Icons.logout_rounded;
      case 'alarm': return Icons.warning_amber_rounded;
      default: return Icons.event_note_rounded;
    }
  }
}
