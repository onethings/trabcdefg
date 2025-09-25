//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SessionApi {
  SessionApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Close the Session
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> sessionDeleteWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/session';

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

  /// Close the Session
  Future<void> sessionDelete() async {
    final response = await sessionDeleteWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Fetch Session information
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] token:
  Future<Response> sessionGetWithHttpInfo({
    String? token,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/session';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (token != null) {
      queryParams.addAll(_queryParams('', 'token', token));
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

  /// Fetch Session information
  ///
  /// Parameters:
  ///
  /// * [String] token:
  Future<User?> sessionGet({
    String? token,
  }) async {
    final response = await sessionGetWithHttpInfo(
      token: token,
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
        'User',
      ) as User;
    }
    return null;
  }

  /// Fetch Session information
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> sessionOpenidAuthGetWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/session/openid/auth';

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

  /// Fetch Session information
  Future<void> sessionOpenidAuthGet() async {
    final response = await sessionOpenidAuthGetWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// OpenID Callback
  ///
  /// Note: This method returns the HTTP [Response].
  Future<Response> sessionOpenidCallbackGetWithHttpInfo() async {
    // ignore: prefer_const_declarations
    final path = r'/session/openid/callback';

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

  /// OpenID Callback
  Future<void> sessionOpenidCallbackGet() async {
    final response = await sessionOpenidCallbackGetWithHttpInfo();
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Create a new Session
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] email (required):
  ///
  /// * [String] password (required):
  Future<Response> sessionPostWithHttpInfo(
    String email,
    String password,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/session';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/x-www-form-urlencoded'];

    if (email != null) {
      formParams[r'email'] = parameterToString(email);
    }
    if (password != null) {
      formParams[r'password'] = parameterToString(password);
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

  /// Create a new Session
  ///
  /// Parameters:
  ///
  /// * [String] email (required):
  ///
  /// * [String] password (required):
  Future<User?> sessionPost(
    String email,
    String password,
  ) async {
    final response = await sessionPostWithHttpInfo(
      email,
      password,
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
        'User',
      ) as User;
    }
    return null;
  }
}
