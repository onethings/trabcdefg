//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ReportSummary {
  /// Returns a new [ReportSummary] instance.
  ReportSummary({
    this.deviceId,
    this.deviceName,
    this.maxSpeed,
    this.averageSpeed,
    this.distance,
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
  int? engineHours;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportSummary &&
          other.deviceId == deviceId &&
          other.deviceName == deviceName &&
          other.maxSpeed == maxSpeed &&
          other.averageSpeed == averageSpeed &&
          other.distance == distance &&
          other.spentFuel == spentFuel &&
          other.engineHours == engineHours;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (deviceId == null ? 0 : deviceId!.hashCode) +
      (deviceName == null ? 0 : deviceName!.hashCode) +
      (maxSpeed == null ? 0 : maxSpeed!.hashCode) +
      (averageSpeed == null ? 0 : averageSpeed!.hashCode) +
      (distance == null ? 0 : distance!.hashCode) +
      (spentFuel == null ? 0 : spentFuel!.hashCode) +
      (engineHours == null ? 0 : engineHours!.hashCode);

  @override
  String toString() =>
      'ReportSummary[deviceId=$deviceId, deviceName=$deviceName, maxSpeed=$maxSpeed, averageSpeed=$averageSpeed, distance=$distance, spentFuel=$spentFuel, engineHours=$engineHours]';

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
    if (this.engineHours != null) {
      json[r'engineHours'] = this.engineHours;
    } else {
      json[r'engineHours'] = null;
    }
    return json;
  }

  /// Returns a new [ReportSummary] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReportSummary? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "ReportSummary[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "ReportSummary[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ReportSummary(
        deviceId: mapValueOfType<int>(json, r'deviceId'),
        deviceName: mapValueOfType<String>(json, r'deviceName'),
        maxSpeed: num.parse('${json[r'maxSpeed']}'),
        averageSpeed: num.parse('${json[r'averageSpeed']}'),
        distance: num.parse('${json[r'distance']}'),
        spentFuel: num.parse('${json[r'spentFuel']}'),
        engineHours: mapValueOfType<int>(json, r'engineHours'),
      );
    }
    return null;
  }

  static List<ReportSummary> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ReportSummary>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportSummary.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReportSummary> mapFromJson(dynamic json) {
    final map = <String, ReportSummary>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReportSummary.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReportSummary-objects as value to a dart map
  static Map<String, List<ReportSummary>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ReportSummary>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReportSummary.listFromJson(
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
