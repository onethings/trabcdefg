# openapi.model.Permission

## Load the model package
```dart
import 'package:openapi/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**userId** | **int** | User id, can be only first parameter | [optional] 
**deviceId** | **int** | Device id, can be first parameter or second only in combination with userId | [optional] 
**groupId** | **int** | Group id, can be first parameter or second only in combination with userId | [optional] 
**geofenceId** | **int** | Geofence id, can be second parameter only | [optional] 
**notificationId** | **int** | Notification id, can be second parameter only | [optional] 
**calendarId** | **int** | Calendar id, can be second parameter only and only in combination with userId | [optional] 
**attributeId** | **int** | Computed attribute id, can be second parameter only | [optional] 
**driverId** | **int** | Driver id, can be second parameter only | [optional] 
**managedUserId** | **int** | User id, can be second parameter only and only in combination with userId | [optional] 
**commandId** | **int** | Saved command id, can be second parameter only | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


