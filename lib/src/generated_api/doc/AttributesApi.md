# openapi.api.AttributesApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://demo.traccar.org/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**attributesComputedGet**](AttributesApi.md#attributescomputedget) | **GET** /attributes/computed | Fetch a list of Attributes
[**attributesComputedIdDelete**](AttributesApi.md#attributescomputediddelete) | **DELETE** /attributes/computed/{id} | Delete an Attribute
[**attributesComputedIdPut**](AttributesApi.md#attributescomputedidput) | **PUT** /attributes/computed/{id} | Update an Attribute
[**attributesComputedPost**](AttributesApi.md#attributescomputedpost) | **POST** /attributes/computed | Create an Attribute


# **attributesComputedGet**
> List<Attribute> attributesComputedGet(all, userId, deviceId, groupId, refresh)

Fetch a list of Attributes

Without params, it returns a list of Attributes the user has access to

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

final api_instance = AttributesApi();
final all = true; // bool | Can only be used by admins or managers to fetch all entities
final userId = 56; // int | Standard users can use this only with their own _userId_
final deviceId = 56; // int | Standard users can use this only with _deviceId_s, they have access to
final groupId = 56; // int | Standard users can use this only with _groupId_s, they have access to
final refresh = true; // bool | 

try {
    final result = api_instance.attributesComputedGet(all, userId, deviceId, groupId, refresh);
    print(result);
} catch (e) {
    print('Exception when calling AttributesApi->attributesComputedGet: $e\n');
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

[**List<Attribute>**](Attribute.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **attributesComputedIdDelete**
> attributesComputedIdDelete(id)

Delete an Attribute

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

final api_instance = AttributesApi();
final id = 56; // int | 

try {
    api_instance.attributesComputedIdDelete(id);
} catch (e) {
    print('Exception when calling AttributesApi->attributesComputedIdDelete: $e\n');
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

# **attributesComputedIdPut**
> Attribute attributesComputedIdPut(id, body)

Update an Attribute

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

final api_instance = AttributesApi();
final id = 56; // int | 
final body = Attribute(); // Attribute | 

try {
    final result = api_instance.attributesComputedIdPut(id, body);
    print(result);
} catch (e) {
    print('Exception when calling AttributesApi->attributesComputedIdPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **int**|  | 
 **body** | [**Attribute**](Attribute.md)|  | 

### Return type

[**Attribute**](Attribute.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **attributesComputedPost**
> Attribute attributesComputedPost(body)

Create an Attribute

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

final api_instance = AttributesApi();
final body = Attribute(); // Attribute | 

try {
    final result = api_instance.attributesComputedPost(body);
    print(result);
} catch (e) {
    print('Exception when calling AttributesApi->attributesComputedPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **body** | [**Attribute**](Attribute.md)|  | 

### Return type

[**Attribute**](Attribute.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

