# openapi.api.CalendarsApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://demo.traccar.org/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**calendarsGet**](CalendarsApi.md#calendarsget) | **GET** /calendars | Fetch a list of Calendars
[**calendarsIdDelete**](CalendarsApi.md#calendarsiddelete) | **DELETE** /calendars/{id} | Delete a Calendar
[**calendarsIdPut**](CalendarsApi.md#calendarsidput) | **PUT** /calendars/{id} | Update a Calendar
[**calendarsPost**](CalendarsApi.md#calendarspost) | **POST** /calendars | Create a Calendar


# **calendarsGet**
> List<Calendar> calendarsGet(all, userId)

Fetch a list of Calendars

Without params, it returns a list of Calendars the user has access to

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

final api_instance = CalendarsApi();
final all = true; // bool | Can only be used by admins or managers to fetch all entities
final userId = 56; // int | Standard users can use this only with their own _userId_

try {
    final result = api_instance.calendarsGet(all, userId);
    print(result);
} catch (e) {
    print('Exception when calling CalendarsApi->calendarsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **all** | **bool**| Can only be used by admins or managers to fetch all entities | [optional] 
 **userId** | **int**| Standard users can use this only with their own _userId_ | [optional] 

### Return type

[**List<Calendar>**](Calendar.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **calendarsIdDelete**
> calendarsIdDelete(id)

Delete a Calendar

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

final api_instance = CalendarsApi();
final id = 56; // int | 

try {
    api_instance.calendarsIdDelete(id);
} catch (e) {
    print('Exception when calling CalendarsApi->calendarsIdDelete: $e\n');
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

# **calendarsIdPut**
> Calendar calendarsIdPut(id, body)

Update a Calendar

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

final api_instance = CalendarsApi();
final id = 56; // int | 
final body = Calendar(); // Calendar | 

try {
    final result = api_instance.calendarsIdPut(id, body);
    print(result);
} catch (e) {
    print('Exception when calling CalendarsApi->calendarsIdPut: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **id** | **int**|  | 
 **body** | [**Calendar**](Calendar.md)|  | 

### Return type

[**Calendar**](Calendar.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **calendarsPost**
> Calendar calendarsPost(body)

Create a Calendar

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

final api_instance = CalendarsApi();
final body = Calendar(); // Calendar | 

try {
    final result = api_instance.calendarsPost(body);
    print(result);
} catch (e) {
    print('Exception when calling CalendarsApi->calendarsPost: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **body** | [**Calendar**](Calendar.md)|  | 

### Return type

[**Calendar**](Calendar.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

