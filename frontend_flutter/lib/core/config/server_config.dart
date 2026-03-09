import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ServerConfig {
  // ── Set your laptop's hotspot IP here ─────────────────────────────────────
  static const bool _useRealPhone = true; 
  static const String _hotspotIp = '172.31.243.93'; // 

  // ── HTTP base (used for /translate and /api/transcribe) ───────────────────
  static String get httpBase {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) {
      if (_useRealPhone) return 'http://$_hotspotIp:8000';
      return 'http://10.0.2.2:8000'; // emulator
    }
    if (Platform.isIOS)     return 'http://$_hotspotIp:8000';
    return 'http://localhost:8000'; // Windows / Linux desktop
  }

  // ── WebSocket base (used for /ws/chat) ────────────────────────────────────
  static String get wsBase {
    if (kIsWeb)             return 'ws://localhost:8000';
    if (Platform.isAndroid) return 'ws://$_hotspotIp:8000';
    if (Platform.isIOS)     return 'ws://$_hotspotIp:8000';
    return 'ws://localhost:8000';
  }
}
