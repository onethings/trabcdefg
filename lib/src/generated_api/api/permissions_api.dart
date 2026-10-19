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
  /// * [Permission] permission (required):
  Future<Response> deletePermissionsWithHttpInfo(
    Permission permission,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/permissions';

    // ignore: prefer_final_locals
    Object? postBody = permission;

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
  /// * [Permission] permission (required):
  Future<void> deletePermissions(
    Permission permission,
  ) async {
    final response = await deletePermissionsWithHttpInfo(
      permission,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Unlink multiple Objects in a single request
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [List<Permission>] permission (required):
  Future<Response> deletePermissionsBulkWithHttpInfo(
    List<Permission> permission,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/permissions/bulk';

    // ignore: prefer_final_locals
    Object? postBody = permission;

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

  /// Unlink multiple Objects in a single request
  ///
  /// Parameters:
  ///
  /// * [List<Permission>] permission (required):
  Future<void> deletePermissionsBulk(
    List<Permission> permission,
  ) async {
    final response = await deletePermissionsBulkWithHttpInfo(
      permission,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Fetch permission links between Objects
  ///
  /// Provide exactly two `*Id` query parameters matching the Permission body shape (e.g. `reportId` and `deviceId`). Use `0` on a side to mean \"any\", e.g. `?reportId=5&deviceId=0` lists all devices linked to report 5. At least one side must be non-zero.
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> getPermissionsWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/permissions';

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

  /// Fetch permission links between Objects
  ///
  /// Provide exactly two `*Id` query parameters matching the Permission body shape (e.g. `reportId` and `deviceId`). Use `0` on a side to mean \"any\", e.g. `?reportId=5&deviceId=0` lists all devices linked to report 5. At least one side must be non-zero.
  Future<List<Permission>?> getPermissions() async {
    final response = await getPermissionsWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
    // When a remote server returns no body with a status of 204, we shall not decode it.
    // At the time of writing this, `dart:convert` will throw an "Unexpected end of input"
    // FormatException when trying to decode an empty string.
    if (response.body.isNotEmpty &&
        response.statusCode != HttpStatus.noContent) {
      final responseBody = await _decodeBodyBytes(response);
      return (await apiClient.deserializeAsync(responseBody, 'List<Permission>')
              as List)
          .cast<Permission>()
          .toList(growable: false);
    }
    return null;
  }

  /// Link an Object to another Object
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [Permission] permission (required):
  Future<Response> postPermissionsWithHttpInfo(
    Permission permission,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/permissions';

    // ignore: prefer_final_locals
    Object? postBody = permission;

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
  /// * [Permission] permission (required):
  Future<void> postPermissions(
    Permission permission,
  ) async {
    final response = await postPermissionsWithHttpInfo(
      permission,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Link multiple Objects in a single request
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [List<Permission>] permission (required):
  Future<Response> postPermissionsBulkWithHttpInfo(
    List<Permission> permission,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/permissions/bulk';

    // ignore: prefer_final_locals
    Object? postBody = permission;

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

  /// Link multiple Objects in a single request
  ///
  /// Parameters:
  ///
  /// * [List<Permission>] permission (required):
  Future<void> postPermissionsBulk(
    List<Permission> permission,
  ) async {
    final response = await postPermissionsBulkWithHttpInfo(
      permission,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }
}
