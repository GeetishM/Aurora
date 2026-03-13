import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ServerConfig {
  static String get httpBase {
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    if (Platform.isIOS) return 'http://localhost:8000';
    return 'http://localhost:8000';
  }

  static String get wsBase {
    if (kIsWeb) return 'ws://localhost:8000';
    if (Platform.isAndroid) return 'ws://10.0.2.2:8000';
    if (Platform.isIOS) return 'ws://localhost:8000';
    return 'ws://localhost:8000';
  }
}