import 'package:flutter/material.dart';
import 'package:frontend_flutter/core/tts/tts_service.dart';
import 'package:frontend_flutter/state/theme_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/storage/hive_service.dart';
import 'state/chat_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  await TtsService.instance.init();
  
  final prefs     = await SharedPreferences.getInstance();
  final savedLang = prefs.getString('aurora_language') ?? 'en';
  final themeMode = await ThemeController.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeController(initial: themeMode),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatController(initialLanguage: savedLang),
        ),
      ],
      child: const AuroraApp(),
    ),
  );
}