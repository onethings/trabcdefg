//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class Command {
  /// Returns a new [Command] instance.
  Command({
    this.id,
    this.deviceId,
    this.description,
    this.type,
    this.textChannel,
    this.attributes,
  });

  /// Unique saved command identifier
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? id;

  /// Target device identifier when the command is bound to one device
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? deviceId;

  /// User friendly label displayed in the UI
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? description;

  /// Command type as defined by the device protocol
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? type;

  /// Whether to send the command using the SMS channel
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? textChannel;

  /// Additional parameters required by the command type
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
      other is Command &&
          other.id == id &&
          other.deviceId == deviceId &&
          other.description == description &&
          other.type == type &&
          other.textChannel == textChannel &&
          other.attributes == attributes;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (id == null ? 0 : id!.hashCode) +
      (deviceId == null ? 0 : deviceId!.hashCode) +
      (description == null ? 0 : description!.hashCode) +
      (type == null ? 0 : type!.hashCode) +
      (textChannel == null ? 0 : textChannel!.hashCode) +
      (attributes == null ? 0 : attributes!.hashCode);

  @override
  String toString() =>
      'Command[id=$id, deviceId=$deviceId, description=$description, type=$type, textChannel=$textChannel, attributes=$attributes]';

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
    if (this.description != null) {
      json[r'description'] = this.description;
    } else {
      json[r'description'] = null;
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

  /// Returns a new [Command] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Command? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "Command[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "Command[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return Command(
        id: mapValueOfType<int>(json, r'id'),
        deviceId: mapValueOfType<int>(json, r'deviceId'),
        description: mapValueOfType<String>(json, r'description'),
        type: mapValueOfType<String>(json, r'type'),
        textChannel: mapValueOfType<bool>(json, r'textChannel'),
        attributes: mapValueOfType<Object>(json, r'attributes'),
      );
    }
    return null;
  }

  static List<Command> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <Command>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Command.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Command> mapFromJson(dynamic json) {
    final map = <String, Command>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Command.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Command-objects as value to a dart map
  static Map<String, List<Command>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<Command>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Command.listFromJson(
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
