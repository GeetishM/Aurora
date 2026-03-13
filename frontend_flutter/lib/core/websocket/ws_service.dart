import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:web_socket_channel/web_socket_channel.dart';

typedef ChunkCallback = void Function(String chunk);
typedef FinalCallback = void Function(String finalText);

class WebSocketService {
  WebSocketChannel? _channel;
  bool _connected = false;

  ChunkCallback? _onChunk;
  FinalCallback? _onFinal;

  static String get _wsUrl {
    if (kIsWeb) return 'ws://localhost:8000/ws/chat';
    if (Platform.isAndroid) return 'ws://10.0.2.2:8000/ws/chat';
    if (Platform.isIOS) return 'ws://localhost:8000/ws/chat';
    return 'ws://localhost:8000/ws/chat';
  }

  void connect() {
    if (_connected) return;
    debugPrint('[WS] Connecting to: $_wsUrl');
    _channel   = WebSocketChannel.connect(Uri.parse(_wsUrl));
    _connected = true;

    _channel!.stream.listen(
      (data) {
        final decoded = jsonDecode(data as String);
        final type    = decoded['type'] as String?;
        final text    = decoded['text']  as String? ?? '';

        if (type == 'chunk') {
          _onChunk?.call(text);
        } else if (type == 'final') {
          _onFinal?.call(text);
        } else if (decoded['error'] != null) {
          debugPrint('[WS] Server error: ${decoded['error']}');
        }
      },
      onError: (e) {
        _connected = false;
        debugPrint('[WS] Stream error: $e');
      },
      onDone: () {
        _connected = false;
        debugPrint('[WS] Connection closed');
      },
    );
  }

  void sendMessage({
    required String message,
    required String language,
    required ChunkCallback onChunk,
    required FinalCallback onFinal,
  }) {
    if (!_connected) connect();
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