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

  String _language;
  String get language => _language;
  static const _langKey = 'aurora_language';

  // ── Cache: { chatId: { msgId: { langCode: translatedText } } } ────────────
  // Used for BOTH user and assistant messages.
  final Map<String, Map<String, Map<String, String>>> _cache = {};

  // ── Originals ─────────────────────────────────────────────────────────────
  // User messages    → exactly as typed (never changes)
  // Assistant msgs   → always English (we always save English to Hive)
  // { chatId: { msgId: originalText } }
  final Map<String, String> _originalTitles = {};   // { chatId: englishTitle }
  final Map<String, String> _translatedTitles = {}; // { chatId: translatedTitle }
  final Map<String, Map<String, String>> _originals = {};

  /// Returns the display title for a chat in the current language.
  String getTitle(String chatId, String fallback) {
    return _translatedTitles[chatId] ?? fallback;
  }

  // ── Static UI strings translated per language ─────────────────────────────
  // Keys: 'new_chat', 'recent_chats', 'no_chats'
  static const Map<String, Map<String, String>> _uiStrings = {
    'new_chat': {
      'en': 'New Chat',     'hi': 'नई चैट',         'hinglish': 'New Chat',
      'bn': 'নতুন চ্যাট',    'mr': 'नवीन चॅट',        'ta': 'புதிய அரட்டை',
      'te': 'కొత్త చాట్',    'gu': 'નવી ચેટ',         'kn': 'ಹೊಸ ಚಾಟ್',
      'ml': 'പുതിയ ചാറ്റ്',  'pa': 'ਨਵੀਂ ਚੈਟ',        'ur': 'نئی چیٹ',
      'or': 'ନୂଆ ଚ୍ୟାଟ',    'as': 'নতুন চেট',        'ne': 'नयाँ कुराकानी',
      'es': 'Nueva Charla', 'fr': 'Nouveau Chat',   'de': 'Neuer Chat',
      'ar': 'محادثة جديدة', 'pt': 'Nova Conversa',  'id': 'Obrolan Baru',
      'ja': '新しいチャット',  'ko': '새 채팅',           'zh': '新聊天',
    },
    'recent_chats': {
      'en': 'Recent Chats',   'hi': 'हाल की चैट',       'hinglish': 'Recent Chats',
      'bn': 'সাম্প্রতিক চ্যাট', 'mr': 'अलीकडील चॅट',     'ta': 'சமீபத்திய அரட்டை',
      'te': 'ఇటీవలి చాట్లు',  'gu': 'તાજેતરની ચેટ',     'kn': 'ಇತ್ತೀಚಿನ ಚಾಟ್',
      'ml': 'സമീപകാല ചാറ്റ്', 'pa': 'ਹਾਲੀਆ ਚੈਟਾਂ',      'ur': 'حالیہ چیٹس',
      'or': 'ସମ୍ପ୍ରତି ଚ୍ୟାଟ',  'as': 'শেহতীয়া চেট',     'ne': 'हालका कुराकानीहरू',
      'es': 'Chats Recientes','fr': 'Chats Récents',  'de': 'Letzte Chats',
      'ar': 'المحادثات الأخيرة','pt': 'Chats Recentes','id': 'Obrolan Terbaru',
      'ja': '最近のチャット',    'ko': '최근 채팅',          'zh': '最近聊天',
    },
    'no_chats': {
      'en': 'No chats yet',   'hi': 'अभी कोई चैट नहीं',  'hinglish': 'No chats yet',
      'bn': 'এখনো কোনো চ্যাট নেই','mr': 'अजून कोणतेही चॅट नाही','ta': 'இன்னும் அரட்டை இல்லை',
      'te': 'ఇంకా చాట్లు లేవు', 'gu': 'હજી સુધી કોઈ ચેટ નથી','kn': 'ಇನ್ನೂ ಚಾಟ್ ಇಲ್ಲ',
      'ml': 'ഇനിയും ചാറ്റ് ഇല്ല','pa': 'ਅਜੇ ਕੋਈ ਚੈਟ ਨਹੀਂ',   'ur': 'ابھی کوئی چیٹ نہیں',
      'or': 'ଏପର୍ଯ୍ୟନ୍ତ କୌଣସି ଚ୍ୟାଟ ନାହିଁ','as': 'এতিয়ালৈ কোনো চেট নাই','ne': 'अहिलेसम्म कुनै कुराकानी छैन',
      'es': 'Sin chats aún',  'fr': 'Aucun chat',     'de': 'Noch keine Chats',
      'ar': 'لا محادثات بعد', 'pt': 'Sem chats ainda','id': 'Belum ada obrolan',
      'ja': 'チャットなし',      'ko': '채팅 없음',          'zh': '暂无聊天',
    },
  };

  /// Returns a translated UI string for the current language.
  String uiLabel(String key) {
    return _uiStrings[key]?[_language] ?? _uiStrings[key]?['en'] ?? key;
  }

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
  // LANGUAGE — set globally, re-translate current chat immediately
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> setLanguage(String langCode) async {
    if (_language == langCode) return;
    _language = langCode;
    notifyListeners(); // update AppBar label this frame

    SharedPreferences.getInstance()
        .then((p) => p.setString(_langKey, langCode));

    if (currentChatId != null && messages.isNotEmpty) {
      await _applyLanguage(currentChatId!, langCode);
    }

    // Also translate all sidebar titles
    await _translateAllTitles(langCode);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TRANSLATE ALL SIDEBAR TITLES
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _translateAllTitles(String langCode) async {
    final box   = HiveBoxes.chatHistoryBox();
    final chats = box.values.toList();

    // Seed originals from Hive for any chat we haven't seen yet
    for (final chat in chats) {
      _originalTitles.putIfAbsent(chat.chatId, () => chat.title);
    }

    if (langCode == 'en') {
      // Restore all originals instantly
      _translatedTitles.clear();
      notifyListeners();
      return;
    }

    // Translate all titles concurrently
    await Future.wait(chats.map((chat) async {
      final original = _originalTitles[chat.chatId] ?? chat.title;
      final translated = await _callTranslate(original, langCode);
      if (translated != null) {
        _translatedTitles[chat.chatId] = translated;
      }
    }));

    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APPLY LANGUAGE TO ALL MESSAGES IN A CHAT
  //
  // User messages:
  //   • original = typed text (stored at send time, loaded from Hive)
  //   • translate ON   → call backend, cache result, show translation
  //   • translate OFF  → restore original typed text instantly
  //
  // Assistant messages:
  //   • original = English (always saved to Hive in English)
  //   • translate ON   → call backend, cache result, show translation
  //   • translate OFF  → restore English original instantly
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _applyLanguage(String chatId, String langCode) async {
    final origMap = _originals[chatId] ?? {};
    final allMsgs = messages
        .where((m) => origMap.containsKey(m.id))
        .toList();

    if (allMsgs.isEmpty) return;

    // English: restore all originals instantly — no API needed
    if (langCode == 'en') {
      for (final m in allMsgs) {
        m.text = origMap[m.id]!;
      }
      notifyListeners();
      return;
    }

    // Pass 1: apply anything already cached — instant, no network
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

    if (!anyMissing) return; // fully cached — done instantly

    // Pass 2: call backend only for uncached messages
    isTranslating = true;
    notifyListeners();

    await Future.wait(
      allMsgs
          .where((m) => chatCache[m.id]?[langCode] == null)
          .map((m) async {
            final translated = await _callTranslate(origMap[m.id]!, langCode);
            if (translated != null) {
              chatCache.putIfAbsent(m.id, () => {})[langCode] = translated;
              m.text = translated;
            }
          }),
    );

    isTranslating = false;
    notifyListeners();
  }

  // ── POST /translate ───────────────────────────────────────────────────────
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
  // LOAD CHAT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> loadChat(String chatId) async {
    if (chatId.isEmpty) return;
    currentChatId = chatId;

    messages
      ..clear()
      ..addAll(HiveService.getMessages(chatId));

    // Seed originals from Hive:
    //   user messages    → typed text (Hive stores as-typed)
    //   assistant msgs   → English   (Hive always stores English)
    final origMap = <String, String>{};
    for (final m in messages) {
      origMap[m.id] = m.text;
      _cache.putIfAbsent(chatId, () => {})
            .putIfAbsent(m.id, () => {})['en'] = m.text;
    }
    _originals[chatId] = origMap;

    // Seed this chat's title as original (used for sidebar translation)
    final chatEntry = HiveBoxes.chatHistoryBox().get(chatId);
    if (chatEntry != null) {
      _originalTitles.putIfAbsent(chatId, () => chatEntry.title);
    }

    // Show messages instantly — render the chat before doing any translation
    notifyListeners();

    // Defer translation to after the first frame so UI never blocks
    if (!_isEnglish && messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyLanguage(chatId, _language);
      });
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
  // SEND MESSAGE
  // ══════════════════════════════════════════════════════════════════════════

  void sendMessage(String text) {
    if (currentChatId == null || isStreaming) return;
    final chatId = currentChatId!;

    // 1️⃣ User message
    final userMsg = Message(
      id:        DateTime.now().millisecondsSinceEpoch.toString(),
      chatId:    chatId,
      text:      text,
      isUser:    true,
      timestamp: DateTime.now(),
    );

    // Store typed text as original — this NEVER changes
    _originals.putIfAbsent(chatId, () => {})[userMsg.id] = text;
    _cache.putIfAbsent(chatId, () => {})
          .putIfAbsent(userMsg.id, () => {})['en'] = text;

    messages.add(userMsg);
    HiveService.saveMessage(userMsg); // saves typed text to Hive
    _maybeUpdateChatTitle(chatId, text);

    // Translate user bubble display if non-English (background, doesn't block)
    if (!_isEnglish) _translateOneBubble(chatId, userMsg, text);

    // 2️⃣ Empty assistant placeholder
    // Add 1ms to guarantee a different timestamp from userMsg
    final assistantMsg = Message(
      id:        '${DateTime.now().millisecondsSinceEpoch + 1}_ai',
      chatId:    chatId,
      text:      '',
      isUser:    false,
      timestamp: DateTime.now(),
    );
    messages.add(assistantMsg);
    isStreaming   = true;
    isTranslating = false;
    notifyListeners();

    // 3️⃣ Always request English from backend
    _ws.sendMessage(
      message:  text,
      language: 'en',
      onChunk: (chunk) {
        if (_isEnglish) assistantMsg.text += chunk;
        // Non-English: suppress chunks → typing dots until final arrives
        notifyListeners();
      },
      onFinal: (finalText) async {
        // Store English as original
        _originals.putIfAbsent(chatId, () => {})[assistantMsg.id] = finalText;
        _cache.putIfAbsent(chatId, () => {})
              .putIfAbsent(assistantMsg.id, () => {})['en'] = finalText;

        isStreaming = false;

        if (_isEnglish) {
          assistantMsg.text = finalText;
          notifyListeners();
        } else {
          // Check cache first, then backend
          final cached = _cache[chatId]?[assistantMsg.id]?[_language];
          if (cached != null) {
            assistantMsg.text = cached;
            notifyListeners();
          } else {
            isTranslating = true;
            notifyListeners();

            final translated = await _callTranslate(finalText, _language);
            final display    = translated ?? finalText;

            _cache[chatId]![assistantMsg.id]![_language] = display;
            assistantMsg.text = display;

            isTranslating = false;
            notifyListeners();
          }
        }

        // Always save English to Hive
        await HiveService.saveMessage(Message(
          id:        assistantMsg.id,
          chatId:    chatId,
          text:      finalText,  // ✅ English in Hive always
          isUser:    false,
          timestamp: assistantMsg.timestamp,
        ));
        await HiveService.updateChatPreview(chatId, assistantMsg.text);
        notifyListeners();
      },
    );
  }

  // Translate a single bubble in background (used for user bubble on send)
  Future<void> _translateOneBubble(
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

  // ══════════════════════════════════════════════════════════════════════════
  // DELETE CHAT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> deleteChat(String chatId) async {
    await HiveService.deleteChat(chatId);
    _cache.remove(chatId);
    _originals.remove(chatId);
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
    final title = newTitle.trim().isEmpty ? 'New Chat' : newTitle.trim();
    await HiveService.renameChat(chatId, title);

    // Update original and translate immediately
    _originalTitles[chatId] = title;
    _translatedTitles.remove(chatId); // clear stale translation

    if (!_isEnglish) {
      final translated = await _callTranslate(title, _language);
      if (translated != null) _translatedTitles[chatId] = translated;
    }

    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _maybeUpdateChatTitle(String chatId, String firstMessage) {
    final box  = HiveBoxes.chatHistoryBox();
    final chat = box.get(chatId);
    if (chat == null || chat.title != 'New Chat') return;
    final title    = firstMessage.length > 40
        ? '${firstMessage.substring(0, 40)}…'
        : firstMessage;
    chat.title     = title;
    chat.updatedAt = DateTime.now();
    chat.save();

    // Store as original title so future language switches can translate it
    _originalTitles[chatId] = title;

    // Translate immediately if non-English
    if (!_isEnglish) {
      _callTranslate(title, _language).then((translated) {
        if (translated != null) {
          _translatedTitles[chatId] = translated;
          notifyListeners();
        }
      });
    }
  }

  @override
  void dispose() {
    _ws.disconnect();
    super.dispose();
  }
}