//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class StreamApi {
  StreamApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Fetch an HLS video segment for a Device camera channel
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] deviceId (required):
  ///
  /// * [int] channel (required):
  ///
  /// * [int] index (required):
  Future<Response> getStreamDeviceIdChannelIndexTsWithHttpInfo(
    int deviceId,
    int channel,
    int index,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/stream/{deviceId}/{channel}/{index}.ts'
        .replaceAll('{deviceId}', deviceId.toString())
        .replaceAll('{channel}', channel.toString())
        .replaceAll('{index}', index.toString());

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

  /// Fetch an HLS video segment for a Device camera channel
  ///
  /// Parameters:
  ///
  /// * [int] deviceId (required):
  ///
  /// * [int] channel (required):
  ///
  /// * [int] index (required):
  Future<MultipartFile?> getStreamDeviceIdChannelIndexTs(
    int deviceId,
    int channel,
    int index,
  ) async {
    final response = await getStreamDeviceIdChannelIndexTsWithHttpInfo(
      deviceId,
      channel,
      index,
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

  /// Fetch the HLS playlist for a Device camera channel
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] deviceId (required):
  ///
  /// * [int] channel (required):
  Future<Response> getStreamDeviceIdChannelLiveM3u8WithHttpInfo(
    int deviceId,
    int channel,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/stream/{deviceId}/{channel}/live.m3u8'
        .replaceAll('{deviceId}', deviceId.toString())
        .replaceAll('{channel}', channel.toString());

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

  /// Fetch the HLS playlist for a Device camera channel
  ///
  /// Parameters:
  ///
  /// * [int] deviceId (required):
  ///
  /// * [int] channel (required):
  Future<String?> getStreamDeviceIdChannelLiveM3u8(
    int deviceId,
    int channel,
  ) async {
    final response = await getStreamDeviceIdChannelLiveM3u8WithHttpInfo(
      deviceId,
      channel,
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
