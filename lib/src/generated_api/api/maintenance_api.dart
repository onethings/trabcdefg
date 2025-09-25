//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class MaintenanceApi {
  MaintenanceApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Fetch a list of Maintenance
  ///
  /// Without params, it returns a list of Maintenance the user has access to
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [bool] all:
  ///   Can only be used by admins or managers to fetch all entities
  ///
  /// * [int] userId:
  ///   Standard users can use this only with their own _userId_
  ///
  /// * [int] deviceId:
  ///   Standard users can use this only with _deviceId_s, they have access to
  ///
  /// * [int] groupId:
  ///   Standard users can use this only with _groupId_s, they have access to
  ///
  /// * [bool] refresh:
  Future<Response> maintenanceGetWithHttpInfo({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    bool? refresh,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/maintenance';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (all != null) {
      queryParams.addAll(_queryParams('', 'all', all));
    }
    if (userId != null) {
      queryParams.addAll(_queryParams('', 'userId', userId));
    }
    if (deviceId != null) {
      queryParams.addAll(_queryParams('', 'deviceId', deviceId));
    }
    if (groupId != null) {
      queryParams.addAll(_queryParams('', 'groupId', groupId));
    }
    if (refresh != null) {
      queryParams.addAll(_queryParams('', 'refresh', refresh));
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

  /// Fetch a list of Maintenance
  ///
  /// Without params, it returns a list of Maintenance the user has access to
  ///
  /// Parameters:
  ///
  /// * [bool] all:
  ///   Can only be used by admins or managers to fetch all entities
  ///
  /// * [int] userId:
  ///   Standard users can use this only with their own _userId_
  ///
  /// * [int] deviceId:
  ///   Standard users can use this only with _deviceId_s, they have access to
  ///
  /// * [int] groupId:
  ///   Standard users can use this only with _groupId_s, they have access to
  ///
  /// * [bool] refresh:
  Future<List<Maintenance>?> maintenanceGet({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    bool? refresh,
  }) async {
    final response = await maintenanceGetWithHttpInfo(
      all: all,
      userId: userId,
      deviceId: deviceId,
      groupId: groupId,
      refresh: refresh,
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
              responseBody, 'List<Maintenance>') as List)
          .cast<Maintenance>()
          .toList(growable: false);
    }
    return null;
  }

  /// Delete a Maintenance
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Response> maintenanceIdDeleteWithHttpInfo(
    int id,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/maintenance/{id}'.replaceAll('{id}', id.toString());

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];

    return apiClient.invokeAPI(
      path,
      'DELETE',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Delete a Maintenance
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<void> maintenanceIdDelete(
    int id,
  ) async {
    final response = await maintenanceIdDeleteWithHttpInfo(
      id,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Update a Maintenance
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [Maintenance] body (required):
  Future<Response> maintenanceIdPutWithHttpInfo(
    int id,
    Maintenance body,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/maintenance/{id}'.replaceAll('{id}', id.toString());

    // ignore: prefer_final_locals
    Object? postBody = body;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];

    return apiClient.invokeAPI(
      path,
      'PUT',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Update a Maintenance
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [Maintenance] body (required):
  Future<Maintenance?> maintenanceIdPut(
    int id,
    Maintenance body,
  ) async {
    final response = await maintenanceIdPutWithHttpInfo(
      id,
      body,
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
        'Maintenance',
      ) as Maintenance;
    }
    return null;
  }

  /// Create a Maintenance
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [Maintenance] body (required):
  Future<Response> maintenancePostWithHttpInfo(
    Maintenance body,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/maintenance';

    // ignore: prefer_final_locals
    Object? postBody = body;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];

    return apiClient.invokeAPI(
      path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Create a Maintenance
  ///
  /// Parameters:
  ///
  /// * [Maintenance] body (required):
  Future<Maintenance?> maintenancePost(
    Maintenance body,
  ) async {
    final response = await maintenancePostWithHttpInfo(
      body,
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
        'Maintenance',
      ) as Maintenance;
    }
    return null;
  }
}
