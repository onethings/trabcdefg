//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ReportsApi {
  ReportsApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Fetch a combined route, Events and Positions report for the Devices or Groups
  ///
  /// At least one _deviceId_ or one _groupId_ must be passed
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  Future<Response> getReportsCombinedWithHttpInfo(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/reports/combined';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deviceId != null) {
      queryParams.addAll(_queryParams('multi', 'deviceId', deviceId));
    }
    if (groupId != null) {
      queryParams.addAll(_queryParams('multi', 'groupId', groupId));
    }
    queryParams.addAll(_queryParams('', 'from', from));
    queryParams.addAll(_queryParams('', 'to', to));

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Fetch a combined route, Events and Positions report for the Devices or Groups
  ///
  /// At least one _deviceId_ or one _groupId_ must be passed
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  Future<List<CombinedReportItem>?> getReportsCombined(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    final response = await getReportsCombinedWithHttpInfo(
      from,
      to,
      deviceId: deviceId,
      groupId: groupId,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(
              responseBody, 'List<CombinedReportItem>') as List)
          .cast<CombinedReportItem>()
          .toList(growable: false);
    }
    return null;
  }

  /// Download the devices report as a spreadsheet or send it by email
  ///
  /// Use `type=xlsx` to download the report, `type=mail` to deliver it by email asynchronously.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] type (required):
  Future<Response> getReportsDevicesTypeWithHttpInfo(
    String type,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/reports/devices/{type}'.replaceAll('{type}', type);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Download the devices report as a spreadsheet or send it by email
  ///
  /// Use `type=xlsx` to download the report, `type=mail` to deliver it by email asynchronously.
  ///
  /// Parameters:
  ///
  /// * [String] type (required):
  Future<MultipartFile?> getReportsDevicesType(
    String type,
  ) async {
    final response = await getReportsDevicesTypeWithHttpInfo(
      type,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'MultipartFile',
      ) as MultipartFile;
    }
    return null;
  }

  /// Fetch a list of Events within the time period for the Devices or Groups
  ///
  /// At least one _deviceId_ or one _groupId_ must be passed
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  ///
  /// * [List<String>] type:
  ///   % can be used to return events of all types
  Future<Response> getReportsEventsWithHttpInfo(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
    List<String>? type,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/reports/events';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deviceId != null) {
      queryParams.addAll(_queryParams('multi', 'deviceId', deviceId));
    }
    if (groupId != null) {
      queryParams.addAll(_queryParams('multi', 'groupId', groupId));
    }
    if (type != null) {
      queryParams.addAll(_queryParams('csv', 'type', type));
    }
    queryParams.addAll(_queryParams('', 'from', from));
    queryParams.addAll(_queryParams('', 'to', to));

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Fetch a list of Events within the time period for the Devices or Groups
  ///
  /// At least one _deviceId_ or one _groupId_ must be passed
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  ///
  /// * [List<String>] type:
  ///   % can be used to return events of all types
  Future<List<Event>?> getReportsEvents(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
    List<String>? type,
  }) async {
    final response = await getReportsEventsWithHttpInfo(
      from,
      to,
      deviceId: deviceId,
      groupId: groupId,
      type: type,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<Event>')
              as List)
          .cast<Event>()
          .toList(growable: false);
    }
    return null;
  }

  /// Download the events report as a spreadsheet or send it by email
  ///
  /// Use `type=xlsx` to download the report, `type=mail` to deliver it by email asynchronously.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] type (required):
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  ///
  /// * [List<String>] type2:
  ///   Event types to include; `%` matches all
  ///
  /// * [List<String>] alarm:
  ///   Alarm types to include
  Future<Response> getReportsEventsTypeWithHttpInfo(
    String type,
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
    List<String>? type2,
    List<String>? alarm,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/reports/events/{type}'.replaceAll('{type}', type);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deviceId != null) {
      queryParams.addAll(_queryParams('multi', 'deviceId', deviceId));
    }
    if (groupId != null) {
      queryParams.addAll(_queryParams('multi', 'groupId', groupId));
    }
    if (type2 != null) {
      queryParams.addAll(_queryParams('csv', 'type', type2));
    }
    if (alarm != null) {
      queryParams.addAll(_queryParams('csv', 'alarm', alarm));
    }
    queryParams.addAll(_queryParams('', 'from', from));
    queryParams.addAll(_queryParams('', 'to', to));

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Download the events report as a spreadsheet or send it by email
  ///
  /// Use `type=xlsx` to download the report, `type=mail` to deliver it by email asynchronously.
  ///
  /// Parameters:
  ///
  /// * [String] type (required):
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  ///
  /// * [List<String>] type2:
  ///   Event types to include; `%` matches all
  ///
  /// * [List<String>] alarm:
  ///   Alarm types to include
  Future<MultipartFile?> getReportsEventsType(
    String type,
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
    List<String>? type2,
    List<String>? alarm,
  }) async {
    final response = await getReportsEventsTypeWithHttpInfo(
      type,
      from,
      to,
      deviceId: deviceId,
      groupId: groupId,
      type2: type2,
      alarm: alarm,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'MultipartFile',
      ) as MultipartFile;
    }
    return null;
  }

  /// Fetch geofence enter/exit intervals within the time period for Devices or Groups
  ///
  /// At least one _deviceId_ or one _groupId_ must be passed
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  ///
  /// * [List<int>] geofenceId:
  Future<Response> getReportsGeofencesWithHttpInfo(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
    List<int>? geofenceId,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/reports/geofences';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deviceId != null) {
      queryParams.addAll(_queryParams('multi', 'deviceId', deviceId));
    }
    if (groupId != null) {
      queryParams.addAll(_queryParams('multi', 'groupId', groupId));
    }
    if (geofenceId != null) {
      queryParams.addAll(_queryParams('multi', 'geofenceId', geofenceId));
    }
    queryParams.addAll(_queryParams('', 'from', from));
    queryParams.addAll(_queryParams('', 'to', to));

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Fetch geofence enter/exit intervals within the time period for Devices or Groups
  ///
  /// At least one _deviceId_ or one _groupId_ must be passed
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  ///
  /// * [List<int>] geofenceId:
  Future<List<ReportGeofences>?> getReportsGeofences(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
    List<int>? geofenceId,
  }) async {
    final response = await getReportsGeofencesWithHttpInfo(
      from,
      to,
      deviceId: deviceId,
      groupId: groupId,
      geofenceId: geofenceId,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(
              responseBody, 'List<ReportGeofences>') as List)
          .cast<ReportGeofences>()
          .toList(growable: false);
    }
    return null;
  }

  /// Fetch a list of Positions within the time period for the Devices or Groups
  ///
  /// At least one _deviceId_ or one _groupId_ must be passed
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  Future<Response> getReportsRouteWithHttpInfo(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/reports/route';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deviceId != null) {
      queryParams.addAll(_queryParams('multi', 'deviceId', deviceId));
    }
    if (groupId != null) {
      queryParams.addAll(_queryParams('multi', 'groupId', groupId));
    }
    queryParams.addAll(_queryParams('', 'from', from));
    queryParams.addAll(_queryParams('', 'to', to));

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Fetch a list of Positions within the time period for the Devices or Groups
  ///
  /// At least one _deviceId_ or one _groupId_ must be passed
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  Future<List<Position>?> getReportsRoute(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    final response = await getReportsRouteWithHttpInfo(
      from,
      to,
      deviceId: deviceId,
      groupId: groupId,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<Position>')
              as List)
          .cast<Position>()
          .toList(growable: false);
    }
    return null;
  }

  /// Download the route report as a spreadsheet or send it by email
  ///
  /// Use `type=xlsx` to download the report, `type=mail` to deliver it by email asynchronously.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] type (required):
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  Future<Response> getReportsRouteTypeWithHttpInfo(
    String type,
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/reports/route/{type}'.replaceAll('{type}', type);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deviceId != null) {
      queryParams.addAll(_queryParams('multi', 'deviceId', deviceId));
    }
    if (groupId != null) {
      queryParams.addAll(_queryParams('multi', 'groupId', groupId));
    }
    queryParams.addAll(_queryParams('', 'from', from));
    queryParams.addAll(_queryParams('', 'to', to));

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Download the route report as a spreadsheet or send it by email
  ///
  /// Use `type=xlsx` to download the report, `type=mail` to deliver it by email asynchronously.
  ///
  /// Parameters:
  ///
  /// * [String] type (required):
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  Future<MultipartFile?> getReportsRouteType(
    String type,
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    final response = await getReportsRouteTypeWithHttpInfo(
      type,
      from,
      to,
      deviceId: deviceId,
      groupId: groupId,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'MultipartFile',
      ) as MultipartFile;
    }
    return null;
  }

  /// Fetch a list of ReportStops within the time period for the Devices or Groups
  ///
  /// At least one _deviceId_ or one _groupId_ must be passed
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  Future<Response> getReportsStopsWithHttpInfo(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/reports/stops';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deviceId != null) {
      queryParams.addAll(_queryParams('multi', 'deviceId', deviceId));
    }
    if (groupId != null) {
      queryParams.addAll(_queryParams('multi', 'groupId', groupId));
    }
    queryParams.addAll(_queryParams('', 'from', from));
    queryParams.addAll(_queryParams('', 'to', to));

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Fetch a list of ReportStops within the time period for the Devices or Groups
  ///
  /// At least one _deviceId_ or one _groupId_ must be passed
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  Future<List<ReportStops>?> getReportsStops(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    final response = await getReportsStopsWithHttpInfo(
      from,
      to,
      deviceId: deviceId,
      groupId: groupId,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(
              responseBody, 'List<ReportStops>') as List)
          .cast<ReportStops>()
          .toList(growable: false);
    }
    return null;
  }

  /// Download the stops report as a spreadsheet or send it by email
  ///
  /// Use `type=xlsx` to download the report, `type=mail` to deliver it by email asynchronously.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] type (required):
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  Future<Response> getReportsStopsTypeWithHttpInfo(
    String type,
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/reports/stops/{type}'.replaceAll('{type}', type);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deviceId != null) {
      queryParams.addAll(_queryParams('multi', 'deviceId', deviceId));
    }
    if (groupId != null) {
      queryParams.addAll(_queryParams('multi', 'groupId', groupId));
    }
    queryParams.addAll(_queryParams('', 'from', from));
    queryParams.addAll(_queryParams('', 'to', to));

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Download the stops report as a spreadsheet or send it by email
  ///
  /// Use `type=xlsx` to download the report, `type=mail` to deliver it by email asynchronously.
  ///
  /// Parameters:
  ///
  /// * [String] type (required):
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  Future<MultipartFile?> getReportsStopsType(
    String type,
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    final response = await getReportsStopsTypeWithHttpInfo(
      type,
      from,
      to,
      deviceId: deviceId,
      groupId: groupId,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'MultipartFile',
      ) as MultipartFile;
    }
    return null;
  }

  /// Fetch a list of ReportSummary within the time period for the Devices or Groups
  ///
  /// At least one _deviceId_ or one _groupId_ must be passed
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  Future<Response> getReportsSummaryWithHttpInfo(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/reports/summary';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deviceId != null) {
      queryParams.addAll(_queryParams('multi', 'deviceId', deviceId));
    }
    if (groupId != null) {
      queryParams.addAll(_queryParams('multi', 'groupId', groupId));
    }
    queryParams.addAll(_queryParams('', 'from', from));
    queryParams.addAll(_queryParams('', 'to', to));

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Fetch a list of ReportSummary within the time period for the Devices or Groups
  ///
  /// At least one _deviceId_ or one _groupId_ must be passed
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  Future<List<ReportSummary>?> getReportsSummary(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    final response = await getReportsSummaryWithHttpInfo(
      from,
      to,
      deviceId: deviceId,
      groupId: groupId,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(
              responseBody, 'List<ReportSummary>') as List)
          .cast<ReportSummary>()
          .toList(growable: false);
    }
    return null;
  }

  /// Download the summary report as a spreadsheet or send it by email
  ///
  /// Use `type=xlsx` to download the report, `type=mail` to deliver it by email asynchronously.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] type (required):
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  ///
  /// * [bool] daily:
  ///   Aggregate values by day instead of the full period
  Future<Response> getReportsSummaryTypeWithHttpInfo(
    String type,
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
    bool? daily,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/reports/summary/{type}'.replaceAll('{type}', type);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deviceId != null) {
      queryParams.addAll(_queryParams('multi', 'deviceId', deviceId));
    }
    if (groupId != null) {
      queryParams.addAll(_queryParams('multi', 'groupId', groupId));
    }
    queryParams.addAll(_queryParams('', 'from', from));
    queryParams.addAll(_queryParams('', 'to', to));
    if (daily != null) {
      queryParams.addAll(_queryParams('', 'daily', daily));
    }

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Download the summary report as a spreadsheet or send it by email
  ///
  /// Use `type=xlsx` to download the report, `type=mail` to deliver it by email asynchronously.
  ///
  /// Parameters:
  ///
  /// * [String] type (required):
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  ///
  /// * [bool] daily:
  ///   Aggregate values by day instead of the full period
  Future<MultipartFile?> getReportsSummaryType(
    String type,
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
    bool? daily,
  }) async {
    final response = await getReportsSummaryTypeWithHttpInfo(
      type,
      from,
      to,
      deviceId: deviceId,
      groupId: groupId,
      daily: daily,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'MultipartFile',
      ) as MultipartFile;
    }
    return null;
  }

  /// Fetch a list of ReportTrips within the time period for the Devices or Groups
  ///
  /// At least one _deviceId_ or one _groupId_ must be passed
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  Future<Response> getReportsTripsWithHttpInfo(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/reports/trips';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deviceId != null) {
      queryParams.addAll(_queryParams('multi', 'deviceId', deviceId));
    }
    if (groupId != null) {
      queryParams.addAll(_queryParams('multi', 'groupId', groupId));
    }
    queryParams.addAll(_queryParams('', 'from', from));
    queryParams.addAll(_queryParams('', 'to', to));

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Fetch a list of ReportTrips within the time period for the Devices or Groups
  ///
  /// At least one _deviceId_ or one _groupId_ must be passed
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  Future<List<ReportTrips>?> getReportsTrips(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    final response = await getReportsTripsWithHttpInfo(
      from,
      to,
      deviceId: deviceId,
      groupId: groupId,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(
              responseBody, 'List<ReportTrips>') as List)
          .cast<ReportTrips>()
          .toList(growable: false);
    }
    return null;
  }

  /// Download the trips report as a spreadsheet or send it by email
  ///
  /// Use `type=xlsx` to download the report, `type=mail` to deliver it by email asynchronously.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] type (required):
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  Future<Response> getReportsTripsTypeWithHttpInfo(
    String type,
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/reports/trips/{type}'.replaceAll('{type}', type);

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deviceId != null) {
      queryParams.addAll(_queryParams('multi', 'deviceId', deviceId));
    }
    if (groupId != null) {
      queryParams.addAll(_queryParams('multi', 'groupId', groupId));
    }
    queryParams.addAll(_queryParams('', 'from', from));
    queryParams.addAll(_queryParams('', 'to', to));

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Download the trips report as a spreadsheet or send it by email
  ///
  /// Use `type=xlsx` to download the report, `type=mail` to deliver it by email asynchronously.
  ///
  /// Parameters:
  ///
  /// * [String] type (required):
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [List<int>] deviceId:
  ///
  /// * [List<int>] groupId:
  Future<MultipartFile?> getReportsTripsType(
    String type,
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    final response = await getReportsTripsTypeWithHttpInfo(
      type,
      from,
      to,
      deviceId: deviceId,
      groupId: groupId,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'MultipartFile',
      ) as MultipartFile;
    }
    return null;
  }
}
