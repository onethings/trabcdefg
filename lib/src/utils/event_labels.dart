import 'package:get/get.dart';

/// Resolves an event type to its localized label, falling back to a humanized
/// form for types the server reports but the app does not know yet.
String eventTypeLabel(String? type) {
  if (type == null || type.isEmpty) return 'unknownEvent'.tr;
  final String key = 'event${type[0].toUpperCase()}${type.substring(1)}';
  final String label = key.tr;
  if (label != key) return label;
  final String spaced = type.replaceAllMapped(RegExp('(?<!^)(?=[A-Z])'), (_) => ' ');
  return spaced[0].toUpperCase() + spaced.substring(1);
}
