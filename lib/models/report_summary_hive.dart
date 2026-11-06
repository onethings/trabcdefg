// lib/models/report_summary_hive.dart
import 'package:hive/hive.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;

part 'report_summary_hive.g.dart';

@HiveType(typeId: 0)
class ReportSummaryHive extends HiveObject {
  @HiveField(0)
  final double? distance;

  @HiveField(1)
  final double? averageSpeed;

  @HiveField(2)
  final double? maxSpeed;

  @HiveField(3)
  final double? spentFuel;

  @HiveField(4)
  final int? engineHours;

  @HiveField(5)
  final int? deviceId; // 新增：裝置 ID

  @HiveField(6)
  final String? dateStr; // 新增：日期 (yyyy-MM-dd)

  ReportSummaryHive({this.distance, this.averageSpeed, this.maxSpeed, this.spentFuel, this.engineHours, this.deviceId, this.dateStr});

  factory ReportSummaryHive.fromApi(api.ReportSummary apiSummary, {int? deviceId, String? dateStr}) {
    return ReportSummaryHive(
      distance: apiSummary.distance?.toDouble(),
      averageSpeed: apiSummary.averageSpeed?.toDouble(),
      maxSpeed: apiSummary.maxSpeed?.toDouble(),
      spentFuel: apiSummary.spentFuel?.toDouble(),
      engineHours: apiSummary.engineHours,
      deviceId: deviceId ?? apiSummary.deviceId,
      dateStr: dateStr,
    );
  }
}
