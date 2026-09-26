// lib/providers/traccar_provider.dart
// Provider to manage Traccar API interactions and WebSocket connections.
import 'package:flutter/material.dart';
import 'package:trabcdefg/services/auth_service.dart';
import 'package:trabcdefg/services/websocket_service.dart';
import 'package:trabcdefg/src/generated_api/api.dart' as api;
import 'package:trabcdefg/storage/user_database_helper.dart';

class TraccarProvider with ChangeNotifier {
  /// Global reference for the global 401 interceptor to update
  /// the session after an auto-relogin succeeds.
  static TraccarProvider? _instance;
  static TraccarProvider? get instance => _instance;

  // FIX: Removed 'final' to allow the client to be updated
  api.ApiClient apiClient;
  final WebSocketService webSocketService;
  final AuthService authService;
  String? _sessionId;
  String? get sessionId => _sessionId; // for device connection only.

  api.User? _currentUser;

  List<api.Device> _devices = [];
  List<api.Position> _positions = [];
  final Map<int, api.Position> _positionMap = {};

  /// 位置資料版本號：每次 positions 有變動就 +1。
  ///
  /// 為什麼需要這個？因為 WebSocket 更新是 **in-place 修改同一個 List**
  /// （見 [_listenToWebSocket] 的 positions 分支），清單本身的參考永遠不變；
  /// 任何靠「清單參考是否改變」判斷要不要重畫地圖的地方都會失效。
  /// 有這個遞增數字，map_screen 才能可靠地在每次位置更新後重畫 marker。
  int _positionsRevision = 0;
  int get positionsRevision => _positionsRevision;

  List<api.Event> _events = [];
  Map<int, api.Event> _latestDeviceEvent = {};
  List<api.Geofence> _geofences = [];
  List<api.Notification> _serverNotifications = [];
  bool _isLoading = false;
  String? _serverVersion;

  /// Returns the cached server version (e.g. "4.4", "6.14.15"), or null if not yet fetched.
  String? get serverVersion => _serverVersion;

  /// Fetches and caches the server version from the Traccar API.
  /// Safe to call multiple times — the result is cached after first fetch.
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

