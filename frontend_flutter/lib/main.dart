import 'package:flutter/material.dart';
import 'package:frontend_flutter/app/app.dart';
import 'package:frontend_flutter/core/storage/hive_service.dart';

Future<void> main() async {
  await HiveService.init();
  runApp(const AuroraApp());
}
