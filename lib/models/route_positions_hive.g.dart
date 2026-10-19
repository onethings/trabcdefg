// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_positions_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RoutePositionsHiveAdapter extends TypeAdapter<RoutePositionsHive> {
  @override
  final int typeId = 2;

  @override
  RoutePositionsHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RoutePositionsHive(
      dateKey: fields[0] as String,
      positionsJson: (fields[1] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      cachedAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RoutePositionsHive obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.dateKey)
      ..writeByte(1)
      ..write(obj.positionsJson)
      ..writeByte(2)
      ..write(obj.cachedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutePositionsHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
