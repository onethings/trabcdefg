//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class Event {
  /// Returns a new [Event] instance.
  Event({
    this.id,
    this.type,
    this.eventTime,
    this.deviceId,
    this.positionId,
    this.geofenceId,
    this.maintenanceId,
    this.attributes,
  });

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? id;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? type;

  /// in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  DateTime? eventTime;

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
  int? positionId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? geofenceId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? maintenanceId;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Object? attributes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Event &&
          other.id == id &&
          other.type == type &&
          other.eventTime == eventTime &&
          other.deviceId == deviceId &&
          other.positionId == positionId &&
          other.geofenceId == geofenceId &&
          other.maintenanceId == maintenanceId &&
          other.attributes == attributes;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (id == null ? 0 : id!.hashCode) +
      (type == null ? 0 : type!.hashCode) +
      (eventTime == null ? 0 : eventTime!.hashCode) +
      (deviceId == null ? 0 : deviceId!.hashCode) +
      (positionId == null ? 0 : positionId!.hashCode) +
      (geofenceId == null ? 0 : geofenceId!.hashCode) +
      (maintenanceId == null ? 0 : maintenanceId!.hashCode) +
      (attributes == null ? 0 : attributes!.hashCode);

  @override
  String toString() =>
      'Event[id=$id, type=$type, eventTime=$eventTime, deviceId=$deviceId, positionId=$positionId, geofenceId=$geofenceId, maintenanceId=$maintenanceId, attributes=$attributes]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.id != null) {
      json[r'id'] = this.id;
    } else {
      json[r'id'] = null;
    }
    if (this.type != null) {
      json[r'type'] = this.type;
    } else {
      json[r'type'] = null;
    }
    if (this.eventTime != null) {
      json[r'eventTime'] = this.eventTime!.toUtc().toIso8601String();
    } else {
      json[r'eventTime'] = null;
    }
    if (this.deviceId != null) {
      json[r'deviceId'] = this.deviceId;
    } else {
      json[r'deviceId'] = null;
    }
    if (this.positionId != null) {
      json[r'positionId'] = this.positionId;
    } else {
      json[r'positionId'] = null;
    }
    if (this.geofenceId != null) {
      json[r'geofenceId'] = this.geofenceId;
    } else {
      json[r'geofenceId'] = null;
    }
    if (this.maintenanceId != null) {
      json[r'maintenanceId'] = this.maintenanceId;
    } else {
      json[r'maintenanceId'] = null;
    }
    if (this.attributes != null) {
      json[r'attributes'] = this.attributes;
    } else {
      json[r'attributes'] = null;
    }
    return json;
  }

  /// Returns a new [Event] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Event? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "Event[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "Event[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return Event(
        id: mapValueOfType<int>(json, r'id'),
        type: mapValueOfType<String>(json, r'type'),
        eventTime: mapDateTime(json, r'eventTime', r''),
        deviceId: mapValueOfType<int>(json, r'deviceId'),
        positionId: mapValueOfType<int>(json, r'positionId'),
        geofenceId: mapValueOfType<int>(json, r'geofenceId'),
        maintenanceId: mapValueOfType<int>(json, r'maintenanceId'),
        attributes: mapValueOfType<Object>(json, r'attributes'),
      );
    }
    return null;
  }

  static List<Event> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <Event>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Event.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Event> mapFromJson(dynamic json) {
    final map = <String, Event>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Event.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Event-objects as value to a dart map
  static Map<String, List<Event>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<Event>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Event.listFromJson(
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
