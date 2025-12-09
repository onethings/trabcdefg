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
  Future<Response> reportsEventsGetWithHttpInfo(
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
  Future<List<Event>?> reportsEventsGet(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
    List<String>? type,
  }) async {
    final response = await reportsEventsGetWithHttpInfo(
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
  Future<Response> reportsRouteGetWithHttpInfo(
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
  Future<List<Position>?> reportsRouteGet(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    final response = await reportsRouteGetWithHttpInfo(
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
  Future<Response> reportsStopsGetWithHttpInfo(
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
  Future<List<ReportStops>?> reportsStopsGet(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    final response = await reportsStopsGetWithHttpInfo(
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
  Future<Response> reportsSummaryGetWithHttpInfo(
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

// 🔥 CRITICAL FIX: Add the 'type=json' query parameter to force JSON response
    // This should finally resolve the 'PK' FormatException.
    queryParams.add(QueryParam('type', 'json'));

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
  Future<List<ReportSummary>?> reportsSummaryGet(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    final response = await reportsSummaryGetWithHttpInfo(
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
  Future<Response> reportsTripsGetWithHttpInfo(
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
  Future<List<ReportTrips>?> reportsTripsGet(
    DateTime from,
    DateTime to, {
    List<int>? deviceId,
    List<int>? groupId,
  }) async {
    final response = await reportsTripsGetWithHttpInfo(
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
}
