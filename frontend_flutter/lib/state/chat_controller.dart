import 'package:flutter/material.dart';
import '../core/storage/boxes.dart';
import '../core/storage/hive_service.dart';
import '../core/websocket/ws_service.dart';
import '../models/chat_history.dart';
import '../models/message.dart';

class ChatController extends ChangeNotifier {
  final WebSocketService _ws = WebSocketService();

  final List<Message> messages = [];
  String? currentChatId;
  String language = 'en'; // expose so UI can set it
  bool isStreaming = false;

  ChatController() {
    _ws.connect();
  }

  // ── LOAD ─────────────────────────────────────────────────────────────────

  void loadChat(String chatId) {
    if (chatId.isEmpty) return;
    currentChatId = chatId;
    messages
      ..clear()
      ..addAll(HiveService.getMessages(chatId));
    notifyListeners();
  }

  // ── CREATE ────────────────────────────────────────────────────────────────

  void createNewChat() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    final chat = ChatHistory(
      chatId:      id,
      title:       'New Chat',
      lastMessage: '',
      updatedAt:   DateTime.now(),
    );

    HiveBoxes.chatHistoryBox().put(id, chat);
    loadChat(id);
  }

  // ── SEND ──────────────────────────────────────────────────────────────────

  void sendMessage(String text) {
    if (currentChatId == null || isStreaming) return;

    final chatId = currentChatId!;

    // 1️⃣ Save user message
    final userMsg = Message(
      id:        DateTime.now().millisecondsSinceEpoch.toString(),
      chatId:    chatId,
      text:      text,
      isUser:    true,
      timestamp: DateTime.now(),
    );
    messages.add(userMsg);
    HiveService.saveMessage(userMsg);

    // 2️⃣ Placeholder for assistant (streams into this)
    final assistantMsg = Message(
      id:        '${DateTime.now().millisecondsSinceEpoch}_ai',
      chatId:    chatId,
      text:      '',
      isUser:    false,
      timestamp: DateTime.now(),
    );
    messages.add(assistantMsg);
    isStreaming = true;
    notifyListeners();

    // 3️⃣ Stream from backend
    _ws.sendMessage(
      message:  text,
      language: language,
      onChunk: (chunk) {
        assistantMsg.text += chunk;
        notifyListeners();
      },
      onFinal: (finalText) async {
        // Replace streamed English text with the final (possibly translated) text
        assistantMsg.text = finalText;
        isStreaming = false;
        notifyListeners();

        await HiveService.saveMessage(assistantMsg);
        await HiveService.updateChatPreview(chatId, finalText);
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _ws.disconnect();
    super.dispose();
  }
}