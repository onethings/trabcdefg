import 'package:hive/hive.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
// Part of the build_runner generated file
part 'route_positions_hive.g.dart';

@HiveType(typeId: 2) // Use a new typeId
class RoutePositionsHive extends HiveObject {
  /// Numeric fields that `api.Position.fromJson` reads through
  /// `num.parse('${json[key]}')`, which throws on null. The map matching splice
  /// only sets the fields it can derive, so its points reach the cache with
  /// these absent and would fail to load back without a default.
  static const List<String> _optionalNumericFields = ['altitude', 'speed', 'course', 'accuracy'];

  // Converts List<api.Position> to List<Map<String, dynamic>>
  static List<Map<String, dynamic>> toJsonList(List<api.Position> positions) {
    // Assuming api.Position has a toJson method (standard in generated Traccar APIs)
    return positions.map((p) => p.toJson()).toList();
  }

  // Converts List<Map<String, dynamic>> back to List<api.Position>
  //
  // Points written before this normalisation existed still sit in users' boxes,
  // so the defaults have to be applied on read, not only on write. A point
  // without coordinates is dropped rather than placed at 0, 0.
  static List<api.Position> fromJsonList(List<Map<String, dynamic>> jsonList) {
    final positions = <api.Position>[];
    for (final json in jsonList) {
      if (json['latitude'] == null || json['longitude'] == null) continue;
      final Map<String, dynamic> normalized = Map<String, dynamic>.of(json);
      for (final String key in _optionalNumericFields) {
        normalized[key] ??= 0;
      }
      final position = api.Position.fromJson(normalized);
      if (position != null) positions.add(position);
    }
    return positions;
  }

  @HiveField(0)
  final String dateKey; // 'deviceId-yyyy-MM-dd'

  // Store the positions as a list of dynamic/map for simpler serialization.
  // You would need a custom TypeAdapter to convert List<api.Position>
  // to List<Map<String, dynamic>> for Hive storage.
  @HiveField(1)
  final List<Map<String, dynamic>> positionsJson;

  @HiveField(2)
  final DateTime cachedAt;

  RoutePositionsHive({required this.dateKey, required this.positionsJson, required this.cachedAt});

  // Add conversion methods from/to List<api.Position>
}
