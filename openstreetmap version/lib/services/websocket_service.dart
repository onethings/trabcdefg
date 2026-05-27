// lib/services/websocket_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer; // 1. Add this import
import 'dart:math';

import 'package:web_socket_channel/io.dart';

class WebSocketService {
  IOWebSocketChannel? _channel;
  final _controller = StreamController<dynamic>.broadcast();
  bool _isConnectAttempted = false;
  Timer? _reconnectTimer;

  int _reconnectAttempts = 0;
  String? _lastUrl;
  String? _lastSessionId;

  Stream<dynamic> get stream => _controller.stream;

  void connect(String wsUrl, String sessionId) {
    _lastUrl = wsUrl;
    _lastSessionId = sessionId;
    _isConnectAttempted = true;

    try {
      // 2. Replaced print with developer.log
      developer.log(
        'Connecting to WebSocket at: $wsUrl',
        name: 'WebSocketService',
      );
      _reconnectTimer?.cancel();

      _channel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        headers: {'Cookie': 'JSESSIONID=$sessionId'},
      );

      _channel!.stream.listen(
        (message) {
          _reconnectAttempts = 0;
          if (!_controller.isClosed) {
            _controller.add(json.decode(message));
          }
        },
        onError: (error) {
          // 3. Replaced print with developer.log
          developer.log(
            'WebSocket error: $error',
            name: 'WebSocketService',
            error: error,
          );
          _scheduleReconnect();
        },
        onDone: () {
          // 4. Replaced print with developer.log
          developer.log('WebSocket closed', name: 'WebSocketService');
          if (_isConnectAttempted) {
            _scheduleReconnect();
          }
        },
      );
    } catch (e) {
      // 5. Replaced print with developer.log
      developer.log(
        'WebSocket connection failed: $e',
        name: 'WebSocketService',
        error: e,
      );
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_isConnectAttempted || _reconnectTimer?.isActive == true) return;

    _reconnectAttempts++;
    final delay = Duration(
      seconds: min(pow(2, _reconnectAttempts).toInt(), 30),
    );

    // 6. Replaced print with developer.log
    developer.log(
      'Scheduling WebSocket reconnect in ${delay.inSeconds}s (Attempt $_reconnectAttempts)',
      name: 'WebSocketService',
    );

    _reconnectTimer = Timer(delay, () {
      if (_lastUrl != null && _lastSessionId != null) {
        connect(_lastUrl!, _lastSessionId!);
      }
    });
  }

  void disconnect() {
    _isConnectAttempted = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (_channel != null) {
      _channel!.sink.close(1000);
      _channel = null;
      if (!_controller.isClosed) {
        _controller.add(false);
      }
    }
  }
}
