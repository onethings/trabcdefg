import 'package:flutter_test/flutter_test.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/src/utils/status_utils.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 1, 1, 12);

  api.Device device({String? status, DateTime? lastUpdate}) => api.Device(id: 1, status: status, lastUpdate: lastUpdate);

  test('stale lastUpdate is offline even when the device reports online', () {
    final api.Device stale = device(status: 'online', lastUpdate: now.subtract(const Duration(minutes: 11)));
    expect(resolveDeviceStatus(stale, null, now), 'offline');
  });

  test('missing fix and missing lastUpdate is offline', () {
    expect(resolveDeviceStatus(device(status: 'online'), null, now), 'offline');
  });

  test('fresh lastUpdate keeps a reported online status', () {
    final api.Device fresh = device(status: 'online', lastUpdate: now.subtract(const Duration(minutes: 1)));
    expect(resolveDeviceStatus(fresh, null, now), 'online');
  });

  test('fresh fix with unknown reported status is unknown', () {
    final api.Device unknown = device(status: 'unknown', lastUpdate: now.subtract(const Duration(minutes: 1)));
    expect(resolveDeviceStatus(unknown, null, now), 'unknown');
  });

  test('position fixTime wins over a stale lastUpdate', () {
    final api.Position position = api.Position(deviceId: 1, fixTime: now.subtract(const Duration(minutes: 1)));
    final api.Device device2 = device(status: 'online', lastUpdate: now.subtract(const Duration(hours: 2)));
    expect(resolveDeviceStatus(device2, position, now), 'online');
  });
}
