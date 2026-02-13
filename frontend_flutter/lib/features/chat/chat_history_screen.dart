import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../../state/chat_controller.dart';
import '../../models/chat_history.dart';
import '../../core/storage/boxes.dart';
import 'chat_screen.dart';

class ChatHistoryScreen extends StatelessWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = HiveBoxes.chatHistoryBox();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Aurora"),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                "Chats",
                style: TextStyle(fontSize: 18),
              ),
              const Divider(),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("New Chat"),
                  onPressed: () {
                    final controller = context.read<ChatController>();
                    controller.createNewChat();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          chatId: controller.currentChatId!,
                          chatTitle: "New Chat",
                        ),
                      ),
                    );
                  },
                ),
              ),

              const Divider(),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: box.listenable(),
                  builder: (context, _, __) {
                    final chats = box.values.toList()
                      ..sort((a, b) =>
                          b.updatedAt.compareTo(a.updatedAt));

                    return ListView.builder(
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final ChatHistory chat =
                            chats[index];

                        return ListTile(
                          title: Text(chat.title),
                          subtitle: Text(
                            chat.lastMessage,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.pop(context);

                            WidgetsBinding.instance
                                .addPostFrameCallback((_) {
                              context
                                  .read<ChatController>()
                                  .loadChat(chat.chatId);
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: const ChatScreen(
        chatId: "",  // ChatController handles real id
        chatTitle: "",
      ),
    );
  }
}
