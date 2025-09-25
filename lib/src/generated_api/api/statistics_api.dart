//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class StatisticsApi {
  StatisticsApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Fetch server Statistics
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  Future<Response> statisticsGetWithHttpInfo(
    DateTime from,
    DateTime to,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/statistics';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    queryParams.addAll(_queryParams('', 'from', from));
    queryParams.addAll(_queryParams('', 'to', to));

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

  /// Fetch server Statistics
  ///
  /// Parameters:
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  Future<List<Statistics>?> statisticsGet(
    DateTime from,
    DateTime to,
  ) async {
    final response = await statisticsGetWithHttpInfo(
      from,
      to,
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
      return (await apiClient.deserializeAsync(responseBody, 'List<Statistics>')
              as List)
          .cast<Statistics>()
          .toList(growable: false);
    }
    return null;
  }
}
