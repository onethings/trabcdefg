//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CommandsApi {
  CommandsApi([ApiClient? apiClient])
      : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Delete a Saved Command
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Response> deleteCommandsIdWithHttpInfo(
    int id,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/commands/{id}'.replaceAll('{id}', id.toString());

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

  /// Delete a Saved Command
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<void> deleteCommandsId(
    int id,
  ) async {
    final response = await deleteCommandsIdWithHttpInfo(
      id,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Fetch a list of Saved Commands
  ///
  /// Without params, it returns a list of Saved Commands the user has access to
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
  /// * [int] deviceId:
  ///   Standard users can use this only with _deviceId_s, they have access to
  ///
  /// * [int] groupId:
  ///   Standard users can use this only with _groupId_s, they have access to
  ///
  /// * [bool] refresh:
  ///
  /// * [int] limit:
  ///   Limit the number of returned results
  ///
  /// * [int] offset:
  ///   Offset for pagination
  ///
  /// * [String] keyword:
  ///   Search keyword filter
  Future<Response> getCommandsWithHttpInfo({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    bool? refresh,
    int? limit,
    int? offset,
    String? keyword,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/commands';

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
    if (deviceId != null) {
      queryParams.addAll(_queryParams('', 'deviceId', deviceId));
    }
    if (groupId != null) {
      queryParams.addAll(_queryParams('', 'groupId', groupId));
    }
    if (refresh != null) {
      queryParams.addAll(_queryParams('', 'refresh', refresh));
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

  /// Fetch a list of Saved Commands
  ///
  /// Without params, it returns a list of Saved Commands the user has access to
  ///
  /// Parameters:
  ///
  /// * [bool] all:
  ///   Can only be used by admins or managers to fetch all entities
  ///
  /// * [int] userId:
  ///   Standard users can use this only with their own _userId_
  ///
  /// * [int] deviceId:
  ///   Standard users can use this only with _deviceId_s, they have access to
  ///
  /// * [int] groupId:
  ///   Standard users can use this only with _groupId_s, they have access to
  ///
  /// * [bool] refresh:
  ///
  /// * [int] limit:
  ///   Limit the number of returned results
  ///
  /// * [int] offset:
  ///   Offset for pagination
  ///
  /// * [String] keyword:
  ///   Search keyword filter
  Future<List<Command>?> getCommands({
    bool? all,
    int? userId,
    int? deviceId,
    int? groupId,
    bool? refresh,
    int? limit,
    int? offset,
    String? keyword,
  }) async {
    final response = await getCommandsWithHttpInfo(
      all: all,
      userId: userId,
      deviceId: deviceId,
      groupId: groupId,
      refresh: refresh,
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
      return (await apiClient.deserializeAsync(responseBody, 'List<Command>')
              as List)
          .cast<Command>()
          .toList(growable: false);
    }
    return null;
  }

  /// Fetch a Saved Command
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Response> getCommandsIdWithHttpInfo(
    int id,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/commands/{id}'.replaceAll('{id}', id.toString());

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

  /// Fetch a Saved Command
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Command?> getCommandsId(
    int id,
  ) async {
    final response = await getCommandsIdWithHttpInfo(
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
        'Command',
      ) as Command;
    }
    return null;
  }

  /// Fetch a list of Saved Commands supported by Device at the moment
  ///
  /// Return a list of saved commands linked to Device and its groups, filtered by current Device protocol support
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] deviceId (required):
  ///   Standard users can use this only with _deviceId_s, they have access to
  Future<Response> getCommandsSendWithHttpInfo(
    int deviceId,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/commands/send';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    queryParams.addAll(_queryParams('', 'deviceId', deviceId));

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

  /// Fetch a list of Saved Commands supported by Device at the moment
  ///
  /// Return a list of saved commands linked to Device and its groups, filtered by current Device protocol support
  ///
  /// Parameters:
  ///
  /// * [int] deviceId (required):
  ///   Standard users can use this only with _deviceId_s, they have access to
  Future<List<Command>?> getCommandsSend(
    int deviceId,
  ) async {
    final response = await getCommandsSendWithHttpInfo(
      deviceId,
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
      return (await apiClient.deserializeAsync(responseBody, 'List<Command>')
              as List)
          .cast<Command>()
          .toList(growable: false);
    }
    return null;
  }

  /// Fetch a list of available Commands for the Device or all possible Commands if Device ommited
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] deviceId:
  ///   Internal device identifier. Only works if device has already reported some locations
  ///
  /// * [bool] textChannel:
  ///   When `true` return SMS commands. If not specified or `false` return data commands
  Future<Response> getCommandsTypesWithHttpInfo({
    int? deviceId,
    bool? textChannel,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/commands/types';

    // ignore: prefer_final_locals
    Object? postBody;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (deviceId != null) {
      queryParams.addAll(_queryParams('', 'deviceId', deviceId));
    }
    if (textChannel != null) {
      queryParams.addAll(_queryParams('', 'textChannel', textChannel));
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

  /// Fetch a list of available Commands for the Device or all possible Commands if Device ommited
  ///
  /// Parameters:
  ///
  /// * [int] deviceId:
  ///   Internal device identifier. Only works if device has already reported some locations
  ///
  /// * [bool] textChannel:
  ///   When `true` return SMS commands. If not specified or `false` return data commands
  Future<List<CommandType>?> getCommandsTypes({
    int? deviceId,
    bool? textChannel,
  }) async {
    final response = await getCommandsTypesWithHttpInfo(
      deviceId: deviceId,
      textChannel: textChannel,
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
      return (await apiClient.deserializeAsync(
              responseBody, 'List<CommandType>') as List)
          .cast<CommandType>()
          .toList(growable: false);
    }
    return null;
  }

  /// Create a Saved Command
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [Command] command (required):
  Future<Response> postCommandsWithHttpInfo(
    Command command,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/commands';

    // ignore: prefer_final_locals
    Object? postBody = command;

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

  /// Create a Saved Command
  ///
  /// Parameters:
  ///
  /// * [Command] command (required):
  Future<Command?> postCommands(
    Command command,
  ) async {
    final response = await postCommandsWithHttpInfo(
      command,
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
        'Command',
      ) as Command;
    }
    return null;
  }

  /// Dispatch commands to device
  ///
  /// Dispatch a new command or Saved Command if _body.id_ set
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [Command] command (required):
  ///
  /// * [int] groupId:
  ///   Send the command to all devices in the group
  Future<Response> postCommandsSendWithHttpInfo(
    Command command, {
    int? groupId,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/commands/send';

    // ignore: prefer_final_locals
    Object? postBody = command;

    final queryParams = <QueryParam>[];
    final headerParams = <String, String>{};
    final formParams = <String, String>{};

    if (groupId != null) {
      queryParams.addAll(_queryParams('', 'groupId', groupId));
    }

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

  /// Dispatch commands to device
  ///
  /// Dispatch a new command or Saved Command if _body.id_ set
  ///
  /// Parameters:
  ///
  /// * [Command] command (required):
  ///
  /// * [int] groupId:
  ///   Send the command to all devices in the group
  Future<Command?> postCommandsSend(
    Command command, {
    int? groupId,
  }) async {
    final response = await postCommandsSendWithHttpInfo(
      command,
      groupId: groupId,
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
        'Command',
      ) as Command;
    }
    return null;
  }

  /// Update a Saved Command
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [Command] command (required):
  Future<Response> putCommandsIdWithHttpInfo(
    int id,
    Command command,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/commands/{id}'.replaceAll('{id}', id.toString());

    // ignore: prefer_final_locals
    Object? postBody = command;

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

  /// Update a Saved Command
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [Command] command (required):
  Future<Command?> putCommandsId(
    int id,
    Command command,
  ) async {
    final response = await putCommandsIdWithHttpInfo(
      id,
      command,
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
        'Command',
      ) as Command;
    }
    return null;
  }
}
