// lib/services/websocket_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:web_socket_channel/io.dart';

class WebSocketService {
  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  bool _isConnectAttempted = false;
  Timer? _reconnectTimer;

  int _reconnectAttempts = 0;
  String? _lastUrl;
  String? _lastSessionId;

  /// Optional callback that returns the latest active session ID.
  /// If set, reconnect will use this instead of the potentially stale [_lastSessionId].
  String? Function()? sessionIdProvider;

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void connect(String wsUrl, String sessionId) {
    _lastUrl = wsUrl;
    _lastSessionId = sessionId;
    _isConnectAttempted = true;

    try {
      developer.log('Connecting to WebSocket at: $wsUrl', name: 'WebSocketService');
      _reconnectTimer?.cancel();

      final previousChannel = _channel;
      final previousSubscription = _channelSubscription;
      _channelSubscription = null;
      if (previousSubscription != null) {
        unawaited(previousSubscription.cancel());
      }
      if (previousChannel != null) {
        unawaited(previousChannel.sink.close(1000));
      }

      final channel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        headers: {'Cookie': 'JSESSIONID=$sessionId'},
      );
      _channel = channel;

      _channelSubscription = channel.stream.listen(
        (message) {
          _reconnectAttempts = 0;
          try {
            final decoded = json.decode(message as String);
            if (decoded is! Map) {
              developer.log(
                'Ignoring non-object WebSocket message',
                name: 'WebSocketService',
              );
              return;
            }
            if (!_controller.isClosed) {
              _controller.add(Map<String, dynamic>.from(decoded));
            }
          } catch (error, stackTrace) {
            developer.log(
              'Failed to decode WebSocket message',
              name: 'WebSocketService',
              error: error,
              stackTrace: stackTrace,
            );
          }
        },
        onError: (error) {
          developer.log('WebSocket error: $error', name: 'WebSocketService', error: error);
          if (identical(_channel, channel)) _scheduleReconnect();
        },
        onDone: () {
          developer.log('WebSocket closed', name: 'WebSocketService');
          if (identical(_channel, channel) && _isConnectAttempted) {
            _scheduleReconnect();
          }
        },
      );
    } catch (e) {
      developer.log('WebSocket connection failed: $e', name: 'WebSocketService', error: e);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_isConnectAttempted || _reconnectTimer?.isActive == true) return;

    _reconnectAttempts++;
    final delay = Duration(seconds: min(pow(2, _reconnectAttempts).toInt(), 30));

    developer.log('Scheduling WebSocket reconnect in ${delay.inSeconds}s (Attempt $_reconnectAttempts)', name: 'WebSocketService');

    _reconnectTimer = Timer(delay, () {
      if (_lastUrl == null) return;

      // Use the latest session ID from the provider if available,
      // falling back to the potentially stale _lastSessionId.
      final sessionId = sessionIdProvider != null ? sessionIdProvider!() : _lastSessionId;

      if (sessionId != null) {
        connect(_lastUrl!, sessionId);
      }
    });
  }

  void disconnect() {
    _isConnectAttempted = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final subscription = _channelSubscription;
    _channelSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(channel.sink.close(1000));
    }
  }

  void dispose() {
    disconnect();
    unawaited(_controller.close());
  }
}
