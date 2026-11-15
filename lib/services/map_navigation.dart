import 'package:flutter/foundation.dart';

/// One-shot cross-tab intent: the device list publishes a focus request for a
/// device and the map tab consumes it once the map style has loaded.
class MapNavigation extends ChangeNotifier {
  int? _pendingDeviceId;

  int? get pendingDeviceId => _pendingDeviceId;

  void focusDevice(int deviceId) {
    _pendingDeviceId = deviceId;
    notifyListeners();
  }

  /// Returns and clears the pending intent so it is applied once.
  int? takePendingDeviceId() {
    final int? deviceId = _pendingDeviceId;
    _pendingDeviceId = null;
    return deviceId;
  }
}
