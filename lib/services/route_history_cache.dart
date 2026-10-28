import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:trabcdefg/models/route_positions_hive.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

class CachedRoutePositions {
  final List<api.Position> positions;
  final DateTime cachedAt;

  const CachedRoutePositions({required this.positions, required this.cachedAt});

  /// 與軌跡頁相同的有效期規則：當天 10 分鐘，其他日期 60 天。
  bool isFreshFor(DateTime day) {
    final now = DateTime.now();
    final isToday = day.year == now.year && day.month == now.month && day.day == now.day;
    final age = now.difference(cachedAt);
    return isToday ? age <= const Duration(minutes: 10) : age <= const Duration(days: 60);
  }
}

/// 讀取軌跡頁（HistoryRouteScreen）寫入的本機軌跡快取。
///
/// 快取 key 與軌跡頁一致：`<deviceId>-<yyyy-MM-dd>`，內容為清理後的完整軌跡點，
/// 因此可以直接用來在離線或報表 API 無資料時推算曲線、行程與停留。
class RouteHistoryCache {
  static const String boxName = 'route_positions';

  static String keyFor({required int deviceId, required DateTime day}) {
    return '$deviceId-${DateFormat('yyyy-MM-dd').format(day)}';
  }

  static Future<CachedRoutePositions?> load({required int deviceId, required DateTime day}) async {
    if (!Hive.isBoxOpen(boxName) && !await Hive.boxExists(boxName)) {
      return null;
    }
    final box = await Hive.openBox<RoutePositionsHive>(boxName);
    final entry = box.get(keyFor(deviceId: deviceId, day: day));
    if (entry == null || entry.positionsJson.isEmpty) {
      return null;
    }
    final positions = RoutePositionsHive.fromJsonList(entry.positionsJson);
    if (positions.isEmpty) {
      return null;
    }
    return CachedRoutePositions(positions: positions, cachedAt: entry.cachedAt);
  }
}
