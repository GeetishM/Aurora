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

    // ── Chat screen ───────────────────────────────────────────────────────
    'how_can_i_help': {
      'en': 'How can I help you today?',
      'hi': 'आज मैं आपकी कैसे मदद कर सकती हूँ?',
      'hinglish': 'Aaj main aapki kaise help kar sakti hoon?',
      'bn': 'আজ আমি আপনাকে কীভাবে সাহায্য করতে পারি?',
      'mr': 'आज मी तुम्हाला कशी मदत करू शकते?',
      'ta': 'இன்று நான் உங்களுக்கு எப்படி உதவலாம்?',
      'te': 'ఈరోజు నేను మీకు ఎలా సహాయపడగలను?',
      'gu': 'આજે હું તમને કેવી રીતે મદદ કરી શકું?',
      'kn': 'ಇಂದು ನಾನು ನಿಮಗೆ ಹೇಗೆ ಸಹಾಯ ಮಾಡಬಹುದು?',
      'ml': 'ഇന്ന് ഞാൻ നിങ്ങളെ എങ്ങനെ സഹായിക്കാം?',
      'pa': 'ਅੱਜ ਮੈਂ ਤੁਹਾਡੀ ਕਿਵੇਂ ਮਦਦ ਕਰ ਸਕਦੀ ਹਾਂ?',
      'ur': 'آج میں آپ کی کیسے مدد کر سکتی ہوں؟',
      'or': 'ଆଜି ମୁଁ ଆପଣଙ୍କୁ କିପରି ସାହାଯ୍ୟ କରିପାରିବି?',
      'as': 'আজি মই আপোনাক কেনেকৈ সহায় কৰিব পাৰো?',
      'ne': 'आज म तपाईंलाई कसरी मद्दत गर्न सक्छु?',
      'es': '¿Cómo puedo ayudarte hoy?',
      'fr': 'Comment puis-je vous aider aujourd\'hui?',
      'de': 'Wie kann ich Ihnen heute helfen?',
      'ar': 'كيف يمكنني مساعدتك اليوم؟',
      'pt': 'Como posso ajudá-la hoje?',
      'id': 'Bagaimana saya bisa membantu Anda hari ini?',
      'ja': '今日はどのようにお手伝いできますか？',
      'ko': '오늘 어떻게 도와드릴까요?',
      'zh': '今天我能帮您什么？',
    },
    'suggestion_pms': {
      'en': 'What are common PMS symptoms?',
      'hi': 'PMS के सामान्य लक्षण क्या हैं?',
      'hinglish': 'PMS ke common symptoms kya hain?',
      'bn': 'PMS-এর সাধারণ লক্ষণগুলি কী?',
      'mr': 'PMS चे सामान्य लक्षणे कोणती आहेत?',
      'ta': 'PMS-இன் பொதுவான அறிகுறிகள் என்ன?',
      'te': 'PMS యొక్క సాధారణ లక్షణాలు ఏమిటి?',
      'gu': 'PMS ના સામાન્ય લક્ષણો શું છે?',
      'kn': 'PMS ನ ಸಾಮಾನ್ಯ ಲಕ್ಷಣಗಳು ಯಾವುವು?',
      'ml': 'PMS-ന്റെ സാധാരണ ലക്ഷണങ്ങൾ എന്തൊക്കെ?',
      'pa': 'PMS ਦੇ ਆਮ ਲੱਛਣ ਕੀ ਹਨ?',
      'ur': 'PMS کی عام علامات کیا ہیں؟',
      'or': 'PMS ର ସାଧାରଣ ଲକ୍ଷଣ କ\'ଣ?',
      'as': 'PMS ৰ সাধাৰণ লক্ষণবোৰ কি?',
      'ne': 'PMS का सामान्य लक्षणहरू के हुन्?',
      'es': '¿Cuáles son los síntomas comunes del SPM?',
      'fr': 'Quels sont les symptômes courants du SPM?',
      'de': 'Was sind häufige PMS-Symptome?',
      'ar': 'ما هي أعراض متلازمة ما قبل الحيض الشائعة؟',
      'pt': 'Quais são os sintomas comuns da TPM?',
      'id': 'Apa gejala umum PMS?',
      'ja': 'PMSの一般的な症状は何ですか？',
      'ko': 'PMS의 일반적인 증상은 무엇인가요?',
      'zh': 'PMS的常见症状是什么？',
    },
    'suggestion_cycle': {
      'en': 'How does the menstrual cycle work?',
      'hi': 'मासिक धर्म चक्र कैसे काम करता है?',
      'hinglish': 'Menstrual cycle kaise kaam karta hai?',
      'bn': 'ঋতুচক্র কীভাবে কাজ করে?',
      'mr': 'मासिक पाळीचे चक्र कसे कार्य करते?',
      'ta': 'மாதவிடாய் சுழற்சி எவ்வாறு செயல்படுகிறது?',
      'te': 'రుతుచక్రం ఎలా పని చేస్తుంది?',
      'gu': 'માસિક ચક્ર કેવી રીતે કામ કરે છે?',
      'kn': 'ಮಾಸಿಕ ಚಕ್ರ ಹೇಗೆ ಕಾರ್ಯನಿರ್ವಹಿಸುತ್ತದೆ?',
      'ml': 'ആർത്തവചക്രം എങ്ങനെ പ്രവർത്തിക്കുന്നു?',
      'pa': 'ਮਾਹਵਾਰੀ ਚੱਕਰ ਕਿਵੇਂ ਕੰਮ ਕਰਦਾ ਹੈ?',
      'ur': 'ماہواری کا چکر کیسے کام کرتا ہے؟',
      'or': 'ଋତୁସ୍ରାବ ଚକ୍ର କିପରି କାର୍ଯ୍ୟ କରେ?',
      'as': 'ঋতুচক্র কেনেকৈ কাম কৰে?',
      'ne': 'महिनावारी चक्र कसरी काम गर्छ?',
      'es': '¿Cómo funciona el ciclo menstrual?',
      'fr': 'Comment fonctionne le cycle menstruel?',
      'de': 'Wie funktioniert der Menstruationszyklus?',
      'ar': 'كيف يعمل الدورة الشهرية؟',
      'pt': 'Como funciona o ciclo menstrual?',
      'id': 'Bagaimana cara kerja siklus menstruasi?',
      'ja': '月経周期はどのように機能しますか？',
      'ko': '월경 주기는 어떻게 작동하나요?',
      'zh': '月经周期是如何运作的？',
    },
    'suggestion_period_pain': {
      'en': 'Tips for managing period pain?',
      'hi': 'मासिक दर्द को कम करने के उपाय?',
      'hinglish': 'Period pain manage karne ke tips?',
      'bn': 'মাসিকের ব্যথা কমানোর টিপস?',
      'mr': 'मासिक वेदना व्यवस्थापनासाठी टिप्स?',
      'ta': 'மாதவிடாய் வலியை நிர்வகிக்கும் குறிப்புகள்?',
      'te': 'పీరియడ్ నొప్పిని నిర్వహించే చిట్కాలు?',
      'gu': 'માસિક દર્દ ઘટાડવાની ટીપ્સ?',
      'kn': 'ಮಾಸಿಕ ನೋವನ್ನು ನಿಯಂತ್ರಿಸಲು ಸಲಹೆಗಳು?',
      'ml': 'ആർത്തവ വേദന നിയന്ത്രിക്കാനുള്ള നുറുങ്ങുകൾ?',
      'pa': 'ਮਾਹਵਾਰੀ ਦਰਦ ਘਟਾਉਣ ਦੇ ਤਰੀਕੇ?',
      'ur': 'ماہواری کے درد کو کم کرنے کے طریقے؟',
      'or': 'ଋତୁସ୍ରାବ ଯନ୍ତ୍ରଣା ପରିଚାଳନା ପାଇଁ ଟିପ୍ସ?',
      'as': 'ঋতুস্রাৱৰ বিষ নিয়ন্ত্ৰণৰ টিপছ?',
      'ne': 'महिनावारी दुखाइ व्यवस्थापनका सुझावहरू?',
      'es': '¿Consejos para manejar el dolor menstrual?',
      'fr': 'Conseils pour gérer les douleurs menstruelles?',
      'de': 'Tipps zur Bewältigung von Menstruationsschmerzen?',
      'ar': 'نصائح لإدارة آلام الدورة الشهرية؟',
      'pt': 'Dicas para controlar a dor menstrual?',
      'id': 'Tips mengatasi nyeri haid?',
      'ja': '生理痛を管理するためのヒント？',
      'ko': '생리통 관리 팁은?',
      'zh': '管理经期疼痛的建议？',
    },
    'suggestion_pcos': {
      'en': 'What is PCOS?',
      'hi': 'PCOS क्या है?',
      'hinglish': 'PCOS kya hai?',
      'bn': 'PCOS কী?',
      'mr': 'PCOS म्हणजे काय?',
      'ta': 'PCOS என்றால் என்ன?',
      'te': 'PCOS అంటే ఏమిటి?',
      'gu': 'PCOS શું છે?',
      'kn': 'PCOS ಎಂದರೇನು?',
      'ml': 'PCOS എന്താണ്?',
      'pa': 'PCOS ਕੀ ਹੈ?',
      'ur': 'PCOS کیا ہے؟',
      'or': 'PCOS କ\'ଣ?',
      'as': 'PCOS কি?',
      'ne': 'PCOS के हो?',
      'es': '¿Qué es el SOP?',
      'fr': 'Qu\'est-ce que le SOPK?',
      'de': 'Was ist PCOS?',
      'ar': 'ما هو تكيس المبايض؟',
      'pt': 'O que é SOP?',
      'id': 'Apa itu PCOS?',
      'ja': 'PCOSとは何ですか？',
      'ko': 'PCOS란 무엇인가요?',
      'zh': '什么是多囊卵巢综合征？',
    },
    'translating': {
      'en': 'Translating messages...',
      'hi': 'संदेश अनुवाद हो रहे हैं...',
      'hinglish': 'Messages translate ho rahe hain...',
      'bn': 'বার্তা অনুবাদ হচ্ছে...',
      'mr': 'संदेश भाषांतरित होत आहेत...',
      'ta': 'செய்திகள் மொழிபெயர்க்கப்படுகின்றன...',
      'te': 'సందేశాలు అనువదించబడుతున్నాయి...',
      'gu': 'સંદેશ અનુવાદ થઈ રહ્યો છે...',
      'kn': 'ಸಂದೇಶಗಳನ್ನು ಅನುವಾದಿಸಲಾಗುತ್ತಿದೆ...',
      'ml': 'സന്ദേശങ്ങൾ പരിഭാഷ ചെയ്യുന്നു...',
      'pa': 'ਸੁਨੇਹੇ ਅਨੁਵਾਦ ਕੀਤੇ ਜਾ ਰਹੇ ਹਨ...',
      'ur': 'پیغامات کا ترجمہ ہو رہا ہے...',
      'or': 'ବାର୍ତ୍ତା ଅନୁବାଦ ହେଉଛି...',
      'as': 'বাৰ্তা অনুবাদ হৈছে...',
      'ne': 'सन्देशहरू अनुवाद हुँदैछन्...',
      'es': 'Traduciendo mensajes...',
      'fr': 'Traduction des messages...',
      'de': 'Nachrichten werden übersetzt...',
      'ar': 'جارٍ ترجمة الرسائل...',
      'pt': 'Traduzindo mensagens...',
      'id': 'Menerjemahkan pesan...',
      'ja': 'メッセージを翻訳中...',
      'ko': '메시지 번역 중...',
      'zh': '正在翻译消息...',
    },
    'message_hint': {
      'en': 'Message Aurora...',
      'hi': 'Aurora को संदेश भेजें...',
      'hinglish': 'Aurora ko message karein...',
      'bn': 'Aurora-কে বার্তা পাঠান...',
      'mr': 'Aurora ला संदेश पाठवा...',
      'ta': 'Aurora-க்கு செய்தி அனுப்பு...',
      'te': 'Aurora కు సందేశం పంపండి...',
      'gu': 'Aurora ને સંદેશ મોકલો...',
      'kn': 'Aurora ಗೆ ಸಂದೇಶ ಕಳುಹಿಸಿ...',
      'ml': 'Aurora-ക്ക് സന്ദേശം അയക്കൂ...',
      'pa': 'Aurora ਨੂੰ ਸੁਨੇਹਾ ਭੇਜੋ...',
      'ur': 'Aurora کو پیغام بھیجیں...',
      'or': 'Aurora କୁ ବାର୍ତ୍ତା ଦିଅନ୍ତୁ...',
      'as': 'Aurora লৈ বাৰ্তা পঠাওক...',
      'ne': 'Aurora लाई सन्देश पठाउनुहोस्...',
      'es': 'Mensaje a Aurora...',
      'fr': 'Message à Aurora...',
      'de': 'Nachricht an Aurora...',
      'ar': 'أرسل رسالة إلى Aurora...',
      'pt': 'Mensagem para Aurora...',
      'id': 'Pesan ke Aurora...',
      'ja': 'Auroraにメッセージ...',
      'ko': 'Aurora에게 메시지...',
      'zh': '给 Aurora 发消息...',
    },
  };

  /// Returns a translated UI string for the current language.
  String uiLabel(String key) {
    return _uiStrings[key]?[_language] ?? _uiStrings[key]?['en'] ?? key;
  }

  // ── Topic data for the empty chat suggestion UI ───────────────────────────
  // Each topic: id, icon, label map, questions list (each a lang→text map)
  static const List<Map<String, dynamic>> _topicsData = [
    {
      'id': 'menstrual',
      'icon': '🩸',
      'label': {
        'en': 'Menstrual Health', 'hi': 'मासिक स्वास्थ्य', 'hinglish': 'Menstrual Health',
        'bn': 'ঋতুস্বাস্থ্য', 'mr': 'मासिक आरोग्य', 'ta': 'மாதவிடாய் ஆரோக்கியம்',
        'te': 'రుతుక్రమ ఆరోగ్యం', 'gu': 'માસિક સ્વાસ્થ્ય', 'kn': 'ಮಾಸಿಕ ಆರೋಗ್ಯ',
        'ml': 'ആർത്തവ ആരോഗ്യം', 'pa': 'ਮਾਹਵਾਰੀ ਸਿਹਤ', 'ur': 'ماہواری صحت',
        'es': 'Salud Menstrual', 'fr': 'Santé Menstruelle', 'de': 'Menstruationsgesundheit',
        'ar': 'صحة الدورة الشهرية', 'pt': 'Saúde Menstrual', 'id': 'Kesehatan Menstruasi',
        'ja': '月経の健康', 'ko': '월경 건강', 'zh': '月经健康',
      },
      'questions': [
        {
          'en': 'What is PCOS and its symptoms?',
          'hi': 'PCOS क्या है और इसके लक्षण क्या हैं?',
          'bn': 'PCOS কী এবং এর লক্ষণ কী?', 'ta': 'PCOS என்றால் என்ன?',
          'te': 'PCOS అంటే ఏమిటి?', 'ur': 'PCOS کیا ہے؟',
          'es': '¿Qué es el SOP?', 'fr': 'Qu\'est-ce que le SOPK?',
          'ar': 'ما هو تكيس المبايض؟', 'ja': 'PCOSとは何ですか？', 'zh': '什么是多囊卵巢综合征？',
        },
        {
          'en': 'What causes painful periods?',
          'hi': 'दर्दनाक मासिक धर्म के कारण क्या हैं?',
          'bn': 'বেদনাদায়ক মাসিকের কারণ কী?', 'ta': 'வலிமிகுந்த மாதவிடாய்க்கு என்ன காரணம்?',
          'te': 'నొప్పితో కూడిన రుతుక్రమానికి కారణమేమిటి?', 'ur': 'تکلیف دہ ماہواری کے اسباب کیا ہیں؟',
          'es': '¿Qué causa períodos dolorosos?', 'fr': 'Qu\'est-ce qui cause des règles douloureuses?',
          'ar': 'ما سبب الدورة الشهرية المؤلمة؟', 'ja': '生理痛の原因は？', 'zh': '痛经的原因是什么？',
        },
        {
          'en': 'What are signs of endometriosis?',
          'hi': 'एंडोमेट्रियोसिस के संकेत क्या हैं?',
          'bn': 'এন্ডোমেট্রিওসিসের লক্ষণ কী?', 'ta': 'எண்டோமெட்ரியோசிஸின் அறிகுறிகள் என்ன?',
          'te': 'ఎండోమెట్రియోసిస్ సంకేతాలు ఏమిటి?', 'ur': 'اینڈومیٹریوسس کی علامات کیا ہیں؟',
          'es': '¿Cuáles son los signos de endometriosis?', 'fr': 'Quels sont les signes d\'endométriose?',
          'ar': 'ما علامات الانتباذ البطاني الرحمي؟', 'ja': '子宮内膜症の兆候は？', 'zh': '子宫内膜异位症的迹象是什么？',
        },
        {
          'en': 'How long should a normal period last?',
          'hi': 'एक सामान्य मासिक धर्म कितने दिन रहना चाहिए?',
          'bn': 'স্বাভাবিক মাসিক কতদিন স্থায়ী হওয়া উচিত?', 'ta': 'சாதாரண மாதவிடாய் எத்தனை நாட்கள் இருக்க வேண்டும்?',
          'te': 'సాధారణ రుతుక్రమం ఎంతకాలం ఉండాలి?', 'ur': 'عام ماہواری کتنے دن رہنی چاہیے؟',
          'es': '¿Cuánto debe durar un período normal?', 'fr': 'Combien de temps dure un cycle normal?',
          'ar': 'كم يجب أن تستمر الدورة الطبيعية؟', 'ja': '通常の生理はどのくらい続くべきですか？', 'zh': '正常经期应该持续多长时间？',
        },
      ],
    },
    {
      'id': 'mental',
      'icon': '🧠',
      'label': {
        'en': 'Mental Wellness', 'hi': 'मानसिक स्वास्थ्य', 'hinglish': 'Mental Wellness',
        'bn': 'মানসিক স্বাস্থ্য', 'mr': 'मानसिक कल्याण', 'ta': 'மன ஆரோக்கியம்',
        'te': 'మానసిక ఆరోగ్యం', 'gu': 'માનસિક સ્વાસ્થ્ય', 'kn': 'ಮಾನಸಿಕ ಆರೋಗ್ಯ',
        'ml': 'മാനസിക ആരോഗ്യം', 'pa': 'ਮਾਨਸਿਕ ਸਿਹਤ', 'ur': 'ذہنی صحت',
        'es': 'Bienestar Mental', 'fr': 'Bien-être Mental', 'de': 'Psychisches Wohlbefinden',
        'ar': 'الصحة النفسية', 'pt': 'Bem-estar Mental', 'id': 'Kesehatan Mental',
        'ja': 'メンタルウェルネス', 'ko': '정신 건강', 'zh': '心理健康',
      },
      'questions': [
        {
          'en': 'What are signs of postpartum depression?',
          'hi': 'प्रसवोत्तर अवसाद के संकेत क्या हैं?',
          'bn': 'প্রসবোত্তর বিষণ্নতার লক্ষণ কী?', 'ta': 'பிரசவத்திற்கு பிந்தைய மனசோர்வின் அறிகுறிகள்?',
          'te': 'ప్రసవానంతర మాంద్యం సంకేతాలు ఏమిటి?', 'ur': 'زچگی کے بعد ڈپریشن کی علامات کیا ہیں؟',
          'es': '¿Signos de depresión postparto?', 'fr': 'Signes de dépression post-partum?',
          'ar': 'علامات اكتئاب ما بعد الولادة؟', 'ja': '産後うつの兆候は？', 'zh': '产后抑郁的迹象是什么？',
        },
        {
          'en': 'How does anxiety affect women differently?',
          'hi': 'महिलाओं में चिंता अलग कैसे प्रभावित करती है?',
          'bn': 'উদ্বেগ মহিলাদের কীভাবে ভিন্নভাবে প্রভাবিত করে?', 'ta': 'பதட்டம் பெண்களை எவ்வாறு வித்தியாசமாக பாதிக்கிறது?',
          'ur': 'پریشانی خواتین کو مختلف طور پر کیسے متاثر کرتی ہے؟',
          'es': '¿Cómo afecta la ansiedad a las mujeres?', 'ar': 'كيف يؤثر القلق على المرأة بشكل مختلف؟',
          'ja': '不安は女性にどう影響しますか？', 'zh': '焦虑如何对女性产生不同影响？',
        },
        {
          'en': 'Tips for managing stress and burnout?',
          'hi': 'तनाव और बर्नआउट से निपटने के उपाय?',
          'bn': 'স্ট্রেস ও বার্নআউট মোকাবেলার উপায়?', 'ta': 'மன அழுத்தம் மற்றும் சோர்வை நிர்வகிக்கும் குறிப்புகள்?',
          'ur': 'تناؤ اور برن آؤٹ سے نمٹنے کے طریقے؟',
          'es': '¿Consejos para manejar el estrés?', 'ar': 'نصائح لإدارة التوتر والإرهاق؟',
          'ja': 'ストレスと燃え尽き症候群の管理のヒントは？', 'zh': '管理压力和倦怠的建议？',
        },
        {
          'en': 'What are signs of depression in women?',
          'hi': 'महिलाओं में अवसाद के संकेत क्या हैं?',
          'bn': 'মহিলাদের বিষণ্নতার লক্ষণ কী?', 'ta': 'பெண்களில் மனசோர்வின் அறிகுறிகள்?',
          'ur': 'خواتین میں ڈپریشن کی علامات کیا ہیں؟',
          'es': '¿Signos de depresión en mujeres?', 'ar': 'علامات الاكتئاب لدى النساء؟',
          'ja': '女性のうつ病の兆候は？', 'zh': '女性抑郁症的迹象是什么？',
        },
      ],
    },
    {
      'id': 'pregnancy',
      'icon': '🤰',
      'label': {
        'en': 'Pregnancy', 'hi': 'गर्भावस्था', 'hinglish': 'Pregnancy',
        'bn': 'গর্ভাবস্থা', 'mr': 'गर्भधारणा', 'ta': 'கர்ப்பம்',
        'te': 'గర్భం', 'gu': 'ગર્ભાવસ્થા', 'kn': 'ಗರ್ಭಧಾರಣೆ',
        'ml': 'ഗർഭകാലം', 'pa': 'ਗਰਭ ਅਵਸਥਾ', 'ur': 'حمل',
        'es': 'Embarazo', 'fr': 'Grossesse', 'de': 'Schwangerschaft',
        'ar': 'الحمل', 'pt': 'Gravidez', 'id': 'Kehamilan',
        'ja': '妊娠', 'ko': '임신', 'zh': '怀孕',
      },
      'questions': [
        {
          'en': 'What are early signs of pregnancy?',
          'hi': 'गर्भावस्था के शुरुआती संकेत क्या हैं?',
          'bn': 'গর্ভাবস্থার প্রাথমিক লক্ষণ কী?', 'ta': 'கர்ப்பத்தின் ஆரம்ப அறிகுறிகள் என்ன?',
          'ur': 'حمل کی ابتدائی علامات کیا ہیں؟',
          'es': '¿Signos tempranos del embarazo?', 'ar': 'ما هي العلامات المبكرة للحمل؟',
          'ja': '妊娠の初期症状は？', 'zh': '妊娠的早期迹象是什么？',
        },
        {
          'en': 'How much folic acid do I need during pregnancy?',
          'hi': 'गर्भावस्था में कितना फोलिक एसिड चाहिए?',
          'bn': 'গর্ভাবস্থায় কতটুকু ফলিক অ্যাসিড প্রয়োজন?', 'ta': 'கர்ப்பகாலத்தில் எவ்வளவு ஃபோலிக் அமிலம் தேவை?',
          'ur': 'حمل کے دوران کتنی فولک ایسڈ کی ضرورت ہے؟',
          'es': '¿Cuánto ácido fólico necesito?', 'ar': 'كم من حمض الفوليك أحتاج أثناء الحمل؟',
          'ja': '妊娠中に必要な葉酸の量は？', 'zh': '怀孕期间需要多少叶酸？',
        },
        {
          'en': 'What foods should I avoid during pregnancy?',
          'hi': 'गर्भावस्था में कौन से खाद्य पदार्थ से बचें?',
          'bn': 'গর্ভাবস্থায় কোন খাবার এড়ানো উচিত?', 'ta': 'கர்ப்பகாலத்தில் எந்த உணவுகளை தவிர்க்க வேண்டும்?',
          'ur': 'حمل کے دوران کون سے کھانے سے بچیں؟',
          'es': '¿Qué alimentos evitar en el embarazo?', 'ar': 'ما الأطعمة التي يجب تجنبها أثناء الحمل؟',
          'ja': '妊娠中に避けるべき食品は？', 'zh': '怀孕期间应避免哪些食物？',
        },
        {
          'en': 'What is preeclampsia and its warning signs?',
          'hi': 'प्री-एक्लेमप्सिया क्या है और इसके चेतावनी संकेत?',
          'bn': 'প্রিক্ল্যাম্পসিয়া কী এবং এর সতর্কতা লক্ষণ?', 'ta': 'ப்ரீக்ளாம்சியா என்றால் என்ன?',
          'ur': 'پری ایکلیمپسیا کیا ہے؟',
          'es': '¿Qué es la preeclampsia?', 'ar': 'ما هو تسمم الحمل؟',
          'ja': '子癇前症とは何ですか？', 'zh': '子痫前症是什么？',
        },
      ],
    },
    {
      'id': 'menopause',
      'icon': '🌸',
      'label': {
        'en': 'Menopause', 'hi': 'रजोनिवृत्ति', 'hinglish': 'Menopause',
        'bn': 'মেনোপজ', 'mr': 'रजोनिवृत्ती', 'ta': 'மாதவிடாய் நிறுத்தம்',
        'te': 'రుతువిరతి', 'gu': 'મેનોપોઝ', 'kn': 'ಋತುಬಂಧ',
        'ml': 'ആർത്തവവിരാമം', 'pa': 'ਮੇਨੋਪੌਜ਼', 'ur': 'سن یاس',
        'es': 'Menopausia', 'fr': 'Ménopause', 'de': 'Wechseljahre',
        'ar': 'سن اليأس', 'pt': 'Menopausa', 'id': 'Menopause',
        'ja': '更年期', 'ko': '폐경', 'zh': '更年期',
      },
      'questions': [
        {
          'en': 'What are common menopause symptoms?',
          'hi': 'रजोनिवृत्ति के सामान्य लक्षण क्या हैं?',
          'bn': 'মেনোপজের সাধারণ লক্ষণ কী?', 'ta': 'மாதவிடாய் நிறுத்தத்தின் பொதுவான அறிகுறிகள்?',
          'ur': 'سن یاس کی عام علامات کیا ہیں؟',
          'es': '¿Síntomas comunes de la menopausia?', 'ar': 'أعراض انقطاع الطمث الشائعة؟',
          'ja': '更年期の一般的な症状は？', 'zh': '更年期的常见症状是什么？',
        },
        {
          'en': 'What is perimenopause?',
          'hi': 'पेरीमेनोपॉज़ क्या है?',
          'bn': 'পেরিমেনোপজ কী?', 'ta': 'பெரிமெனோபாஸ் என்றால் என்ன?',
          'ur': 'پیری مینوپاز کیا ہے؟',
          'es': '¿Qué es la perimenopausia?', 'ar': 'ما هو فترة ما قبل انقطاع الطمث؟',
          'ja': '更年期前期とは何ですか？', 'zh': '围绝经期是什么？',
        },
        {
          'en': 'How does menopause affect bone health?',
          'hi': 'रजोनिवृत्ति हड्डियों को कैसे प्रभावित करती है?',
          'bn': 'মেনোপজ হাড়ের স্বাস্থ্যকে কীভাবে প্রভাবিত করে?', 'ta': 'மாதவிடாய் நிறுத்தம் எலும்பு ஆரோக்கியத்தை எவ்வாறு பாதிக்கிறது?',
          'ur': 'سن یاس ہڈیوں کی صحت کو کیسے متاثر کرتا ہے؟',
          'es': '¿Cómo afecta la menopausia a la salud ósea?', 'ar': 'كيف تؤثر انقطاع الطمث على صحة العظام؟',
          'ja': '更年期は骨の健康にどう影響しますか？', 'zh': '更年期如何影响骨骼健康？',
        },
        {
          'en': 'What helps with hot flashes?',
          'hi': 'हॉट फ्लैशेज में क्या मदद करता है?',
          'bn': 'হট ফ্ল্যাশে কী সাহায্য করে?', 'ta': 'ஹாட் ஃப்ளாஷ்களுக்கு என்ன உதவும்?',
          'ur': 'ہاٹ فلیشز میں کیا مدد کرتا ہے؟',
          'es': '¿Qué ayuda con los sofocos?', 'ar': 'ما الذي يساعد في الهبات الساخنة؟',
          'ja': 'ほてりに何が効きますか？', 'zh': '什么有助于缓解潮热？',
        },
      ],
    },
    {
      'id': 'sexual_health',
      'icon': '💊',
      'label': {
        'en': 'Sexual Health', 'hi': 'यौन स्वास्थ्य', 'hinglish': 'Sexual Health',
        'bn': 'যৌন স্বাস্থ্য', 'mr': 'लैंगिक आरोग्य', 'ta': 'பாலியல் ஆரோக்கியம்',
        'te': 'లైంగిక ఆరోగ్యం', 'gu': 'જાતીય સ્વાસ્થ્ય', 'kn': 'ಲೈಂಗಿಕ ಆರೋಗ್ಯ',
        'ml': 'ലൈംഗിക ആരോഗ്യം', 'pa': 'ਜਿਨਸੀ ਸਿਹਤ', 'ur': 'جنسی صحت',
        'es': 'Salud Sexual', 'fr': 'Santé Sexuelle', 'de': 'Sexuelle Gesundheit',
        'ar': 'الصحة الجنسية', 'pt': 'Saúde Sexual', 'id': 'Kesehatan Seksual',
        'ja': '性の健康', 'ko': '성 건강', 'zh': '性健康',
      },
      'questions': [
        {
          'en': 'What are common STI symptoms in women?',
          'hi': 'महिलाओं में यौन संचारित संक्रमण के लक्षण क्या हैं?',
          'bn': 'মহিলাদের মধ্যে STI-এর সাধারণ লক্ষণ কী?', 'ta': 'பெண்களில் பாலியல் நோய்களின் அறிகுறிகள்?',
          'ur': 'خواتین میں STI کی عام علامات کیا ہیں؟',
          'es': '¿Síntomas comunes de ITS en mujeres?', 'ar': 'أعراض الأمراض المنقولة جنسياً الشائعة؟',
          'ja': '女性のSTIの一般的な症状は？', 'zh': '女性STI常见症状是什么？',
        },
        {
          'en': 'What birth control options are available?',
          'hi': 'कौन से गर्भनिरोधक विकल्प उपलब्ध हैं?',
          'bn': 'কোন জন্মনিয়ন্ত্রণ পদ্ধতি উপলব্ধ?', 'ta': 'என்ன கருத்தடை விருப்பங்கள் உள்ளன?',
          'ur': 'کون سے مانع حمل اختیارات دستیاب ہیں؟',
          'es': '¿Qué métodos anticonceptivos hay?', 'ar': 'ما هي خيارات تنظيم النسل المتاحة؟',
          'ja': 'どんな避妊方法がありますか？', 'zh': '有哪些避孕方式？',
        },
        {
          'en': 'What is bacterial vaginosis?',
          'hi': 'बैक्टीरियल वेजिनोसिस क्या है?',
          'bn': 'ব্যাকটেরিয়াল ভ্যাজিনোসিস কী?', 'ta': 'பாக்டீரியல் வஜினோசிஸ் என்றால் என்ன?',
          'ur': 'بیکٹیریل وجینوسس کیا ہے؟',
          'es': '¿Qué es la vaginosis bacteriana?', 'ar': 'ما هو داء المهبل الجرثومي؟',
          'ja': '細菌性膣炎とは何ですか？', 'zh': '细菌性阴道病是什么？',
        },
        {
          'en': 'How is HPV prevented and treated?',
          'hi': 'HPV की रोकथाम और उपचार कैसे किया जाता है?',
          'bn': 'HPV কীভাবে প্রতিরোধ ও চিকিৎসা করা হয়?', 'ta': 'HPV எவ்வாறு தடுக்கப்படுகிறது?',
          'ur': 'HPV کو کیسے روکا اور علاج کیا جاتا ہے؟',
          'es': '¿Cómo se previene y trata el VPH?', 'ar': 'كيف يمكن الوقاية من فيروس الورم الحليمي البشري؟',
          'ja': 'HPVの予防と治療は？', 'zh': 'HPV如何预防和治疗？',
        },
      ],
    },
    {
      'id': 'nutrition',
      'icon': '🥗',
      'label': {
        'en': 'Nutrition & Fitness', 'hi': 'पोषण और फिटनेस', 'hinglish': 'Nutrition & Fitness',
        'bn': 'পুষ্টি ও ফিটনেস', 'mr': 'पोषण आणि फिटनेस', 'ta': 'ஊட்டச்சத்து மற்றும் உடற்பயிற்சி',
        'te': 'పోషణ మరియు ఫిట్‌నెస్', 'gu': 'પોષણ અને ફિટનેસ', 'kn': 'ಪೋಷಣೆ ಮತ್ತು ಫಿಟ್ನೆಸ್',
        'ml': 'പോഷണവും ഫിറ്റ്നസും', 'pa': 'ਪੋਸ਼ਣ ਅਤੇ ਤੰਦਰੁਸਤੀ', 'ur': 'غذائیت اور فٹنس',
        'es': 'Nutrición y Fitness', 'fr': 'Nutrition et Forme', 'de': 'Ernährung und Fitness',
        'ar': 'التغذية واللياقة', 'pt': 'Nutrição e Fitness', 'id': 'Nutrisi & Kebugaran',
        'ja': '栄養とフィットネス', 'ko': '영양 및 피트니스', 'zh': '营养与健身',
      },
      'questions': [
        {
          'en': 'What nutrients do women need most?',
          'hi': 'महिलाओं को किन पोषक तत्वों की सबसे अधिक जरूरत है?',
          'bn': 'মহিলাদের সবচেয়ে বেশি কোন পুষ্টি প্রয়োজন?', 'ta': 'பெண்களுக்கு எந்த ஊட்டச்சத்துகள் மிகவும் தேவை?',
          'ur': 'خواتین کو کن غذائی اجزاء کی سب سے زیادہ ضرورت ہے؟',
          'es': '¿Qué nutrientes necesitan más las mujeres?', 'ar': 'ما العناصر الغذائية التي تحتاجها المرأة أكثر؟',
          'ja': '女性が最も必要とする栄養素は？', 'zh': '女性最需要哪些营养素？',
        },
        {
          'en': 'How does iron deficiency affect women?',
          'hi': 'आयरन की कमी महिलाओं को कैसे प्रभावित करती है?',
          'bn': 'আয়রনের অভাব মহিলাদের কীভাবে প্রভাবিত করে?', 'ta': 'இரும்புச்சத்து குறைபாடு பெண்களை எவ்வாறு பாதிக்கிறது?',
          'ur': 'آئرن کی کمی خواتین کو کیسے متاثر کرتی ہے؟',
          'es': '¿Cómo afecta la deficiencia de hierro a las mujeres?', 'ar': 'كيف يؤثر نقص الحديد على المرأة؟',
          'ja': '鉄欠乏は女性にどう影響しますか？', 'zh': '缺铁如何影响女性？',
        },
        {
          'en': 'Tips for staying active during periods?',
          'hi': 'मासिक धर्म के दौरान सक्रिय रहने के उपाय?',
          'bn': 'মাসিকের সময় সক্রিয় থাকার টিপস?', 'ta': 'மாதவிடாய் காலத்தில் சுறுசுறுப்பாக இருக்க குறிப்புகள்?',
          'ur': 'ماہواری کے دوران متحرک رہنے کے طریقے؟',
          'es': '¿Consejos para mantenerse activa durante el período?', 'ar': 'نصائح للبقاء نشيطة أثناء الدورة؟',
          'ja': '生理中に活動的でいるためのヒント？', 'zh': '经期保持活跃的建议？',
        },
        {
          'en': 'What is a healthy weight for women?',
          'hi': 'महिलाओं के लिए स्वस्थ वजन क्या है?',
          'bn': 'মহিলাদের জন্য স্বাস্থ্যকর ওজন কত?', 'ta': 'பெண்களுக்கு ஆரோக்கியமான எடை என்ன?',
          'ur': 'خواتین کے لیے صحت مند وزن کیا ہے؟',
          'es': '¿Cuál es el peso saludable para mujeres?', 'ar': 'ما هو الوزن الصحي للمرأة؟',
          'ja': '女性の健康的な体重は？', 'zh': '女性健康体重是多少？',
        },
      ],
    },
    {
      'id': 'cancer',
      'icon': '🎗️',
      'label': {
        'en': 'Cancer Screening', 'hi': 'कैंसर जांच', 'hinglish': 'Cancer Screening',
        'bn': 'ক্যান্সার স্ক্রিনিং', 'mr': 'कर्करोग तपासणी', 'ta': 'புற்றுநோய் பரிசோதனை',
        'te': 'క్యాన్సర్ స్క్రీనింగ్', 'gu': 'કેન્સર સ્ક્રીનિંગ', 'kn': 'ಕ್ಯಾನ್ಸರ್ ತಪಾಸಣೆ',
        'ml': 'ക്യാൻസർ സ്ക്രീനിംഗ്', 'pa': 'ਕੈਂਸਰ ਜਾਂਚ', 'ur': 'کینسر اسکریننگ',
        'es': 'Detección de Cáncer', 'fr': 'Dépistage du Cancer', 'de': 'Krebsvorsorge',
        'ar': 'فحص السرطان', 'pt': 'Rastreio de Cancro', 'id': 'Skrining Kanker',
        'ja': 'がん検診', 'ko': '암 검진', 'zh': '癌症筛查',
      },
      'questions': [
        {
          'en': 'When should I get a Pap smear?',
          'hi': 'पैप स्मीयर कब करानी चाहिए?',
          'bn': 'কখন প্যাপ স্মিয়ার করা উচিত?', 'ta': 'பாப் ஸ்மியர் எப்போது செய்ய வேண்டும்?',
          'ur': 'پیپ سمیر کب کروانی چاہیے؟',
          'es': '¿Cuándo hacerse una citología?', 'ar': 'متى يجب إجراء مسحة عنق الرحم؟',
          'ja': '子宮頸がん検査はいつ受けるべきですか？', 'zh': '什么时候应该做宫颈涂片检查？',
        },
        {
          'en': 'What are symptoms of ovarian cancer?',
          'hi': 'डिम्बग्रंथि कैंसर के लक्षण क्या हैं?',
          'bn': 'ডিম্বাশয়ের ক্যান্সারের লক্ষণ কী?', 'ta': 'கர்ப்பப்பை புற்றுநோயின் அறிகுறிகள்?',
          'ur': 'رحم کے کینسر کی علامات کیا ہیں؟',
          'es': '¿Síntomas del cáncer de ovario?', 'ar': 'أعراض سرطان المبيض؟',
          'ja': '卵巣がんの症状は？', 'zh': '卵巢癌的症状是什么？',
        },
        {
          'en': 'How do I do a breast self-exam?',
          'hi': 'स्तन स्व-परीक्षण कैसे करें?',
          'bn': 'স্তন স্ব-পরীক্ষা কীভাবে করবেন?', 'ta': 'மார்பக சுய பரிசோதனை எப்படி செய்வது?',
          'ur': 'چھاتی کی خود جانچ کیسے کریں؟',
          'es': '¿Cómo hacer un autoexamen de seno?', 'ar': 'كيف أجري فحصاً ذاتياً للثدي؟',
          'ja': '乳房の自己検査はどうやって行いますか？', 'zh': '如何进行乳房自我检查？',
        },
        {
          'en': 'What is cervical cancer risk and prevention?',
          'hi': 'सर्वाइकल कैंसर का खतरा और बचाव क्या है?',
          'bn': 'জরায়ু ক্যান্সারের ঝুঁকি ও প্রতিরোধ কী?', 'ta': 'கர்ப்பப்பை வாய் புற்றுநோய் ஆபத்து மற்றும் தடுப்பு?',
          'ur': 'سروائیکل کینسر کا خطرہ اور بچاؤ؟',
          'es': '¿Riesgo y prevención del cáncer cervical?', 'ar': 'خطر سرطان عنق الرحم والوقاية منه؟',
          'ja': '子宮頸がんのリスクと予防は？', 'zh': '宫颈癌风险和预防？',
        },
      ],
    },
    {
      'id': 'chronic',
      'icon': '💙',
      'label': {
        'en': 'Chronic Conditions', 'hi': 'दीर्घकालिक स्थितियाँ', 'hinglish': 'Chronic Conditions',
        'bn': 'দীর্ঘমেয়াদী রোগ', 'mr': 'दीर्घकालीन आजार', 'ta': 'நீண்டகால நோய்கள்',
        'te': 'దీర్ఘకాలిక పరిస్థితులు', 'gu': 'ક્રોનિક સ્થિતિઓ', 'kn': 'ದೀರ್ಘಕಾಲಿಕ ಪರಿಸ್ಥಿತಿಗಳು',
        'ml': 'വിട്ടുമാറാത്ത രോഗങ്ങൾ', 'pa': 'ਲੰਮੇ ਸਮੇਂ ਦੀਆਂ ਬਿਮਾਰੀਆਂ', 'ur': 'دائمی بیماریاں',
        'es': 'Condiciones Crónicas', 'fr': 'Maladies Chroniques', 'de': 'Chronische Erkrankungen',
        'ar': 'الأمراض المزمنة', 'pt': 'Condições Crónicas', 'id': 'Kondisi Kronis',
        'ja': '慢性疾患', 'ko': '만성 질환', 'zh': '慢性病',
      },
      'questions': [
        {
          'en': 'What is fibromyalgia and how does it affect women?',
          'hi': 'फाइब्रोमायल्जिया क्या है और यह महिलाओं को कैसे प्रभावित करता है?',
          'bn': 'ফাইব্রোমায়ালজিয়া কী এবং এটি মহিলাদের কীভাবে প্রভাবিত করে?',
          'ta': 'ஃபைப்ரோமயால்ஜியா என்றால் என்ன?',
          'ur': 'فائبرومیالجیا کیا ہے؟',
          'es': '¿Qué es la fibromialgia?', 'ar': 'ما هو الفيبروميالغيا؟',
          'ja': '線維筋痛症とは何ですか？', 'zh': '纤维肌痛症是什么？',
        },
        {
          'en': 'How does lupus affect women differently?',
          'hi': 'ल्यूपस महिलाओं को अलग तरह से कैसे प्रभावित करता है?',
          'bn': 'লুপাস মহিলাদের কীভাবে ভিন্নভাবে প্রভাবিত করে?',
          'ta': 'லூபஸ் பெண்களை எவ்வாறு வித்தியாசமாக பாதிக்கிறது?',
          'ur': 'لوپس خواتین کو کیسے مختلف طریقے سے متاثر کرتا ہے؟',
          'es': '¿Cómo afecta el lupus a las mujeres?', 'ar': 'كيف يؤثر مرض الذئبة على المرأة؟',
          'ja': 'ループスは女性にどう影響しますか？', 'zh': '狼疮如何对女性产生不同影响？',
        },
        {
          'en': 'What are symptoms of thyroid disease?',
          'hi': 'थायरॉइड रोग के लक्षण क्या हैं?',
          'bn': 'থাইরয়েড রোগের লক্ষণ কী?', 'ta': 'தைராய்டு நோயின் அறிகுறிகள் என்ன?',
          'ur': 'تھائیرائیڈ بیماری کی علامات کیا ہیں؟',
          'es': '¿Síntomas de enfermedad tiroidea?', 'ar': 'أعراض أمراض الغدة الدرقية؟',
          'ja': '甲状腺疾患の症状は？', 'zh': '甲状腺疾病的症状是什么？',
        },
        {
          'en': 'How \'does diabetes affect women\'s health?',
          'hi': 'मधुमेह महिलाओं के स्वास्थ्य को कैसे प्रभावित करता है?',
          'bn': 'ডায়াবেটিস মহিলাদের স্বাস্থ্যকে কীভাবে প্রভাবিত করে?',
          'ta': 'நீரிழிவு நோய் பெண்களின் ஆரோக்கியத்தை எவ்வாறு பாதிக்கிறது?',
          'ur': 'ذیابیطس خواتین کی صحت کو کیسے متاثر کرتی ہے؟',
          'es': '¿Cómo afecta la diabetes a la salud de la mujer?', 'ar': 'كيف يؤثر السكري على صحة المرأة؟',
          'ja': '糖尿病は女性の健康にどう影響しますか？', 'zh': '糖尿病如何影响女性健康？',
        },
      ],
    },
  ];

  /// Returns topics with labels/questions translated to current language.
  List<Map<String, dynamic>> getTopics() {
    return _topicsData.map((topic) {
      final label = (topic['label'] as Map<String, dynamic>)[_language]
          ?? (topic['label'] as Map<String, dynamic>)['en'];
      final questions = (topic['questions'] as List).map((q) {
        return (q as Map<String, dynamic>)[_language] ?? q['en'];
      }).toList();
      return {
        'id': topic['id'],
        'icon': topic['icon'],
        'label': label,
        'questions': questions,
      };
    }).toList();
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