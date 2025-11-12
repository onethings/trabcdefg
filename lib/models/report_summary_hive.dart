// lib/models/report_summary_hive.dart
// Model to store report summary data in Hive database.
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

  ReportSummaryHive({
    this.distance,
    this.averageSpeed,
    this.maxSpeed,
    this.spentFuel,
  });

  factory ReportSummaryHive.fromApi(api.ReportSummary apiSummary) {
    return ReportSummaryHive(
      distance: apiSummary.distance?.toDouble(),
      averageSpeed: apiSummary.averageSpeed?.toDouble(),
      maxSpeed: apiSummary.maxSpeed?.toDouble(),
      spentFuel: apiSummary.spentFuel?.toDouble(),
    );
  }
}