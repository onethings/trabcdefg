//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ServerApi {
  ServerApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Fetch Server information
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getServerWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/server';

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

  /// Fetch Server information
  Future<Server?> getServer() async {
    final response = await getServerWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'Server',
      ) as Server;
    }
    return null;
  }

  /// Fetch cache diagnostics
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getServerCacheWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/server/cache';

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

  /// Fetch cache diagnostics
  Future<String?> getServerCache() async {
    final response = await getServerCacheWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'String',
      ) as String;
    }
    return null;
  }

  /// Trigger garbage collection
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getServerGcWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/server/gc';

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

  /// Trigger garbage collection
  Future<void> getServerGc() async {
    final response = await getServerGcWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Reverse geocode coordinates
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [double] latitude (required):
  ///
  /// * [double] longitude (required):
  Future<Response> getServerGeocodeWithHttpInfo(
    double latitude,
    double longitude,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/server/geocode';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    queryParams.addAll(_queryParams('', 'latitude', latitude));
    queryParams.addAll(_queryParams('', 'longitude', longitude));

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

  /// Reverse geocode coordinates
  ///
  /// Parameters:
  ///
  /// * [double] latitude (required):
  ///
  /// * [double] longitude (required):
  Future<String?> getServerGeocode(
    double latitude,
    double longitude,
  ) async {
    final response = await getServerGeocodeWithHttpInfo(
      latitude,
      longitude,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'String',
      ) as String;
    }
    return null;
  }

  /// Fetch available timezones
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getServerTimezonesWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/server/timezones';

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

  /// Fetch available timezones
  Future<List<String>?> getServerTimezones() async {
    final response = await getServerTimezonesWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<String>') as List).cast<String>().toList(growable: false);
    }
    return null;
  }

  /// Upload a server file
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] path (required):
  ///
  /// * [MultipartFile] body (required):
  Future<Response> postServerFilePathWithHttpInfo(
    String path,
    MultipartFile body,
  ) async {
    // ignore: prefer_const_declarations
    final _path = r'/server/file/{path}'.replaceAll('{path}', path);

    // ignore: prefer_final_locals
    Object? postBody = body;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/octet-stream'];

    return apiClient.invokeAPI(
      _path,
      'POST',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Upload a server file
  ///
  /// Parameters:
  ///
  /// * [String] path (required):
  ///
  /// * [MultipartFile] body (required):
  Future<void> postServerFilePath(
    String path,
    MultipartFile body,
  ) async {
    final response = await postServerFilePathWithHttpInfo(
      path,
      body,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Reboot the server process
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> postServerRebootWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/server/reboot';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>[];

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

  /// Reboot the server process
  Future<void> postServerReboot() async {
    final response = await postServerRebootWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Update Server information
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [Server] server (required):
  Future<Response> putServerWithHttpInfo(
    Server server,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/server';

    // ignore: prefer_final_locals
    Object? postBody = server;

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

  /// Update Server information
  ///
  /// Parameters:
  ///
  /// * [Server] server (required):
  Future<Server?> putServer(
    Server server,
  ) async {
    final response = await putServerWithHttpInfo(
      server,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty && response.statusCode != HttpStatus.noContent) {
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'Server',
      ) as Server;
    }
    return null;
  }
}
