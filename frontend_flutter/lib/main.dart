import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/storage/hive_service.dart';
import 'state/chat_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();

  // ✅ Load saved language BEFORE app starts — no race condition
  final prefs       = await SharedPreferences.getInstance();
  final savedLang   = prefs.getString('aurora_language') ?? 'en';

  runApp(
    ChangeNotifierProvider(
      create: (_) => ChatController(initialLanguage: savedLang),
      child: const AuroraApp(),
    ),
  );
}