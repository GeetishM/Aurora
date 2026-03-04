import 'package:flutter/material.dart';
import '../features/chat/chat_history_screen.dart';
import '../theme/app_theme.dart';

// Provider is already created in main.dart — do NOT add another one here.
class AuroraApp extends StatelessWidget {
  const AuroraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aurora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const ChatHistoryScreen(),
    );
  }
}