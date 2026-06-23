//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ShareApi {
  ShareApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Share device location
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] deviceId (required):
  ///
  /// * [DateTime] expiration (required):
  Future<Response> postShareDeviceWithHttpInfo(
    int deviceId,
    DateTime expiration,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/share/device';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/x-www-form-urlencoded'];

    if (deviceId != null) {
      formParams[r'deviceId'] = parameterToString(deviceId);
    }
    if (expiration != null) {
      formParams[r'expiration'] = parameterToString(expiration);
    }

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

  /// Share device location
  ///
  /// Parameters:
  ///
  /// * [int] deviceId (required):
  ///
  /// * [DateTime] expiration (required):
  Future<String?> postShareDevice(
    int deviceId,
    DateTime expiration,
  ) async {
    final response = await postShareDeviceWithHttpInfo(
      deviceId,
      expiration,
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

  /// Share group devices
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] groupId (required):
  ///
  /// * [DateTime] expiration (required):
  Future<Response> postShareGroupWithHttpInfo(
    int groupId,
    DateTime expiration,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/share/group';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/x-www-form-urlencoded'];

    if (groupId != null) {
      formParams[r'groupId'] = parameterToString(groupId);
    }
    if (expiration != null) {
      formParams[r'expiration'] = parameterToString(expiration);
    }

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

  /// Share group devices
  ///
  /// Parameters:
  ///
  /// * [int] groupId (required):
  ///
  /// * [DateTime] expiration (required):
  Future<String?> postShareGroup(
    int groupId,
    DateTime expiration,
  ) async {
    final response = await postShareGroupWithHttpInfo(
      groupId,
      expiration,
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
}
