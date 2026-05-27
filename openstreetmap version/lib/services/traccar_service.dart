// lib/services/traccar_service.dart

import 'dart:developer' as developer; // 1. Import the developer library

import 'package:trabcdefg/src/generated_api/api.dart';

class TraccarService {
  final ApiClient apiClient;
  late final DevicesApi api;

  TraccarService({required this.apiClient}) {
    api = DevicesApi(apiClient);
  }

  Future<void> fetchDevices() async {
    try {
      final response = await api.devicesGet();
      final devices = response;
      if (devices != null) {
        for (var device in devices) {
          // 2. Replace print with developer.log
          developer.log(
            'Device Name: ${device.name}, Status: ${device.status}',
            name: 'TraccarService',
          );
        }
      }
    } catch (e) {
      // 3. Pass the error object directly into the error parameter
      developer.log(
        'Failed to fetch devices',
        error: e,
        name: 'TraccarService',
      );
    }
  }
}
