//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class DevicesApi {
  DevicesApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Fetch a list of Devices
  ///
  /// Without any params, returns a list of the user's devices
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
  /// * [int] id:
  ///   To fetch one or more devices. Multiple params can be passed like `id=31&id=42`
  ///
  /// * [String] uniqueId:
  ///   To fetch one or more devices. Multiple params can be passed like `uniqueId=333331&uniqieId=44442`
  Future<Response> devicesGetWithHttpInfo({
    bool? all,
    int? userId,
    int? id,
    String? uniqueId,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/devices';

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
    if (id != null) {
      queryParams.addAll(_queryParams('', 'id', id));
    }
    if (uniqueId != null) {
      queryParams.addAll(_queryParams('', 'uniqueId', uniqueId));
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

  /// Fetch a list of Devices
  ///
  /// Without any params, returns a list of the user's devices
  ///
  /// Parameters:
  ///
  /// * [bool] all:
  ///   Can only be used by admins or managers to fetch all entities
  ///
  /// * [int] userId:
  ///   Standard users can use this only with their own _userId_
  ///
  /// * [int] id:
  ///   To fetch one or more devices. Multiple params can be passed like `id=31&id=42`
  ///
  /// * [String] uniqueId:
  ///   To fetch one or more devices. Multiple params can be passed like `uniqueId=333331&uniqieId=44442`
  Future<List<Device>?> devicesGet({
    bool? all,
    int? userId,
    int? id,
    String? uniqueId,
  }) async {
    final response = await devicesGetWithHttpInfo(
      all: all,
      userId: userId,
      id: id,
      uniqueId: uniqueId,
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
      return (await apiClient.deserializeAsync(responseBody, 'List<Device>')
              as List)
          .cast<Device>()
          .toList(growable: false);
    }
    return null;
  }

  /// Update total distance and hours of the Device
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [DeviceAccumulators] body (required):
  Future<Response> devicesIdAccumulatorsPutWithHttpInfo(
    int id,
    DeviceAccumulators body,
  ) async {
    // ignore: prefer_const_declarations
    final path =
        r'/devices/{id}/accumulators'.replaceAll('{id}', id.toString());

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

  /// Update total distance and hours of the Device
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [DeviceAccumulators] body (required):
  Future<void> devicesIdAccumulatorsPut(
    int id,
    DeviceAccumulators body,
  ) async {
    final response = await devicesIdAccumulatorsPutWithHttpInfo(
      id,
      body,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Delete a Device
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Response> devicesIdDeleteWithHttpInfo(
    int id,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/devices/{id}'.replaceAll('{id}', id.toString());

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

  /// Delete a Device
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<void> devicesIdDelete(
    int id,
  ) async {
    final response = await devicesIdDeleteWithHttpInfo(
      id,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Update a Device
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [Device] body (required):
  Future<Response> devicesIdPutWithHttpInfo(
    int id,
    Device body,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/devices/{id}'.replaceAll('{id}', id.toString());

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

  /// Update a Device
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [Device] body (required):
  Future<Device?> devicesIdPut(
    int id,
    Device body,
  ) async {
    final response = await devicesIdPutWithHttpInfo(
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
        'Device',
      ) as Device;
    }
    return null;
  }

  /// Create a Device
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [Device] body (required):
  Future<Response> devicesPostWithHttpInfo(
    Device body,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/devices';

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

  /// Create a Device
  ///
  /// Parameters:
  ///
  /// * [Device] body (required):
  Future<Device?> devicesPost(
    Device body,
  ) async {
    final response = await devicesPostWithHttpInfo(
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
        'Device',
      ) as Device;
    }
    return null;
  }
}
