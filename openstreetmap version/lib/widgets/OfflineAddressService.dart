import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:maplibre_gl/maplibre_gl.dart';

class AddressResult {
  final String address;
  final String? matchedGeohash;
  AddressResult({required this.address, this.matchedGeohash});
}


class OfflineAddressService {
  static Database? _db;
  static String? _currentLang;
  static Box? _cacheBox;
  
  // Local AI State: 軌跡黏著 (Trajectory Stickiness)
  static String? _lastMatchedStreetName;

  // Nominatim Rate Limiting State
  static DateTime? _lastNominatimRequest;
  static const int _minNominatimIntervalMs = 1500;

  static Future<void> _initCache() async {
    if (_cacheBox == null || !_cacheBox!.isOpen) {
      _cacheBox = await Hive.openBox('address_cache');
      
      // 啟動時如果資料量較大，執行檔案壓縮優化磁碟佔用
      if (_cacheBox!.length > 50000) {
        await _cacheBox!.compact();
      }
    }
  }
  static String _getDbName(String langCode) {
    if (langCode == 'my') return "myanmar_ultra_res.db";
    if (langCode == 'zh') return "chinese_ultra_res.db";
    return "english_ultra_res.db";
  }

  static Future<void> initDatabase({String? manualLangCode}) async {
    await _initCache();
    String langCode = manualLangCode ??
        Get.locale?.languageCode ??
        Get.deviceLocale?.languageCode ??
        'en';

    if (_db != null && _currentLang == langCode) return;

    if (_db != null) {
      await _db!.close();
      _db = null;
    }

    String dbName = _getDbName(langCode);
    var databasesPath = await getDatabasesPath();
    var path = join(databasesPath, dbName);

    if (!(await databaseExists(path))) {
      ByteData data = await rootBundle.load("assets/sqldb/$dbName");
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
    }

    _db = await openDatabase(path, readOnly: true);
    _currentLang = langCode;
  }

  static Future<void> forceSwitchLanguage(String langCode) async {
    await initDatabase(manualLangCode: langCode);
  }

  static String? getAddressFromCache(double lat, double lon) {
    if (_cacheBox == null || !_cacheBox!.isOpen) return null;
    final String fullHash = GeoHasher().encode(lon, lat, precision: 9);
    final String cacheKey = "${_currentLang}_${fullHash.substring(0, 7)}";
    return _cacheBox!.get(cacheKey);
  }

  /// 核心邏輯移植：使用 Java 版的九宮格搜尋策略
  static Future<String> getAddress(double lat, double lon) async {
    try {
      await initDatabase();
      
      String? cached = getAddressFromCache(lat, lon);
      if (cached != null) return cached;

      return (await getAddressDetailed(lat, lon)).address;
    } catch (e) {
      return "Error: $e";
    }
  }

