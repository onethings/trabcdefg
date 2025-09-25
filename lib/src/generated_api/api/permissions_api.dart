//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PermissionsApi {
  PermissionsApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Unlink an Object from another Object
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [Permission] body (required):
  Future<Response> permissionsDeleteWithHttpInfo(
    Permission body,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/permissions';

    // ignore: prefer_final_locals
    Object? postBody = body;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/json'];

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

  /// Unlink an Object from another Object
  ///
  /// Parameters:
  ///
  /// * [Permission] body (required):
  Future<void> permissionsDelete(
    Permission body,
  ) async {
    final response = await permissionsDeleteWithHttpInfo(
      body,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Link an Object to another Object
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [Permission] body (required):
  Future<Response> permissionsPostWithHttpInfo(
    Permission body,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/permissions';

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

  /// Link an Object to another Object
  ///
  /// Parameters:
  ///
  /// * [Permission] body (required):
  Future<void> permissionsPost(
    Permission body,
  ) async {
    final response = await permissionsPostWithHttpInfo(
      body,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }
}
