// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_summary_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ReportSummaryHiveAdapter extends TypeAdapter<ReportSummaryHive> {
  @override
  final int typeId = 0;

  @override
  ReportSummaryHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ReportSummaryHive(
      distance: fields[0] as double?,
      averageSpeed: fields[1] as double?,
      maxSpeed: fields[2] as double?,
      spentFuel: fields[3] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, ReportSummaryHive obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.distance)
      ..writeByte(1)
      ..write(obj.averageSpeed)
      ..writeByte(2)
      ..write(obj.maxSpeed)
      ..writeByte(3)
      ..write(obj.spentFuel);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportSummaryHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
