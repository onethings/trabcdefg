// lib/providers/traccar_provider.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:trabcdefg/services/auth_service.dart';
import 'package:trabcdefg/services/auth_session_store.dart';
import 'package:trabcdefg/services/websocket_service.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/storage/user_database_helper.dart';

class TraccarProvider with ChangeNotifier {
  static TraccarProvider? _instance;
  static TraccarProvider? get instance => _instance;

  api.ApiClient apiClient;
  final WebSocketService webSocketService;
  final AuthService authService;

  String? _sessionId;
  String? get sessionId => _sessionId;

  api.User? _currentUser;
  List<api.Device> _devices = [];
  List<api.Position> _positions = [];
  final Map<int, api.Position> _positionMap = {};

  StreamSubscription<Map<String, dynamic>>? _webSocketSubscription;
  Future<void>? _initialDataFuture;
  Map<int, api.Position>? _webSocketPositionsDuringFetch;

  int _positionsRevision = 0;
  int get positionsRevision => _positionsRevision;

  /// Bumped whenever the device list itself changes (category, name, ...),
  /// so map markers can be redrawn even without a new position.
  int _devicesRevision = 0;
  int get devicesRevision => _devicesRevision;

  List<api.Event> _events = [];
  final Map<int, api.Event> _latestDeviceEvent = {};
  List<api.Geofence> _geofences = [];
  List<api.Notification> _serverNotifications = [];
  bool _isLoading = false;
  String? _serverVersion;

  Set<int> _favoriteDeviceIds = {};
  Set<int> get favoriteDeviceIds => _favoriteDeviceIds;

  final Map<int, List<api.Position>> _prefetchedHistory = {};
  Map<int, List<api.Position>> get prefetchedHistory => _prefetchedHistory;

  TraccarProvider({required this.apiClient, required this.webSocketService, required this.authService}) {
    _instance = this;
    _listenToWebSocket();
    _loadFavorites();

    webSocketService.sessionIdProvider = () => _sessionId;

    final sessionStore = AuthSessionStore.instance;
    sessionStore.onSessionUpdated = setSessionId;
    sessionStore.onSessionCleared = clearLocalSession;
  }

  String? get serverVersion => _serverVersion;

  Future<String?> fetchServerVersion() async {
    if (_serverVersion != null) return _serverVersion;
    try {
      final serverApi = api.ServerApi(apiClient);
      final server = await serverApi.getServer();
      _serverVersion = server?.version;
      debugPrint('Server version: $_serverVersion');
      return _serverVersion;
    } catch (e) {
      debugPrint('Failed to fetch server version: $e');
      return null;
    }
  }

