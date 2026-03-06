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
      appBar: _AuroraAppBar(),
      drawer: const _AuroraSidebar(),
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
}

// ── APP BAR ───────────────────────────────────────────────────────────────────

class _AuroraAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatController>(
      builder: (context, controller, _) {
        return AppBar(
          backgroundColor: AuroraColors.background,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded,
                  color: AuroraColors.textSecondary),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              tooltip: 'Menu',
            ),
          ),
          title: ShaderMask(
            shaderCallback: (b) => AuroraColors.auroraGlow.createShader(b),
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
          actions: [
            _LanguagePicker(),
            IconButton(
              icon: ShaderMask(
                shaderCallback: (b) => AuroraColors.userBubble.createShader(b),
                child: const Icon(Icons.edit_square,
                    color: Colors.white, size: 22),
              ),
              tooltip: 'New chat',
              onPressed: () async => await controller.createNewChat(),
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: AuroraColors.divider, height: 1),
          ),
        );
      },
    );
  }
}

// ── LANGUAGE PICKER ───────────────────────────────────────────────────────────

class _LanguagePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final languages  = ChatController.supportedLanguages;

    final currentName = languages.entries
        .firstWhere(
          (e) => e.value == controller.language,
          orElse: () => const MapEntry('English', 'en'),
        )
        .key;

    return PopupMenuButton<String>(
      tooltip: 'Select language',
      color: AuroraColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AuroraColors.divider, width: 1),
      ),
      offset: const Offset(0, 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded,
                size: 18, color: AuroraColors.textSecondary),
            const SizedBox(width: 5),
            Text(
              currentName,
              style: const TextStyle(
                  color: AuroraColors.textSecondary, fontSize: 13),
            ),
            const Icon(Icons.arrow_drop_down_rounded,
                size: 18, color: AuroraColors.textSecondary),
          ],
        ),
      ),
      onSelected: (code) => controller.setLanguage(code),
      itemBuilder: (_) => languages.entries.map((entry) {
        final isSelected = controller.language == entry.value;
        return PopupMenuItem<String>(
          value: entry.value,
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 16,
                color: isSelected ? AuroraColors.teal : AuroraColors.textHint,
              ),
              const SizedBox(width: 10),
              Text(
                entry.key,
                style: TextStyle(
                  color: isSelected
                      ? AuroraColors.textPrimary
                      : AuroraColors.textSecondary,
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── SIDEBAR ───────────────────────────────────────────────────────────────────

class _AuroraSidebar extends StatelessWidget {
  const _AuroraSidebar();

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
                      child: Text('No chats yet',
                          style: TextStyle(color: AuroraColors.textHint)),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    itemCount: chats.length,
                    itemBuilder: (context, index) =>
                        _ChatTile(chat: chats[index]),
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
          onTap: () async {
            await context.read<ChatController>().createNewChat();
            if (context.mounted) Navigator.pop(context);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('New Chat',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── CHAT TILE with long-press menu ────────────────────────────────────────────

class _ChatTile extends StatelessWidget {
  final ChatHistory chat;
  const _ChatTile({required this.chat});

  // ── Rename dialog ─────────────────────────────────────────────────────────
  Future<void> _showRenameDialog(BuildContext context) async {
    final textController = TextEditingController(text: chat.title);
    // Capture controller via read — safe for async use
    final controller = context.read<ChatController>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuroraColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AuroraColors.divider),
        ),
        title: const Text(
          'Rename Chat',
          style: TextStyle(
              color: AuroraColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: AuroraColors.textPrimary),
          cursorColor: AuroraColors.teal,
          decoration: InputDecoration(
            hintText: 'Enter chat name',
            hintStyle: const TextStyle(color: AuroraColors.textHint),
            filled: true,
            fillColor: AuroraColors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AuroraColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AuroraColors.teal, width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AuroraColors.divider),
            ),
          ),
          onSubmitted: (_) async {
            await controller.renameChat(chat.chatId, textController.text);
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AuroraColors.textSecondary)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: AuroraColors.userBubble,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () async {
                await controller.renameChat(chat.chatId, textController.text);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Rename',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );

    textController.dispose();
  }

  // ── Delete confirmation dialog ────────────────────────────────────────────
  Future<void> _showDeleteDialog(BuildContext context) async {
    // Capture via read — safe across async gap
    final controller = context.read<ChatController>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuroraColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AuroraColors.divider),
        ),
        title: const Text(
          'Delete Chat',
          style: TextStyle(
              color: AuroraColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Delete "${chat.title}"? This cannot be undone.',
          style: const TextStyle(
              color: AuroraColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AuroraColors.textSecondary)),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.red.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () async {
                await controller.deleteChat(chat.chatId);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Delete',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // context.watch for reactive UI (isActive highlight)
    final isActive = context.select<ChatController, bool>(
      (c) => c.currentChatId == chat.chatId,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isActive ? AuroraColors.surfaceVariant : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isActive
            ? Border.all(
                color: AuroraColors.teal.withOpacity(0.3), width: 1)
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
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
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

        // ── Tap: open chat ─────────────────────────────────────────────
        onTap: () async {
          // Use read in callbacks — never watch
          await context.read<ChatController>().loadChat(chat.chatId);
          if (context.mounted) Navigator.pop(context);
        },

        // ── Long press: bottom sheet menu ──────────────────────────────
        onLongPress: () => _showChatMenu(context),

        // ── Trailing: three-dot menu ───────────────────────────────────
        trailing: _ChatMenuButton(
          onRename: () => _showRenameDialog(context),
          onDelete: () => _showDeleteDialog(context),
        ),
      ),
    );
  }

  void _showChatMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AuroraColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AuroraColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                chat.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AuroraColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(color: AuroraColors.divider, height: 1),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline_rounded,
                  color: AuroraColors.teal, size: 20),
              title: const Text('Rename',
                  style: TextStyle(color: AuroraColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: Colors.red.shade400, size: 20),
              title: Text('Delete',
                  style: TextStyle(color: Colors.red.shade400)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Three-dot menu button on each tile ───────────────────────────────────────

class _ChatMenuButton extends StatelessWidget {
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ChatMenuButton({
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded,
          size: 16, color: AuroraColors.textHint),
      color: AuroraColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AuroraColors.divider, width: 1),
      ),
      onSelected: (value) {
        if (value == 'rename') onRename();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: const [
              Icon(Icons.drive_file_rename_outline_rounded,
                  size: 16, color: AuroraColors.teal),
              SizedBox(width: 10),
              Text('Rename',
                  style: TextStyle(
                      color: AuroraColors.textPrimary, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 16, color: Colors.red.shade400),
              const SizedBox(width: 10),
              Text('Delete',
                  style: TextStyle(
                      color: Colors.red.shade400, fontSize: 13)),
            ],
          ),
        ),
      ],
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
            child: const Icon(Icons.auto_awesome_rounded,
                size: 38, color: Colors.white),
          ),
          const SizedBox(height: 28),
          ShaderMask(
            shaderCallback: (b) => AuroraColors.auroraGlow.createShader(b),
            child: const Text(
              'Aurora',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Your women's health companion",
            style: TextStyle(color: AuroraColors.textSecondary, fontSize: 15),
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
          onTap: () async =>
              await context.read<ChatController>().createNewChat(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            child: Text(
              'Start a conversation',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}