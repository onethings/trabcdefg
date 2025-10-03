# openapi.api.StatisticsApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://demo.traccar.org/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**statisticsGet**](StatisticsApi.md#statisticsget) | **GET** /statistics | Fetch server Statistics


# **statisticsGet**
> List<Statistics> statisticsGet(from, to)

Fetch server Statistics

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

final api_instance = StatisticsApi();
final from = 2013-10-20T19:20:30+01:00; // DateTime | in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
final to = 2013-10-20T19:20:30+01:00; // DateTime | in ISO 8601 format. eg. `1963-11-22T18:30:00Z`

try {
    final result = api_instance.statisticsGet(from, to);
    print(result);
} catch (e) {
    print('Exception when calling StatisticsApi->statisticsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **from** | **DateTime**| in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | 
 **to** | **DateTime**| in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | 

### Return type

[**List<Statistics>**](Statistics.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

