//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class GeofencesApi {
  GeofencesApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Fetch a list of Geofences
  ///
  /// Without params, it returns a list of Geofences the user has access to
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
  Future<Response> geofencesGetWithHttpInfo({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    bool? refresh,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/geofences';

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

  /// Fetch a list of Geofences
  ///
  /// Without params, it returns a list of Geofences the user has access to
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
  Future<List<Geofence>?> geofencesGet({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    bool? refresh,
  }) async {
    final response = await geofencesGetWithHttpInfo(
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
      return (await apiClient.deserializeAsync(responseBody, 'List<Geofence>')
              as List)
          .cast<Geofence>()
          .toList(growable: false);
    }
    return null;
  }

  /// Delete a Geofence
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Response> geofencesIdDeleteWithHttpInfo(
    int id,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/geofences/{id}'.replaceAll('{id}', id.toString());

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

  /// Delete a Geofence
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<void> geofencesIdDelete(
    int id,
  ) async {
    final response = await geofencesIdDeleteWithHttpInfo(
      id,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Update a Geofence
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [Geofence] body (required):
  Future<Response> geofencesIdPutWithHttpInfo(
    int id,
    Geofence body,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/geofences/{id}'.replaceAll('{id}', id.toString());

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

  /// Update a Geofence
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [Geofence] body (required):
  Future<Geofence?> geofencesIdPut(
    int id,
    Geofence body,
  ) async {
    final response = await geofencesIdPutWithHttpInfo(
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
        'Geofence',
      ) as Geofence;
    }
    return null;
  }

  /// Create a Geofence
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [Geofence] body (required):
  Future<Response> geofencesPostWithHttpInfo(
    Geofence body,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/geofences';

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

  /// Create a Geofence
  ///
  /// Parameters:
  ///
  /// * [Geofence] body (required):
  Future<Geofence?> geofencesPost(
    Geofence body,
  ) async {
    final response = await geofencesPostWithHttpInfo(
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
        'Geofence',
      ) as Geofence;
    }
    return null;
  }
}
