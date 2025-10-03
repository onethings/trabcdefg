# openapi.api.ReportsApi

## Load the API package
```dart
import 'package:openapi/api.dart';
```

All URIs are relative to *https://demo.traccar.org/api*

Method | HTTP request | Description
------------- | ------------- | -------------
[**reportsEventsGet**](ReportsApi.md#reportseventsget) | **GET** /reports/events | Fetch a list of Events within the time period for the Devices or Groups
[**reportsRouteGet**](ReportsApi.md#reportsrouteget) | **GET** /reports/route | Fetch a list of Positions within the time period for the Devices or Groups
[**reportsStopsGet**](ReportsApi.md#reportsstopsget) | **GET** /reports/stops | Fetch a list of ReportStops within the time period for the Devices or Groups
[**reportsSummaryGet**](ReportsApi.md#reportssummaryget) | **GET** /reports/summary | Fetch a list of ReportSummary within the time period for the Devices or Groups
[**reportsTripsGet**](ReportsApi.md#reportstripsget) | **GET** /reports/trips | Fetch a list of ReportTrips within the time period for the Devices or Groups


# **reportsEventsGet**
> List<Event> reportsEventsGet(from, to, deviceId, groupId, type)

Fetch a list of Events within the time period for the Devices or Groups

At least one _deviceId_ or one _groupId_ must be passed

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

final api_instance = ReportsApi();
final from = 2013-10-20T19:20:30+01:00; // DateTime | in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
final to = 2013-10-20T19:20:30+01:00; // DateTime | in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
final deviceId = []; // List<int> | 
final groupId = []; // List<int> | 
final type = []; // List<String> | % can be used to return events of all types

try {
    final result = api_instance.reportsEventsGet(from, to, deviceId, groupId, type);
    print(result);
} catch (e) {
    print('Exception when calling ReportsApi->reportsEventsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **from** | **DateTime**| in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | 
 **to** | **DateTime**| in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | 
 **deviceId** | [**List<int>**](int.md)|  | [optional] [default to const []]
 **groupId** | [**List<int>**](int.md)|  | [optional] [default to const []]
 **type** | [**List<String>**](String.md)| % can be used to return events of all types | [optional] [default to const []]

### Return type

[**List<Event>**](Event.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **reportsRouteGet**
> List<Position> reportsRouteGet(from, to, deviceId, groupId)

Fetch a list of Positions within the time period for the Devices or Groups

At least one _deviceId_ or one _groupId_ must be passed

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

final api_instance = ReportsApi();
final from = 2013-10-20T19:20:30+01:00; // DateTime | in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
final to = 2013-10-20T19:20:30+01:00; // DateTime | in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
final deviceId = []; // List<int> | 
final groupId = []; // List<int> | 

try {
    final result = api_instance.reportsRouteGet(from, to, deviceId, groupId);
    print(result);
} catch (e) {
    print('Exception when calling ReportsApi->reportsRouteGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **from** | **DateTime**| in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | 
 **to** | **DateTime**| in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | 
 **deviceId** | [**List<int>**](int.md)|  | [optional] [default to const []]
 **groupId** | [**List<int>**](int.md)|  | [optional] [default to const []]

### Return type

[**List<Position>**](Position.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **reportsStopsGet**
> List<ReportStops> reportsStopsGet(from, to, deviceId, groupId)

Fetch a list of ReportStops within the time period for the Devices or Groups

At least one _deviceId_ or one _groupId_ must be passed

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

final api_instance = ReportsApi();
final from = 2013-10-20T19:20:30+01:00; // DateTime | in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
final to = 2013-10-20T19:20:30+01:00; // DateTime | in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
final deviceId = []; // List<int> | 
final groupId = []; // List<int> | 

try {
    final result = api_instance.reportsStopsGet(from, to, deviceId, groupId);
    print(result);
} catch (e) {
    print('Exception when calling ReportsApi->reportsStopsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **from** | **DateTime**| in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | 
 **to** | **DateTime**| in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | 
 **deviceId** | [**List<int>**](int.md)|  | [optional] [default to const []]
 **groupId** | [**List<int>**](int.md)|  | [optional] [default to const []]

### Return type

[**List<ReportStops>**](ReportStops.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **reportsSummaryGet**
> List<ReportSummary> reportsSummaryGet(from, to, deviceId, groupId)

Fetch a list of ReportSummary within the time period for the Devices or Groups

At least one _deviceId_ or one _groupId_ must be passed

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

final api_instance = ReportsApi();
final from = 2013-10-20T19:20:30+01:00; // DateTime | in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
final to = 2013-10-20T19:20:30+01:00; // DateTime | in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
final deviceId = []; // List<int> | 
final groupId = []; // List<int> | 

try {
    final result = api_instance.reportsSummaryGet(from, to, deviceId, groupId);
    print(result);
} catch (e) {
    print('Exception when calling ReportsApi->reportsSummaryGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **from** | **DateTime**| in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | 
 **to** | **DateTime**| in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | 
 **deviceId** | [**List<int>**](int.md)|  | [optional] [default to const []]
 **groupId** | [**List<int>**](int.md)|  | [optional] [default to const []]

### Return type

[**List<ReportSummary>**](ReportSummary.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **reportsTripsGet**
> List<ReportTrips> reportsTripsGet(from, to, deviceId, groupId)

Fetch a list of ReportTrips within the time period for the Devices or Groups

At least one _deviceId_ or one _groupId_ must be passed

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

final api_instance = ReportsApi();
final from = 2013-10-20T19:20:30+01:00; // DateTime | in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
final to = 2013-10-20T19:20:30+01:00; // DateTime | in ISO 8601 format. eg. `1963-11-22T18:30:00Z`
final deviceId = []; // List<int> | 
final groupId = []; // List<int> | 

try {
    final result = api_instance.reportsTripsGet(from, to, deviceId, groupId);
    print(result);
} catch (e) {
    print('Exception when calling ReportsApi->reportsTripsGet: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **from** | **DateTime**| in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | 
 **to** | **DateTime**| in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | 
 **deviceId** | [**List<int>**](int.md)|  | [optional] [default to const []]
 **groupId** | [**List<int>**](int.md)|  | [optional] [default to const []]

### Return type

[**List<ReportTrips>**](ReportTrips.md)

### Authorization

[ApiKey](../README.md#ApiKey), [BasicAuth](../README.md#BasicAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

