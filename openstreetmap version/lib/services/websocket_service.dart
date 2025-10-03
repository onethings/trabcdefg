// lib/services/websocket_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:get/get.dart';

class WebSocketService {
  IOWebSocketChannel? _channel;
  final _controller = StreamController<dynamic>.broadcast();
  bool _isConnectAttempted = false; // Add this line
  Timer? _reconnectTimer; // Add this line

  Stream<dynamic> get stream => _controller.stream;

  void connect(String wsUrl, String sessionId) {
    try {
      print('Connecting to WebSocket at: $wsUrl');

      // Add the Cookie header for authentication
      _channel = IOWebSocketChannel.connect(
        Uri.parse(wsUrl),
        headers: {'Cookie': 'JSESSIONID=$sessionId'},
      );

      _channel!.stream.listen(
        (message) {
          _controller.add(json.decode(message));
        },
        onError: (error) {
          print('WebSocket error: $error');
        },
        onDone: () {
          print('WebSocket closed');
          _controller.close();
        },
      );
    } catch (e) {
      print('WebSocket connection failed: $e');
    }
  }

  void disconnect() {
    if (_channel != null) {
      // Use a valid close code, such as 1000 for normal closure.
      _channel!.sink.close(1000);
      _channel = null;
      _isConnectAttempted = false;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _controller.add(false); // Correct the variable name here
    }
  }
}