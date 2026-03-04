import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/storage/boxes.dart';
import '../../models/chat_history.dart';
import '../../state/chat_controller.dart';
import '../../theme/app_theme.dart';
import 'chat_screen.dart';

class ChatHistoryScreen extends StatelessWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuroraColors.background,
      appBar: _buildAppBar(context),
      drawer: _AuroraSidebar(),
      // ✅ Body is either the active chat view OR the welcome splash.
      //    ChatView itself is NOT a Scaffold — no double AppBar.
      body: Consumer<ChatController>(
        builder: (context, controller, _) {
          if (controller.currentChatId == null) {
            return const _WelcomeSplash();
          }
          return const ChatView();
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AuroraColors.background,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: AuroraColors.textSecondary),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
          tooltip: 'Menu',
        ),
      ),
      title: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                AuroraColors.auroraGlow.createShader(bounds),
            child: const Text(
              'Aurora',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Consumer<ChatController>(
          builder: (context, controller, _) => IconButton(
            icon: ShaderMask(
              shaderCallback: (b) => AuroraColors.userBubble.createShader(b),
              child: const Icon(Icons.edit_square, color: Colors.white, size: 22),
            ),
            tooltip: 'New chat',
            onPressed: () => controller.createNewChat(),
          ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AuroraColors.divider, height: 1),
      ),
    );
  }
}

// ── SIDEBAR ───────────────────────────────────────────────────────────────────

class _AuroraSidebar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final box = HiveBoxes.chatHistoryBox();

    return Drawer(
      backgroundColor: AuroraColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) =>
                        AuroraColors.auroraGlow.createShader(b),
                    child: const Text(
                      'Aurora',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AuroraColors.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // New Chat button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _NewChatButton(),
            ),

            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'RECENT CHATS',
                style: TextStyle(
                  color: AuroraColors.textHint,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
            ),

            Expanded(
              child: ValueListenableBuilder(
                valueListenable: box.listenable(),
                builder: (context, _, __) {
                  final chats = box.values.toList()
                    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

                  if (chats.isEmpty) {
                    return const Center(
                      child: Text(
                        'No chats yet',
                        style: TextStyle(color: AuroraColors.textHint),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final ChatHistory chat = chats[index];
                      return _ChatTile(chat: chat);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewChatButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AuroraColors.userBubble,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            context.read<ChatController>().createNewChat();
            Navigator.pop(context);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'New Chat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatHistory chat;
  const _ChatTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ChatController>();
    final isActive = controller.currentChatId == chat.chatId;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isActive ? AuroraColors.surfaceVariant : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isActive
            ? Border.all(color: AuroraColors.teal.withOpacity(0.3), width: 1)
            : null,
      ),
      child: ListTile(
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Icon(
          Icons.chat_bubble_outline_rounded,
          size: 16,
          color: isActive ? AuroraColors.teal : AuroraColors.textHint,
        ),
        title: Text(
          chat.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isActive
                ? AuroraColors.textPrimary
                : AuroraColors.textSecondary,
            fontSize: 13,
            fontWeight:
                isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: chat.lastMessage.isNotEmpty
            ? Text(
                chat.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AuroraColors.textHint, fontSize: 11),
              )
            : null,
        onTap: () {
          controller.loadChat(chat.chatId);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ── WELCOME SPLASH ────────────────────────────────────────────────────────────

class _WelcomeSplash extends StatelessWidget {
  const _WelcomeSplash();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Aurora glow orb
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFF00E5C4),
                  Color(0xFF7C4DFF),
                  Colors.transparent,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: AuroraColors.teal.withOpacity(0.35),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 38,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 28),
          ShaderMask(
            shaderCallback: (b) =>
                AuroraColors.auroraGlow.createShader(b),
            child: const Text(
              'Aurora',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your women\'s health companion',
            style: TextStyle(
              color: AuroraColors.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 40),
          _StartButton(),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AuroraColors.userBubble,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AuroraColors.teal.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => context.read<ChatController>().createNewChat(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            child: Text(
              'Start a conversation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}