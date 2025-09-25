# openapi.api.PositionsApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://demo.traccar.org/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**positionsDelete**](PositionsApi.md#positionsdelete) | **DELETE** /positions | Deletes all the Positions of a device in the time span specified
[**positionsGet**](PositionsApi.md#positionsget) | **GET** /positions | Fetches a list of Positions
[**positionsIdDelete**](PositionsApi.md#positionsiddelete) | **DELETE** /positions/{id} | Delete a Position


# **positionsDelete**
> positionsDelete(deviceId, from, to)

Deletes all the Positions of a device in the time span specified



### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: ApiKey
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('ApiKey').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('ApiKey').setAccessToken(yourTokenGeneratorFunction);
// TODO Configure HTTP basic authorization: BasicAuth
//defaultApiClient.getAuthentication<HttpBasicAuth>('BasicAuth').username = 'YOUR_USERNAME'
//defaultApiClient.getAuthentication<HttpBasicAuth>('BasicAuth').password = 'YOUR_PASSWORD';

final api_instance = PositionsApi();
final deviceId = 56; // int | 
final from = 2013-10-20T19:20:30+01:00; // DateTime | in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
final to = 2013-10-20T19:20:30+01:00; // DateTime | in ISO 8601 format. eg. `1963-11-22T18:30:00Z`

try {
    api_instance.positionsDelete(deviceId, from, to);
} catch (e) {
    print('Exception when calling PositionsApi->positionsDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **deviceId** | **int**|  | 
 **from** | **DateTime**| in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | 
 **to** | **DateTime**| in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | 

### Return type

void (empty response body)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **positionsGet**
> List<Position> positionsGet(deviceId, from, to, id)

Fetches a list of Positions

We strongly recommend using [Traccar WebSocket API](https://www.traccar.org/traccar-api/) instead of periodically polling positions endpoint. Without any params, it returns a list of last known positions for all the user's Devices. _from_ and _to_ fields are not required with _id_.

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: ApiKey
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('ApiKey').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('ApiKey').setAccessToken(yourTokenGeneratorFunction);
// TODO Configure HTTP basic authorization: BasicAuth
//defaultApiClient.getAuthentication<HttpBasicAuth>('BasicAuth').username = 'YOUR_USERNAME'
//defaultApiClient.getAuthentication<HttpBasicAuth>('BasicAuth').password = 'YOUR_PASSWORD';

final api_instance = PositionsApi();
final deviceId = 56; // int | _deviceId_ is optional, but requires the _from_ and _to_ parameters when used
final from = 2013-10-20T19:20:30+01:00; // DateTime | in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
final to = 2013-10-20T19:20:30+01:00; // DateTime | in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
final id = 56; // int | To fetch one or more positions. Multiple params can be passed like `id=31&id=42`

try {
    final result = api_instance.positionsGet(deviceId, from, to, id);
    print(result);
} catch (e) {
    print('Exception when calling PositionsApi->positionsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **deviceId** | **int**| _deviceId_ is optional, but requires the _from_ and _to_ parameters when used | [optional] 
 **from** | **DateTime**| in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | [optional] 
 **to** | **DateTime**| in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | [optional] 
 **id** | **int**| To fetch one or more positions. Multiple params can be passed like `id=31&id=42` | [optional] 

### Return type

[**List<Position>**](Position.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, text/csv, application/gpx+xml

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **positionsIdDelete**
> positionsIdDelete(id)

Delete a Position

### Example
```dart
import 'package:openapi/api.dart';
// TODO Configure HTTP Bearer authorization: ApiKey
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('ApiKey').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('ApiKey').setAccessToken(yourTokenGeneratorFunction);
// TODO Configure HTTP basic authorization: BasicAuth
//defaultApiClient.getAuthentication<HttpBasicAuth>('BasicAuth').username = 'YOUR_USERNAME'
//defaultApiClient.getAuthentication<HttpBasicAuth>('BasicAuth').password = 'YOUR_PASSWORD';

final api_instance = PositionsApi();
final id = 56; // int | 

try {
    api_instance.positionsIdDelete(id);
} catch (e) {
    print('Exception when calling PositionsApi->positionsIdDelete: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **int**|  | 

### Return type

void (empty response body)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

