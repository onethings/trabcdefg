//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class Permission {
  /// Returns a new [Permission] instance.
  Permission({
    this.userId,
    this.deviceId,
    this.groupId,
    this.geofenceId,
    this.notificationId,
    this.calendarId,
    this.attributeId,
    this.driverId,
    this.managedUserId,
    this.commandId,
  });

  /// User id, can be only first parameter
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? userId;

  /// Device id, can be first parameter or second only in combination with userId
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? deviceId;

  /// Group id, can be first parameter or second only in combination with userId
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? groupId;

  /// Geofence id, can be second parameter only
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? geofenceId;

  /// Notification id, can be second parameter only
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? notificationId;

  /// Calendar id, can be second parameter only and only in combination with userId
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? calendarId;

  /// Computed attribute id, can be second parameter only
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? attributeId;

  /// Driver id, can be second parameter only
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? driverId;

  /// User id, can be second parameter only and only in combination with userId
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? managedUserId;

  /// Saved command id, can be second parameter only
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? commandId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Permission &&
          other.userId == userId &&
          other.deviceId == deviceId &&
          other.groupId == groupId &&
          other.geofenceId == geofenceId &&
          other.notificationId == notificationId &&
          other.calendarId == calendarId &&
          other.attributeId == attributeId &&
          other.driverId == driverId &&
          other.managedUserId == managedUserId &&
          other.commandId == commandId;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (userId == null ? 0 : userId!.hashCode) +
      (deviceId == null ? 0 : deviceId!.hashCode) +
      (groupId == null ? 0 : groupId!.hashCode) +
      (geofenceId == null ? 0 : geofenceId!.hashCode) +
      (notificationId == null ? 0 : notificationId!.hashCode) +
      (calendarId == null ? 0 : calendarId!.hashCode) +
      (attributeId == null ? 0 : attributeId!.hashCode) +
      (driverId == null ? 0 : driverId!.hashCode) +
      (managedUserId == null ? 0 : managedUserId!.hashCode) +
      (commandId == null ? 0 : commandId!.hashCode);

  @override
  String toString() =>
      'Permission[userId=$userId, deviceId=$deviceId, groupId=$groupId, geofenceId=$geofenceId, notificationId=$notificationId, calendarId=$calendarId, attributeId=$attributeId, driverId=$driverId, managedUserId=$managedUserId, commandId=$commandId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.userId != null) {
      json[r'userId'] = this.userId;
    } else {
      json[r'userId'] = null;
    }
    if (this.deviceId != null) {
      json[r'deviceId'] = this.deviceId;
    } else {
      json[r'deviceId'] = null;
    }
    if (this.groupId != null) {
      json[r'groupId'] = this.groupId;
    } else {
      json[r'groupId'] = null;
    }
    if (this.geofenceId != null) {
      json[r'geofenceId'] = this.geofenceId;
    } else {
      json[r'geofenceId'] = null;
    }
    if (this.notificationId != null) {
      json[r'notificationId'] = this.notificationId;
    } else {
      json[r'notificationId'] = null;
    }
    if (this.calendarId != null) {
      json[r'calendarId'] = this.calendarId;
    } else {
      json[r'calendarId'] = null;
    }
    if (this.attributeId != null) {
      json[r'attributeId'] = this.attributeId;
    } else {
      json[r'attributeId'] = null;
    }
    if (this.driverId != null) {
      json[r'driverId'] = this.driverId;
    } else {
      json[r'driverId'] = null;
    }
    if (this.managedUserId != null) {
      json[r'managedUserId'] = this.managedUserId;
    } else {
      json[r'managedUserId'] = null;
    }
    if (this.commandId != null) {
      json[r'commandId'] = this.commandId;
    } else {
      json[r'commandId'] = null;
    }
    return json;
  }

  /// Returns a new [Permission] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Permission? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "Permission[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "Permission[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return Permission(
        userId: mapValueOfType<int>(json, r'userId'),
        deviceId: mapValueOfType<int>(json, r'deviceId'),
        groupId: mapValueOfType<int>(json, r'groupId'),
        geofenceId: mapValueOfType<int>(json, r'geofenceId'),
        notificationId: mapValueOfType<int>(json, r'notificationId'),
        calendarId: mapValueOfType<int>(json, r'calendarId'),
        attributeId: mapValueOfType<int>(json, r'attributeId'),
        driverId: mapValueOfType<int>(json, r'driverId'),
        managedUserId: mapValueOfType<int>(json, r'managedUserId'),
        commandId: mapValueOfType<int>(json, r'commandId'),
      );
    }
    return null;
  }

  static List<Permission> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <Permission>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Permission.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Permission> mapFromJson(dynamic json) {
    final map = <String, Permission>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Permission.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Permission-objects as value to a dart map
  static Map<String, List<Permission>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<Permission>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Permission.listFromJson(
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
