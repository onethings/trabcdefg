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
  Future<Response> deletePositionsWithHttpInfo(
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
  Future<void> deletePositions(
    int deviceId,
    DateTime from,
    DateTime to,
  ) async {
    final response = await deletePositionsWithHttpInfo(
      deviceId,
      from,
      to,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Delete a Position
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Response> deletePositionsIdWithHttpInfo(
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
  Future<void> deletePositionsId(
    int id,
  ) async {
    final response = await deletePositionsIdWithHttpInfo(
      id,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Fetch a list of Positions
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
  Future<Response> getPositionsWithHttpInfo({
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

  /// Fetch a list of Positions
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
  Future<List<Position>?> getPositions({
    int? deviceId,
    DateTime? from,
    DateTime? to,
    int? id,
  }) async {
    final response = await getPositionsWithHttpInfo(
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

  /// Export Positions as CSV
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] deviceId (required):
  ///
  /// * [DateTime] from (required):
  ///
  /// * [DateTime] to (required):
  ///
  /// * [int] geofenceId:
  Future<Response> getPositionsCsvWithHttpInfo(
    int deviceId,
    DateTime from,
    DateTime to, {
    int? geofenceId,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/positions/csv';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    queryParams.addAll(_queryParams('', 'deviceId', deviceId));
    if (geofenceId != null) {
      queryParams.addAll(_queryParams('', 'geofenceId', geofenceId));
    }
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

  /// Export Positions as CSV
  ///
  /// Parameters:
  ///
  /// * [int] deviceId (required):
  ///
  /// * [DateTime] from (required):
  ///
  /// * [DateTime] to (required):
  ///
  /// * [int] geofenceId:
  Future<MultipartFile?> getPositionsCsv(
    int deviceId,
    DateTime from,
    DateTime to, {
    int? geofenceId,
  }) async {
    final response = await getPositionsCsvWithHttpInfo(
      deviceId,
      from,
      to,
      geofenceId: geofenceId,
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
        'MultipartFile',
      ) as MultipartFile;
    }
    return null;
  }

  /// Export Positions as GPX
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] deviceId (required):
  ///
  /// * [DateTime] from (required):
  ///
  /// * [DateTime] to (required):
  Future<Response> getPositionsGpxWithHttpInfo(
    int deviceId,
    DateTime from,
    DateTime to,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/positions/gpx';

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
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Export Positions as GPX
  ///
  /// Parameters:
  ///
  /// * [int] deviceId (required):
  ///
  /// * [DateTime] from (required):
  ///
  /// * [DateTime] to (required):
  Future<MultipartFile?> getPositionsGpx(
    int deviceId,
    DateTime from,
    DateTime to,
  ) async {
    final response = await getPositionsGpxWithHttpInfo(
      deviceId,
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
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'MultipartFile',
      ) as MultipartFile;
    }
    return null;
  }

  /// Export Positions as KML
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] deviceId (required):
  ///
  /// * [DateTime] from (required):
  ///
  /// * [DateTime] to (required):
  Future<Response> getPositionsKmlWithHttpInfo(
    int deviceId,
    DateTime from,
    DateTime to,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/positions/kml';

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
      'GET',
      queryParams,
      postBody,
      headerParams,
      formParams,
      contentTypes.isEmpty ? null : contentTypes.first,
    );
  }

  /// Export Positions as KML
  ///
  /// Parameters:
  ///
  /// * [int] deviceId (required):
  ///
  /// * [DateTime] from (required):
  ///
  /// * [DateTime] to (required):
  Future<MultipartFile?> getPositionsKml(
    int deviceId,
    DateTime from,
    DateTime to,
  ) async {
    final response = await getPositionsKmlWithHttpInfo(
      deviceId,
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
      return await apiClient.deserializeAsync(
        await _decodeBodyBytes(response),
        'MultipartFile',
      ) as MultipartFile;
    }
    return null;
  }
}
