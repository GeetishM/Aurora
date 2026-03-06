import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../core/storage/boxes.dart';
import '../core/storage/hive_service.dart';
import '../core/websocket/ws_service.dart';
import '../models/chat_history.dart';
import '../models/message.dart';

class ChatController extends ChangeNotifier {
  final WebSocketService _ws = WebSocketService();

  final List<Message> messages = [];
  String? currentChatId;
  bool isStreaming   = false;
  bool isTranslating = false;

  // ── Language ──────────────────────────────────────────────────────────────
  String _language;
  String get language => _language;
  static const _langKey = 'aurora_language';

  // ── Cache: { chatId: { msgId: { langCode: translatedText } } } ────────────
  // Persisted per-chat so switching between chats is fast after first visit.
  final Map<String, Map<String, Map<String, String>>> _cache = {};

  // ── Originals: { chatId: { msgId: englishText } } ─────────────────────────
  // Always English — loaded from Hive (we always save English to Hive).
  final Map<String, Map<String, String>> _originals = {};

  static const Map<String, String> supportedLanguages = {
    'English':    'en', 'Hindi':      'hi', 'Hinglish':   'hinglish',
    'Bengali':    'bn', 'Marathi':    'mr', 'Tamil':      'ta',
    'Telugu':     'te', 'Gujarati':   'gu', 'Kannada':    'kn',
    'Malayalam':  'ml', 'Punjabi':    'pa', 'Urdu':       'ur',
    'Odia':       'or', 'Assamese':   'as', 'Nepali':     'ne',
    'Spanish':    'es', 'French':     'fr', 'German':     'de',
    'Arabic':     'ar', 'Portuguese': 'pt', 'Indonesian': 'id',
    'Japanese':   'ja', 'Korean':     'ko', 'Chinese':    'zh',
  };

  static String get _baseUrl {
    if (kIsWeb)             return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    if (Platform.isIOS)     return 'http://127.0.0.1:8000';
    return 'http://localhost:8000';
  }

  ChatController({String initialLanguage = 'en'})
      : _language = initialLanguage {
    _ws.connect();
  }

  bool get _isEnglish => _language == 'en';

