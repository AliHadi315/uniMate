import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'db/db_provider.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop builds need the FFI sqlite factory before any query runs.
  DatabaseProvider.initFfiIfNeeded();

  // A missing .env must not stop the app from starting; the AI screen reports
  // the missing key on its own.
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('No .env loaded ($e) — AI features will be disabled.');
  }

  await NotificationService.instance.init();

  runApp(const UniMateApp());
}