  static Future<AddressResult> getAddressDetailed(double lat, double lon) async {
    try {
      await initDatabase();
      final String fullHash = GeoHasher().encode(lon, lat, precision: 9);
      final String cacheKey = "${_currentLang}_${fullHash.substring(0, 7)}";
      
      if (_cacheBox?.containsKey(cacheKey) ?? false) {
        return AddressResult(address: _cacheBox!.get(cacheKey));
      }

      if (_db == null) return AddressResult(address: "Unknown");

      String? street, town, state;
      String? matchedStreetGeohash;

      // 1. 街道搜索 (精度 9 -> 7)
      // 優化：搜尋鄰近網格以解決邊界問題 (Boundary Problem)
      for (int len = 9; len >= 7; len--) {
        String centerPrefix = fullHash.substring(0, len);
        List<String> searchPrefixes = _getNeighbors(centerPrefix);
        searchPrefixes.add(centerPrefix);
        
        // 構建查詢：WHERE gh LIKE 'p1%' OR gh LIKE 'p2%' ...
        // 注意：一次查 9 個 LIKE 可能效能較差，但對於本地 DB 來說通常可接受。
        // 為求效能，我們先只查 len=8 的鄰居 (覆蓋範圍約 100m)，len=9 只查自己
        
        List<Map> candidates = [];
        

        
        // 優化：Level 9 也啟用鄰居搜尋，追求極致精度 (+- 5m 範圍內的邊界問題)
        // 雖然 Level 9 網格很小，但若車輛壓線，最近的路名點可能在隔壁網格
        
        // 構建 SQL: SELECT ... WHERE gh LIKE ? OR gh LIKE ? ...
        String whereClause = List.filled(searchPrefixes.length, "gh LIKE ?").join(" OR ");
        List<String> args = searchPrefixes.map((e) => "$e%").toList();
        
        int limit = len == 9 ? 10 : 20; // Level 9 範圍小，取 10 筆夠了
        
        List<Map> res = await _db!.rawQuery(
          "SELECT name, gh FROM streets WHERE $whereClause LIMIT $limit",
          args);
        candidates.addAll(res);

        if (candidates.isNotEmpty) {
          // Local AI: 傳入上一條路名進行黏著評分
          var best = _findClosestItem(lat, lon, candidates, previousStreetName: _lastMatchedStreetName);
          
          if (best != null) {
            street = best['name'];
            matchedStreetGeohash = best['gh'];
            
            // Local AI: 更新狀態，讓下一次查詢傾向於這條路
            _lastMatchedStreetName = street;
          }
          break;
        }
      }

      // 2. 行政區域搜索 (移植 Java 的九宮格優化)

      // --- 第一階段：精度 5 (約 5km) 九宮格搜尋 ---
      String center5 = fullHash.substring(0, 5);
      List<String> blocks5 = _getNeighbors(center5);
      blocks5.add(center5);

      List<Map> admins5 = await _queryRegionsIn(blocks5, 5);
      if (admins5.isNotEmpty) {
        // 優先找最近的鎮區 (lvl 8-15)
        var closestTown = _findClosestItem(
            lat, lon, admins5.where((e) => e['lvl'] >= 8).toList());
        if (closestTown != null) town = closestTown['admin'];

        // 找最近的省份 (lvl 0-6)
        var closestState = _findClosestItem(
            lat, lon, admins5.where((e) => e['lvl'] <= 6).toList());
        if (closestState != null) state = closestState['admin'];
      }

      // --- 第二階段：補救邏輯 (如果沒找到，擴大到精度 4 的九宮格) ---
      if (state == null || town == null) {
        String center4 = fullHash.substring(0, 4);
        List<String> blocks4 = _getNeighbors(center4);
        blocks4.add(center4);

        List<Map> admins4 = await _queryRegionsIn(blocks4, 4);

        if (state == null) {
          var closestState = _findClosestItem(
              lat, lon, admins4.where((e) => e['lvl'] <= 6).toList());
          if (closestState != null) state = closestState['admin'];
        }

        if (town == null) {
          var closestTown = _findClosestItem(
              lat, lon, admins4.where((e) => e['lvl'] >= 8).toList());
          if (closestTown != null) town = closestTown['admin'];
        }
      }

      // 3. 組合地址
      List<String> parts = [
        if (street != null) street,
        if (town != null) town,
        if (state != null && state != town) state
      ];

      String result = parts.isNotEmpty
          ? parts.join(", ")
          : "Location: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}";

      // --- 如果離線庫查不到街道，嘗試 Nominatim (備援機制) ---
      if (street == null) {
        String? remoteAddress = await _getRemoteAddress(lat, lon);
        if (remoteAddress != null) {
          result = remoteAddress;
        }
      }

      // --- Hive 快取管理與自動清理 ---
      if (_cacheBox != null && result != "Location: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}") {
        // 當資料超過 10.5 萬筆時，清理掉最舊的 1 萬筆
        if (_cacheBox!.length > 105000) {
          final List<dynamic> keysToDelete =
              _cacheBox!.keys.take(10000).toList();
          await _cacheBox!.deleteAll(keysToDelete);
        }
        // 改成不使用 await，讓它在背景執行
        _cacheBox?.put(cacheKey, result);
      }

      return AddressResult(address: result, matchedGeohash: matchedStreetGeohash);
    } catch (e) {
      return AddressResult(address: "Error: $e");
    }
  }

