//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class DeviceAccumulators {
  /// Returns a new [DeviceAccumulators] instance.
  DeviceAccumulators({
    this.deviceId,
    this.totalDistance,
    this.hours,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? deviceId;

  /// in meters
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  num? totalDistance;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  num? hours;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceAccumulators &&
          other.deviceId == deviceId &&
          other.totalDistance == totalDistance &&
          other.hours == hours;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (deviceId == null ? 0 : deviceId!.hashCode) +
      (totalDistance == null ? 0 : totalDistance!.hashCode) +
      (hours == null ? 0 : hours!.hashCode);

  @override
  String toString() =>
      'DeviceAccumulators[deviceId=$deviceId, totalDistance=$totalDistance, hours=$hours]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.deviceId != null) {
      json[r'deviceId'] = this.deviceId;
    } else {
      json[r'deviceId'] = null;
    }
    if (this.totalDistance != null) {
      json[r'totalDistance'] = this.totalDistance;
    } else {
      json[r'totalDistance'] = null;
    }
    if (this.hours != null) {
      json[r'hours'] = this.hours;
    } else {
      json[r'hours'] = null;
    }
    return json;
  }

  /// Returns a new [DeviceAccumulators] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static DeviceAccumulators? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "DeviceAccumulators[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "DeviceAccumulators[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return DeviceAccumulators(
        deviceId: mapValueOfType<int>(json, r'deviceId'),
        totalDistance: num.parse('${json[r'totalDistance']}'),
        hours: num.parse('${json[r'hours']}'),
      );
    }
    return null;
  }

  static List<DeviceAccumulators> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <DeviceAccumulators>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = DeviceAccumulators.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, DeviceAccumulators> mapFromJson(dynamic json) {
    final map = <String, DeviceAccumulators>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = DeviceAccumulators.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of DeviceAccumulators-objects as value to a dart map
  static Map<String, List<DeviceAccumulators>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<DeviceAccumulators>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = DeviceAccumulators.listFromJson(
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
