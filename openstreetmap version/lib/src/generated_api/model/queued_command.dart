//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class QueuedCommand {
  /// Returns a new [QueuedCommand] instance.
  QueuedCommand({
    this.id,
    this.deviceId,
    this.type,
    this.textChannel,
    this.attributes,
  });

  /// Identifier of the queued command job
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? id;

  /// Device identifier the queued command will be delivered to
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? deviceId;

  /// Command type that will be executed
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? type;

  /// Indicates whether the queued command uses SMS delivery
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? textChannel;

  /// Stored parameters for the queued command
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
      other is QueuedCommand &&
          other.id == id &&
          other.deviceId == deviceId &&
          other.type == type &&
          other.textChannel == textChannel &&
          other.attributes == attributes;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (id == null ? 0 : id!.hashCode) +
      (deviceId == null ? 0 : deviceId!.hashCode) +
      (type == null ? 0 : type!.hashCode) +
      (textChannel == null ? 0 : textChannel!.hashCode) +
      (attributes == null ? 0 : attributes!.hashCode);

  @override
  String toString() =>
      'QueuedCommand[id=$id, deviceId=$deviceId, type=$type, textChannel=$textChannel, attributes=$attributes]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.id != null) {
      json[r'id'] = this.id;
    } else {
      json[r'id'] = null;
    }
    if (this.deviceId != null) {
      json[r'deviceId'] = this.deviceId;
    } else {
      json[r'deviceId'] = null;
    }
    if (this.type != null) {
      json[r'type'] = this.type;
    } else {
      json[r'type'] = null;
    }
    if (this.textChannel != null) {
      json[r'textChannel'] = this.textChannel;
    } else {
      json[r'textChannel'] = null;
    }
    if (this.attributes != null) {
      json[r'attributes'] = this.attributes;
    } else {
      json[r'attributes'] = null;
    }
    return json;
  }

  /// Returns a new [QueuedCommand] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static QueuedCommand? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "QueuedCommand[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "QueuedCommand[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return QueuedCommand(
        id: mapValueOfType<int>(json, r'id'),
        deviceId: mapValueOfType<int>(json, r'deviceId'),
        type: mapValueOfType<String>(json, r'type'),
        textChannel: mapValueOfType<bool>(json, r'textChannel'),
        attributes: mapValueOfType<Object>(json, r'attributes'),
      );
    }
    return null;
  }

  static List<QueuedCommand> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <QueuedCommand>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = QueuedCommand.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, QueuedCommand> mapFromJson(dynamic json) {
    final map = <String, QueuedCommand>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = QueuedCommand.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of QueuedCommand-objects as value to a dart map
  static Map<String, List<QueuedCommand>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<QueuedCommand>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = QueuedCommand.listFromJson(
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
