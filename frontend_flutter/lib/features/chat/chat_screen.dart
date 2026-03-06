import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/message.dart';
import '../../state/chat_controller.dart';
import '../../theme/app_theme.dart';

// ✅ ChatView is a pure widget — NO Scaffold inside.
//    ChatHistoryScreen owns the only Scaffold.
class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _inputHasFocus = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(ChatController controller) {
    final text = _textController.text.trim();
    if (text.isEmpty || controller.isStreaming) return;
    controller.sendMessage(text);
    _textController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatController>(
      builder: (context, controller, _) {
        final messages = controller.messages;

        if (controller.messages.isNotEmpty) {
          _scrollToBottom();
        }

        return Column(
          children: [
            // ── Message list ────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  messages.isEmpty
                  ? const _EmptyChatHint()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isLast = index == messages.length - 1;
                        final isLastAssistant = isLast && !msg.isUser;
                        return _MessageBubble(
                          message: msg,
                          // Show typing dots when:
                          // - English: streaming chunks (text is being built)
                          // - Non-English: streaming OR translating (text is empty until final)
                          isStreaming: isLastAssistant &&
                              (controller.isStreaming || controller.isTranslating),
                        );
                      },
                    ),
                  // ── Translating overlay ──────────────────────────
                  if (controller.isTranslating && messages.isNotEmpty)
                    Positioned.fill(
                      child: Container(
                        color: AuroraColors.background.withOpacity(0.6),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            decoration: BoxDecoration(
                              color: AuroraColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AuroraColors.teal.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AuroraColors.teal,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Translating messages...',
                                  style: TextStyle(
                                    color: AuroraColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Input bar ────────────────────────────────────────────
            _InputBar(
              controller: _textController,
              scrollController: _scrollController,
              isStreaming: controller.isStreaming,
              onSend: () => _send(controller),
            ),
          ],
        );
      },
    );
  }
}

// ── MESSAGE BUBBLE ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isStreaming;

  const _MessageBubble({
    required this.message,
    required this.isStreaming,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _AuroraAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                isUser
                    ? _UserBubble(text: message.text)
                    : _AssistantBubble(
                        text: message.text,
                        isStreaming: isStreaming,
                      ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _UserAvatar(),
          ],
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied to clipboard'),
            duration: Duration(seconds: 1),
            backgroundColor: AuroraColors.surfaceVariant,
          ),
        );
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: AuroraColors.userBubble,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: AuroraColors.teal.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final String text;
  final bool isStreaming;

  const _AssistantBubble({
    required this.text,
    required this.isStreaming,
  });

  // Non-English: text is empty while streaming because chunks are suppressed.
  // The typing indicator shows until onFinal fires with the translated text.

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        if (text.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied to clipboard'),
              duration: Duration(seconds: 1),
              backgroundColor: AuroraColors.surfaceVariant,
            ),
          );
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AuroraColors.surfaceVariant,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: AuroraColors.divider,
            width: 1,
          ),
        ),
        child: isStreaming && text.isEmpty
            ? const _TypingIndicator()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                      color: AuroraColors.textPrimary,
                      fontSize: 14.5,
                      height: 1.55,
                    ),
                  ),
                  if (isStreaming)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _CursorBlink(),
                    ),
                ],
              ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ac,
          builder: (_, __) {
            final t = (_ac.value - i * 0.15).clamp(0.0, 1.0);
            final opacity = (1 - (t - 0.5).abs() * 2).clamp(0.3, 1.0);
            return Container(
              margin: const EdgeInsets.only(right: 5),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AuroraColors.teal.withOpacity(opacity),
              ),
            );
          },
        );
      }),
    );
  }
}

class _CursorBlink extends StatefulWidget {
  @override
  State<_CursorBlink> createState() => _CursorBlinkState();
}

class _CursorBlinkState extends State<_CursorBlink>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ac,
      child: Container(
        width: 2,
        height: 14,
        decoration: BoxDecoration(
          color: AuroraColors.teal,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ── AVATARS ───────────────────────────────────────────────────────────────────

class _AuroraAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AuroraColors.teal, AuroraColors.purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AuroraColors.teal.withOpacity(0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        size: 15,
        color: Colors.white,
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AuroraColors.surfaceVariant,
        border: Border.all(color: AuroraColors.divider, width: 1),
      ),
      child: const Icon(
        Icons.person_rounded,
        size: 16,
        color: AuroraColors.textSecondary,
      ),
    );
  }
}

// ── INPUT BAR ─────────────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final ScrollController scrollController;
  final bool isStreaming;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.scrollController,
    required this.isStreaming,
    required this.onSend,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      final has = widget.controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AuroraColors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: AuroraColors.divider),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Text field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AuroraColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: AuroraColors.divider,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: widget.controller,
                      style: const TextStyle(
                        color: AuroraColors.textPrimary,
                        fontSize: 14.5,
                      ),
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Message Aurora...',
                        hintStyle: TextStyle(
                          color: AuroraColors.textHint,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => widget.onSend(),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Send / stop button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: (_hasText && !widget.isStreaming)
                        ? AuroraColors.userBubble
                        : null,
                    color: (_hasText && !widget.isStreaming)
                        ? null
                        : AuroraColors.surfaceVariant,
                    boxShadow: (_hasText && !widget.isStreaming)
                        ? [
                            BoxShadow(
                              color: AuroraColors.teal.withOpacity(0.35),
                              blurRadius: 12,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: (widget.isStreaming || !_hasText)
                          ? null
                          : widget.onSend,
                      child: Center(
                        child: widget.isStreaming
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AuroraColors.teal,
                                ),
                              )
                            : Icon(
                                Icons.arrow_upward_rounded,
                                size: 20,
                                color: _hasText
                                    ? Colors.white
                                    : AuroraColors.textHint,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── EMPTY HINT ────────────────────────────────────────────────────────────────

class _EmptyChatHint extends StatelessWidget {
  const _EmptyChatHint();

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      'What are common PMS symptoms?',
      'How does the menstrual cycle work?',
      'Tips for managing period pain?',
      'What is PCOS?',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (b) => AuroraColors.auroraGlow.createShader(b),
            child: const Text(
              'How can I help you today?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: suggestions.map((s) => _SuggestionChip(text: s)).toList(),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  const _SuggestionChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<ChatController>().sendMessage(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AuroraColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AuroraColors.divider, width: 1),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: AuroraColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}