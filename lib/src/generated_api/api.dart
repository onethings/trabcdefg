//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

library openapi.api;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

part 'api_client.dart';
part 'api_helper.dart';
part 'api_exception.dart';
part 'auth/authentication.dart';
part 'auth/api_key_auth.dart';
part 'auth/oauth.dart';
part 'auth/http_basic_auth.dart';
part 'auth/http_bearer_auth.dart';

part 'api/attributes_api.dart';
part 'api/calendars_api.dart';
part 'api/commands_api.dart';
part 'api/devices_api.dart';
part 'api/drivers_api.dart';
part 'api/events_api.dart';
part 'api/geofences_api.dart';
part 'api/groups_api.dart';
part 'api/maintenance_api.dart';
part 'api/notifications_api.dart';
part 'api/permissions_api.dart';
part 'api/positions_api.dart';
part 'api/reports_api.dart';
part 'api/server_api.dart';
part 'api/session_api.dart';
part 'api/statistics_api.dart';
part 'api/users_api.dart';

part 'model/attribute.dart';
part 'model/calendar.dart';
part 'model/command.dart';
part 'model/command_type.dart';
part 'model/device.dart';
part 'model/device_accumulators.dart';
part 'model/driver.dart';
part 'model/event.dart';
part 'model/geofence.dart';
part 'model/group.dart';
part 'model/maintenance.dart';
part 'model/notification.dart';
part 'model/notification_type.dart';
part 'model/permission.dart';
part 'model/position.dart';
part 'model/report_stops.dart';
part 'model/report_summary.dart';
part 'model/report_trips.dart';
part 'model/server.dart';
part 'model/statistics.dart';
part 'model/user.dart';

/// An [ApiClient] instance that uses the default values obtained from
/// the OpenAPI specification file.
var defaultApiClient = ApiClient();

const _delimiters = {'csv': ',', 'ssv': ' ', 'tsv': '\t', 'pipes': '|'};
const _dateEpochMarker = 'epoch';
const _deepEquality = DeepCollectionEquality();
final _dateFormatter = DateFormat('yyyy-MM-dd');
final _regList = RegExp(r'^List<(.*)>$');
final _regSet = RegExp(r'^Set<(.*)>$');
final _regMap = RegExp(r'^Map<String,(.*)>$');

bool _isEpochMarker(String? pattern) =>
    pattern == _dateEpochMarker || pattern == '/$_dateEpochMarker/';
