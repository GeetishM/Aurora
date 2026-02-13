import 'package:flutter/material.dart';
import 'package:frontend_flutter/core/storage/boxes.dart';
import 'package:frontend_flutter/models/chat_history.dart';
import '../models/message.dart';
import '../core/websocket/ws_service.dart';
import '../core/storage/hive_service.dart';

class ChatController extends ChangeNotifier {
  final WebSocketService _ws = WebSocketService();

  final List<Message> messages = [];
  String? currentChatId;

  ChatController() {
    _ws.connect();
  }

  void loadChat(String chatId) {
    currentChatId = chatId;
    messages.clear();
    messages.addAll(HiveService.getMessages(chatId));
    notifyListeners();
  }

  void createNewChat() {
  final id = DateTime.now().millisecondsSinceEpoch.toString();

  final chat = ChatHistory(
    chatId: id,
    title: "New Chat",
    lastMessage: "",
    updatedAt: DateTime.now(),
  );

  HiveBoxes.chatHistoryBox().put(id, chat);

  loadChat(id);
}


  void sendMessage(String text) {
    if (currentChatId == null) return;

    final chatId = currentChatId!;

    // 1️⃣ USER MESSAGE
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: chatId,
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    messages.add(userMessage);
    HiveService.saveMessage(userMessage);
    notifyListeners();

    // 2️⃣ EMPTY ASSISTANT MESSAGE (for streaming)
    final assistantMessage = Message(
      id: "${DateTime.now().millisecondsSinceEpoch}_ai",
      chatId: chatId,
      text: "",
      isUser: false,
      timestamp: DateTime.now(),
    );

    messages.add(assistantMessage);
    notifyListeners();

    // 3️⃣ STREAM FROM BACKEND
    _ws.sendMessage(
      message: text,
      language: 'en',
      onChunk: (chunk) {
        assistantMessage.text =
            assistantMessage.text + chunk;
        notifyListeners();
      },
      onFinal: () async {
        await HiveService.saveMessage(assistantMessage);
        await HiveService.updateChatPreview(
            chatId, assistantMessage.text);
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
