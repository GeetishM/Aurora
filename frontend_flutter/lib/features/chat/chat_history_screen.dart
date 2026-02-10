import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/storage/boxes.dart';
import '../../models/chat_history.dart';
import 'chat_screen.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  int selectedIndex = 0;

  void createNewChat() {
    final chatId = DateTime.now().millisecondsSinceEpoch.toString();

    final chat = ChatHistory(
      chatId: chatId,
      title: 'New Chat',
      lastMessage: '',
      updatedAt: DateTime.now(),
    );

    HiveBoxes.chatHistoryBox().add(chat);
    setState(() {
      selectedIndex = HiveBoxes.chatHistoryBox().length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    Widget sidebar = Container(
      width: 280,
      color: const Color(0xFF202123),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Text(
            'Aurora',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: createNewChat,
            child: const Text('New Chat'),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable:
                  HiveBoxes.chatHistoryBox().listenable(),
              builder: (context, box, _) {
                if (box.isEmpty) {
                  return const Center(
                    child: Text(
                      'No chats yet',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: box.length,
                  itemBuilder: (context, index) {
                    final chat = box.getAt(index)!;
                    final isSelected = index == selectedIndex;

                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: Colors.white10,
                      title: Text(
                        chat.title,
                        style: TextStyle(
                          color:
                              isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                      subtitle: Text(
                        chat.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white38),
                      ),
                      onTap: () {
                        setState(() => selectedIndex = index);
                        if (!isWide) Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );

    Widget chatArea = ValueListenableBuilder(
      valueListenable: HiveBoxes.chatHistoryBox().listenable(),
      builder: (context, box, _) {
        if (box.isEmpty) {
          return const Center(child: Text('Start a new chat'));
        }

        final chat = box.getAt(selectedIndex)!;

        return ChatScreen(
          chatId: chat.chatId,
          chatTitle: chat.title,
        );
      },
    );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            sidebar,
            Expanded(child: chatArea),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Aurora')),
      drawer: Drawer(child: sidebar),
      body: chatArea,
    );
  }
}
