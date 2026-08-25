//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CombinedReportItem {
  /// Returns a new [CombinedReportItem] instance.
  CombinedReportItem({
    this.deviceId,
    this.route = const [],
    this.events = const [],
    this.positions = const [],
  });

  /// Device identifier for the report item
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? deviceId;

  /// Simplified route as `[longitude, latitude]` pairs
  List<List<num>> route;

  List<Event> events;

  List<Position> positions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CombinedReportItem &&
          other.deviceId == deviceId &&
          _deepEquality.equals(other.route, route) &&
          _deepEquality.equals(other.events, events) &&
          _deepEquality.equals(other.positions, positions);

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (deviceId == null ? 0 : deviceId!.hashCode) +
      (route.hashCode) +
      (events.hashCode) +
      (positions.hashCode);

  @override
  String toString() =>
      'CombinedReportItem[deviceId=$deviceId, route=$route, events=$events, positions=$positions]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.deviceId != null) {
      json[r'deviceId'] = this.deviceId;
    } else {
      json[r'deviceId'] = null;
    }
    json[r'route'] = this.route;
    json[r'events'] = this.events;
    json[r'positions'] = this.positions;
    return json;
  }

  /// Returns a new [CombinedReportItem] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CombinedReportItem? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "CombinedReportItem[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "CombinedReportItem[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CombinedReportItem(
        deviceId: mapValueOfType<int>(json, r'deviceId'),
        route: json[r'route'] is List
            ? (json[r'route'] as List)
                .map((e) => e == null ? const <num>[] : (e as List).cast<num>())
                .toList()
            : const [],
        events: Event.listFromJson(json[r'events']),
        positions: Position.listFromJson(json[r'positions']),
      );
    }
    return null;
  }

  static List<CombinedReportItem> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <CombinedReportItem>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CombinedReportItem.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CombinedReportItem> mapFromJson(dynamic json) {
    final map = <String, CombinedReportItem>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CombinedReportItem.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CombinedReportItem-objects as value to a dart map
  static Map<String, List<CombinedReportItem>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<CombinedReportItem>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CombinedReportItem.listFromJson(
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
