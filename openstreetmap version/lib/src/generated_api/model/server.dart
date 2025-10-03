//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class Server {
  /// Returns a new [Server] instance.
  Server({
    this.id,
    this.registration,
    this.readonly,
    this.deviceReadonly,
    this.limitCommands,
    this.map,
    this.bingKey,
    this.mapUrl,
    this.poiLayer,
    this.latitude,
    this.longitude,
    this.zoom,
    this.version,
    this.forceSettings,
    this.coordinateFormat,
    this.openIdEnabled,
    this.openIdForce,
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
  bool? registration;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? readonly;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? deviceReadonly;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? limitCommands;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? map;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? bingKey;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? mapUrl;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? poiLayer;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  num? latitude;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  num? longitude;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  int? zoom;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? version;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? forceSettings;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  String? coordinateFormat;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? openIdEnabled;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  bool? openIdForce;

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
      other is Server &&
          other.id == id &&
          other.registration == registration &&
          other.readonly == readonly &&
          other.deviceReadonly == deviceReadonly &&
          other.limitCommands == limitCommands &&
          other.map == map &&
          other.bingKey == bingKey &&
          other.mapUrl == mapUrl &&
          other.poiLayer == poiLayer &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.zoom == zoom &&
          other.version == version &&
          other.forceSettings == forceSettings &&
          other.coordinateFormat == coordinateFormat &&
          other.openIdEnabled == openIdEnabled &&
          other.openIdForce == openIdForce &&
          other.attributes == attributes;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (id == null ? 0 : id!.hashCode) +
      (registration == null ? 0 : registration!.hashCode) +
      (readonly == null ? 0 : readonly!.hashCode) +
      (deviceReadonly == null ? 0 : deviceReadonly!.hashCode) +
      (limitCommands == null ? 0 : limitCommands!.hashCode) +
      (map == null ? 0 : map!.hashCode) +
      (bingKey == null ? 0 : bingKey!.hashCode) +
      (mapUrl == null ? 0 : mapUrl!.hashCode) +
      (poiLayer == null ? 0 : poiLayer!.hashCode) +
      (latitude == null ? 0 : latitude!.hashCode) +
      (longitude == null ? 0 : longitude!.hashCode) +
      (zoom == null ? 0 : zoom!.hashCode) +
      (version == null ? 0 : version!.hashCode) +
      (forceSettings == null ? 0 : forceSettings!.hashCode) +
      (coordinateFormat == null ? 0 : coordinateFormat!.hashCode) +
      (openIdEnabled == null ? 0 : openIdEnabled!.hashCode) +
      (openIdForce == null ? 0 : openIdForce!.hashCode) +
      (attributes == null ? 0 : attributes!.hashCode);

  @override
  String toString() =>
      'Server[id=$id, registration=$registration, readonly=$readonly, deviceReadonly=$deviceReadonly, limitCommands=$limitCommands, map=$map, bingKey=$bingKey, mapUrl=$mapUrl, poiLayer=$poiLayer, latitude=$latitude, longitude=$longitude, zoom=$zoom, version=$version, forceSettings=$forceSettings, coordinateFormat=$coordinateFormat, openIdEnabled=$openIdEnabled, openIdForce=$openIdForce, attributes=$attributes]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.id != null) {
      json[r'id'] = this.id;
    } else {
      json[r'id'] = null;
    }
    if (this.registration != null) {
      json[r'registration'] = this.registration;
    } else {
      json[r'registration'] = null;
    }
    if (this.readonly != null) {
      json[r'readonly'] = this.readonly;
    } else {
      json[r'readonly'] = null;
    }
    if (this.deviceReadonly != null) {
      json[r'deviceReadonly'] = this.deviceReadonly;
    } else {
      json[r'deviceReadonly'] = null;
    }
    if (this.limitCommands != null) {
      json[r'limitCommands'] = this.limitCommands;
    } else {
      json[r'limitCommands'] = null;
    }
    if (this.map != null) {
      json[r'map'] = this.map;
    } else {
      json[r'map'] = null;
    }
    if (this.bingKey != null) {
      json[r'bingKey'] = this.bingKey;
    } else {
      json[r'bingKey'] = null;
    }
    if (this.mapUrl != null) {
      json[r'mapUrl'] = this.mapUrl;
    } else {
      json[r'mapUrl'] = null;
    }
    if (this.poiLayer != null) {
      json[r'poiLayer'] = this.poiLayer;
    } else {
      json[r'poiLayer'] = null;
    }
    if (this.latitude != null) {
      json[r'latitude'] = this.latitude;
    } else {
      json[r'latitude'] = null;
    }
    if (this.longitude != null) {
      json[r'longitude'] = this.longitude;
    } else {
      json[r'longitude'] = null;
    }
    if (this.zoom != null) {
      json[r'zoom'] = this.zoom;
    } else {
      json[r'zoom'] = null;
    }
    if (this.version != null) {
      json[r'version'] = this.version;
    } else {
      json[r'version'] = null;
    }
    if (this.forceSettings != null) {
      json[r'forceSettings'] = this.forceSettings;
    } else {
      json[r'forceSettings'] = null;
    }
    if (this.coordinateFormat != null) {
      json[r'coordinateFormat'] = this.coordinateFormat;
    } else {
      json[r'coordinateFormat'] = null;
    }
    if (this.openIdEnabled != null) {
      json[r'openIdEnabled'] = this.openIdEnabled;
    } else {
      json[r'openIdEnabled'] = null;
    }
    if (this.openIdForce != null) {
      json[r'openIdForce'] = this.openIdForce;
    } else {
      json[r'openIdForce'] = null;
    }
    if (this.attributes != null) {
      json[r'attributes'] = this.attributes;
    } else {
      json[r'attributes'] = null;
    }
    return json;
  }

  /// Returns a new [Server] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Server? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key),
              'Required key "Server[$key]" is missing from JSON.');
          assert(json[key] != null,
              'Required key "Server[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return Server(
        id: mapValueOfType<int>(json, r'id'),
        registration: mapValueOfType<bool>(json, r'registration'),
        readonly: mapValueOfType<bool>(json, r'readonly'),
        deviceReadonly: mapValueOfType<bool>(json, r'deviceReadonly'),
        limitCommands: mapValueOfType<bool>(json, r'limitCommands'),
        map: mapValueOfType<String>(json, r'map'),
        bingKey: mapValueOfType<String>(json, r'bingKey'),
        mapUrl: mapValueOfType<String>(json, r'mapUrl'),
        poiLayer: mapValueOfType<String>(json, r'poiLayer'),
        latitude: num.parse('${json[r'latitude']}'),
        longitude: num.parse('${json[r'longitude']}'),
        zoom: mapValueOfType<int>(json, r'zoom'),
        version: mapValueOfType<String>(json, r'version'),
        forceSettings: mapValueOfType<bool>(json, r'forceSettings'),
        coordinateFormat: mapValueOfType<String>(json, r'coordinateFormat'),
        openIdEnabled: mapValueOfType<bool>(json, r'openIdEnabled'),
        openIdForce: mapValueOfType<bool>(json, r'openIdForce'),
        attributes: mapValueOfType<Object>(json, r'attributes'),
      );
    }
    return null;
  }

  static List<Server> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <Server>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Server.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Server> mapFromJson(dynamic json) {
    final map = <String, Server>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Server.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Server-objects as value to a dart map
  static Map<String, List<Server>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<Server>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Server.listFromJson(
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
