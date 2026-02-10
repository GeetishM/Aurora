import 'package:hive/hive.dart';

part 'chat_history.g.dart';

@HiveType(typeId: 1)
class ChatHistory extends HiveObject {
  @HiveField(0)
  final String chatId;

  @HiveField(1)
  String title;

  @HiveField(2)
  String lastMessage;

  @HiveField(3)
  DateTime updatedAt;

  ChatHistory({
    required this.chatId,
    required this.title,
    required this.lastMessage,
    required this.updatedAt,
  });
}
