import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SensitiveContentMode { warn, block }

class SensitiveContentService {
  SensitiveContentService._();

  static const preferenceKey = 'sensitive_content_mode';
  static final mode = ValueNotifier<SensitiveContentMode>(
    SensitiveContentMode.warn,
  );

  static Future<void> init() async {
    final preferences = await SharedPreferences.getInstance();
    mode.value = preferences.getString(preferenceKey) == 'block'
        ? SensitiveContentMode.block
        : SensitiveContentMode.warn;
  }

  static Future<void> setMode(SensitiveContentMode value) async {
    mode.value = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      preferenceKey,
      value == SensitiveContentMode.block ? 'block' : 'warn',
    );
  }
}
