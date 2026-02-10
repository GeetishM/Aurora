import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/storage/boxes.dart';
import '../../models/message.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatTitle;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  final scrollController = ScrollController();

  List<Message> get messages =>
      HiveBoxes.messagesBox()
          .values
          .where((m) => m.chatId == widget.chatId)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  void sendMessage() {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    final userMessage = Message(
      id: DateTime.now().toIso8601String(),
      chatId: widget.chatId,
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    HiveBoxes.messagesBox().add(userMessage);
    controller.clear();
    updateChatHistory(text);

    Future.delayed(const Duration(milliseconds: 500), () {
      final botMessage = Message(
        id: DateTime.now().toIso8601String(),
        chatId: widget.chatId,
        text: "I’m Aurora. This is a preview response.",
        isUser: false,
        timestamp: DateTime.now(),
      );

      HiveBoxes.messagesBox().add(botMessage);
      updateChatHistory(botMessage.text);
    });

    scrollToBottom();
  }

  void updateChatHistory(String lastMessage) {
    final box = HiveBoxes.chatHistoryBox();
    final index =
        box.values.toList().indexWhere((c) => c.chatId == widget.chatId);

    if (index != -1) {
      final chat = box.getAt(index)!;
      chat
        ..lastMessage = lastMessage
        ..updatedAt = DateTime.now()
        ..save();
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: HiveBoxes.messagesBox().listenable(),
            builder: (context, box, _) {
              final msgs = messages;

              if (msgs.isEmpty) {
                return const Center(
                  child: Text('Start the conversation'),
                );
              }

              return ListView.builder(
                controller: scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: msgs.length,
                itemBuilder: (context, index) {
                  final msg = msgs[index];

                  return Align(
                    alignment: msg.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      constraints:
                          const BoxConstraints(maxWidth: 500),
                      decoration: BoxDecoration(
                        color: msg.isUser
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          color: msg.isUser
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => sendMessage(),
                  decoration: const InputDecoration(
                    hintText: "Message Aurora...",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
