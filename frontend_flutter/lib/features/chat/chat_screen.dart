
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../models/message.dart';
import '../../state/chat_controller.dart';
import '../../theme/app_theme.dart';
import '../../core/config/server_config.dart';
import '../../core/tts/tts_service.dart';  // ← NEW

// ── ChatView ──────────────────────────────────────────────────────────────────

class ChatView extends StatefulWidget {
  const ChatView({super.key});
  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _textController   = TextEditingController();
  final _scrollController = ScrollController();
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
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _selectedTopicIndex == null
                          ? _TopicsGrid(
                              key: const ValueKey('grid'),
                              onTopicTapped: (i) =>
                                  setState(() => _selectedTopicIndex = i),
                            )
                          : const SizedBox.shrink(key: ValueKey('empty')),
                    ),

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
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AuroraColors.teal),
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

            if (isEmpty && _selectedTopicIndex != null)
              _QuestionsPanel(
                topicIndex: _selectedTopicIndex!,
                onBack:     () => setState(() => _selectedTopicIndex = null),
                onQuestion: _sendSuggestion,
              ),

            _InputBar(
              controller:       _textController,
              scrollController: _scrollController,
              isStreaming:      controller.isStreaming,
              onSend:           () => _send(controller),
            ),
          ],
        );
      },
    );
  }
}

// ── TOPICS GRID ───────────────────────────────────────────────────────────────

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
            Text(
              c.uiLabel('how_can_i_help'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color:      AuroraColors.txtPrimary(context),
                fontSize:   22,
                fontWeight: FontWeight.w700,
                height:     1.35,
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing:    10,
              runSpacing: 10,
              alignment:  WrapAlignment.center,
              children: List.generate(topics.length, (i) {
                final topic = topics[i];
                return _TopicPill(
                  icon:  topic['icon']  as String,
                  label: topic['label'] as String,
                  onTap: () => onTopicTapped(i),
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
  const _TopicPill(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color:        AuroraColors.surfVar(context),
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
                  color:      AuroraColors.txtPrimary(context),
                  fontSize:   13.5,
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

class _QuestionsPanel extends StatelessWidget {
  final int topicIndex;
  final VoidCallback onBack;
  final void Function(String) onQuestion;
  const _QuestionsPanel(
      {required this.topicIndex,
      required this.onBack,
      required this.onQuestion});

  @override
  Widget build(BuildContext context) {
    final c         = context.watch<ChatController>();
    final topics    = c.getTopics();
    final topic     = topics[topicIndex];
    final questions = topic['questions'] as List<dynamic>;

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve:    Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: AuroraColors.surf(context),
          border: Border(
              top: BorderSide(color: AuroraColors.div(context), width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: AuroraColors.accent(context)),
                    onPressed:   onBack,
                    tooltip:     'Back to topics',
                    padding:     const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${topic['icon']}  ${topic['label']}',
                    style: TextStyle(
                      color:      AuroraColors.accent(context),
                      fontSize:   14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
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
              child: Text(text,
                  style: TextStyle(
                      color:    AuroraColors.txtPrimary(context),
                      fontSize: 13.5,
                      height:   1.4)),
            ),
            const SizedBox(width: 10),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: AuroraColors.txtHint(context)),
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
  const _MessageBubble(
      {required this.message, required this.isStreaming});

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
          if (!isUser) ...[_AuroraAvatar(), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                isUser
                    ? _UserBubble(text: message.text)
                    : _AssistantBubble(
                        text: message.text, isStreaming: isStreaming),
              ],
            ),
          ),
          if (isUser) ...[const SizedBox(width: 8), _UserAvatar()],
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Copied to clipboard'),
          duration: const Duration(seconds: 1),
          backgroundColor: AuroraColors.surfVar(context),
        ));
      },
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            )
          ],
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 14.5, height: 1.5)),
      ),
    );
  }
}

// ── ASSISTANT BUBBLE — with TTS speaker button ────────────────────────────────

class _AssistantBubble extends StatefulWidget {
  final String text;
  final bool isStreaming;
  const _AssistantBubble(
      {required this.text, required this.isStreaming});

  @override
  State<_AssistantBubble> createState() => _AssistantBubbleState();
}

class _AssistantBubbleState extends State<_AssistantBubble> {
  final TtsService _tts = TtsService.instance;

