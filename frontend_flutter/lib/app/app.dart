import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/chat_controller.dart';
import '../features/chat/chat_history_screen.dart';
import '../theme/app_theme.dart';

class AuroraApp extends StatelessWidget {
  const AuroraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatController(),
      child: MaterialApp(
        title: 'Aurora',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const ChatHistoryScreen(),
      ),
    );
  }
}
