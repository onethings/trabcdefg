import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

// --- Tile Caching Implementation using Hive ---

class TileCacheService {
  TileCacheService({this.maxTiles = 2000});

  late LazyBox<Uint8List> _tileBox;
  static const String boxName = 'mapTilesCache';

  /// Tiles kept on disk. Hive exposes no insertion order, so eviction keeps a
  /// session recency table and drops the tiles this session used least.
  final int maxTiles;

  final Map<String, int> _usedAt = {};
  int _tick = 0;

  Future<void> init() async {
    // A lazy box reads keys up front but decodes a value only when asked, so a
    // large tile cache no longer sits in memory for the whole session.
    _tileBox = await Hive.openLazyBox<Uint8List>(boxName);
  }

  Future<Uint8List?> getTile(String url) async {
    _touch(url);
    return _tileBox.get(url);
  }

  Future<void> saveTile(String url, Uint8List tileData) async {
    _touch(url);
    await _tileBox.put(url, tileData);
    await _evictIfNeeded();
  }

  void _touch(String url) {
    _usedAt[url] = ++_tick;
  }

  Future<void> _evictIfNeeded() async {
    if (_tileBox.length <= maxTiles) return;

    // Drop a tenth below the cap so a pan does not re-sort on every new tile.
    final int target = maxTiles - (maxTiles ~/ 10);
    final List<dynamic> keys = _tileBox.keys.toList();
    keys.sort((a, b) {
      final int aUsed = _usedAt[a] ?? 0;
      final int bUsed = _usedAt[b] ?? 0;
      return aUsed.compareTo(bUsed);
    });

    final List<dynamic> victims = keys.take(keys.length - target).toList();
    await _tileBox.deleteAll(victims);
    for (final victim in victims) {
      _usedAt.remove(victim);
    }
  }
}

class HiveTileProvider extends TileProvider {
  final TileCacheService cacheService;
  final http.Client httpClient;

  HiveTileProvider({required this.cacheService, required this.httpClient});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      cacheService: cacheService,
      httpClient: httpClient,
    );
  }
}

class CachedNetworkImageProvider
    extends ImageProvider<CachedNetworkImageProvider> {
  final String url;
  final TileCacheService cacheService;
  final http.Client httpClient;

  CachedNetworkImageProvider(
    this.url, {
    required this.cacheService,
    required this.httpClient,
  });

  @override
  ImageStreamCompleter loadImage(
    CachedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<CachedNetworkImageProvider>('Original key', key),
      ],
    );
  }

  @override
  Future<CachedNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return Future<CachedNetworkImageProvider>.value(this);
  }

  Future<ui.Codec> _loadAsync(
    CachedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    assert(key == this);

    final cachedData = await cacheService.getTile(url);

    if (cachedData != null) {
      return decode(await ui.ImmutableBuffer.fromUint8List(cachedData));
    }

    try {
      final response = await httpClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        await cacheService.saveTile(url, bytes);
        return await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
      } else {
        throw Exception(
          'Failed to load tile from network: ${response.statusCode}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}