  /// Checks whether the cached server version is >= [target] (e.g. "5.0").
  /// Returns false if version is unknown or parsing fails.
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
      return true; // equal
    } catch (_) {
      return false;
    }
  }

  /// Whether the server is a legacy Traccar 4.x instance.
  ///
  /// Traccar 4.x `/api/positions` requires `from` and `to` whenever `deviceId`
  /// is supplied. Without them the server calls `DateUtil.parseDate(null)`,
  /// which throws a NullPointerException and the request fails with
  /// `Application 400: ... < DateUtil:63 < PositionResource:67`.
  /// Newer servers simply return the last known position instead.
  bool get isLegacyServer {
    if (_serverVersion == null) return false; // unknown -> try the modern call first
    return !isVersionAtLeast('5.0');
  }

  /// Fetches the latest known position of a single [deviceId] in a way that
  /// works on every Traccar version, 4.x included. Falls back to the position
  /// already received over the WebSocket when every request fails.
  Future<api.Position?> fetchLatestPosition(int deviceId) async {
    if (_serverVersion == null) {
      await fetchServerVersion();
    }

    // Modern servers accept `/positions?deviceId=...` without a time range.
    if (!isLegacyServer) {
      final direct = _firstPositionForDevice(await _requestPositions(deviceId: deviceId), deviceId);
      if (direct != null) return direct;
    }

    // `/positions` without parameters returns the last known position of every
    // device and is supported by all server versions.
    final initial = _firstPositionForDevice(await _requestPositions(), deviceId);
    if (initial != null) return initial;

    // Last network resort: legacy servers can only filter by device together
    // with an explicit time range, so ask for the recent history instead.
    final now = DateTime.now().toUtc();
    final recent = _latestPositionForDevice(await _requestPositions(deviceId: deviceId, from: now.subtract(const Duration(days: 7)), to: now.add(const Duration(minutes: 5))), deviceId);
    if (recent != null) return recent;

    // Offline, empty or slow server — use whatever the WebSocket delivered.
    return getPosition(deviceId);
  }

  /// Runs a `/positions` request, returning null when it fails for any reason.
  Future<List<api.Position>?> _requestPositions({int? deviceId, DateTime? from, DateTime? to}) async {
    try {
      final positionsApi = api.PositionsApi(apiClient);
      return await positionsApi.getPositions(deviceId: deviceId, from: from, to: to) ?? [];
    } catch (e) {
      debugPrint('Positions request failed (deviceId: $deviceId, from: $from, to: $to): $e');
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

  Set<int> _favoriteDeviceIds = {};
  Set<int> get favoriteDeviceIds => _favoriteDeviceIds;

  final Map<int, List<api.Position>> _prefetchedHistory = {};
  Map<int, List<api.Position>> get prefetchedHistory => _prefetchedHistory;

  TraccarProvider({required this.apiClient, required this.webSocketService, required this.authService}) {
    _instance = this;
    _listenToWebSocket();
    _loadFavorites();

    // Wire up the session ID provider so WebSocket reconnects
    // always use the latest session ID, not a potentially stale one.
    webSocketService.sessionIdProvider = () => _sessionId;
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

  // FIX: Method to replace the entire ApiClient instance
  void updateApiClient(api.ApiClient newClient) {
    apiClient = newClient;
  }

  void _listenToWebSocket() {
    webSocketService.stream.listen((message) {
      final data = message;

      if (data['devices'] != null) {
        final deviceList = (data['devices'] as Iterable).map((model) => api.Device.fromJson(model)).whereType<api.Device>().toList();

        for (var newDevice in deviceList) {
          if (newDevice.id != null) {
            final existingDeviceIndex = _devices.indexWhere((dev) => dev.id == newDevice.id);
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
            _positionMap[newPosition.deviceId!] = newPosition;

            final existingPositionIndex = _positions.indexWhere((pos) => pos.deviceId == newPosition.deviceId);

            if (existingPositionIndex != -1) {
              _positions[existingPositionIndex] = newPosition;
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
            _latestDeviceEvent.putIfAbsent(newEvent.deviceId!, () => newEvent);
            _latestDeviceEvent.update(newEvent.deviceId!, (value) => newEvent);
            _events.add(newEvent);
          }
        }

        // Prevent Out of Memory (OOM) by limiting events array size
        if (_events.length > 1000) {
          _events.removeRange(0, _events.length - 1000);
        }

        notifyListeners();
      }
    });
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

  /// Returns the set of event types configured on the server for the given notificator.
  /// If notificator is null, returns all configured event types.
  Set<String> getServerEventTypes({String? notificator}) {
    return _serverNotifications.where((n) => n.type != null && (notificator == null || (n.notificators?.contains(notificator) ?? false))).map((n) => n.type!).toSet();
  }

  /// Returns the geofence name for a given geofence ID, or null if not found.
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

    // Use the apiClient's basePath to construct the WebSocket URL dynamically
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
      // FIX: Changed print to debugPrint to comply with production rules
      debugPrint('Failed to delete session on the server: $e');
    }

    await authService.logout();

    _sessionId = null;
    _serverVersion = null;
    _devices = [];
    _positions = [];
    _positionMap.clear();
    _positionsRevision++;
    _events = [];
    _latestDeviceEvent = {};
    _geofences = [];
    _serverNotifications = [];

    try {
      webSocketService.disconnect();
    } catch (e) {
      // FIX: Changed print to debugPrint to comply with production rules
      debugPrint('Error disconnecting WebSocket: $e');
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

    // 🔥 FIX: Ensure the Accept header is set here, before fetching initial data.
    // This resolves the cold-start PK error.
    apiClient.addDefaultHeader('Accept', 'application/json');

    try {
      final sessionApi = api.SessionApi(apiClient);
      final fetchedUser = await sessionApi.getSession();
      final devicesApi = api.DevicesApi(apiClient);
      final positionsApi = api.PositionsApi(apiClient);
      final geofencesApi = api.GeofencesApi(apiClient);
      final notificationsApi = api.NotificationsApi(apiClient);

      final fetchedDevices = await devicesApi.getDevices();
      final fetchedPositions = await positionsApi.getPositions();
      final fetchedGeofences = await geofencesApi.getGeofences();
      final fetchedNotifications = await notificationsApi.getNotifications();

      _currentUser = fetchedUser;
      _devices = (fetchedDevices ?? []).whereType<api.Device>().toList();
      _positions = fetchedPositions ?? [];
      _geofences = (fetchedGeofences ?? []).whereType<api.Geofence>().toList();
      _serverNotifications = (fetchedNotifications ?? []).whereType<api.Notification>().toList();
      _positionMap.clear();
      for (var pos in _positions) {
        if (pos.deviceId != null) {
          _positionMap[pos.deviceId!] = pos;
        }
      }
      _positionsRevision++;
    } finally {
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
      // FIX: Enhanced the catch clause to output the actual error using debugPrint
      debugPrint("Pre-fetch failed for device $deviceId: $e");
    }
  }
}
