import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeColorChoice {
  final String id;
  final String label;
  final Color color;

  const ThemeColorChoice(this.id, this.label, this.color);
}

class ThemeColorService {
  ThemeColorService._();

  static const _preferenceKey = 'theme_color';

  static const choices = <ThemeColorChoice>[
    ThemeColorChoice('pink', '轻坛粉', Color(0xFFFB7299)),
    ThemeColorChoice('md3_blue', 'MD3 经典蓝', Color(0xFF415F91)),
    ThemeColorChoice('green', '翡翠绿', Color(0xFF198754)),
    ThemeColorChoice('orange', '活力橙', Color(0xFFF57C00)),
    ThemeColorChoice('red', '珊瑚红', Color(0xFFD64545)),
    ThemeColorChoice('violet', '罗兰紫', Color(0xFF7655A6)),
  ];

  static final selected = ValueNotifier<ThemeColorChoice>(choices.first);

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_preferenceKey);
      selected.value = choices.firstWhere(
        (choice) => choice.id == id,
        orElse: () => choices.first,
      );
    } catch (_) {}
  }

  static Future<void> select(ThemeColorChoice choice) async {
    if (selected.value.id == choice.id) return;
    selected.value = choice;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preferenceKey, choice.id);
    } catch (_) {}
  }
}
