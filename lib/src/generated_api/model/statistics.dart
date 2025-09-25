//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class Statistics {
  /// Returns a new [Statistics] instance.
  Statistics({
    this.captureTime,
    this.activeUsers,
    this.activeDevices,
    this.requests,
    this.messagesReceived,
    this.messagesStored,
  });

  /// in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? captureTime;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? activeUsers;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? activeDevices;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? requests;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? messagesReceived;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? messagesStored;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Statistics &&
          other.captureTime == captureTime &&
          other.activeUsers == activeUsers &&
          other.activeDevices == activeDevices &&
          other.requests == requests &&
          other.messagesReceived == messagesReceived &&
          other.messagesStored == messagesStored;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (captureTime == null ? 0 : captureTime!.hashCode) +
      (activeUsers == null ? 0 : activeUsers!.hashCode) +
      (activeDevices == null ? 0 : activeDevices!.hashCode) +
      (requests == null ? 0 : requests!.hashCode) +
      (messagesReceived == null ? 0 : messagesReceived!.hashCode) +
      (messagesStored == null ? 0 : messagesStored!.hashCode);

  @override
  String toString() =>
      'Statistics[captureTime=$captureTime, activeUsers=$activeUsers, activeDevices=$activeDevices, requests=$requests, messagesReceived=$messagesReceived, messagesStored=$messagesStored]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.captureTime != null) {
      json[r'captureTime'] = this.captureTime!.toUtc().toIso8601String();
    } else {
      json[r'captureTime'] = null;
    }
    if (this.activeUsers != null) {
      json[r'activeUsers'] = this.activeUsers;
    } else {
      json[r'activeUsers'] = null;
    }
    if (this.activeDevices != null) {
      json[r'activeDevices'] = this.activeDevices;
    } else {
      json[r'activeDevices'] = null;
    }
    if (this.requests != null) {
      json[r'requests'] = this.requests;
    } else {
      json[r'requests'] = null;
    }
    if (this.messagesReceived != null) {
      json[r'messagesReceived'] = this.messagesReceived;
    } else {
      json[r'messagesReceived'] = null;
    }
    if (this.messagesStored != null) {
      json[r'messagesStored'] = this.messagesStored;
    } else {
      json[r'messagesStored'] = null;
    }
    return json;
  }

  /// Returns a new [Statistics] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Statistics? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "Statistics[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "Statistics[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return Statistics(
        captureTime: mapDateTime(json, r'captureTime', r''),
        activeUsers: mapValueOfType<int>(json, r'activeUsers'),
        activeDevices: mapValueOfType<int>(json, r'activeDevices'),
        requests: mapValueOfType<int>(json, r'requests'),
        messagesReceived: mapValueOfType<int>(json, r'messagesReceived'),
        messagesStored: mapValueOfType<int>(json, r'messagesStored'),
      );
    }
    return null;
  }

  static List<Statistics> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <Statistics>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Statistics.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Statistics> mapFromJson(dynamic json) {
    final map = <String, Statistics>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Statistics.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Statistics-objects as value to a dart map
  static Map<String, List<Statistics>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<Statistics>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Statistics.listFromJson(
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
