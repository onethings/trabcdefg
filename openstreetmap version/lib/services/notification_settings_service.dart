// lib/services/notification_settings_service.dart
// Service to manage notification timer and filter settings via Hive.
import 'package:hive/hive.dart';

class NotificationSettingsService {
  static const String _boxName = 'ui_settings';

  // Keys
  static const String _timerDurationKey = 'notif_timer_duration';
  // NOTE: Event type filters removed — now uses server-side notification settings via provider.getServerEventTypes()

  // Defaults
  static const int _defaultTimerSeconds = 300; // 5 minutes

  // Color threshold keys: stores color int (ARGB) for each minute mark
  static String _colorKey(int minutes) => 'notif_timer_color_$minutes';

  // Default colors (ARGB ints): 5min=Red, 4min=Orange, 3min=Yellow, 2min=Blue, 1min=Green
  static const Map<int, int> _defaultColors = {
    5: 0xFFFF1744, // Red
    4: 0xFFFF9100, // Orange
    3: 0xFFFFEA00, // Yellow
    2: 0xFF2979FF, // Blue
    1: 0xFF00E676, // Green
  };

  static Box<dynamic>? _box;

  static Future<Box<dynamic>> get _boxInstance async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
    return _box!;
  }

  // --- Timer Duration ---

  static Future<int> getTimerDuration() async {
    final box = await _boxInstance;
    return box.get(_timerDurationKey, defaultValue: _defaultTimerSeconds) as int;
  }

  static Future<void> setTimerDuration(int seconds) async {
    final box = await _boxInstance;
    await box.put(_timerDurationKey, seconds);
  }

  // --- Color Thresholds ---

  static Future<Map<int, int>> getAllColorThresholds() async {
    final box = await _boxInstance;
    final colors = <int, int>{};
    for (final minutes in _defaultColors.keys) {
      final stored = box.get(_colorKey(minutes));
      if (stored is int) {
        colors[minutes] = stored;
      } else {
        colors[minutes] = _defaultColors[minutes]!;
      }
    }
    return colors;
  }

  static Future<void> setColorThreshold(int minutes, int colorArgb) async {
    final box = await _boxInstance;
    await box.put(_colorKey(minutes), colorArgb);
  }

  static Future<int> getColorForRemainingMinutes(int remainingMinutes) async {
    final colors = await getAllColorThresholds();
    // Find the closest threshold <= remaining minutes
    final sorted = colors.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final min in sorted) {
      if (remainingMinutes >= min) {
        return colors[min]!;
      }
    }
    // Default to the lowest threshold color
    return colors.values.last;
  }

  // --- Card Layout (order & visibility) ---

  static const String _cardFieldsOrderKey = 'notif_card_fields_order';
  static const String _cardFieldsVisibleKey = 'notif_card_fields_visible';

  /// Default fields in display order: ['type', 'deviceName', 'geofenceName', 'time']
  static const List<String> _defaultCardFields = ['type', 'deviceName', 'geofenceName', 'time'];

  /// All available card field IDs.
  static const List<String> allCardFields = ['type', 'deviceName', 'geofenceName', 'time'];

  /// Get the ORDERED list of all fields (for display order in settings & card).
  static Future<List<String>> getCardFieldsOrder() async {
    final box = await _boxInstance;
    final stored = box.get(_cardFieldsOrderKey);
    if (stored is List && stored.length == allCardFields.length) {
      return stored.cast<String>();
    }
    return List.from(_defaultCardFields);
  }

  /// Save the ordered list of all fields.
  static Future<void> setCardFieldsOrder(List<String> fields) async {
    final box = await _boxInstance;
    await box.put(_cardFieldsOrderKey, fields);
  }

  /// Get the list of VISIBLE card fields (subset of all fields).
  /// Empty or missing = all fields visible.
  static Future<List<String>> getVisibleCardFields() async {
    final box = await _boxInstance;
    final stored = box.get(_cardFieldsVisibleKey);
    if (stored is List && stored.isNotEmpty) {
      return stored.cast<String>();
    }
    return List.from(_defaultCardFields); // default = all visible
  }

  /// Save which fields are visible.
  static Future<void> setVisibleCardFields(List<String> fields) async {
    final box = await _boxInstance;
    await box.put(_cardFieldsVisibleKey, fields);
  }

  static Future<void> resetToDefaults() async {
    final box = await _boxInstance;
    await box.delete(_timerDurationKey);
    for (final minutes in _defaultColors.keys) {
      await box.delete(_colorKey(minutes));
    }
    await box.delete(_cardFieldsOrderKey);
    await box.delete(_cardFieldsVisibleKey);
  }

  // --- Helpers ---

  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Returns the color for a given remaining duration based on configured thresholds.
  static Future<int> getColorForDuration(Duration remaining) async {
    final remainingSecs = remaining.inSeconds;
    if (remainingSecs <= 0) return 0xFF9E9E9E; // grey when expired

    final thresholds = await getAllColorThresholds();
    final remainingMinutes = (remainingSecs / 60).ceil();
    final sorted = thresholds.keys.toList()..sort((a, b) => b.compareTo(a));

    for (final min in sorted) {
      if (remainingMinutes >= min) {
        return thresholds[min]!;
      }
    }
    return thresholds.values.last;
  }
}
