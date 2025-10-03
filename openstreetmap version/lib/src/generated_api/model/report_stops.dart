//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ReportStops {
  /// Returns a new [ReportStops] instance.
  ReportStops({
    this.deviceId,
    this.deviceName,
    this.duration,
    this.startTime,
    this.address,
    this.lat,
    this.lon,
    this.endTime,
    this.spentFuel,
    this.engineHours,
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
  String? address;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  num? lat;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  num? lon;

  /// in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? endTime;

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
  int? engineHours;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportStops &&
          other.deviceId == deviceId &&
          other.deviceName == deviceName &&
          other.duration == duration &&
          other.startTime == startTime &&
          other.address == address &&
          other.lat == lat &&
          other.lon == lon &&
          other.endTime == endTime &&
          other.spentFuel == spentFuel &&
          other.engineHours == engineHours;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (deviceId == null ? 0 : deviceId!.hashCode) +
      (deviceName == null ? 0 : deviceName!.hashCode) +
      (duration == null ? 0 : duration!.hashCode) +
      (startTime == null ? 0 : startTime!.hashCode) +
      (address == null ? 0 : address!.hashCode) +
      (lat == null ? 0 : lat!.hashCode) +
      (lon == null ? 0 : lon!.hashCode) +
      (endTime == null ? 0 : endTime!.hashCode) +
      (spentFuel == null ? 0 : spentFuel!.hashCode) +
      (engineHours == null ? 0 : engineHours!.hashCode);

  @override
  String toString() =>
      'ReportStops[deviceId=$deviceId, deviceName=$deviceName, duration=$duration, startTime=$startTime, address=$address, lat=$lat, lon=$lon, endTime=$endTime, spentFuel=$spentFuel, engineHours=$engineHours]';

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
    if (this.address != null) {
      json[r'address'] = this.address;
    } else {
      json[r'address'] = null;
    }
    if (this.lat != null) {
      json[r'lat'] = this.lat;
    } else {
      json[r'lat'] = null;
    }
    if (this.lon != null) {
      json[r'lon'] = this.lon;
    } else {
      json[r'lon'] = null;
    }
    if (this.endTime != null) {
      json[r'endTime'] = this.endTime!.toUtc().toIso8601String();
    } else {
      json[r'endTime'] = null;
    }
    if (this.spentFuel != null) {
      json[r'spentFuel'] = this.spentFuel;
    } else {
      json[r'spentFuel'] = null;
    }
    if (this.engineHours != null) {
      json[r'engineHours'] = this.engineHours;
    } else {
      json[r'engineHours'] = null;
    }
    return json;
  }

  /// Returns a new [ReportStops] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReportStops? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "ReportStops[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "ReportStops[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ReportStops(
        deviceId: mapValueOfType<int>(json, r'deviceId'),
        deviceName: mapValueOfType<String>(json, r'deviceName'),
        duration: mapValueOfType<int>(json, r'duration'),
        startTime: mapDateTime(json, r'startTime', r''),
        address: mapValueOfType<String>(json, r'address'),
        lat: num.parse('${json[r'lat']}'),
        lon: num.parse('${json[r'lon']}'),
        endTime: mapDateTime(json, r'endTime', r''),
        spentFuel: num.parse('${json[r'spentFuel']}'),
        engineHours: mapValueOfType<int>(json, r'engineHours'),
      );
    }
    return null;
  }

  static List<ReportStops> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ReportStops>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportStops.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReportStops> mapFromJson(dynamic json) {
    final map = <String, ReportStops>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReportStops.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReportStops-objects as value to a dart map
  static Map<String, List<ReportStops>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ReportStops>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReportStops.listFromJson(
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
