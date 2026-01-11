import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dart_geohash/dart_geohash.dart';

//Example.
//Yangon 16.840964833809384, 96.17351708794621  w5tn203z2fu5
//Mandalay 21.958846666908578, 96.08906519532363 w5ukft3zt98n
//東枝 20.788766004573187, 97.0336909191174 w5tn203z2fu5
//
//
//
//

class OfflineGeocoder {
  static Database? _db;

  // Future<void> initDB() async {
  //   if (_db != null) return;

  //   var databasesPath = await getDatabasesPath();
  //   var path = join(databasesPath, "myanmar_minimal.db");

  //   // 注意：每次更新資產裡的 db 後，必須刪除手機 App 重裝，或手動刪除舊檔
  //   if (!await databaseExists(path)) {
  //     ByteData data = await rootBundle.load("assets/sqldb/myanmar_minimal.db");
  //     List<int> bytes = data.buffer.asUint8List(
  //       data.offsetInBytes,
  //       data.lengthInBytes,
  //     );
  //     await File(path).writeAsBytes(bytes, flush: true);
  //     print("OfflineGeocoder: 資料庫已拷貝至內部儲存空間");
  //   }
  //   _db = await openDatabase(path, readOnly: true);
  // }
  Future<void> initDB() async {
    if (_db != null) return;
    var databasesPath = await getDatabasesPath();
    var path = join(databasesPath, "myanmar_minimal.db");

    // 開發階段：強制覆蓋舊 DB，確保讀到 10.2 萬條的新數據
    print("OfflineGeocoder: 正在強制更新資料庫...");
    ByteData data = await rootBundle.load("assets/sqldb/myanmar_minimal.db");
    List<int> bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await File(path).writeAsBytes(bytes, flush: true);

    _db = await openDatabase(path, readOnly: true);
  }

  Future<String> getAddress(double lat, double lon) async {
    try {
      await initDB();

      // Get full Geohash
      final String fullHash = GeoHash.fromDecimalDegrees(lon, lat).geohash;

      // --- DEBUG PRINTS START ---
      print("DEBUG Geocoder: Target Coord ($lat, $lon)");
      print("DEBUG Geocoder: Full Geohash: $fullHash");
      // --- DEBUG PRINTS END ---

      // 1. Level 1: Precise (7 chars, ~150m)
      String gh7 = fullHash.substring(0, 7);
      print("DEBUG Geocoder: Searching Level 1 (Exact): $gh7"); // Added
      List<Map<String, dynamic>> res7 = await _db!.query(
        'streets',
        where: 'gh = ?',
        whereArgs: [gh7],
        limit: 1,
      );
      if (res7.isNotEmpty) return res7.first['name'] as String;

      // 2. Level 2: Local (6 chars, ~600m)
      String gh6 = fullHash.substring(0, 6);
      print("DEBUG Geocoder: Searching Level 2 (LIKE): $gh6%"); // Added
      List<Map<String, dynamic>> res6 = await _db!.query(
        'streets',
        where: 'gh LIKE ?',
        whereArgs: ['$gh6%'],
        limit: 1,
      );
      if (res6.isNotEmpty) return res6.first['name'] as String;

      // 3. Level 3: Area Search (5 chars, ~5km)
      String gh5 = fullHash.substring(0, 5);
      print("DEBUG Geocoder: Searching Level 3 (Nearby): $gh5%"); // Added
      List<Map<String, dynamic>> nearby = await _db!.query(
        'streets',
        where: 'gh LIKE ?',
        whereArgs: ['$gh5%'],
        limit: 10,
      );

      if (nearby.isNotEmpty) {
        String closestName = nearby.first['name'] as String;
        return "$closestName (Nearby Area)";
      }

      // 4. Level 4: District (4 chars, ~20km)
      String gh4 = fullHash.substring(0, 4);
      print("DEBUG Geocoder: Searching Level 4 (District): $gh4%"); // Added
      List<Map<String, dynamic>> res4 = await _db!.query(
        'streets',
        where: 'gh LIKE ?',
        whereArgs: ['$gh4%'],
        limit: 1,
      );
      if (res4.isNotEmpty) {
        return "${res4.first['name']} District";
      }

      print(
        "DEBUG Geocoder: No matches found in database for Geohash $gh4",
      ); // Added
    } catch (e) {
      print("OfflineGeocoder Error: $e");
    }

    return "Myanmar Road"; // Final Fallback
  }

  // Debug 工具：查看資料庫總條數
  Future<int> getItemsCount() async {
    await initDB();
    var x = await _db!.rawQuery('SELECT COUNT(*) as cnt FROM streets');
    return x.first['cnt'] as int;
  }
}
