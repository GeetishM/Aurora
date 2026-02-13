import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef ChunkCallback = void Function(String chunk);
typedef FinalCallback = void Function();

class WebSocketService {
  WebSocketChannel? _channel;

  ChunkCallback? _onChunk;
  FinalCallback? _onFinal;

  void connect() {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://10.0.2.2:8000/ws/chat'), 
      // 👆 If Android emulator
      // For Chrome use:
      // Uri.parse('ws://localhost:8000/ws/chat')
    );

    _channel!.stream.listen(
      (data) {
        final decoded = jsonDecode(data);

        if (decoded['type'] == 'chunk') {
          _onChunk?.call(decoded['text']);
        }

        if (decoded['type'] == 'final') {
          _onFinal?.call();
        }
      },
      onError: (e) {
        print("WebSocket error: $e");
      },
      onDone: () {
        print("WebSocket closed");
      },
    );
  }

  void sendMessage({
    required String message,
    required String language,
    required ChunkCallback onChunk,
    required FinalCallback onFinal,
  }) {
    _onChunk = onChunk;
    _onFinal = onFinal;

    _channel?.sink.add(jsonEncode({
      "message": message,
      "language": language,
    }));
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
