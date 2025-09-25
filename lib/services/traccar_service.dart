// lib/services/traccar_service.dart

import 'package:dio/dio.dart';
import 'package:trabcdefg/src/generated_api/api.dart'; // Correctly import the main library file
import 'websocket_service.dart';
import 'package:get/get.dart';

class TraccarService {

  final ApiClient apiClient; // No longer `late final`, as it's passed in
  late final DevicesApi api;

  // Accept ApiClient as a constructor parameter
  TraccarService({required this.apiClient}) {
    api = DevicesApi(apiClient);
  }

  Future<void> fetchDevices() async {
    try {
      final response = await api.devicesGet();
      final devices = response;
      if (devices != null) {
        for (var device in devices) {
          print('Device Name: ${device.name}, Status: ${device.status}');
        }
      }
    } catch (e) {
      print('Failed to fetch devices: $e');
    }
  }
}