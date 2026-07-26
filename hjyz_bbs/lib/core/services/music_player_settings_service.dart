import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicPlayerVisualSettings {
  final bool advancedBlur;
  final bool musicReactive;
  final bool dynamicBackground;

  const MusicPlayerVisualSettings({
    this.advancedBlur = false,
    this.musicReactive = false,
    this.dynamicBackground = false,
  });

  MusicPlayerVisualSettings copyWith({
    bool? advancedBlur,
    bool? musicReactive,
    bool? dynamicBackground,
  }) {
    return MusicPlayerVisualSettings(
      advancedBlur: advancedBlur ?? this.advancedBlur,
      musicReactive: musicReactive ?? this.musicReactive,
      dynamicBackground: dynamicBackground ?? this.dynamicBackground,
    );
  }
}

class MusicPlayerSettingsService {
  MusicPlayerSettingsService._();

  static const _advancedBlurKey = 'music_player_advanced_blur';
  static const _musicReactiveKey = 'music_player_music_reactive';
  static const _dynamicBackgroundKey = 'music_player_dynamic_background';

  static final settings = ValueNotifier<MusicPlayerVisualSettings>(
    const MusicPlayerVisualSettings(),
  );

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      settings.value = MusicPlayerVisualSettings(
        advancedBlur: prefs.getBool(_advancedBlurKey) ?? false,
        musicReactive: prefs.getBool(_musicReactiveKey) ?? false,
        dynamicBackground: prefs.getBool(_dynamicBackgroundKey) ?? false,
      );
    } catch (_) {}
  }

  static Future<void> setAdvancedBlur(bool value) async {
    settings.value = settings.value.copyWith(advancedBlur: value);
    await _save(_advancedBlurKey, value);
  }

  static Future<void> setMusicReactive(bool value) async {
    settings.value = settings.value.copyWith(musicReactive: value);
    await _save(_musicReactiveKey, value);
  }

  static Future<void> setDynamicBackground(bool value) async {
    settings.value = settings.value.copyWith(dynamicBackground: value);
    await _save(_dynamicBackgroundKey, value);
  }

  static Future<void> _save(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }
}
