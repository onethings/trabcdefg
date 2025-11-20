import 'package:hive/hive.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
// Part of the build_runner generated file
part 'route_positions_hive.g.dart'; 

@HiveType(typeId: 2) // Use a new typeId
class RoutePositionsHive extends HiveObject {

// Converts List<api.Position> to List<Map<String, dynamic>>
  static List<Map<String, dynamic>> toJsonList(List<api.Position> positions) {
    // Assuming api.Position has a toJson method (standard in generated Traccar APIs)
    return positions.map((p) => p.toJson()).toList();
  }

  // Converts List<Map<String, dynamic>> back to List<api.Position>
  static List<api.Position> fromJsonList(List<Map<String, dynamic>> jsonList) {
    return jsonList.map((json) => api.Position.fromJson(json)!).toList();
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

  RoutePositionsHive({
    required this.dateKey,
    required this.positionsJson,
    required this.cachedAt,
  });

  // Add conversion methods from/to List<api.Position>
}