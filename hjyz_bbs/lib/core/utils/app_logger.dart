import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppLogger {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${dir.path}/logs');
      if (await logDir.exists()) await logDir.delete(recursive: true);
    } catch (_) {}
  }

  static Future<void> log(String tag, String message) async {
    // Intentionally disabled. Requests may contain sensitive configuration.
  }

}
