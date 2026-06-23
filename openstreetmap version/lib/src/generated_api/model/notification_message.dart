//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class NotificationMessage {
  /// Returns a new [NotificationMessage] instance.
  NotificationMessage({
    required this.body,
    this.subject,
    this.digest,
    this.priority,
  });

  /// Full notification text
  String body;

  /// Subject or title of the notification
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? subject;

  /// Short summary shown in compact contexts; defaults to the body when omitted
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? digest;

  /// Whether the message should be treated as high priority
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? priority;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationMessage &&
          other.body == body &&
          other.subject == subject &&
          other.digest == digest &&
          other.priority == priority;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (body.hashCode) +
      (subject == null ? 0 : subject!.hashCode) +
      (digest == null ? 0 : digest!.hashCode) +
      (priority == null ? 0 : priority!.hashCode);

  @override
  String toString() =>
      'NotificationMessage[body=$body, subject=$subject, digest=$digest, priority=$priority]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'body'] = this.body;
    if (this.subject != null) {
      json[r'subject'] = this.subject;
    } else {
      json[r'subject'] = null;
    }
    if (this.digest != null) {
      json[r'digest'] = this.digest;
    } else {
      json[r'digest'] = null;
    }
    if (this.priority != null) {
      json[r'priority'] = this.priority;
    } else {
      json[r'priority'] = null;
    }
    return json;
  }

  /// Returns a new [NotificationMessage] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static NotificationMessage? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "NotificationMessage[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "NotificationMessage[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return NotificationMessage(
        body: mapValueOfType<String>(json, r'body')!,
        subject: mapValueOfType<String>(json, r'subject'),
        digest: mapValueOfType<String>(json, r'digest'),
        priority: mapValueOfType<bool>(json, r'priority'),
      );
    }
    return null;
  }

  static List<NotificationMessage> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <NotificationMessage>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = NotificationMessage.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, NotificationMessage> mapFromJson(dynamic json) {
    final map = <String, NotificationMessage>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = NotificationMessage.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of NotificationMessage-objects as value to a dart map
  static Map<String, List<NotificationMessage>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<NotificationMessage>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = NotificationMessage.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'body',
  };
}