  /// Nominatim 原生查詢 (備援)
  static Future<String?> _getRemoteAddress(double lat, double lon) async {
    // 1. 檢查速率限制 (每 1.5 秒最多一次)
    final now = DateTime.now();
    if (_lastNominatimRequest != null) {
      if (now.difference(_lastNominatimRequest!).inMilliseconds < _minNominatimIntervalMs) {
        debugPrint("Nominatim: Rate limit skipped.");
        return null;
      }
    }
    _lastNominatimRequest = now;

    try {
      // 2. 構建請求 (需要 User-Agent 否則可能被封鎖)
      final url = Uri.parse("https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1");
      
      final response = await http.get(url, headers: {
        'User-Agent': 'ShweGPS-Pro-App-Flutter',
        'Accept-Language': _currentLang ?? 'en'
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String? displayName = data['display_name'];
        if (displayName != null) {
          debugPrint("Nominatim Success: $displayName");
          
          // 只取前幾個部分以保持簡潔
          List<String> parts = displayName.split(', ');
          if (parts.length > 4) {
             return parts.take(4).join(', ');
          }
          return displayName;
        }
      }
      return null;
    } catch (e) {
      debugPrint("Nominatim Error: $e");
      return null;
    }
  }

  /// 獲取 Geohash 的邊界頂點 (用於在地圖上畫框)
  static List<LatLng> getGeohashBounds(String geohash) {
    try {
      final decoded = GeoHasher().decode(geohash); // returns [lon, lat]
      // 由於 geohash_plus 可能沒直接提供 bounds，我們利用精度計算誤差範圍
      // 或者如果 decoded 有 bounds 屬性則直接使用
      // 假設 decode 返回的是中心點，且我們知道各精度的長寬
      
      // 這裡採用一種更穩健的方法：如果庫沒提供 bounds，我們可以自己算，
      // 但通常 geohash 庫會提供。如果沒有，我們預設返回中心點周圍的一個小範圍。
      // 實際上 Geohash 精度表：
      // 7: 152.9m x 152.4m
      // 8: 38.2m x 19m
      // 9: 4.8m x 4.8m
      
      // 理想情況是從 decoded 中獲取。
      // 先嘗試動態檢查是否有 bounds 屬性 (在 Dart 中較難，我們先按常用庫邏輯寫)
      
      // 注意：geohash_plus 的 decode 回傳的是一個包含 center 的物件。
      // 如果它沒有 bounds，我們需要手動計算。
      
      // 暫時使用中心點配合偏移量來模擬邊界 (精度對應的約略值)
      double lat = decoded[1];
      double lon = decoded[0];
      
      double latHalf, lonHalf;
      int len = geohash.length;
      
      // Geohash 精度大約值 (度數)
      switch (len) {
        case 9: latHalf = 0.00002; lonHalf = 0.00002; break;
        case 8: latHalf = 0.00008; lonHalf = 0.00017; break;
        case 7: latHalf = 0.0007; lonHalf = 0.0007; break;
        case 6: latHalf = 0.005; lonHalf = 0.005; break;
        case 5: latHalf = 0.02; lonHalf = 0.02; break;
        default: latHalf = 0.1; lonHalf = 0.1;
      }

      final bounds = [
        LatLng(lat + latHalf, lon - lonHalf),
        LatLng(lat + latHalf, lon + lonHalf),
        LatLng(lat - latHalf, lon + lonHalf),
        LatLng(lat - latHalf, lon - lonHalf),
      ];
      debugPrint("Geohash $geohash bounds: $bounds");
      return bounds;
    } catch (e) {
      debugPrint("Geohash bounds error for $geohash: $e");
      return [];
    }
  }

  /// 移植 Java 的 queryRegionsIn：使用 IN 子句查詢多個網格
  static Future<List<Map>> _queryRegionsIn(
      List<String> prefixes, int len) async {
    if (prefixes.isEmpty) return [];

    // 構建 WHERE SUBSTR(gh, 1, len) IN (?, ?, ...)
    String placeholders = List.filled(prefixes.length, '?').join(',');
    String sql =
        "SELECT admin, lvl, gh FROM regions WHERE SUBSTR(gh, 1, $len) IN ($placeholders)";

    return await _db!.rawQuery(sql, prefixes);
  }

  /// 獲取周邊 8 個鄰居的 Geohash (對應 Java 的 getNeighbors)
  static List<String> _getNeighbors(String geohash) {
    final List<String> neighbors = [];
    final decoded = GeoHasher().decode(geohash);
    final double lat = decoded[1];
    final double lon = decoded[0];

    // 根據精度決定偏移量 (更精確的數值)
    // 參考 getGeohashBounds 的 switch case
    double latErr, lonErr;
    int len = geohash.length;
    
    switch (len) {
      case 9: latErr = 0.00004; lonErr = 0.00004; break; // ~4.8m
      case 8: latErr = 0.00017; lonErr = 0.00034; break; // ~19m x 38m? bounds 裡是 0.00008/0.00017
      case 7: latErr = 0.0014; lonErr = 0.0014; break;   // ~150m
      case 6: latErr = 0.005; lonErr = 0.01; break;
      case 5: latErr = 0.045; lonErr = 0.045; break;     // ~5km
      case 4: latErr = 0.18; lonErr = 0.35; break;       // ~20km
      default: latErr = 0.7; lonErr = 0.7; break;
    }

    List<double> dLat = [
      latErr,
      latErr,
      0,
      -latErr,
      -latErr,
      -latErr,
      0,
      latErr
    ];
    List<double> dLon = [
      0,
      lonErr,
      lonErr,
      lonErr,
      0,
      -lonErr,
      -lonErr,
      -lonErr
    ];

  for (int i = 0; i < 8; i++) {
      neighbors.add(
          GeoHasher().encode(lon + dLon[i], lat + dLat[i], precision: len));
    }
    return neighbors;
  }

  static String? _findClosest(
      double lat, double lon, List<Map> items, String key) {
    var best = _findClosestItem(lat, lon, items);
    return best?[key];
  }

  static Map? _findClosestItem(double lat, double lon, List<Map> items, {String? previousStreetName}) {
    if (items.isEmpty) return null;
    double minScore = double.infinity;
    Map? best;
    
    for (var item in items) {
      final decoded = GeoHasher().decode(item['gh']);
      final double pLat = decoded[1];
      final double pLon = decoded[0];
      // 1. 計算原始歐幾里得距離 (單位: 度數平房，非米)
      // 簡單起見，我們視為相對距離
      double dist = sqrt(pow(lat - pLat, 2) + pow(lon - pLon, 2));
      
      // 2. 應用軌跡黏著與 AI 加權
      double score = dist;
      
      // Stickiness Logic: 如果路名與上一條相同，給予距離減免優惠
      // 0.00015 度約等於 15~20 米
      if (previousStreetName != null && item['name'] == previousStreetName) {
        score -= 0.00015; 
      }
      
      if (score < minScore) {
        minScore = score;
        best = item;
      }
    }
    return best;
  }
}
