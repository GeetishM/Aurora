import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/chat_controller.dart';
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
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatController>().loadChat(widget.chatId);
    });
  }

  void _sendMessage(ChatController controller) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    controller.sendMessage(text);
    _textController.clear();
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(   // ✅ THIS FIXES YOUR ERROR
      appBar: AppBar(
        title: Text(widget.chatTitle.isEmpty ? "Aurora" : widget.chatTitle),
      ),
      body: Consumer<ChatController>(
        builder: (context, controller, _) {
          final messages = controller.messages;

          _autoScroll();

          return Column(
            children: [
              Expanded(
                child: messages.isEmpty
                    ? const Center(
                        child: Text("Start the conversation"),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final Message msg = messages[index];

                          return Align(
                            alignment: msg.isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin:
                                  const EdgeInsets.only(bottom: 12),
                              padding:
                                  const EdgeInsets.all(14),
                              constraints:
                                  const BoxConstraints(
                                      maxWidth: 500),
                              decoration: BoxDecoration(
                                color: msg.isUser
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                    : Colors.grey.shade300,
                                borderRadius:
                                    BorderRadius.circular(12),
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
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        onSubmitted: (_) =>
                            _sendMessage(controller),
                        decoration:
                            const InputDecoration(
                          hintText: "Message Aurora...",
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon:
                          const Icon(Icons.send),
                      onPressed: () =>
                          _sendMessage(controller),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
