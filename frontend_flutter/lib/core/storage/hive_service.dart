import 'package:flutter/widgets.dart';
import 'package:frontend_flutter/models/message.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/chat_history.dart';
import '../../models/user_model.dart';
import 'boxes.dart';

class HiveService {
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
}
