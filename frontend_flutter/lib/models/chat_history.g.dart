// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_history.dart';

class ChatHistoryAdapter extends TypeAdapter<ChatHistory> {
  @override
  final int typeId = 1;

  @override
  ChatHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return ChatHistory(
      chatId: fields[0] as String,
      title: fields[1] as String,
      lastMessage: fields[2] as String,
      updatedAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ChatHistory obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.chatId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.lastMessage)
      ..writeByte(3)
      ..write(obj.updatedAt);
  }
}
