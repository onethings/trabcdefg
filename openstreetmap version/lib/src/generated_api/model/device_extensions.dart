import 'package:trabcdefg/src/generated_api/api.dart';

extension DeviceX on Device {
  /// Always returns a safe, lowercase category
  String get normalizedCategory {
    final raw = category ?? '';
    return raw.trim().isNotEmpty ? raw.trim().toLowerCase() : 'default';
  }

  /// Always returns a safe, lowercase status
  String get normalizedStatus {
    final raw = status ?? '';
    return raw.trim().isNotEmpty ? raw.trim().toLowerCase() : 'offline';
  }
}
