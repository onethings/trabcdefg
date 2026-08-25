// lib/screens/notification_settings_screen.dart
// Settings screen for notification timer and filter configuration.
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:trabcdefg/services/notification_settings_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  int _timerSeconds = 300;
  final Map<int, int> _colorThresholds = {};
  List<String> _cardFieldsOrder = [];
  List<String> _visibleFields = [];
  bool _isLoading = true;

  // Predefined color palette for quick selection
  static const List<Color> _colorPalette = [
    Color(0xFFFF1744), // Red
    Color(0xFFFF9100), // Orange
    Color(0xFFFFEA00), // Yellow
    Color(0xFF2979FF), // Blue
    Color(0xFF00E676), // Green
    Color(0xFFD500F9), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFF4081), // Pink
    Color(0xFF8BC34A), // Light Green
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF607D8B), // Blue Grey
    Color(0xFF795548), // Brown
    Color(0xFF9E9E9E), // Grey
    Color(0xFF000000), // Black
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final duration = await NotificationSettingsService.getTimerDuration();
    final colors = await NotificationSettingsService.getAllColorThresholds();
    final order = await NotificationSettingsService.getCardFieldsOrder();
    final visible = await NotificationSettingsService.getVisibleCardFields();
    if (!mounted) return;
    setState(() {
      _timerSeconds = duration;
      _colorThresholds.addAll(colors);
      _cardFieldsOrder = List.from(order);
      _visibleFields = List.from(visible);
      _isLoading = false;
    });
  }

  Future<void> _saveTimerDuration(int seconds) async {
    await NotificationSettingsService.setTimerDuration(seconds);
  }

  Future<void> _saveColorThreshold(int minutes, int color) async {
    await NotificationSettingsService.setColorThreshold(minutes, color);
    setState(() => _colorThresholds[minutes] = color);
  }

  Future<void> _resetToDefaults() async {
    await NotificationSettingsService.resetToDefaults();
    await _loadSettings();
  }

  void _showColorPicker(int minutes) {
    final currentColor = Color(_colorThresholds[minutes] ?? 0xFFFF1744);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ColorPickerSheet(
        title: '$minutes ${'sharedMinuteAbbreviation'.tr}',
        currentColor: currentColor,
        palette: _colorPalette,
        onColorSelected: (color) {
          Navigator.pop(ctx);
          _saveColorThreshold(minutes, color.value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('settingsTitle'.tr)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Get sorted thresholds for display
    final sortedMinutes = _colorThresholds.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('settingsTitle'.tr, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.1)),
          ),
        ),
        actions: [IconButton(icon: const Icon(Icons.restore_rounded), tooltip: 'Reset to defaults', onPressed: _resetToDefaults)],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.colorScheme.primary.withValues(alpha: 0.08), theme.colorScheme.surface, theme.colorScheme.secondary.withValues(alpha: 0.05)]),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_buildTimerSection(theme), const SizedBox(height: 24), _buildColorSection(theme, sortedMinutes), const SizedBox(height: 24), _buildCardLayoutSection(theme), const SizedBox(height: 40)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerSection(ThemeData theme) {
    final minutes = (_timerSeconds / 60).round();
    final displayMinutes = minutes < 1 ? 1 : minutes;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text('Timer Duration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '$displayMinutes min',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Text('(${_timerSeconds}s)', style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: minutes.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            label: '$displayMinutes min',
            activeColor: theme.colorScheme.primary,
            onChanged: (val) {
              final newMinutes = val.round();
              final newSeconds = newMinutes * 60;
              setState(() => _timerSeconds = newSeconds);
              _saveTimerDuration(newSeconds);
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 min', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              Text('30 min', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorSection(ThemeData theme, List<int> sortedMinutes) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text('Timer Colors', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Tap a color to change it', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          ...sortedMinutes.map(
            (minutes) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text('≥ $minutes min', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showColorPicker(minutes),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(_colorThresholds[minutes]!),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                        boxShadow: [BoxShadow(color: Color(_colorThresholds[minutes]!).withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: const Icon(Icons.colorize_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardLayoutSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.view_agenda_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text('Card Layout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Toggle visibility & drag to reorder. Fewer fields = larger text.', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _cardFieldsOrder.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _cardFieldsOrder.removeAt(oldIndex);
                _cardFieldsOrder.insert(newIndex, item);
              });
              NotificationSettingsService.setCardFieldsOrder(_cardFieldsOrder);
            },
            itemBuilder: (context, index) {
              final field = _cardFieldsOrder[index];
              final isVisible = _visibleFields.contains(field);
              return Container(
                key: ValueKey(field),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.drag_handle_rounded, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_fieldLabel(field), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                    Switch(
                      value: isVisible,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (val) {
                        setState(() {
                          if (val) {
                            _visibleFields.add(field);
                          } else {
                            _visibleFields.remove(field);
                          }
                        });
                        NotificationSettingsService.setVisibleCardFields(_visibleFields);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _fieldLabel(String field) {
    switch (field) {
      case 'type':
        return 'Event Type';
      case 'deviceName':
        return 'License Plate';
      case 'geofenceName':
        return 'Geofence';
      case 'time':
        return 'Time';
      default:
        return field;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Color picker bottom sheet
// ---------------------------------------------------------------------------
class _ColorPickerSheet extends StatelessWidget {
  final String title;
  final Color currentColor;
  final List<Color> palette;
  final ValueChanged<Color> onColorSelected;

  const _ColorPickerSheet({required this.title, required this.currentColor, required this.palette, required this.onColorSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Choose Color — $title', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          // Current color preview
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: currentColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
              ),
              const SizedBox(width: 10),
              Text('Current', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: palette.map((color) {
              final isSelected = color.value == currentColor.value;
              return GestureDetector(
                onTap: () => onColorSelected(color),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.withValues(alpha: 0.2), width: isSelected ? 3 : 1),
                    boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 4))] : null,
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 22) : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
