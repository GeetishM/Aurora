import 'package:flutter/material.dart';
import 'package:frontend_flutter/state/theme_controller.dart';
import 'package:provider/provider.dart';

import '../features/chat/chat_history_screen.dart';
import '../theme/app_theme.dart';

class AuroraApp extends StatelessWidget {
  const AuroraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeController>().mode;

    return MaterialApp(
      title: 'Aurora',
      debugShowCheckedModeBanner: false,
      theme:      AppTheme.lightTheme,
      darkTheme:  AppTheme.darkTheme,
      themeMode:  themeMode,
      home: const ChatHistoryScreen(),
    );
  }
}