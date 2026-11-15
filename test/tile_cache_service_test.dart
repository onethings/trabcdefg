import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:trabcdefg/services/tile_cache_service.dart';

Uint8List _tile(int seed) => Uint8List.fromList(List<int>.filled(8, seed));

void main() {
  late Directory tempDir;
  late TileCacheService service;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('tile_cache_test');
    Hive.init(tempDir.path);
    service = TileCacheService(maxTiles: 20);
    await service.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('cached tile comes back byte for byte', () async {
    await service.saveTile('https://tiles/1/1/1.png', _tile(7));

    expect(await service.getTile('https://tiles/1/1/1.png'), _tile(7));
  });

  test('missing tile reads as null rather than throwing', () async {
    expect(await service.getTile('https://tiles/absent.png'), isNull);
  });

  test('cache stays at the cap and drops the least recently used tiles', () async {
    for (int i = 0; i < 20; i++) {
      await service.saveTile('https://tiles/$i.png', _tile(i));
    }
    // Read the first tile so it is no longer the least recently used.
    await service.getTile('https://tiles/0.png');

    for (int i = 20; i < 25; i++) {
      await service.saveTile('https://tiles/$i.png', _tile(i));
    }

    expect(await service.getTile('https://tiles/0.png'), isNotNull, reason: 'read last, must survive');
    expect(await service.getTile('https://tiles/1.png'), isNull, reason: 'least recently used, evicted');
    expect(await service.getTile('https://tiles/24.png'), isNotNull, reason: 'newest, must survive');
  });
}
