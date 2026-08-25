//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class OrdersApi {
  OrdersApi([ApiClient? apiClient]) : apiClient = apiClient ?? defaultApiClient;

  final ApiClient apiClient;

  /// Delete an Order
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Response> deleteOrdersIdWithHttpInfo(
    int id,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/orders/{id}'.replaceAll('{id}', id.toString());

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

  /// Delete an Order
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<void> deleteOrdersId(
    int id,
  ) async {
    final response = await deleteOrdersIdWithHttpInfo(
      id,
    );
    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, await _decodeBodyBytes(response));
    }
  }

  /// Fetch a list of Orders
  ///
  /// Without params, it returns a list of Orders the user has access to
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
  /// * [bool] excludeAttributes:
  ///   Skip returning the attributes map
  ///
  /// * [int] limit:
  ///   Limit the number of returned results
  ///
  /// * [int] offset:
  ///   Offset for pagination
  ///
  /// * [String] keyword:
  ///   Search keyword filter
  Future<Response> getOrdersWithHttpInfo({
    bool? all,
    int? userId,
    bool? excludeAttributes,
    int? limit,
    int? offset,
    String? keyword,
  }) async {
    // ignore: prefer_const_declarations
    final path = r'/orders';

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
    if (excludeAttributes != null) {
      queryParams
          .addAll(_queryParams('', 'excludeAttributes', excludeAttributes));
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

  /// Fetch a list of Orders
  ///
  /// Without params, it returns a list of Orders the user has access to
  ///
  /// Parameters:
  ///
  /// * [bool] all:
  ///   Can only be used by admins or managers to fetch all entities
  ///
  /// * [int] userId:
  ///   Standard users can use this only with their own _userId_
  ///
  /// * [bool] excludeAttributes:
  ///   Skip returning the attributes map
  ///
  /// * [int] limit:
  ///   Limit the number of returned results
  ///
  /// * [int] offset:
  ///   Offset for pagination
  ///
  /// * [String] keyword:
  ///   Search keyword filter
  Future<List<Order>?> getOrders({
    bool? all,
    int? userId,
    bool? excludeAttributes,
    int? limit,
    int? offset,
    String? keyword,
  }) async {
    final response = await getOrdersWithHttpInfo(
      all: all,
      userId: userId,
      excludeAttributes: excludeAttributes,
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
      return (await apiClient.deserializeAsync(responseBody, 'List<Order>')
              as List)
          .cast<Order>()
          .toList(growable: false);
    }
    return null;
  }

  /// Fetch an Order
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Response> getOrdersIdWithHttpInfo(
    int id,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/orders/{id}'.replaceAll('{id}', id.toString());

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

  /// Fetch an Order
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  Future<Order?> getOrdersId(
    int id,
  ) async {
    final response = await getOrdersIdWithHttpInfo(
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
        'Order',
      ) as Order;
    }
    return null;
  }

  /// Create an Order
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [Order] order (required):
  Future<Response> postOrdersWithHttpInfo(
    Order order,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/orders';

    // ignore: prefer_final_locals
    Object? postBody = order;

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

  /// Create an Order
  ///
  /// Parameters:
  ///
  /// * [Order] order (required):
  Future<Order?> postOrders(
    Order order,
  ) async {
    final response = await postOrdersWithHttpInfo(
      order,
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
        'Order',
      ) as Order;
    }
    return null;
  }

  /// Update an Order
  ///
  /// Note: This method returns the HTTP [Response].
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [Order] order (required):
  Future<Response> putOrdersIdWithHttpInfo(
    int id,
    Order order,
  ) async {
    // ignore: prefer_const_declarations
    final path = r'/orders/{id}'.replaceAll('{id}', id.toString());

    // ignore: prefer_final_locals
    Object? postBody = order;

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

  /// Update an Order
  ///
  /// Parameters:
  ///
  /// * [int] id (required):
  ///
  /// * [Order] order (required):
  Future<Order?> putOrdersId(
    int id,
    Order order,
  ) async {
    final response = await putOrdersIdWithHttpInfo(
      id,
      order,
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
        'Order',
      ) as Order;
    }
    return null;
  }
}
