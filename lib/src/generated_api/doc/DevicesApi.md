# openapi.api.DevicesApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://demo.traccar.org/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**devicesGet**](DevicesApi.md#devicesget) | **GET** /devices | Fetch a list of Devices
[**devicesIdAccumulatorsPut**](DevicesApi.md#devicesidaccumulatorsput) | **PUT** /devices/{id}/accumulators | Update total distance and hours of the Device
[**devicesIdDelete**](DevicesApi.md#devicesiddelete) | **DELETE** /devices/{id} | Delete a Device
[**devicesIdPut**](DevicesApi.md#devicesidput) | **PUT** /devices/{id} | Update a Device
[**devicesPost**](DevicesApi.md#devicespost) | **POST** /devices | Create a Device


# **devicesGet**
> List<Device> devicesGet(all, userId, id, uniqueId)

Fetch a list of Devices

Without any params, returns a list of the user's devices

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

final api_instance = DevicesApi();
final all = true; // bool | Can only be used by admins or managers to fetch all entities
final userId = 56; // int | Standard users can use this only with their own _userId_
final id = 56; // int | To fetch one or more devices. Multiple params can be passed like `id=31&id=42`
final uniqueId = uniqueId_example; // String | To fetch one or more devices. Multiple params can be passed like `uniqueId=333331&uniqieId=44442`

try {
    final result = api_instance.devicesGet(all, userId, id, uniqueId);
    print(result);
} catch (e) {
    print('Exception when calling DevicesApi->devicesGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **all** | **bool**| Can only be used by admins or managers to fetch all entities | [optional] 
 **userId** | **int**| Standard users can use this only with their own _userId_ | [optional] 
 **id** | **int**| To fetch one or more devices. Multiple params can be passed like `id=31&id=42` | [optional] 
 **uniqueId** | **String**| To fetch one or more devices. Multiple params can be passed like `uniqueId=333331&uniqieId=44442` | [optional] 

### Return type

[**List<Device>**](Device.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **devicesIdAccumulatorsPut**
> devicesIdAccumulatorsPut(id, body)

Update total distance and hours of the Device

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

final api_instance = DevicesApi();
final id = 56; // int | 
final body = DeviceAccumulators(); // DeviceAccumulators | 

try {
    api_instance.devicesIdAccumulatorsPut(id, body);
} catch (e) {
    print('Exception when calling DevicesApi->devicesIdAccumulatorsPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **int**|  | 
 **body** | [**DeviceAccumulators**](DeviceAccumulators.md)|  | 

### Return type

void (empty response body)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **devicesIdDelete**
> devicesIdDelete(id)

Delete a Device

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

final api_instance = DevicesApi();
final id = 56; // int | 

try {
    api_instance.devicesIdDelete(id);
} catch (e) {
    print('Exception when calling DevicesApi->devicesIdDelete: $e\n');
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

# **devicesIdPut**
> Device devicesIdPut(id, body)

Update a Device

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

final api_instance = DevicesApi();
final id = 56; // int | 
final body = Device(); // Device | 

try {
    final result = api_instance.devicesIdPut(id, body);
    print(result);
} catch (e) {
    print('Exception when calling DevicesApi->devicesIdPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **int**|  | 
 **body** | [**Device**](Device.md)|  | 

### Return type

[**Device**](Device.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **devicesPost**
> Device devicesPost(body)

Create a Device

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

final api_instance = DevicesApi();
final body = Device(); // Device | 

try {
    final result = api_instance.devicesPost(body);
    print(result);
} catch (e) {
    print('Exception when calling DevicesApi->devicesPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **body** | [**Device**](Device.md)|  | 

### Return type

[**Device**](Device.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

