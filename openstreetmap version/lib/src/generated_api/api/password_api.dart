//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PasswordApi {
  PasswordApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Send password reset email
  ///
  /// Always responds with `200` regardless of whether the email matches a user.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] email (required):
  Future<Response> postPasswordResetWithHttpInfo(
    String email,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/password/reset';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/x-www-form-urlencoded'];

    if (email != null) {
      formParams[r'email'] = parameterToString(email);
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

  /// Send password reset email
  ///
  /// Always responds with `200` regardless of whether the email matches a user.
  ///
  /// Parameters:
  ///
  /// * [String] email (required):
  Future<void> postPasswordReset(
    String email,
  ) async {
    final response = await postPasswordResetWithHttpInfo(
      email,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Set a new password using a reset token
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [String] token (required):
  ///
  /// * [String] password (required):
  Future<Response> postPasswordUpdateWithHttpInfo(
    String token,
    String password,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/password/update';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    const contentTypes = <String>['application/x-www-form-urlencoded'];

    if (token != null) {
      formParams[r'token'] = parameterToString(token);
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

  /// Set a new password using a reset token
  ///
  /// Parameters:
  ///
  /// * [String] token (required):
  ///
  /// * [String] password (required):
  Future<void> postPasswordUpdate(
    String token,
    String password,
  ) async {
    final response = await postPasswordUpdateWithHttpInfo(
      token,
      password,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }
}
