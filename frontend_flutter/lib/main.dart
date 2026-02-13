import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'core/storage/hive_service.dart';
import 'state/chat_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ChatController(),
      child: const AuroraApp(),
    ),
  );
}
