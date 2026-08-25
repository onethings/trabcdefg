import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trabcdefg/providers/traccar_provider.dart';
import 'package:trabcdefg/services/notification_settings_service.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

import 'notification_settings_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  int _timerDurationSec = 300;
  Map<int, int> _colorThresholds = {
    5: 0xFFFF1744, // Red
    4: 0xFFFF9100, // Orange
    3: 0xFFFFEA00, // Yellow
    2: 0xFF2979FF, // Blue
    1: 0xFF00E676, // Green
  };
  List<String> _cardFieldsOrder = [];
  List<String> _visibleFields = [];
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // Tick every second to update countdowns
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final duration = await NotificationSettingsService.getTimerDuration();
    final colors = await NotificationSettingsService.getAllColorThresholds();
    final order = await NotificationSettingsService.getCardFieldsOrder();
    final visible = await NotificationSettingsService.getVisibleCardFields();
    if (mounted) {
      setState(() {
        _timerDurationSec = duration;
        _colorThresholds = colors;
        _cardFieldsOrder = order;
        _visibleFields = visible;
      });
    }
  }

  Future<void> _openSettings() async {
    await Get.to(() => const NotificationSettingsScreen());
    // Reload settings after returning
    await _loadSettings();
  }

  /// Returns true if the event type is configured on the server (or no server config = show all).
  bool _isEventVisible(api.Event event, TraccarProvider provider) {
    final serverTypes = provider.getServerEventTypes();
    if (serverTypes.isEmpty) return true; // no server config = show all
    return serverTypes.contains(event.type);
  }

  /// Compute remaining seconds from event.eventTime + timer duration.
  int _computeRemainingSecs(DateTime? eventTime) {
    if (eventTime == null) return 0;
    final deadline = eventTime.add(Duration(seconds: _timerDurationSec));
    final remaining = deadline.difference(DateTime.now());
    return remaining.inSeconds;
  }

  /// Get the color for a given remaining seconds.
  int _getTimerColor(int remainingSecs) {
    if (remainingSecs <= 0) return 0xFF9E9E9E; // grey when expired
    final remainingMinutes = (remainingSecs / 60).ceil();
    final sorted = _colorThresholds.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final min in sorted) {
      if (remainingMinutes >= min) {
        return _colorThresholds[min]!;
      }
    }
    return _colorThresholds.values.last;
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            const Text('How to Use Notifications', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _helpSection(
                'Countdown Timer',
                'Each notification has a countdown timer on the right side. '
                    'The timer starts from the moment the event is received and runs for the configured duration. '
                    'You can set the duration and colors in Settings (⚙️).',
              ),
              const SizedBox(height: 16),
              _helpSection(
                'Timer Colors',
                'The timer changes color as time runs down:\n'
                    '• More time remaining → warmer colors (red/orange)\n'
                    '• Less time remaining → cooler colors (blue/green)\n'
                    'All colors are customizable in Settings.',
              ),
              const SizedBox(height: 16),
              _helpSection(
                'Event Type Filter',
                'Use Settings to select which event types to show. '
                    'For example, you can choose to see only geofence entries/exits and alarms.',
              ),
              const SizedBox(height: 16),
              _helpSection(
                'Card Layout',
                'You can customize what information appears on each notification card: '
                    'Event Type, License Plate, Geofence Name, and Time. '
                    'Toggle fields on/off and reorder them by dragging in Settings. '
                    'When fewer fields are shown, the text becomes larger for better readability.',
              ),
              const SizedBox(height: 16),
              _helpSection(
                'Geofence Alerts',
                'When a vehicle enters or exits a geofence, a notification is created. '
                    'The geofence name is displayed on the card if available.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('sharedAccept'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _helpSection(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(fontSize: 13, height: 1.4)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TraccarProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter events
    final displayedEvents = provider.events.where((e) => _isEventVisible(e, provider)).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('notificationsTitle'.tr, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.1)),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline_rounded), tooltip: 'How to use Notifications', onPressed: () => _showHelpDialog(context)),
          IconButton(icon: const Icon(Icons.tune_rounded), tooltip: 'Notification Settings', onPressed: _openSettings),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.colorScheme.primary.withValues(alpha: 0.08), theme.colorScheme.surface, theme.colorScheme.secondary.withValues(alpha: 0.05)]),
            ),
          ),
          SafeArea(
            child: displayedEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text('dashboardNoEvents'.tr, style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: displayedEvents.length,
                    itemBuilder: (context, index) {
                      // Show latest events first
                      final event = displayedEvents[displayedEvents.length - 1 - index];
                      return _EventCard(
                        event: event,
                        provider: provider,
                        remainingSecs: _computeRemainingSecs(event.eventTime),
                        timerColor: _getTimerColor(_computeRemainingSecs(event.eventTime)),
                        timerDurationSec: _timerDurationSec,
                        cardFieldsOrder: _cardFieldsOrder,
                        visibleFields: _visibleFields,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Event card widget
// ---------------------------------------------------------------------------
class _EventCard extends StatelessWidget {
  final api.Event event;
  final TraccarProvider provider;
  final int remainingSecs;
  final int timerColor;
  final int timerDurationSec;
  final List<String> cardFieldsOrder;
  final List<String> visibleFields;

  const _EventCard({required this.event, required this.provider, required this.remainingSecs, required this.timerColor, required this.timerDurationSec, required this.cardFieldsOrder, required this.visibleFields});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Fetch data once
    String? deviceName;
    if (event.deviceId != null) {
      final device = provider.devices.cast<api.Device?>().firstWhere((d) => d?.id == event.deviceId, orElse: () => null);
      deviceName = device?.name;
    }
    final geofenceName = provider.getGeofenceName(event.geofenceId);
    final eventType = (event.type ?? 'unknownEvent').tr;
    final timeStr = DateFormat.yMMMd().add_jm().format(event.eventTime?.toLocal() ?? DateTime.now());

    final hasTimer = event.eventTime != null;
    final isExpired = remainingSecs <= 0;

    // Compute visible fields: respect both order and visibility toggle
    final shownFields = cardFieldsOrder.where((f) => this.visibleFields.contains(f) && _fieldAvailable(f, deviceName, geofenceName)).toList();
    final fieldCount = shownFields.length;

    // Dynamic sizing
    double titleSize; // for event type
    double bodySize; // for device, geofence, time
    double iconSize;
    double spacing;
    if (fieldCount <= 1) {
      titleSize = 20;
      bodySize = 18;
      iconSize = 32;
      spacing = 6;
    } else if (fieldCount == 2) {
      titleSize = 17;
      bodySize = 15;
      iconSize = 28;
      spacing = 4;
    } else {
      titleSize = 15;
      bodySize = 13;
      iconSize = 24;
      spacing = 3;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: hasTimer && !isExpired ? Color(timerColor).withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.1), width: hasTimer && !isExpired ? 1.5 : 1.0),
      ),
      child: Row(
        crossAxisAlignment: fieldCount <= 1 ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: EdgeInsets.all(iconSize > 24 ? 14 : 12),
            decoration: BoxDecoration(color: hasTimer && !isExpired ? Color(timerColor).withValues(alpha: 0.15) : theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(_getEventIcon(event.type), size: iconSize, color: hasTimer && !isExpired ? Color(timerColor) : theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          // Content — built dynamically from cardFields order
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final field in shownFields) ...[if (shownFields.indexOf(field) > 0) SizedBox(height: spacing), _buildField(field, eventType, deviceName, geofenceName, timeStr, titleSize, bodySize, theme)],
              ],
            ),
          ),
          // Timer
          if (hasTimer) ...[const SizedBox(width: 12), _buildTimerBadge(context)],
        ],
      ),
    );
  }

  bool _fieldAvailable(String field, String? deviceName, String? geofenceName) {
    switch (field) {
      case 'deviceName':
        return deviceName != null;
      case 'geofenceName':
        return geofenceName != null;
      case 'type':
      case 'time':
        return true;
      default:
        return false;
    }
  }

  Widget _buildField(String field, String eventType, String? deviceName, String? geofenceName, String timeStr, double titleSize, double bodySize, ThemeData theme) {
    switch (field) {
      case 'type':
        return Text(
          eventType,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: titleSize, letterSpacing: -0.3),
        );
      case 'deviceName':
        return Text(
          deviceName!,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: bodySize, color: theme.colorScheme.primary),
        );
      case 'geofenceName':
        return Row(
          children: [
            Icon(Icons.flag_rounded, size: bodySize - 2, color: theme.colorScheme.secondary),
            const SizedBox(width: 4),
            Text(
              geofenceName!,
              style: TextStyle(fontSize: bodySize, fontWeight: FontWeight.w500, color: theme.colorScheme.secondary),
            ),
          ],
        );
      case 'time':
        return Text(
          timeStr,
          style: TextStyle(fontSize: bodySize, color: theme.colorScheme.onSurfaceVariant),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTimerBadge(BuildContext context) {
    final color = Color(timerColor);
    final isExpired = remainingSecs <= 0;
    final timeStr = NotificationSettingsService.formatDuration(Duration(seconds: remainingSecs < 0 ? 0 : remainingSecs));

    return Container(
      constraints: const BoxConstraints(minWidth: 68),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isExpired ? 0.1 : 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isExpired ? Icons.timer_off_rounded : Icons.timer_outlined, size: 16, color: isExpired ? Colors.grey : color),
          const SizedBox(height: 2),
          Text(
            timeStr,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, fontFeatures: const [FontFeature.tabularFigures()], color: isExpired ? Colors.grey : color),
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
