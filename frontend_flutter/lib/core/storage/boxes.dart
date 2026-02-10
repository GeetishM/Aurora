import 'package:hive/hive.dart';
import '../../models/chat_history.dart';
import '../../models/message.dart';
import '../../models/user_model.dart';

class HiveBoxes {
  static const String chatHistory = 'chat_history';
  static const String messages = 'messages';
  static const String user = 'user';

  static Box<ChatHistory> chatHistoryBox() =>
      Hive.box<ChatHistory>(chatHistory);

  static Box<Message> messagesBox() =>
      Hive.box<Message>(messages);

  static Box<UserModel> userBox() =>
      Hive.box<UserModel>(user);
}
