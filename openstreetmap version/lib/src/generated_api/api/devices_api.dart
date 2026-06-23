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

  /// Delete a Device
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Response> deleteDevicesIdWithHttpInfo(
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
  Future<void> deleteDevicesId(
    int id,
  ) async {
    final response = await deleteDevicesIdWithHttpInfo(
      id,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

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
  ///
  /// * [bool] excludeAttributes:
  ///   Exclude attributes field from device payload
  ///
  /// * [int] limit:
  ///   Limit the number of returned results
  ///
  /// * [int] offset:
  ///   Offset for pagination
  ///
  /// * [String] keyword:
  ///   Search keyword filter (searches name, uniqueId, phone, model, contact)
  Future<Response> getDevicesWithHttpInfo({
    bool? all,
    int? userId,
    int? id,
    String? uniqueId,
    bool? excludeAttributes,
    int? limit,
    int? offset,
    String? keyword,
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
    if (excludeAttributes != null) {
      queryParams
          .addAll(_queryParams('', 'excludeAttributes', excludeAttributes));
    }
    if (limit != null) {
      queryParams.addAll(_queryParams('', 'limit', limit));
    }
    if (offset != null) {
      queryParams.addAll(_queryParams('', 'offset', offset));
    }
    if (keyword != null) {
      queryParams.addAll(_queryParams('', 'keyword', keyword));
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
  ///
  /// * [bool] excludeAttributes:
  ///   Exclude attributes field from device payload
  ///
  /// * [int] limit:
  ///   Limit the number of returned results
  ///
  /// * [int] offset:
  ///   Offset for pagination
  ///
  /// * [String] keyword:
  ///   Search keyword filter (searches name, uniqueId, phone, model, contact)
  Future<List<Device>?> getDevices({
    bool? all,
    int? userId,
    int? id,
    String? uniqueId,
    bool? excludeAttributes,
    int? limit,
    int? offset,
    String? keyword,
  }) async {
    final response = await getDevicesWithHttpInfo(
      all: all,
      userId: userId,
      id: id,
      uniqueId: uniqueId,
      excludeAttributes: excludeAttributes,
      limit: limit,
      offset: offset,
      keyword: keyword,
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

  /// Fetch a Device
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Response> getDevicesIdWithHttpInfo(
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
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Fetch a Device
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Device?> getDevicesId(
    int id,
  ) async {
    final response = await getDevicesIdWithHttpInfo(
      id,
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
  /// * [Device] device (required):
  Future<Response> postDevicesWithHttpInfo(
    Device device,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/devices';

    // ignore: prefer_final_locals
    Object? postBody = device;

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
  /// * [Device] device (required):
  Future<Device?> postDevices(
    Device device,
  ) async {
    final response = await postDevicesWithHttpInfo(
      device,
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

  /// Upload/Update Device image
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [MultipartFile] body (required):
  Future<Response> postDevicesIdImageWithHttpInfo(
    int id,
    MultipartFile body,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/devices/{id}/image'.replaceAll('{id}', id.toString());

    // ignore: prefer_final_locals
    Object? postBody = body;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['image/*'];

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

  /// Upload/Update Device image
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [MultipartFile] body (required):
  Future<String?> postDevicesIdImage(
    int id,
    MultipartFile body,
  ) async {
    final response = await postDevicesIdImageWithHttpInfo(
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
        'String',
      ) as String;
    }
    return null;
  }

  /// Update a Device
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [Device] device (required):
  Future<Response> putDevicesIdWithHttpInfo(
    int id,
    Device device,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/devices/{id}'.replaceAll('{id}', id.toString());

    // ignore: prefer_final_locals
    Object? postBody = device;

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
  /// * [Device] device (required):
  Future<Device?> putDevicesId(
    int id,
    Device device,
  ) async {
    final response = await putDevicesIdWithHttpInfo(
      id,
      device,
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

  /// Update total distance and hours of the Device
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [DeviceAccumulators] deviceAccumulators (required):
  Future<Response> putDevicesIdAccumulatorsWithHttpInfo(
    int id,
    DeviceAccumulators deviceAccumulators,
  ) async {
    // ignore: prefer_const_declarations
    final path =
        r'/devices/{id}/accumulators'.replaceAll('{id}', id.toString());

    // ignore: prefer_final_locals
    Object? postBody = deviceAccumulators;

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
  /// * [DeviceAccumulators] deviceAccumulators (required):
  Future<void> putDevicesIdAccumulators(
    int id,
    DeviceAccumulators deviceAccumulators,
  ) async {
    final response = await putDevicesIdAccumulatorsWithHttpInfo(
      id,
      deviceAccumulators,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }
}
