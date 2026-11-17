// The route cache stores `api.Position.toJson()` maps and reads them back with
// `api.Position.fromJson`. This pins that round trip for the positions the map
// matching splice creates, which carry only the fields the splice sets.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:trabcdefg/models/route_positions_hive.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

api.Position _serverPosition() => api.Position(
      id: 1,
      deviceId: 7,
      protocol: 'osmand',
      deviceTime: DateTime.utc(2025, 11, 15, 1, 2, 3),
      fixTime: DateTime.utc(2025, 11, 15, 1, 2, 3),
      serverTime: DateTime.utc(2025, 11, 15, 1, 2, 4),
      valid: true,
      latitude: 16.8409,
      longitude: 96.1951,
      altitude: 12.0,
      speed: 20.0,
      course: 90.0,
      accuracy: 5.0,
    );

// Mirrors the spliced road-geometry points the removed map matching feature
// wrote into the cache. Entries holding them are still on users' devices.
api.Position _splicedPosition() => api.Position(
      deviceId: 7,
      latitude: 16.8412,
      longitude: 96.1955,
      fixTime: DateTime.utc(2025, 11, 15, 1, 2, 30),
      deviceTime: DateTime.utc(2025, 11, 15, 1, 2, 30),
      speed: 18.0,
      valid: true,
    );

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('route_cache_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(RoutePositionsHiveAdapter());
    }
  });

  setUp(() async {
    await Hive.deleteFromDisk();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<List<api.Position>> roundTrip(List<api.Position> positions) async {
    const key = 'device-2025-11-15';
    final box = await Hive.openLazyBox<RoutePositionsHive>('route_positions');
    await box.put(key, RoutePositionsHive(dateKey: key, positionsJson: RoutePositionsHive.toJsonList(positions), cachedAt: DateTime.now()));
    await box.close();

    final reopened = await Hive.openLazyBox<RoutePositionsHive>('route_positions');
    final entry = await reopened.get(key);
    return RoutePositionsHive.fromJsonList(entry!.positionsJson);
  }

  test('server positions survive the cache round trip', () async {
    final restored = await roundTrip([_serverPosition()]);
    expect(restored, hasLength(1));
    expect(restored.single.latitude, 16.8409);
    expect(restored.single.altitude, 12.0);
    expect(restored.single.course, 90.0);
  });

  test('spliced positions survive the cache round trip', () async {
    final restored = await roundTrip([_serverPosition(), _splicedPosition()]);
    expect(restored, hasLength(2));
    expect(restored.last.latitude, 16.8412);
    expect(restored.last.speed, 18.0);
  });

  test('a cache entry holding a null numeric field still loads', () async {
    // Entries already written by the shipped build look like this.
    final cached = RoutePositionsHive.toJsonList([_splicedPosition()]);
    final restored = RoutePositionsHive.fromJsonList(cached);
    expect(restored, hasLength(1));
    expect(restored.single.longitude, 96.1955);
  });
}
