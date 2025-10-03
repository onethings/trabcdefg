// lib/providers/traccar_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/services/websocket_service.dart';
import 'package:trabcdefg/services/auth_service.dart';

class TraccarProvider with ChangeNotifier {
  final api.ApiClient apiClient;
  final WebSocketService webSocketService;
  final AuthService authService;
  String? _sessionId;
  String? get sessionId => _sessionId; // for device connection only.

  api.User? _currentUser;

  List<api.Device> _devices = [];
  List<api.Position> _positions = [];
  List<api.Event> _events = [];
  Map<int, api.Event> _latestDeviceEvent = {};
  bool _isLoading = false;

  TraccarProvider({
    required this.apiClient,
    required this.webSocketService,
    required this.authService,
  }) {
    _listenToWebSocket();
  }

  void _listenToWebSocket() {
    webSocketService.stream.listen((message) {
      final data = message;

      if (data['devices'] != null) {
        final deviceList = (data['devices'] as Iterable)
            .map((model) => api.Device.fromJson(model))
            .whereType<api.Device>()
            .toList();

        for (var newDevice in deviceList) {
          if (newDevice.id != null) {
            final existingDeviceIndex = _devices.indexWhere(
              (dev) => dev.id == newDevice.id,
            );
            if (existingDeviceIndex != -1) {
              _devices[existingDeviceIndex] = newDevice;
            } else {
              _devices.add(newDevice);
            }
          }
        }
        notifyListeners();
      }

      if (data['positions'] != null) {
        for (var newPositionJson in data['positions']) {
          final newPosition = api.Position.fromJson(newPositionJson);

          if (newPosition != null && newPosition.deviceId != null) {
            final existingPositionIndex = _positions.indexWhere(
              (pos) => pos.deviceId == newPosition.deviceId,
            );

            if (existingPositionIndex != -1) {
              _positions[existingPositionIndex] = newPosition;
            } else {
              _positions.add(newPosition);
            }
          }
        }
        notifyListeners();
      }

      if (data['events'] != null) {
        final eventList = (data['events'] as Iterable)
            .map((model) => api.Event.fromJson(model))
            .whereType<api.Event>()
            .toList();

        eventList.forEach((api.Event newEvent) {
          if (newEvent.deviceId != null) {
            _latestDeviceEvent.putIfAbsent(newEvent.deviceId!, () => newEvent);
            _latestDeviceEvent.update(newEvent.deviceId!, (value) => newEvent);
            _events.add(newEvent);
          }
        });
        notifyListeners();
      }
    });
  }

  api.User? get currentUser => _currentUser;

  List<api.Device> get devices => _devices;
  List<api.Position> get positions => _positions;
  List<api.Event> get events => _events;
  Map<int, api.Event> get latestDeviceEvent => _latestDeviceEvent;
  bool get isLoading => _isLoading;

  void setSessionId(String sessionId) {
    _sessionId = sessionId;
    
    // Use the apiClient's basePath to construct the WebSocket URL dynamically
    final uri = Uri.parse(apiClient.basePath);
    final wsUrl = uri.replace(
      scheme: uri.scheme == 'https' ? 'wss' : 'ws', 
      path: '/api/socket',
    );

    webSocketService.connect(wsUrl.toString(), _sessionId!);
  }

  Future<void> clearSessionAndData() async {
    try {
      final path = '/session';
      final headerParams = <String, String>{'Cookie': 'JSESSIONID=$_sessionId'};

      await apiClient.invokeAPI(
        path,
        'DELETE',
        [],
        null,
        headerParams,
        {},
        null,
      );
    } catch (e) {
      print('Failed to delete session on the server: $e');
    }

    await authService.logout();

    _sessionId = null;
    _devices = [];
    _positions = [];
    _events = [];
    _latestDeviceEvent = {};

    try {
      webSocketService.disconnect();
    } catch (e) {
      print('Error disconnecting WebSocket: $e');
    }

    notifyListeners();
  }

  Future<void> fetchInitialData() async {
    if (_sessionId == null) {
      throw Exception('Session not set');
    }

    _isLoading = true;
    notifyListeners();

    apiClient.addDefaultHeader('Cookie', 'JSESSIONID=$_sessionId');

    try {
      final sessionApi = api.SessionApi(apiClient);
      final fetchedUser = await sessionApi.sessionGet();
      final devicesApi = api.DevicesApi(apiClient);
      final positionsApi = api.PositionsApi(apiClient);

      final fetchedDevices = await devicesApi.devicesGet();
      final fetchedPositions = await positionsApi.positionsGet();

      _currentUser = fetchedUser;
      _devices = (fetchedDevices ?? []).whereType<api.Device>().toList();
      _positions = fetchedPositions ?? [];
    } on api.ApiException catch (e) {
      throw Exception('Failed to fetch initial data: ${e.message}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}