  // ══════════════════════════════════════════════════════════════════════════
  // LANGUAGE — set globally, translate current chat in real time
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> setLanguage(String langCode) async {
    if (_language == langCode) return;
    _language = langCode;
    notifyListeners(); // ✅ update dropdown label immediately

    // Save to prefs (background)
    SharedPreferences.getInstance()
        .then((p) => p.setString(_langKey, langCode));

    // Translate current chat right now
    if (currentChatId != null && messages.isNotEmpty) {
      await _translateChat(currentChatId!, langCode);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TRANSLATE A CHAT — translates every message (user + assistant)
  // Uses cache: hit = instant, miss = backend call + store in cache
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _translateChat(String chatId, String langCode) async {
    final origMap = _originals[chatId] ?? {};
    final allMsgs = messages.where((m) => origMap.containsKey(m.id)).toList();
    if (allMsgs.isEmpty) return;

    // English: always restore from originals — instant, no backend
    if (langCode == 'en') {
      for (final m in allMsgs) {
        m.text = origMap[m.id]!;
      }
      notifyListeners();
      return;
    }

    // Pass 1 — apply anything already cached (instant, no network)
    final chatCache = _cache.putIfAbsent(chatId, () => {});
    bool anyMissing = false;

    for (final m in allMsgs) {
      final cached = chatCache[m.id]?[langCode];
      if (cached != null) {
        m.text = cached;
      } else {
        anyMissing = true;
      }
    }
    notifyListeners();

    if (!anyMissing) return; // ✅ fully cached — done

    // Pass 2 — call backend for uncached messages
    isTranslating = true;
    notifyListeners();

    final uncached = allMsgs.where((m) => chatCache[m.id]?[langCode] == null);

    await Future.wait(uncached.map((m) async {
      final translated = await _callTranslate(origMap[m.id]!, langCode);
      if (translated != null) {
        chatCache.putIfAbsent(m.id, () => {})[langCode] = translated;
        m.text = translated;
      }
    }));

    isTranslating = false;
    notifyListeners();
  }

  // ── Single translate API call ─────────────────────────────────────────────
  Future<String?> _callTranslate(String text, String langCode) async {
    if (langCode == 'en') return text;
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/translate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'language': langCode}),
      );
      if (res.statusCode == 200) {
        return (jsonDecode(res.body)['translated'] as String?)?.trim();
      }
      debugPrint('[Translate] HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('[Translate] Error: $e');
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOAD CHAT — loads from Hive, seeds originals, applies current language
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> loadChat(String chatId) async {
    if (chatId.isEmpty) return;
    currentChatId = chatId;

    messages
      ..clear()
      ..addAll(HiveService.getMessages(chatId));

    // Seed originals from Hive (always English)
    final origMap = <String, String>{};
    for (final m in messages) {
      origMap[m.id] = m.text;
      // Seed 'en' in cache
      _cache.putIfAbsent(chatId, () => {})
            .putIfAbsent(m.id, () => {})['en'] = m.text;
    }
    _originals[chatId] = origMap;

    // Show English instantly
    notifyListeners();

    // Then apply current language
    if (!_isEnglish && messages.isNotEmpty) {
      await _translateChat(chatId, _language);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CREATE NEW CHAT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> createNewChat() async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    HiveBoxes.chatHistoryBox().put(id, ChatHistory(
      chatId:      id,
      title:       'New Chat',
      lastMessage: '',
      updatedAt:   DateTime.now(),
    ));
    await loadChat(id);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DELETE CHAT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> deleteChat(String chatId) async {
    // Remove from Hive
    await HiveService.deleteChat(chatId);

    // Remove from in-memory caches
    _cache.remove(chatId);
    _originals.remove(chatId);

    // If this was the active chat, clear the view
    if (currentChatId == chatId) {
      currentChatId = null;
      messages.clear();
    }

    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RENAME CHAT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> renameChat(String chatId, String newTitle) async {
    await HiveService.renameChat(chatId, newTitle);
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SEND MESSAGE
  // ══════════════════════════════════════════════════════════════════════════

  void sendMessage(String text) {
    if (currentChatId == null || isStreaming) return;
    final chatId = currentChatId!;

    // 1️⃣ User message — save original, translate display if non-English
    final userMsg = Message(
      id:        DateTime.now().millisecondsSinceEpoch.toString(),
      chatId:    chatId,
      text:      text,
      isUser:    true,
      timestamp: DateTime.now(),
    );

    // Store English original
    _originals.putIfAbsent(chatId, () => {})[userMsg.id] = text;
    _cache.putIfAbsent(chatId, () => {})
          .putIfAbsent(userMsg.id, () => {})['en'] = text;

    messages.add(userMsg);
    HiveService.saveMessage(userMsg);
    _maybeUpdateChatTitle(chatId, text);

    // Translate user bubble in background for non-English
    if (!_isEnglish) {
      _translateSingleBubble(chatId, userMsg, text);
    }

    // 2️⃣ Empty assistant placeholder
    final assistantMsg = Message(
      id:        '${DateTime.now().millisecondsSinceEpoch}_ai',
      chatId:    chatId,
      text:      '',
      isUser:    false,
      timestamp: DateTime.now(),
    );
    messages.add(assistantMsg);
    isStreaming   = true;
    isTranslating = false;
    notifyListeners();

    // 3️⃣ Always get English from backend — so we always have the original
    _ws.sendMessage(
      message:  text,
      language: 'en',
      onChunk: (chunk) {
        // Only show chunks for English — non-English shows typing dots
        if (_isEnglish) assistantMsg.text += chunk;
        notifyListeners();
      },
      onFinal: (finalText) async {
        // Store English original
        _originals.putIfAbsent(chatId, () => {})[assistantMsg.id] = finalText;
        _cache.putIfAbsent(chatId, () => {})
              .putIfAbsent(assistantMsg.id, () => {})['en'] = finalText;

        isStreaming = false;

        if (_isEnglish) {
          assistantMsg.text = finalText;
          notifyListeners();
        } else {
          // Check cache, then backend
          final cached = _cache[chatId]?[assistantMsg.id]?[_language];
          if (cached != null) {
            assistantMsg.text = cached;
            notifyListeners();
          } else {
            isTranslating = true;
            notifyListeners();

            final translated = await _callTranslate(finalText, _language);
            final display = translated ?? finalText;

            _cache[chatId]![assistantMsg.id]![_language] = display;
            assistantMsg.text = display;

            isTranslating = false;
            notifyListeners();
          }
        }

        // ✅ Always save English to Hive
        await HiveService.saveMessage(Message(
          id:        assistantMsg.id,
          chatId:    chatId,
          text:      finalText,       // English in Hive always
          isUser:    false,
          timestamp: assistantMsg.timestamp,
        ));
        await HiveService.updateChatPreview(chatId, assistantMsg.text);
        notifyListeners();
      },
    );
  }

  // Translate a single bubble in background
  Future<void> _translateSingleBubble(
      String chatId, Message msg, String original) async {
    final cached = _cache[chatId]?[msg.id]?[_language];
    if (cached != null) {
      msg.text = cached;
      notifyListeners();
      return;
    }
    final translated = await _callTranslate(original, _language);
    if (translated != null) {
      _cache.putIfAbsent(chatId, () => {})
            .putIfAbsent(msg.id, () => {})[_language] = translated;
      msg.text = translated;
      notifyListeners();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _maybeUpdateChatTitle(String chatId, String firstMessage) {
    final box  = HiveBoxes.chatHistoryBox();
    final chat = box.get(chatId);
    if (chat == null || chat.title != 'New Chat') return;
    chat.title     = firstMessage.length > 40
        ? '${firstMessage.substring(0, 40)}…'
        : firstMessage;
    chat.updatedAt = DateTime.now();
    chat.save();
  }

  @override
  void dispose() {
    _ws.disconnect();
    super.dispose();
  }
}