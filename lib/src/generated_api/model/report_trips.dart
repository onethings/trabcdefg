//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ReportTrips {
  /// Returns a new [ReportTrips] instance.
  ReportTrips({
    this.deviceId,
    this.deviceName,
    this.maxSpeed,
    this.averageSpeed,
    this.distance,
    this.spentFuel,
    this.duration,
    this.startTime,
    this.startAddress,
    this.startLat,
    this.startLon,
    this.endTime,
    this.endAddress,
    this.endLat,
    this.endLon,
    this.driverUniqueId,
    this.driverName,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? deviceId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? deviceName;

  /// in knots
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  num? maxSpeed;

  /// in knots
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  num? averageSpeed;

  /// in meters
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  num? distance;

  /// in liters
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  num? spentFuel;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? duration;

  /// in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? startTime;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? startAddress;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  num? startLat;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  num? startLon;

  /// in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? endTime;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? endAddress;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  num? endLat;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  num? endLon;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? driverUniqueId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? driverName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportTrips &&
          other.deviceId == deviceId &&
          other.deviceName == deviceName &&
          other.maxSpeed == maxSpeed &&
          other.averageSpeed == averageSpeed &&
          other.distance == distance &&
          other.spentFuel == spentFuel &&
          other.duration == duration &&
          other.startTime == startTime &&
          other.startAddress == startAddress &&
          other.startLat == startLat &&
          other.startLon == startLon &&
          other.endTime == endTime &&
          other.endAddress == endAddress &&
          other.endLat == endLat &&
          other.endLon == endLon &&
          other.driverUniqueId == driverUniqueId &&
          other.driverName == driverName;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (deviceId == null ? 0 : deviceId!.hashCode) +
      (deviceName == null ? 0 : deviceName!.hashCode) +
      (maxSpeed == null ? 0 : maxSpeed!.hashCode) +
      (averageSpeed == null ? 0 : averageSpeed!.hashCode) +
      (distance == null ? 0 : distance!.hashCode) +
      (spentFuel == null ? 0 : spentFuel!.hashCode) +
      (duration == null ? 0 : duration!.hashCode) +
      (startTime == null ? 0 : startTime!.hashCode) +
      (startAddress == null ? 0 : startAddress!.hashCode) +
      (startLat == null ? 0 : startLat!.hashCode) +
      (startLon == null ? 0 : startLon!.hashCode) +
      (endTime == null ? 0 : endTime!.hashCode) +
      (endAddress == null ? 0 : endAddress!.hashCode) +
      (endLat == null ? 0 : endLat!.hashCode) +
      (endLon == null ? 0 : endLon!.hashCode) +
      (driverUniqueId == null ? 0 : driverUniqueId!.hashCode) +
      (driverName == null ? 0 : driverName!.hashCode);

  @override
  String toString() =>
      'ReportTrips[deviceId=$deviceId, deviceName=$deviceName, maxSpeed=$maxSpeed, averageSpeed=$averageSpeed, distance=$distance, spentFuel=$spentFuel, duration=$duration, startTime=$startTime, startAddress=$startAddress, startLat=$startLat, startLon=$startLon, endTime=$endTime, endAddress=$endAddress, endLat=$endLat, endLon=$endLon, driverUniqueId=$driverUniqueId, driverName=$driverName]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.deviceId != null) {
      json[r'deviceId'] = this.deviceId;
    } else {
      json[r'deviceId'] = null;
    }
    if (this.deviceName != null) {
      json[r'deviceName'] = this.deviceName;
    } else {
      json[r'deviceName'] = null;
    }
    if (this.maxSpeed != null) {
      json[r'maxSpeed'] = this.maxSpeed;
    } else {
      json[r'maxSpeed'] = null;
    }
    if (this.averageSpeed != null) {
      json[r'averageSpeed'] = this.averageSpeed;
    } else {
      json[r'averageSpeed'] = null;
    }
    if (this.distance != null) {
      json[r'distance'] = this.distance;
    } else {
      json[r'distance'] = null;
    }
    if (this.spentFuel != null) {
      json[r'spentFuel'] = this.spentFuel;
    } else {
      json[r'spentFuel'] = null;
    }
    if (this.duration != null) {
      json[r'duration'] = this.duration;
    } else {
      json[r'duration'] = null;
    }
    if (this.startTime != null) {
      json[r'startTime'] = this.startTime!.toUtc().toIso8601String();
    } else {
      json[r'startTime'] = null;
    }
    if (this.startAddress != null) {
      json[r'startAddress'] = this.startAddress;
    } else {
      json[r'startAddress'] = null;
    }
    if (this.startLat != null) {
      json[r'startLat'] = this.startLat;
    } else {
      json[r'startLat'] = null;
    }
    if (this.startLon != null) {
      json[r'startLon'] = this.startLon;
    } else {
      json[r'startLon'] = null;
    }
    if (this.endTime != null) {
      json[r'endTime'] = this.endTime!.toUtc().toIso8601String();
    } else {
      json[r'endTime'] = null;
    }
    if (this.endAddress != null) {
      json[r'endAddress'] = this.endAddress;
    } else {
      json[r'endAddress'] = null;
    }
    if (this.endLat != null) {
      json[r'endLat'] = this.endLat;
    } else {
      json[r'endLat'] = null;
    }
    if (this.endLon != null) {
      json[r'endLon'] = this.endLon;
    } else {
      json[r'endLon'] = null;
    }
    if (this.driverUniqueId != null) {
      json[r'driverUniqueId'] = this.driverUniqueId;
    } else {
      json[r'driverUniqueId'] = null;
    }
    if (this.driverName != null) {
      json[r'driverName'] = this.driverName;
    } else {
      json[r'driverName'] = null;
    }
    return json;
  }

  /// Returns a new [ReportTrips] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReportTrips? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "ReportTrips[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "ReportTrips[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ReportTrips(
        deviceId: mapValueOfType<int>(json, r'deviceId'),
        deviceName: mapValueOfType<String>(json, r'deviceName'),
        maxSpeed: num.parse('${json[r'maxSpeed']}'),
        averageSpeed: num.parse('${json[r'averageSpeed']}'),
        distance: num.parse('${json[r'distance']}'),
        spentFuel: num.parse('${json[r'spentFuel']}'),
        duration: mapValueOfType<int>(json, r'duration'),
        startTime: mapDateTime(json, r'startTime', r''),
        startAddress: mapValueOfType<String>(json, r'startAddress'),
        startLat: num.parse('${json[r'startLat']}'),
        startLon: num.parse('${json[r'startLon']}'),
        endTime: mapDateTime(json, r'endTime', r''),
        endAddress: mapValueOfType<String>(json, r'endAddress'),
        endLat: num.parse('${json[r'endLat']}'),
        endLon: num.parse('${json[r'endLon']}'),
        driverUniqueId: mapValueOfType<String>(json, r'driverUniqueId'),
        driverName: mapValueOfType<String>(json, r'driverName'),
      );
    }
    return null;
  }

  static List<ReportTrips> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ReportTrips>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportTrips.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReportTrips> mapFromJson(dynamic json) {
    final map = <String, ReportTrips>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReportTrips.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReportTrips-objects as value to a dart map
  static Map<String, List<ReportTrips>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ReportTrips>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReportTrips.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{};
}
