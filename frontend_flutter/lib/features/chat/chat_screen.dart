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

  // null  → showing topic grid
  // 0..n  → showing questions for that topic index
  int? _selectedTopicIndex;

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

  void _sendSuggestion(String text) {
    final controller = context.read<ChatController>();
    controller.sendMessage(text);
    setState(() => _selectedTopicIndex = null);
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
        final isEmpty  = messages.isEmpty;

        if (messages.isNotEmpty) _scrollToBottom();

        return Column(
          children: [
            // ── Message list OR centered topic grid ──────────────────
            Expanded(
              child: Stack(
                children: [
                  if (!isEmpty)
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg    = messages[index];
                        final isLast = index == messages.length - 1;
                        return _MessageBubble(
                          message: msg,
                          isStreaming: isLast &&
                              !msg.isUser &&
                              (controller.isStreaming ||
                                  controller.isTranslating),
                        );
                      },
                    )
                  else
                    // Show centered topic grid; hide it when questions open
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _selectedTopicIndex == null
                          ? _TopicsGrid(
                              key: const ValueKey('grid'),
                              onTopicTapped: (i) =>
                                  setState(() => _selectedTopicIndex = i),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('empty'),
                            ),
                    ),

                  // ── Translating overlay ──────────────────────────
                  if (controller.isTranslating && !isEmpty)
                    Positioned.fill(
                      child: Container(
                        color: AuroraColors.bg(context).withOpacity(0.6),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            decoration: BoxDecoration(
                              color: AuroraColors.surf(context),
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
                                Text(
                                  controller.uiLabel('translating'),
                                  style: TextStyle(
                                    color: AuroraColors.txtSecondary(context),
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

            // ── Questions panel (slides in above input bar) ──────────
            if (isEmpty && _selectedTopicIndex != null)
              _QuestionsPanel(
                topicIndex: _selectedTopicIndex!,
                onBack: () => setState(() => _selectedTopicIndex = null),
                onQuestion: _sendSuggestion,
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

// ── TOPICS GRID ───────────────────────────────────────────────────────────────
// Centered wrap of topic pills shown when no chat is active.

class _TopicsGrid extends StatelessWidget {
  final void Function(int) onTopicTapped;

  const _TopicsGrid({super.key, required this.onTopicTapped});

  @override
  Widget build(BuildContext context) {
    final c      = context.watch<ChatController>();
    final topics = c.getTopics();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Greeting ────────────────────────────────────────────
            Text(
              c.uiLabel('how_can_i_help'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AuroraColors.txtPrimary(context),
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),

            const SizedBox(height: 32),

            // ── Topic pills — centered Wrap ──────────────────────────
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: List.generate(topics.length, (i) {
                final topic = topics[i];
                return _TopicPill(
                  icon:    topic['icon']  as String,
                  label:   topic['label'] as String,
                  onTap:   () => onTopicTapped(i),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicPill extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _TopicPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AuroraColors.surfVar(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AuroraColors.div(context), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AuroraColors.txtPrimary(context),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── QUESTIONS PANEL ───────────────────────────────────────────────────────────
// Slides in just above the input bar when a topic is selected.

class _QuestionsPanel extends StatelessWidget {
  final int topicIndex;
  final VoidCallback onBack;
  final void Function(String) onQuestion;

  const _QuestionsPanel({
    required this.topicIndex,
    required this.onBack,
    required this.onQuestion,
  });

  @override
  Widget build(BuildContext context) {
    final c      = context.watch<ChatController>();
    final topics = c.getTopics();
    final topic  = topics[topicIndex];
    final questions = topic['questions'] as List<dynamic>;

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: AuroraColors.surf(context),
          border: Border(
            top: BorderSide(color: AuroraColors.div(context), width: 1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header: back + topic name ──────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: AuroraColors.accent(context),
                    ),
                    onPressed: onBack,
                    tooltip: 'Back to topics',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${topic['icon']}  ${topic['label']}',
                    style: TextStyle(
                      color: AuroraColors.accent(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // ── Question tiles ────────────────────────────────────
            ...questions.map((q) => _QuestionTile(
                  text:  q as String,
                  onTap: () => onQuestion(q as String),
                )),

            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

// ── Question tile ─────────────────────────────────────────────────────────────

class _QuestionTile extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _QuestionTile({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: AuroraColors.txtPrimary(context),
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: AuroraColors.txtHint(context),
            ),
          ],
        ),
      ),
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
          SnackBar(
            content: const Text('Copied to clipboard'),
            duration: const Duration(seconds: 1),
            backgroundColor: AuroraColors.surfVar(context),
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
            topLeft:     Radius.circular(18),
            topRight:    Radius.circular(18),
            bottomLeft:  Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color:      AuroraColors.teal.withOpacity(0.2),
              blurRadius: 12,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color:    Colors.white,
            fontSize: 14.5,
            height:   1.5,
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        if (text.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Copied to clipboard'),
              duration: const Duration(seconds: 1),
              backgroundColor: AuroraColors.surfVar(context),
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
          color: AuroraColors.surfVar(context),
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(4),
            topRight:    Radius.circular(18),
            bottomLeft:  Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: AuroraColors.div(context), width: 1),
        ),
        child: isStreaming && text.isEmpty
            ? const _TypingIndicator()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color:    AuroraColors.txtPrimary(context),
                      fontSize: 14.5,
                      height:   1.55,
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

// ── TYPING INDICATOR ──────────────────────────────────────────────────────────

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
            final t       = (_ac.value - i * 0.15).clamp(0.0, 1.0);
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

// ── CURSOR BLINK ──────────────────────────────────────────────────────────────

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
            color:      AuroraColors.teal.withOpacity(0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        size:  15,
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
        shape:  BoxShape.circle,
        color:  AuroraColors.surfVar(context),
        border: Border.all(color: AuroraColors.div(context), width: 1),
      ),
      child: Icon(
        Icons.person_rounded,
        size:  16,
        color: AuroraColors.txtSecondary(context),
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
    final hintText = context.watch<ChatController>().uiLabel('message_hint');

    return Container(
      color: AuroraColors.bg(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: AuroraColors.div(context)),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16, 12, 16,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ── Text field ──────────────────────────────────────
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AuroraColors.surfVar(context),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: AuroraColors.div(context),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: widget.controller,
                      style: TextStyle(
                        color:    AuroraColors.txtPrimary(context),
                        fontSize: 14.5,
                      ),
                      maxLines:              5,
                      minLines:              1,
                      textCapitalization:    TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText:  hintText,
                        hintStyle: TextStyle(
                          color:    AuroraColors.txtHint(context),
                          fontSize: 14,
                        ),
                        border:          InputBorder.none,
                        contentPadding:  const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => widget.onSend(),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // ── Send button ─────────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width:  44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape:    BoxShape.circle,
                    gradient: (_hasText && !widget.isStreaming)
                        ? AuroraColors.userBubble
                        : null,
                    color: (_hasText && !widget.isStreaming)
                        ? null
                        : AuroraColors.surfVar(context),
                    boxShadow: (_hasText && !widget.isStreaming)
                        ? [
                            BoxShadow(
                              color:      AuroraColors.teal.withOpacity(0.35),
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
                                width:  18,
                                height: 18,
                                child:  CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AuroraColors.teal,
                                ),
                              )
                            : Icon(
                                Icons.arrow_upward_rounded,
                                size:  20,
                                color: _hasText
                                    ? Colors.white
                                    : AuroraColors.txtHint(context),
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