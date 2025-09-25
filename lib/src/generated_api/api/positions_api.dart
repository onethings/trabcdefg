//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PositionsApi {
  PositionsApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Deletes all the Positions of a device in the time span specified
  ///
  ///
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] deviceId (required):
  ///
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  Future<Response> positionsDeleteWithHttpInfo(
    int deviceId,
    DateTime from,
    DateTime to,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/positions';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    queryParams.addAll(_queryParams('', 'deviceId', deviceId));
    queryParams.addAll(_queryParams('', 'from', from));
    queryParams.addAll(_queryParams('', 'to', to));

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

  /// Deletes all the Positions of a device in the time span specified
  ///
  ///
  ///
  /// Parameters:
  ///
  /// * [int] deviceId (required):
  ///
  ///
  /// * [DateTime] from (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to (required):
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  Future<void> positionsDelete(
    int deviceId,
    DateTime from,
    DateTime to,
  ) async {
    final response = await positionsDeleteWithHttpInfo(
      deviceId,
      from,
      to,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Fetches a list of Positions
  ///
  /// We strongly recommend using [Traccar WebSocket API](https://www.traccar.org/traccar-api/) instead of periodically polling positions endpoint. Without any params, it returns a list of last known positions for all the user's Devices. _from_ and _to_ fields are not required with _id_.
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] deviceId:
  ///   _deviceId_ is optional, but requires the _from_ and _to_ parameters when used
  ///
  /// * [DateTime] from:
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to:
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [int] id:
  ///   To fetch one or more positions. Multiple params can be passed like `id=31&id=42`
  Future<Response> positionsGetWithHttpInfo({
    int? deviceId,
    DateTime? from,
    DateTime? to,
    int? id,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/positions';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deviceId != null) {
      queryParams.addAll(_queryParams('', 'deviceId', deviceId));
    }
    if (from != null) {
      queryParams.addAll(_queryParams('', 'from', from));
    }
    if (to != null) {
      queryParams.addAll(_queryParams('', 'to', to));
    }
    if (id != null) {
      queryParams.addAll(_queryParams('', 'id', id));
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

  /// Fetches a list of Positions
  ///
  /// We strongly recommend using [Traccar WebSocket API](https://www.traccar.org/traccar-api/) instead of periodically polling positions endpoint. Without any params, it returns a list of last known positions for all the user's Devices. _from_ and _to_ fields are not required with _id_.
  ///
  /// Parameters:
  ///
  /// * [int] deviceId:
  ///   _deviceId_ is optional, but requires the _from_ and _to_ parameters when used
  ///
  /// * [DateTime] from:
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [DateTime] to:
  ///   in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
  ///
  /// * [int] id:
  ///   To fetch one or more positions. Multiple params can be passed like `id=31&id=42`
  Future<List<Position>?> positionsGet({
    int? deviceId,
    DateTime? from,
    DateTime? to,
    int? id,
  }) async {
    final response = await positionsGetWithHttpInfo(
      deviceId: deviceId,
      from: from,
      to: to,
      id: id,
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
      return (await apiClient.deserializeAsync(responseBody, 'List<Position>')
              as List)
          .cast<Position>()
          .toList(growable: false);
    }
    return null;
  }

  /// Delete a Position
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Response> positionsIdDeleteWithHttpInfo(
    int id,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/positions/{id}'.replaceAll('{id}', id.toString());

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

  /// Delete a Position
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<void> positionsIdDelete(
    int id,
  ) async {
    final response = await positionsIdDeleteWithHttpInfo(
      id,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }
}
