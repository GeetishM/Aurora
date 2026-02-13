import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/message.dart';
import '../../models/chat_history.dart';
import '../../models/user_model.dart';
import 'boxes.dart';

class HiveService {
  // ---------------- INIT ----------------
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

  // ---------------- MESSAGES ----------------

  /// Get all messages for a chat (sorted)
  static List<Message> getMessages(String chatId) {
    final box = Hive.box<Message>(HiveBoxes.messages);

    return box.values
        .where((m) => m.chatId == chatId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Save a single message
  static Future<void> saveMessage(Message message) async {
    final box = Hive.box<Message>(HiveBoxes.messages);
    await box.put(message.id, message);
  }

  // ---------------- CHAT HISTORY ----------------

  /// Update sidebar preview + timestamp
  static Future<void> updateChatPreview(
    String chatId,
    String lastMessage,
  ) async {
    final box = Hive.box<ChatHistory>(HiveBoxes.chatHistory);

    final chat = box.get(chatId);
    if (chat == null) return;

    chat.lastMessage = lastMessage;
    chat.updatedAt = DateTime.now();

    await chat.save();
  }
}
