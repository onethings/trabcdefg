//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ReportGeofences {
  /// Returns a new [ReportGeofences] instance.
  ReportGeofences({
    this.deviceId,
    this.deviceName,
    this.geofenceId,
    this.startTime,
    this.endTime,
  });

  /// Device identifier for the geofence interval
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? deviceId;

  /// Human readable device name
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? deviceName;

  /// Geofence identifier
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? geofenceId;

  /// in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? startTime;

  /// in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? endTime;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportGeofences &&
          other.deviceId == deviceId &&
          other.deviceName == deviceName &&
          other.geofenceId == geofenceId &&
          other.startTime == startTime &&
          other.endTime == endTime;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (deviceId == null ? 0 : deviceId!.hashCode) +
      (deviceName == null ? 0 : deviceName!.hashCode) +
      (geofenceId == null ? 0 : geofenceId!.hashCode) +
      (startTime == null ? 0 : startTime!.hashCode) +
      (endTime == null ? 0 : endTime!.hashCode);

  @override
  String toString() =>
      'ReportGeofences[deviceId=$deviceId, deviceName=$deviceName, geofenceId=$geofenceId, startTime=$startTime, endTime=$endTime]';

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
    if (this.geofenceId != null) {
      json[r'geofenceId'] = this.geofenceId;
    } else {
      json[r'geofenceId'] = null;
    }
    if (this.startTime != null) {
      json[r'startTime'] = this.startTime!.toUtc().toIso8601String();
    } else {
      json[r'startTime'] = null;
    }
    if (this.endTime != null) {
      json[r'endTime'] = this.endTime!.toUtc().toIso8601String();
    } else {
      json[r'endTime'] = null;
    }
    return json;
  }

  /// Returns a new [ReportGeofences] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ReportGeofences? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "ReportGeofences[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "ReportGeofences[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return ReportGeofences(
        deviceId: mapValueOfType<int>(json, r'deviceId'),
        deviceName: mapValueOfType<String>(json, r'deviceName'),
        geofenceId: mapValueOfType<int>(json, r'geofenceId'),
        startTime: mapDateTime(json, r'startTime', r''),
        endTime: mapDateTime(json, r'endTime', r''),
      );
    }
    return null;
  }

  static List<ReportGeofences> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ReportGeofences>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ReportGeofences.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ReportGeofences> mapFromJson(dynamic json) {
    final map = <String, ReportGeofences>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ReportGeofences.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ReportGeofences-objects as value to a dart map
  static Map<String, List<ReportGeofences>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ReportGeofences>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ReportGeofences.listFromJson(
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
