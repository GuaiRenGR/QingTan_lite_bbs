import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AppLogger {
  static File? _file;
  static bool _initialized = false;
  static const int _maxBytes = 1024 * 512;

  static Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${dir.path}/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _file = File('${logDir.path}/qingtan.log');
    _initialized = true;
    await _trim();
    await _write('AppLogger', '初始化完成');
  }

  static Future<void> log(String tag, String message) async {
    if (!_initialized) return;
    await _write(tag, message);
  }

  static Future<void> _write(String tag, String message) async {
    try {
      final line = '[${DateTime.now()}] [$tag] $message\n';
      await _file!.writeAsString(line, mode: FileMode.append);
    } catch (_) {}
  }

  static Future<void> _trim() async {
    try {
      if (await _file!.exists() && await _file!.length() > _maxBytes) {
        await _file!.writeAsString('');
      }
    } catch (_) {}
  }
}
