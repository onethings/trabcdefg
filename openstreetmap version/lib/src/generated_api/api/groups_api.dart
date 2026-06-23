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

  /// Delete a Group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Response> deleteGroupsIdWithHttpInfo(
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
  Future<void> deleteGroupsId(
    int id,
  ) async {
    final response = await deleteGroupsIdWithHttpInfo(
      id,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

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
  ///
  /// * [int] limit:
  ///   Limit the number of returned results
  ///
  /// * [int] offset:
  ///   Offset for pagination
  ///
  /// * [String] keyword:
  ///   Search keyword filter
  Future<Response> getGroupsWithHttpInfo({
    bool? all,
    int? userId,
    int? limit,
    int? offset,
    String? keyword,
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
  ///
  /// * [int] limit:
  ///   Limit the number of returned results
  ///
  /// * [int] offset:
  ///   Offset for pagination
  ///
  /// * [String] keyword:
  ///   Search keyword filter
  Future<List<Group>?> getGroups({
    bool? all,
    int? userId,
    int? limit,
    int? offset,
    String? keyword,
  }) async {
    final response = await getGroupsWithHttpInfo(
      all: all,
      userId: userId,
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
      return (await apiClient.deserializeAsync(responseBody, 'List<Group>')
              as List)
          .cast<Group>()
          .toList(growable: false);
    }
    return null;
  }

  /// Fetch a Group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Response> getGroupsIdWithHttpInfo(
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
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Fetch a Group
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Group?> getGroupsId(
    int id,
  ) async {
    final response = await getGroupsIdWithHttpInfo(
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
  /// * [Group] group (required):
  Future<Response> postGroupsWithHttpInfo(
    Group group,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/groups';

    // ignore: prefer_final_locals
    Object? postBody = group;

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
  /// * [Group] group (required):
  Future<Group?> postGroups(
    Group group,
  ) async {
    final response = await postGroupsWithHttpInfo(
      group,
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

  /// Update a Group
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [Group] group (required):
  Future<Response> putGroupsIdWithHttpInfo(
    int id,
    Group group,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/groups/{id}'.replaceAll('{id}', id.toString());

    // ignore: prefer_final_locals
    Object? postBody = group;

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
  /// * [Group] group (required):
  Future<Group?> putGroupsId(
    int id,
    Group group,
  ) async {
    final response = await putGroupsIdWithHttpInfo(
      id,
      group,
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
