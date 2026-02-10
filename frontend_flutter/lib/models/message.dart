import 'package:hive/hive.dart';

part 'message.g.dart';

@HiveType(typeId: 3)
class Message extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String chatId;

  @HiveField(2)
  final String text;

  @HiveField(3)
  final bool isUser;

  @HiveField(4)
  final DateTime timestamp;

  Message({
    required this.id,
    required this.chatId,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
