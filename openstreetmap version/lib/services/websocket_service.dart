// lib/services/websocket_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:get/get.dart';

class WebSocketService {
  IOWebSocketChannel? _channel;
  final _controller = StreamController<dynamic>.broadcast();
  bool _isConnectAttempted = false; // Add this line
  Timer? _reconnectTimer; // Add this line

  int _reconnectAttempts = 0;
  String? _lastUrl;
  String? _lastSessionId;

  Stream<dynamic> get stream => _controller.stream;

  void connect(String wsUrl, String sessionId) {
    _lastUrl = wsUrl;
    _lastSessionId = sessionId;
    _isConnectAttempted = true;

    try {
      print('Connecting to WebSocket at: $wsUrl');
      _reconnectTimer?.cancel();

      _channel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        headers: {'Cookie': 'JSESSIONID=$sessionId'},
      );

      _channel!.stream.listen(
        (message) {
          _reconnectAttempts = 0; // Reset on successful message
          if (!_controller.isClosed) {
            _controller.add(json.decode(message));
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          print('WebSocket closed');
          if (_isConnectAttempted) {
            _scheduleReconnect();
          }
        },
      );
    } catch (e) {
      print('WebSocket connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_isConnectAttempted || _reconnectTimer?.isActive == true) return;

    _reconnectAttempts++;
    final delay = Duration(seconds: min(pow(2, _reconnectAttempts).toInt(), 30));
    print('Scheduling WebSocket reconnect in ${delay.inSeconds}s (Attempt $_reconnectAttempts)');

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