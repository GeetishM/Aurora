import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef ChunkCallback = void Function(String chunk);
typedef FinalCallback = void Function(String finalText); // ✅ now carries the text

class WebSocketService {
  WebSocketChannel? _channel;
  bool _connected = false;

  ChunkCallback? _onChunk;
  FinalCallback? _onFinal;

  void connect() {
    if (_connected) return;

    _channel = WebSocketChannel.connect(
      Uri.parse('ws://10.0.2.2:8000/ws/chat'),
      // Android emulator  → ws://10.0.2.2:8000/ws/chat
      // iOS simulator     → ws://127.0.0.1:8000/ws/chat
      // Physical device   → ws://<your-machine-ip>:8000/ws/chat
      // Web (Chrome)      → ws://localhost:8000/ws/chat
    );

    _connected = true;

    _channel!.stream.listen(
      (data) {
        final decoded = jsonDecode(data as String);
        final type    = decoded['type'] as String?;
        final text    = decoded['text'] as String? ?? '';

        if (type == 'chunk') {
          _onChunk?.call(text);
        } else if (type == 'final') {
          _onFinal?.call(text); // ✅ pass translated text up
        } else if (decoded['error'] != null) {
          debugPrint('WebSocket error from server: ${decoded['error']}');
        }
      },
      onError: (e) {
        _connected = false;
        debugPrint('WebSocket stream error: $e');
      },
      onDone: () {
        _connected = false;
        debugPrint('WebSocket connection closed');
      },
    );
  }

  void sendMessage({
    required String message,
    required String language,
    required ChunkCallback onChunk,
    required FinalCallback onFinal,
  }) {
    if (_channel == null) {
      connect();
    }

    _onChunk = onChunk;
    _onFinal = onFinal;

    _channel?.sink.add(jsonEncode({
      'message':  message,
      'language': language,
    }));
  }

  void disconnect() {
    _connected = false;
    _channel?.sink.close();
    _channel = null;
  }
}