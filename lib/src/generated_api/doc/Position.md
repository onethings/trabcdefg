# openapi.model.Position

## Load the model package
```dart
import 'package:openapi/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **int** |  | [optional] 
**deviceId** | **int** |  | [optional] 
**protocol** | **String** |  | [optional] 
**deviceTime** | [**DateTime**](DateTime.md) | in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | [optional] 
**fixTime** | [**DateTime**](DateTime.md) | in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | [optional] 
**serverTime** | [**DateTime**](DateTime.md) | in ISO 8601 format. eg. `1963-11-22T18:30:00Z` | [optional] 
**outdated** | **bool** |  | [optional] 
**valid** | **bool** |  | [optional] 
**latitude** | **num** |  | [optional] 
**longitude** | **num** |  | [optional] 
**altitude** | **num** |  | [optional] 
**speed** | **num** | in knots | [optional] 
**course** | **num** |  | [optional] 
**address** | **String** |  | [optional] 
**accuracy** | **num** |  | [optional] 
**network** | [**Object**](.md) |  | [optional] 
**geofenceIds** | **List<int>** |  | [optional] [default to const []]
**attributes** | [**Object**](.md) |  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


