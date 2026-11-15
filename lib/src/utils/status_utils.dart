// lib/src/utils/status_utils.dart

import 'package:trabcdefg/src/generated_api/api.dart' as api;

/// The window in which a device's last fix still counts as online.
///
/// The dashboard, the device list and the map all resolve a device's status
/// through [resolveDeviceStatus] so the numbers they show stay identical.
const Duration kDeviceOnlineWindow = Duration(minutes: 10);

/// Resolves a device's display status from its last fix and reported status.
///
/// A device with no fix, or whose last fix is older than [kDeviceOnlineWindow],
/// is treated as offline regardless of the status field.
String resolveDeviceStatus(api.Device device, api.Position? position, DateTime nowUtc) {
  final DateTime? lastUpdate = position?.fixTime?.toUtc() ?? device.lastUpdate?.toUtc();
  if (lastUpdate == null || nowUtc.difference(lastUpdate) >= kDeviceOnlineWindow) return 'offline';
  final String? status = device.status;
  return status == 'online' || status == 'offline' ? status! : 'unknown';
}
