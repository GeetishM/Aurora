import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/message.dart';
import '../../models/chat_history.dart';
import '../../models/user_model.dart';
import 'boxes.dart';

class HiveService {
  // ── INIT ──────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();
    Hive.registerAdapter(ChatHistoryAdapter());
    Hive.registerAdapter(MessageAdapter());
    Hive.registerAdapter(UserModelAdapter());
    await Hive.openBox<ChatHistory>(HiveBoxes.chatHistory);
    await Hive.openBox<Message>(HiveBoxes.messages);
    await Hive.openBox<UserModel>(HiveBoxes.user);
  }

  // ── MESSAGES ──────────────────────────────────────────────────────────────

  static List<Message> getMessages(String chatId) {
    return Hive.box<Message>(HiveBoxes.messages)
        .values
        .where((m) => m.chatId == chatId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static Future<void> saveMessage(Message message) async {
    await Hive.box<Message>(HiveBoxes.messages).put(message.id, message);
  }

  /// Delete all messages belonging to [chatId]
  static Future<void> deleteMessages(String chatId) async {
    final box  = Hive.box<Message>(HiveBoxes.messages);
    final keys = box.values
        .where((m) => m.chatId == chatId)
        .map((m) => m.id)
        .toList();
    await box.deleteAll(keys);
  }

  // ── CHAT HISTORY ──────────────────────────────────────────────────────────

  static Future<void> updateChatPreview(
      String chatId, String lastMessage) async {
    final chat = Hive.box<ChatHistory>(HiveBoxes.chatHistory).get(chatId);
    if (chat == null) return;
    chat.lastMessage = lastMessage;
    chat.updatedAt   = DateTime.now();
    await chat.save();
  }

  /// Rename a chat
  static Future<void> renameChat(String chatId, String newTitle) async {
    final chat = Hive.box<ChatHistory>(HiveBoxes.chatHistory).get(chatId);
    if (chat == null) return;
    chat.title     = newTitle.trim().isEmpty ? 'New Chat' : newTitle.trim();
    chat.updatedAt = DateTime.now();
    await chat.save();
  }

  /// Delete a chat and all its messages
  static Future<void> deleteChat(String chatId) async {
    await deleteMessages(chatId);
    await Hive.box<ChatHistory>(HiveBoxes.chatHistory).delete(chatId);
  }
}