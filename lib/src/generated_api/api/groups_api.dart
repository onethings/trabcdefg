//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class GroupsApi {
  GroupsApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Fetch a list of Groups
  ///
  /// Without any params, returns a list of the Groups the user belongs to
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
  Future<Response> groupsGetWithHttpInfo({
    bool? all,
    int? userId,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/groups';

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

  /// Fetch a list of Groups
  ///
  /// Without any params, returns a list of the Groups the user belongs to
  ///
  /// Parameters:
  ///
  /// * [bool] all:
  ///   Can only be used by admins or managers to fetch all entities
  ///
  /// * [int] userId:
  ///   Standard users can use this only with their own _userId_
  Future<List<Group>?> groupsGet({
    bool? all,
    int? userId,
  }) async {
    final response = await groupsGetWithHttpInfo(
      all: all,
      userId: userId,
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
      return (await apiClient.deserializeAsync(responseBody, 'List<Group>')
              as List)
          .cast<Group>()
          .toList(growable: false);
    }
    return null;
  }

  /// Delete a Group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Response> groupsIdDeleteWithHttpInfo(
    int id,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/groups/{id}'.replaceAll('{id}', id.toString());

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

  /// Delete a Group
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<void> groupsIdDelete(
    int id,
  ) async {
    final response = await groupsIdDeleteWithHttpInfo(
      id,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Update a Group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [Group] body (required):
  Future<Response> groupsIdPutWithHttpInfo(
    int id,
    Group body,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/groups/{id}'.replaceAll('{id}', id.toString());

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

  /// Update a Group
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [Group] body (required):
  Future<Group?> groupsIdPut(
    int id,
    Group body,
  ) async {
    final response = await groupsIdPutWithHttpInfo(
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
        'Group',
      ) as Group;
    }
    return null;
  }

  /// Create a Group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [Group] body (required):
  Future<Response> groupsPostWithHttpInfo(
    Group body,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/groups';

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

  /// Create a Group
  ///
  /// Parameters:
  ///
  /// * [Group] body (required):
  Future<Group?> groupsPost(
    Group body,
  ) async {
    final response = await groupsPostWithHttpInfo(
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
        'Group',
      ) as Group;
    }
    return null;
  }
}
