# openapi.api.GeofencesApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://demo.traccar.org/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**geofencesGet**](GeofencesApi.md#geofencesget) | **GET** /geofences | Fetch a list of Geofences
[**geofencesIdDelete**](GeofencesApi.md#geofencesiddelete) | **DELETE** /geofences/{id} | Delete a Geofence
[**geofencesIdPut**](GeofencesApi.md#geofencesidput) | **PUT** /geofences/{id} | Update a Geofence
[**geofencesPost**](GeofencesApi.md#geofencespost) | **POST** /geofences | Create a Geofence


# **geofencesGet**
> List<Geofence> geofencesGet(all, userId, deviceId, groupId, refresh)

Fetch a list of Geofences

Without params, it returns a list of Geofences the user has access to

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

final api_instance = GeofencesApi();
final all = true; // bool | Can only be used by admins or managers to fetch all entities
final userId = 56; // int | Standard users can use this only with their own _userId_
final deviceId = 56; // int | Standard users can use this only with _deviceId_s, they have access to
final groupId = 56; // int | Standard users can use this only with _groupId_s, they have access to
final refresh = true; // bool | 

try {
    final result = api_instance.geofencesGet(all, userId, deviceId, groupId, refresh);
    print(result);
} catch (e) {
    print('Exception when calling GeofencesApi->geofencesGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **all** | **bool**| Can only be used by admins or managers to fetch all entities | [optional] 
 **userId** | **int**| Standard users can use this only with their own _userId_ | [optional] 
 **deviceId** | **int**| Standard users can use this only with _deviceId_s, they have access to | [optional] 
 **groupId** | **int**| Standard users can use this only with _groupId_s, they have access to | [optional] 
 **refresh** | **bool**|  | [optional] 

### Return type

[**List<Geofence>**](Geofence.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **geofencesIdDelete**
> geofencesIdDelete(id)

Delete a Geofence

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

final api_instance = GeofencesApi();
final id = 56; // int | 

try {
    api_instance.geofencesIdDelete(id);
} catch (e) {
    print('Exception when calling GeofencesApi->geofencesIdDelete: $e\n');
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

# **geofencesIdPut**
> Geofence geofencesIdPut(id, body)

Update a Geofence

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

final api_instance = GeofencesApi();
final id = 56; // int | 
final body = Geofence(); // Geofence | 

try {
    final result = api_instance.geofencesIdPut(id, body);
    print(result);
} catch (e) {
    print('Exception when calling GeofencesApi->geofencesIdPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **int**|  | 
 **body** | [**Geofence**](Geofence.md)|  | 

### Return type

[**Geofence**](Geofence.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **geofencesPost**
> Geofence geofencesPost(body)

Create a Geofence

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

final api_instance = GeofencesApi();
final body = Geofence(); // Geofence | 

try {
    final result = api_instance.geofencesPost(body);
    print(result);
} catch (e) {
    print('Exception when calling GeofencesApi->geofencesPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **body** | [**Geofence**](Geofence.md)|  | 

### Return type

[**Geofence**](Geofence.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