  bool isVersionAtLeast(String target) {
    if (_serverVersion == null) return false;
    try {
      final parts = _serverVersion!.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      final targetParts = target.split('.').map((s) => int.tryParse(s) ?? 0).toList();
      final maxLen = parts.length > targetParts.length ? parts.length : targetParts.length;
      for (var i = 0; i < maxLen; i++) {
        final a = i < parts.length ? parts[i] : 0;
        final b = i < targetParts.length ? targetParts[i] : 0;
        if (a > b) return true;
        if (a < b) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  bool get isLegacyServer {
    if (_serverVersion == null) return false;
    return !isVersionAtLeast('5.0');
  }

  Future<Object?> testComputedAttribute({required int deviceId, required api.Attribute attribute}) async {
    if (_serverVersion == null) {
      await fetchServerVersion();
    }
    if (_serverVersion == null) {
      throw StateError('Unable to determine the Traccar server version.');
    }
    if (!isVersionAtLeast('6.16.0')) {
      throw UnsupportedError('Computed attribute testing requires Traccar 6.16.0 or newer (server version: $_serverVersion).');
    }
    return api.AttributesApi(apiClient).postAttributesComputedTest(deviceId, attribute);
  }

  Future<api.Position?> fetchLatestPosition(int deviceId) async {
    if (_serverVersion == null) {
      await fetchServerVersion();
    }

    if (!isLegacyServer) {
      final direct = _firstPositionForDevice(await _requestPositions(deviceId: deviceId), deviceId);
      if (direct != null) return direct;
    }

    final initial = _firstPositionForDevice(await _requestPositions(), deviceId);
    if (initial != null) return initial;

    final now = DateTime.now().toUtc();
    final recent = _latestPositionForDevice(await _requestPositions(deviceId: deviceId, from: now.subtract(const Duration(days: 7)), to: now.add(const Duration(minutes: 5))), deviceId);
    if (recent != null) return recent;

    return getPosition(deviceId);
  }

  Future<List<api.Position>?> _requestPositions({int? deviceId, DateTime? from, DateTime? to}) async {
    try {
      final positionsApi = api.PositionsApi(apiClient);
      return await positionsApi.getPositions(deviceId: deviceId, from: from, to: to) ?? [];
    } catch (e) {
      debugPrint('Positions request failed (deviceId: $deviceId): $e');
      return null;
    }
  }

  api.Position? _firstPositionForDevice(List<api.Position>? positions, int deviceId) {
    if (positions == null) return null;
    for (final position in positions) {
      if (position.deviceId == deviceId) return position;
    }
    return null;
  }

  api.Position? _latestPositionForDevice(List<api.Position>? positions, int deviceId) {
    if (positions == null) return null;
    api.Position? latest;
    for (final position in positions) {
      if (position.deviceId != deviceId) continue;
      final fixTime = position.fixTime;
      final latestFixTime = latest?.fixTime;
      if (latest == null || (fixTime != null && (latestFixTime == null || fixTime.isAfter(latestFixTime)))) {
        latest = position;
      }
    }
    return latest;
  }

  Future<void> _loadFavorites() async {
    _favoriteDeviceIds = await UserDatabaseHelper.getFavorites();
    notifyListeners();
  }

  bool isFavorite(int deviceId) => _favoriteDeviceIds.contains(deviceId);

  Future<void> toggleFavorite(int deviceId) async {
    if (_favoriteDeviceIds.contains(deviceId)) {
      _favoriteDeviceIds.remove(deviceId);
      await UserDatabaseHelper.removeFavorite(deviceId);
    } else {
      _favoriteDeviceIds.add(deviceId);
      await UserDatabaseHelper.addFavorite(deviceId);
    }
    notifyListeners();
  }

  void updateApiClient(api.ApiClient newClient) {
    apiClient = newClient;
    _serverVersion = null;
  }

  void _listenToWebSocket() {
    _webSocketSubscription = webSocketService.stream.listen((data) {
      if (data['devices'] != null) {
        final deviceList = (data['devices'] as Iterable).map((model) => api.Device.fromJson(model)).whereType<api.Device>().toList();

        for (var newDevice in deviceList) {
          if (newDevice.id != null) {
            final existingIndex = _devices.indexWhere((dev) => dev.id == newDevice.id);
            if (existingIndex != -1) {
              _devices[existingIndex] = newDevice;
            } else {
              _devices.add(newDevice);
            }
          }
        }
        _devicesRevision++;
        notifyListeners();
      }

      if (data['positions'] != null) {
        for (var newPositionJson in data['positions']) {
          final newPosition = api.Position.fromJson(newPositionJson);

          if (newPosition != null && newPosition.deviceId != null) {
            _positionMap[newPosition.deviceId!] = newPosition;
            _webSocketPositionsDuringFetch?[newPosition.deviceId!] = newPosition;

            final existingIndex = _positions.indexWhere((pos) => pos.deviceId == newPosition.deviceId);
            if (existingIndex != -1) {
              _positions[existingIndex] = newPosition;
            } else {
              _positions.add(newPosition);
            }
          }
        }
        _positionsRevision++;
        notifyListeners();
      }

      if (data['events'] != null) {
        final eventList = (data['events'] as Iterable).map((model) => api.Event.fromJson(model)).whereType<api.Event>().toList();

        for (var newEvent in eventList) {
          if (newEvent.deviceId != null) {
            _latestDeviceEvent[newEvent.deviceId!] = newEvent;
            _events.add(newEvent);
          }
        }

        if (_events.length > 1000) {
          _events.removeRange(0, _events.length - 1000);
        }

        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    unawaited(_webSocketSubscription?.cancel());
    webSocketService.disconnect();
    final sessionStore = AuthSessionStore.instance;
    sessionStore.onSessionUpdated = null;
    sessionStore.onSessionCleared = null;
    if (identical(_instance, this)) _instance = null;
    super.dispose();
  }

  api.User? get currentUser => _currentUser;
  List<api.Device> get devices => _devices;
  List<api.Position> get positions => _positions;
  api.Position? getPosition(int deviceId) => _positionMap[deviceId];
  List<api.Event> get events => _events;
  Map<int, api.Event> get latestDeviceEvent => _latestDeviceEvent;
  List<api.Geofence> get geofences => _geofences;
  List<api.Notification> get serverNotifications => _serverNotifications;
  bool get isLoading => _isLoading;

  /// Applies a saved device to the in-memory list (adding it when it is new)
  /// and bumps [devicesRevision] so views such as the map redraw immediately.
  void updateDevice(api.Device updatedDevice) {
    final index = _devices.indexWhere((device) => device.id == updatedDevice.id);
    if (index == -1) {
      _devices.add(updatedDevice);
      _devicesRevision++;
      notifyListeners();
      return;
    }

    final current = _devices[index];
    _devices[index] = api.Device(
      id: updatedDevice.id,
      name: updatedDevice.name,
      uniqueId: updatedDevice.uniqueId,
      status: current.status,
      disabled: updatedDevice.disabled,
      lastUpdate: current.lastUpdate,
      positionId: current.positionId,
      groupId: updatedDevice.groupId,
      phone: updatedDevice.phone,
      model: updatedDevice.model,
      contact: updatedDevice.contact,
      category: updatedDevice.category,
      attributes: updatedDevice.attributes,
    );
    _devicesRevision++;
    notifyListeners();
  }

  Set<String> getServerEventTypes({String? notificator}) {
    return _serverNotifications.where((n) => n.type != null && (notificator == null || (n.notificators?.contains(notificator) ?? false))).map((n) => n.type!).toSet();
  }

  String? getGeofenceName(int? geofenceId) {
    if (geofenceId == null) return null;
    try {
      return _geofences.firstWhere((g) => g.id == geofenceId).name;
    } catch (_) {
      return null;
    }
  }

  void setSessionId(String sessionId) {
    _sessionId = sessionId;
    final uri = Uri.parse(apiClient.basePath);
    final wsUrl = uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws', path: '/api/socket');
    webSocketService.connect(wsUrl.toString(), _sessionId!);
  }

  Future<void> clearSessionAndData() async {
    try {
      final path = '/session';
      final headerParams = <String, String>{'Cookie': 'JSESSIONID=$_sessionId'};
      await apiClient.invokeAPI(path, 'DELETE', [], null, headerParams, {}, null);
    } catch (e) {
      debugPrint('Failed to delete session on the server: $e');
    }
    await authService.logout();
  }

  Future<void> clearLocalSession() async {
    _sessionId = null;
    _serverVersion = null;
    _devices = [];
    _positions = [];
    _positionMap.clear();
    _positionsRevision++;
    _devicesRevision++;
    _events = [];
    _latestDeviceEvent.clear();
    _geofences = [];
    _serverNotifications = [];
    _prefetchedHistory.clear();

    try {
      webSocketService.disconnect();
    } catch (e) {
      debugPrint('Error disconnecting WebSocket: $e');
    }

    notifyListeners();
  }

  Future<void> fetchInitialData() {
    final inFlight = _initialDataFuture;
    if (inFlight != null) return inFlight;

    late final Future<void> request;
    request = _fetchInitialData().whenComplete(() {
      if (identical(_initialDataFuture, request)) {
        _initialDataFuture = null;
      }
    });
    _initialDataFuture = request;
    return request;
  }

  Future<void> _fetchInitialData() async {
    if (_sessionId == null) {
      throw Exception('Session not set');
    }

    _isLoading = true;
    notifyListeners();

    apiClient.addDefaultHeader('Cookie', 'JSESSIONID=$_sessionId');
    apiClient.addDefaultHeader('Accept', 'application/json');

    final websocketPositions = <int, api.Position>{};
    _webSocketPositionsDuringFetch = websocketPositions;

    try {
      final sessionApi = api.SessionApi(apiClient);
      final devicesApi = api.DevicesApi(apiClient);
      final positionsApi = api.PositionsApi(apiClient);
      final geofencesApi = api.GeofencesApi(apiClient);
      final notificationsApi = api.NotificationsApi(apiClient);

      final fetchedUserFuture = sessionApi.getSession();
      final fetchedDevicesFuture = devicesApi.getDevices();
      final fetchedPositionsFuture = positionsApi.getPositions();
      final fetchedGeofencesFuture = geofencesApi.getGeofences();
      final fetchedNotificationsFuture = notificationsApi.getNotifications();

      await Future.wait<Object?>([fetchedUserFuture, fetchedDevicesFuture, fetchedPositionsFuture, fetchedGeofencesFuture, fetchedNotificationsFuture]);

      _currentUser = await fetchedUserFuture;
      _devices = ((await fetchedDevicesFuture) ?? []).whereType<api.Device>().toList();
      _positions = (await fetchedPositionsFuture) ?? [];

      final positionIndexes = <int, int>{
        for (var index = 0; index < _positions.length; index++)
          if (_positions[index].deviceId != null) _positions[index].deviceId!: index,
      };

      for (final entry in websocketPositions.entries) {
        final index = positionIndexes[entry.key];
        if (index == null) {
          positionIndexes[entry.key] = _positions.length;
          _positions.add(entry.value);
        } else {
          _positions[index] = entry.value;
        }
      }

      _geofences = ((await fetchedGeofencesFuture) ?? []).whereType<api.Geofence>().toList();
      _serverNotifications = ((await fetchedNotificationsFuture) ?? []).whereType<api.Notification>().toList();

      _positionMap.clear();
      for (var pos in _positions) {
        if (pos.deviceId != null) {
          _positionMap[pos.deviceId!] = pos;
        }
      }
      _positionsRevision++;
      _devicesRevision++;
    } finally {
      _webSocketPositionsDuringFetch = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> prefetchDeviceHistory(int deviceId) async {
    if (_sessionId == null || _prefetchedHistory.containsKey(deviceId)) return;

    final to = DateTime.now();
    final from = to.subtract(const Duration(hours: 1));

    try {
      debugPrint('Pre-fetching 1h history for device: $deviceId');
      final positionsApi = api.PositionsApi(apiClient);
      final history = await positionsApi.getPositions(deviceId: deviceId, from: from.toUtc(), to: to.toUtc()) ?? [];

      _prefetchedHistory[deviceId] = history;
      notifyListeners();
    } catch (e) {
      debugPrint("Pre-fetch failed for device $deviceId: $e");
    }
  }
}