  @override
  void initState() {
    super.initState();
    _tts.onStateChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    if (_tts.onStateChanged != null) _tts.onStateChanged = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _tts.isLoadingText(widget.text);
    final isPlaying = _tts.isPlayingText(widget.text);

    return GestureDetector(
      onLongPress: () {
        if (widget.text.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: widget.text));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Copied to clipboard'),
            duration: const Duration(seconds: 1),
            backgroundColor: AuroraColors.surfVar(context),
          ));
        }
      },
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
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
        child: widget.isStreaming && widget.text.isEmpty
            ? const _TypingIndicator()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.text,
                      style: TextStyle(
                        color:    AuroraColors.txtPrimary(context),
                        fontSize: 14.5,
                        height:   1.55,
                      )),
                  if (widget.isStreaming)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child:   _CursorBlink(),
                    ),

                  // ── TTS speaker button — only after streaming done ────
                  if (!widget.isStreaming && widget.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () => _tts.speak(widget.text),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (isPlaying || isLoading)
                                ? AuroraColors.teal.withOpacity(0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: (isPlaying || isLoading)
                                  ? AuroraColors.teal.withOpacity(0.5)
                                  : AuroraColors.div(context),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isLoading)
                                SizedBox(
                                  width: 12, height: 12,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: AuroraColors.teal),
                                )
                              else
                                Icon(
                                  isPlaying
                                      ? Icons.stop_rounded
                                      : Icons.volume_up_rounded,
                                  size: 14,
                                  color: (isPlaying || isLoading)
                                      ? AuroraColors.teal
                                      : AuroraColors.txtHint(context),
                                ),
                              const SizedBox(width: 5),
                              Text(
                                isLoading
                                    ? 'Loading...'
                                    : isPlaying
                                        ? 'Stop'
                                        : 'Listen',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: (isPlaying || isLoading)
                                      ? AuroraColors.teal
                                      : AuroraColors.txtHint(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }
  @override
  void dispose() { _ac.dispose(); super.dispose(); }
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
              width: 7, height: 7,
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
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _ac.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ac,
      child: Container(
        width: 2, height: 14,
        decoration: BoxDecoration(
          color:        AuroraColors.teal,
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
      width: 30, height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AuroraColors.teal, AuroraColors.purple],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: AuroraColors.teal.withOpacity(0.3), blurRadius: 8)
        ],
      ),
      child: const Icon(Icons.auto_awesome_rounded,
          size: 15, color: Colors.white),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        shape:  BoxShape.circle,
        color:  AuroraColors.surfVar(context),
        border: Border.all(color: AuroraColors.div(context), width: 1),
      ),
      child: Icon(Icons.person_rounded,
          size: 16, color: AuroraColors.txtSecondary(context)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// INPUT BAR — with redesigned recording / transcribing UI
// ══════════════════════════════════════════════════════════════════════════════

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

class _InputBarState extends State<_InputBar>
    with TickerProviderStateMixin {

  bool _hasText        = false;
  bool _isRecording    = false;
  bool _isTranscribing = false;

  final _recorder = AudioRecorder();

  int    _recordSeconds = 0;
  Timer? _ticker;

  late final List<AnimationController> _barCtrls;
  late final List<Animation<double>>   _barAnims;
  late final AnimationController       _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);

    _barCtrls = List.generate(5, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300 + i * 80),
      )..repeat(reverse: true);
    });

    _barAnims = List.generate(5, (i) {
      return Tween<double>(begin: 4, end: 20 + (i % 3) * 8.0).animate(
        CurvedAnimation(parent: _barCtrls[i], curve: Curves.easeInOut),
      );
    });

    _shimmerCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  void _startTicker() {
    _ticker?.cancel();
    _recordSeconds = 0;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isRecording) setState(() => _recordSeconds++);
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _recorder.dispose();
    _ticker?.cancel();
    for (final c in _barCtrls) { c.dispose(); }
    _shimmerCtrl.dispose();
    super.dispose();
  }

  String get _timerLabel {
    final m = _recordSeconds ~/ 60;
    final s = _recordSeconds  % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _startRecording() async {
    final granted = await _recorder.hasPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Microphone permission denied'),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }

    final dir  = await getTemporaryDirectory();
    final path =
        '${dir.path}/aurora_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000),
      path: path,
    );

    setState(() => _isRecording = true);
    _startTicker();
  }

  Future<void> _stopAndTranscribe() async {
    _stopTicker();
    final path = await _recorder.stop();

    setState(() {
      _isRecording    = false;
      _isTranscribing = true;
      _recordSeconds  = 0;
    });

    if (path == null || path.isEmpty) {
      setState(() => _isTranscribing = false);
      return;
    }

    try {
      final bytes   = await File(path).readAsBytes();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ServerConfig.httpBase}/api/transcribe'),
      );
      request.files.add(http.MultipartFile.fromBytes(
        'file', bytes, filename: 'recording.m4a',
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final text = (json['text'] as String? ?? '').trim();
        if (text.isNotEmpty) {
          widget.controller.text = text;
          widget.controller.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Transcription failed (${response.statusCode})'),
            backgroundColor: Colors.red.shade700,
          ));
        }
      }

      try { await File(path).delete(); } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
        ));
      }
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  Future<void> _cancelRecording() async {
    _stopTicker();
    await _recorder.stop();
    setState(() {
      _isRecording   = false;
      _recordSeconds = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AuroraColors.bg(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: AuroraColors.div(context)),
          if (_isRecording)
            _buildRecordingBar()
          else if (_isTranscribing)
            _buildTranscribingBar()
          else
            _buildNormalInput(),
        ],
      ),
    );
  }

  Widget _buildNormalInput() {
    final hintText =
        context.watch<ChatController>().uiLabel('message_hint');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color:        AuroraColors.surfVar(context),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AuroraColors.div(context), width: 1),
              ),
              child: TextField(
                controller: widget.controller,
                style: TextStyle(
                    color: AuroraColors.txtPrimary(context), fontSize: 14.5),
                maxLines:           5,
                minLines:           1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText:  hintText,
                  hintStyle: TextStyle(
                      color:    AuroraColors.txtHint(context),
                      fontSize: 14),
                  border:         InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
                onSubmitted: (_) => widget.onSend(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildRightButton(),
        ],
      ),
    );
  }

  Widget _buildRightButton() {
    if (widget.isStreaming) {
      return _CircleButton(
        color: AuroraColors.surfVar(context),
        child: SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AuroraColors.teal),
        ),
      );
    }
    if (_hasText) {
      return _CircleButton(
        gradient: AuroraColors.userBubble,
        shadow: BoxShadow(
            color: AuroraColors.teal.withOpacity(0.35),
            blurRadius: 12, spreadRadius: 1),
        onTap:  widget.onSend,
        child:  const Icon(Icons.arrow_upward_rounded,
            size: 20, color: Colors.white),
      );
    }
    return _CircleButton(
      color: AuroraColors.surfVar(context),
      onTap: _startRecording,
      child: Icon(Icons.mic_rounded,
          size: 20, color: AuroraColors.txtSecondary(context)),
    );
  }

  Widget _buildRecordingBar() {
    return Container(
      margin: EdgeInsets.fromLTRB(
          12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.red.shade900.withOpacity(0.85),
            Colors.red.shade700.withOpacity(0.75),
          ],
          begin: Alignment.centerLeft,
          end:   Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
              color:      Colors.red.withOpacity(0.3),
              blurRadius: 16,
              spreadRadius: 1,
              offset:     const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.15),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_barAnims.length, (i) {
              return AnimatedBuilder(
                animation: _barAnims[i],
                builder: (_, __) => Container(
                  width:  3.5,
                  height: _barAnims[i].value,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(width: 14),
          Text(
            _timerLabel,
            style: const TextStyle(
              color:      Colors.white,
              fontSize:   15,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _stopAndTranscribe,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color:      Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset:     const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color:        Colors.red.shade600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Stop',
                    style: TextStyle(
                      color:      Colors.red.shade700,
                      fontSize:   13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscribingBar() {
    return Container(
      margin: EdgeInsets.fromLTRB(
          12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AuroraColors.surf(context),
        border: Border.all(
            color: AuroraColors.teal.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
              color:      AuroraColors.teal.withOpacity(0.1),
              blurRadius: 16,
              spreadRadius: 1),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (_, __) {
              final pulse =
                  ((_shimmerCtrl.value - 0.5).abs() * 2).clamp(0.4, 1.0);
              return Icon(
                Icons.auto_awesome_rounded,
                size:  20,
                color: AuroraColors.teal.withOpacity(pulse),
              );
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Converting speech to text...',
                  style: TextStyle(
                    color:      AuroraColors.txtPrimary(context),
                    fontSize:   14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedBuilder(
                  animation: _shimmerCtrl,
                  builder: (_, __) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        backgroundColor:
                            AuroraColors.teal.withOpacity(0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AuroraColors.teal.withOpacity(0.7)),
                        minHeight: 3,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AuroraColors.teal.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper: circle button ─────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final LinearGradient? gradient;
  final BoxShadow? shadow;

  const _CircleButton({
    required this.child,
    this.onTap,
    this.color,
    this.gradient,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44, height: 44,
      decoration: BoxDecoration(
        shape:     BoxShape.circle,
        color:     gradient == null ? color : null,
        gradient:  gradient,
        boxShadow: shadow != null ? [shadow!] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap:  onTap,
          child:  Center(child: child),
        ),
      ),
    );
  }
}